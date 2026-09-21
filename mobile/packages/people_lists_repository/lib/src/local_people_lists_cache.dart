// ABOUTME: Hive-backed local cache for NIP-51 kind 30000 people lists.
// ABOUTME: Scopes entries by owner pubkey and enforces deletion tombstones;
// ABOUTME: also mirrors the public lists a viewer follows, scoped by viewer.

import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:models/models.dart';
import 'package:people_lists_repository/src/people_list_search_result.dart';
import 'package:unified_logger/unified_logger.dart';

/// Key prefix constants and JSON field names for the Hive box.
abstract class _CacheKeys {
  static const String listPrefix = 'list:';
  static const String deletedPrefix = 'deleted:';
  static const String followedPrefix = 'followed:';
  static const String keySeparator = ':';

  static const String ownerPubkey = 'ownerPubkey';
  static const String list = 'list';
  static const String receivedAtMillis = 'receivedAtMillis';
  static const String sourceTags = 'sourceTags';
  static const String sourceContent = 'sourceContent';
  static const String deletedAtMillis = 'deletedAtMillis';
}

/// Logger name used for cache-level diagnostic log entries.
const String _logName = 'people_lists_repository.local_cache';

/// A cached display model and, when available, its complete publish source.
///
/// Rows written before source preservation have no [sourceTags] or
/// [sourceContent]. They remain readable for display but must not be used as
/// the base of a replaceable-event publish.
class CachedPeopleListRecord {
  /// Creates a decoded cache record.
  const CachedPeopleListRecord({
    required this.list,
    this.sourceTags,
    this.sourceContent,
  });

  /// The display model consumed by repository clients.
  final UserList list;

  /// Exact ordered tags of the event represented by [list].
  final List<List<String>>? sourceTags;

  /// Exact content of the event represented by [list].
  final String? sourceContent;

  /// Whether this record can safely drive a complete replacement publish.
  bool get hasPublishSource => sourceTags != null && sourceContent != null;
}

/// Local cache for kind 30000 people lists, scoped by owner pubkey.
///
/// The cache stores list records under keys of the form
/// `list:<ownerPubkey>:<listId>` and deletion tombstones under
/// `deleted:<ownerPubkey>:<listId>`. A tombstone hides a list when
/// `deletedAtMillis >= list.updatedAt.millisecondsSinceEpoch`; a recreated
/// list with a newer `updatedAt` can beat the tombstone and become visible
/// again.
///
/// A public list somebody else owns, followed by a viewer, has a copy under
/// `followed:<viewerPubkey>:<ownerPubkey>:<listId>`, kept apart from the
/// owner's `list:` rows so following a list can never surface it among the
/// lists that owner's account edits. A row there is only a mirror to show the
/// list and read its members from. Whether the list is followed is recorded
/// elsewhere, in a `FollowedPeopleListsStore`: this box is a relay mirror a
/// cache reset may wipe, and a follow has nowhere to be rebuilt from.
class LocalPeopleListsCache {
  /// Creates a cache that lazily opens the backing Hive box via [openBox].
  ///
  /// The opener is invoked once successfully per cache instance; subsequent
  /// calls reuse the cached [Box]. Failed opens are not cached so callers can
  /// retry after storage becomes available.
  LocalPeopleListsCache({required Future<Box<dynamic>> Function() openBox})
    : _openBox = openBox;

  final Future<Box<dynamic>> Function() _openBox;
  Future<Box<dynamic>>? _boxFuture;

  Future<Box<dynamic>> _box() {
    final cached = _boxFuture;
    if (cached != null) return cached;

    final opening = _openBox();
    _boxFuture = opening;

    return opening.onError<Object>((error, stackTrace) {
      if (identical(_boxFuture, opening)) {
        _boxFuture = null;
      }
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  /// Returns all non-tombstoned lists owned by [ownerPubkey], sorted by
  /// `updatedAt` descending.
  ///
  /// Throws any error raised by the injected box opener (for example if the
  /// Hive box cannot be opened). Malformed individual rows are logged via
  /// `dart:developer` and skipped; they do not cause the call to throw.
  Future<List<UserList>> readLists({required String ownerPubkey}) async {
    final box = await _box();
    return _collectLists(box, ownerPubkey);
  }

  /// Returns one non-tombstoned cache record, including its publish source.
  ///
  /// A row written before source preservation, or one whose stored source no
  /// longer matches its list, comes back with
  /// [CachedPeopleListRecord.hasPublishSource] false rather than as `null`.
  Future<CachedPeopleListRecord?> readRecord({
    required String ownerPubkey,
    required String listId,
  }) async {
    final box = await _box();
    final raw = box.get(_listKey(ownerPubkey, listId));
    if (raw is! Map) return null;
    final record = _decodeRecord(raw);
    if (record == null) return null;
    final tombstoneMillis = _tombstoneMillis(box, ownerPubkey, listId);
    if (tombstoneMillis != null &&
        tombstoneMillis >= record.list.updatedAt.millisecondsSinceEpoch) {
      return null;
    }
    return record;
  }

  /// Emits the current lists for [ownerPubkey] immediately, then re-emits on
  /// each box mutation that affects this owner.
  ///
  /// If opening the Hive box fails, the error is forwarded onto the returned
  /// stream. Malformed individual rows are logged and skipped; they do not
  /// terminate the stream.
  Stream<List<UserList>> watchLists({required String ownerPubkey}) {
    return _watch(
      affects: (key) => _keyBelongsToOwner(key, ownerPubkey),
      collect: (box) => _collectLists(box, ownerPubkey),
    );
  }

  /// Emits [collect] over the box immediately, then again after each box
  /// mutation whose key [affects] accepts.
  Stream<List<T>> _watch<T>({
    required bool Function(String key) affects,
    required List<T> Function(Box<dynamic> box) collect,
  }) {
    late StreamController<List<T>> controller;
    StreamSubscription<BoxEvent>? subscription;

    Future<void> start() async {
      try {
        final box = await _box();
        if (controller.isClosed) return;
        controller.add(collect(box));
        subscription = box.watch().listen((event) {
          final key = event.key;
          if (key is! String || !affects(key)) return;
          controller.add(collect(box));
        });
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      }
    }

    controller = StreamController<List<T>>(
      onListen: () {
        unawaited(start());
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  /// Persists [list] for [ownerPubkey] unless a tombstone with a later or
  /// equal timestamp already exists. [receivedAt] is stored alongside the
  /// record for diagnostics and future sync logic.
  ///
  /// [sourceTags] and [sourceContent] are the exact tags and content of the
  /// event [list] was decoded from. Supply both to keep the row editable: a
  /// membership edit republishes from them, so a row stored without them can
  /// be displayed but not edited. This write replaces the whole row, so
  /// omitting them discards a source the row already carried.
  ///
  /// Throws:
  ///
  /// * [ArgumentError] if exactly one of [sourceTags] and [sourceContent] is
  ///   supplied. They are both-or-neither.
  /// * Whatever opening the Hive box or the underlying write throws.
  Future<void> putList({
    required String ownerPubkey,
    required UserList list,
    required DateTime receivedAt,
    List<List<String>>? sourceTags,
    String? sourceContent,
  }) async {
    if ((sourceTags == null) != (sourceContent == null)) {
      throw ArgumentError(
        'sourceTags and sourceContent must both be present or both be absent',
      );
    }
    final box = await _box();
    final tombstoneMillis = _tombstoneMillis(box, ownerPubkey, list.id);
    if (tombstoneMillis != null &&
        tombstoneMillis >= list.updatedAt.millisecondsSinceEpoch) {
      return;
    }
    await box.put(_listKey(ownerPubkey, list.id), <String, dynamic>{
      _CacheKeys.ownerPubkey: ownerPubkey,
      _CacheKeys.list: list.toJson(),
      _CacheKeys.receivedAtMillis: receivedAt.millisecondsSinceEpoch,
      if (sourceTags != null)
        _CacheKeys.sourceTags: [
          for (final tag in sourceTags) List<String>.of(tag),
        ],
      _CacheKeys.sourceContent: ?sourceContent,
    });
  }

  /// Persists every entry in [lists] via [putList], sharing the same
  /// [receivedAt] timestamp.
  ///
  /// Passes no publish source, so every row written here is display-only and
  /// membership edits on it fail closed until a relay revision restores the
  /// source. Prefer [putList] with the originating event's tags and content
  /// for anything the user can edit.
  ///
  /// Throws if the Hive box cannot be opened or any underlying write fails.
  /// A partial failure leaves previously written entries in the box.
  Future<void> putLists({
    required String ownerPubkey,
    required Iterable<UserList> lists,
    required DateTime receivedAt,
  }) async {
    for (final list in lists) {
      await putList(
        ownerPubkey: ownerPubkey,
        list: list,
        receivedAt: receivedAt,
      );
    }
  }

  /// Records a tombstone for [listId] at [deletedAt] and removes any existing
  /// list record whose `updatedAt` is older than or equal to [deletedAt].
  ///
  /// A later recreation with a strictly newer `updatedAt` will replace the
  /// tombstone when written via [putList].
  ///
  /// Throws if the Hive box cannot be opened or an underlying write fails.
  Future<void> markDeleted({
    required String ownerPubkey,
    required String listId,
    required DateTime deletedAt,
  }) async {
    final box = await _box();
    final deletedMillis = deletedAt.millisecondsSinceEpoch;
    await box.put(_deletedKey(ownerPubkey, listId), <String, dynamic>{
      _CacheKeys.ownerPubkey: ownerPubkey,
      _CacheKeys.deletedAtMillis: deletedMillis,
    });

    final listKey = _listKey(ownerPubkey, listId);
    final existing = box.get(listKey);
    if (existing is Map) {
      final record = _decodeRecord(existing);
      if (record != null &&
          record.list.updatedAt.millisecondsSinceEpoch <= deletedMillis) {
        await box.delete(listKey);
      }
    }
  }

  /// Removes every list record and tombstone owned by [ownerPubkey].
  ///
  /// Throws if the Hive box cannot be opened or the bulk delete fails.
  Future<void> clearOwner({required String ownerPubkey}) async {
    final box = await _box();
    final keysToDelete = box.keys
        .whereType<String>()
        .where((key) => _keyBelongsToOwner(key, ownerPubkey))
        .toList(growable: false);
    if (keysToDelete.isEmpty) {
      return;
    }
    await box.deleteAll(keysToDelete);
  }

  /// Returns the stored copies of the public lists [viewerPubkey] follows,
  /// ordered by addressable id.
  ///
  /// Throws any error raised by the injected box opener. Malformed rows are
  /// logged and skipped.
  Future<List<PeopleListSearchResult>> readFollowedCopies({
    required String viewerPubkey,
  }) async {
    final box = await _box();
    return _collectFollowedCopies(box, viewerPubkey);
  }

  /// Emits [viewerPubkey]'s followed-list copies immediately, then re-emits
  /// whenever one is written or removed.
  ///
  /// The box is shared by name across cache instances, so a copy written
  /// through one instance reaches a listener holding another.
  Stream<List<PeopleListSearchResult>> watchFollowedCopies({
    required String viewerPubkey,
  }) {
    return _watch(
      affects: (key) => _isFollowedKey(key, viewerPubkey),
      collect: (box) => _collectFollowedCopies(box, viewerPubkey),
    );
  }

  /// Stores [list], published by [ownerPubkey], as the copy [viewerPubkey]
  /// follows, replacing any copy already held.
  ///
  /// Throws if the Hive box cannot be opened or the write fails.
  Future<void> putFollowedCopy({
    required String viewerPubkey,
    required String ownerPubkey,
    required UserList list,
  }) async {
    final box = await _box();
    await box.put(
      _followedKey(viewerPubkey, ownerPubkey, list.id),
      _followedRow(ownerPubkey, list),
    );
  }

  /// Stores [list] as [viewerPubkey]'s copy when none is held, or when it is
  /// a newer revision than the one held, and reports whether it wrote.
  ///
  /// An equal or older revision is skipped so a relay refresh that found
  /// nothing new does not wake every listener.
  ///
  /// Throws if the Hive box cannot be opened or the write fails.
  Future<bool> refreshFollowedCopy({
    required String viewerPubkey,
    required String ownerPubkey,
    required UserList list,
  }) async {
    final box = await _box();
    final key = _followedKey(viewerPubkey, ownerPubkey, list.id);
    final existing = box.get(key);
    final stored = existing is Map ? _decodeFollowedCopy(existing) : null;
    if (stored != null && !list.updatedAt.isAfter(stored.list.updatedAt)) {
      return false;
    }
    await box.put(key, _followedRow(ownerPubkey, list));
    return true;
  }

  /// Removes [viewerPubkey]'s copy of the list [ownerPubkey] published as
  /// [listId]. A no-op when none is held.
  ///
  /// Throws if the Hive box cannot be opened or the delete fails.
  Future<void> removeFollowedCopy({
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  }) async {
    final box = await _box();
    await box.delete(_followedKey(viewerPubkey, ownerPubkey, listId));
  }

  /// Removes every followed-list copy held for [viewerPubkey], for when that
  /// account's data is deleted from the device.
  ///
  /// Throws if the Hive box cannot be opened or the bulk delete fails.
  Future<void> clearFollowedCopies({required String viewerPubkey}) async {
    final box = await _box();
    final keysToDelete = box.keys
        .whereType<String>()
        .where((key) => _isFollowedKey(key, viewerPubkey))
        .toList(growable: false);
    if (keysToDelete.isEmpty) return;
    await box.deleteAll(keysToDelete);
  }

  static Map<String, dynamic> _followedRow(String ownerPubkey, UserList list) =>
      <String, dynamic>{
        _CacheKeys.ownerPubkey: ownerPubkey,
        _CacheKeys.list: list.toJson(),
      };

  List<PeopleListSearchResult> _collectFollowedCopies(
    Box<dynamic> box,
    String viewerPubkey,
  ) {
    final copies = <PeopleListSearchResult>[];
    for (final key in box.keys) {
      if (key is! String || !_isFollowedKey(key, viewerPubkey)) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final copy = _decodeFollowedCopy(raw);
      if (copy != null) copies.add(copy);
    }
    copies.sort((a, b) => a.addressableId.compareTo(b.addressableId));
    return List.unmodifiable(copies);
  }

  /// Decodes one followed-list row, or `null` when it has no owner or its
  /// list does not decode. One malformed row must not hide the others.
  PeopleListSearchResult? _decodeFollowedCopy(Map<dynamic, dynamic> row) {
    final ownerPubkey = row[_CacheKeys.ownerPubkey];
    if (ownerPubkey is! String || ownerPubkey.isEmpty) return null;
    final record = _decodeRecord(row);
    if (record == null) return null;
    return PeopleListSearchResult(ownerPubkey: ownerPubkey, list: record.list);
  }

  List<UserList> _collectLists(Box<dynamic> box, String ownerPubkey) {
    final tombstones = <String, int>{};
    final records = <UserList>[];

    for (final key in box.keys) {
      if (key is! String) continue;
      if (_isDeletedKey(key, ownerPubkey)) {
        final raw = box.get(key);
        if (raw is Map) {
          final millis = raw[_CacheKeys.deletedAtMillis];
          if (millis is int) {
            tombstones[_listIdFromDeletedKey(key, ownerPubkey)] = millis;
          }
        }
      }
    }

    for (final key in box.keys) {
      if (key is! String) continue;
      if (!_isListKey(key, ownerPubkey)) continue;
      final raw = box.get(key);
      if (raw is! Map) continue;
      final record = _decodeRecord(raw);
      if (record == null) continue;
      final list = record.list;
      final tombstoneMillis = tombstones[list.id];
      if (tombstoneMillis != null &&
          tombstoneMillis >= list.updatedAt.millisecondsSinceEpoch) {
        continue;
      }
      records.add(list);
    }

    records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return records;
  }

  /// Decodes a single stored record into a [CachedPeopleListRecord].
  ///
  /// Returns `null` and logs a warning when the record is shaped unexpectedly
  /// or when [UserList.fromJson] throws. A single malformed row must not
  /// poison the whole `readLists`/`watchLists` result.
  ///
  /// A row whose stored source is malformed, or names a different `d` tag than
  /// its list, degrades to a record with no source rather than being dropped:
  /// it still displays, but [CachedPeopleListRecord.hasPublishSource] is false
  /// and it cannot drive a membership edit.
  CachedPeopleListRecord? _decodeRecord(Map<dynamic, dynamic> record) {
    final raw = record[_CacheKeys.list];
    if (raw is! Map) return null;
    final UserList list;
    try {
      final json = Map<String, dynamic>.from(
        raw.map((key, value) => MapEntry(key.toString(), value)),
      );
      list = UserList.fromJson(json);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Dropped malformed people-list record during decode',
        name: _logName,
        category: LogCategory.storage,
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }

    try {
      final rawTags = record[_CacheKeys.sourceTags];
      final rawContent = record[_CacheKeys.sourceContent];
      if (rawTags == null && rawContent == null) {
        return CachedPeopleListRecord(list: list);
      }
      if (rawTags is! List || rawContent is! String) {
        throw const FormatException('Incomplete cached people-list source');
      }
      final tags = <List<String>>[];
      for (final rawTag in rawTags) {
        if (rawTag is! List || rawTag.any((value) => value is! String)) {
          throw const FormatException('Invalid cached people-list source tag');
        }
        tags.add([for (final value in rawTag) value as String]);
      }
      final sourceDTag = _firstNonEmptyTagValue(tags, 'd');
      if (sourceDTag != list.id) {
        throw const FormatException(
          'Cached people-list source does not match its list',
        );
      }
      return CachedPeopleListRecord(
        list: list,
        sourceTags: List<List<String>>.unmodifiable(
          tags.map(List<String>.unmodifiable),
        ),
        sourceContent: rawContent,
      );
    } on Object catch (error, stackTrace) {
      Log.error(
        'Ignored malformed people-list publish source during decode',
        name: _logName,
        category: LogCategory.storage,
        error: error,
        stackTrace: stackTrace,
      );
      return CachedPeopleListRecord(list: list);
    }
  }

  static String? _firstNonEmptyTagValue(
    List<List<String>> tags,
    String name,
  ) {
    for (final tag in tags) {
      if (tag.length >= 2 && tag[0] == name && tag[1].isNotEmpty) {
        return tag[1];
      }
    }
    return null;
  }

  int? _tombstoneMillis(Box<dynamic> box, String ownerPubkey, String listId) {
    final raw = box.get(_deletedKey(ownerPubkey, listId));
    if (raw is! Map) return null;
    final value = raw[_CacheKeys.deletedAtMillis];
    return value is int ? value : null;
  }

  static String _listKey(String ownerPubkey, String listId) =>
      '${_CacheKeys.listPrefix}$ownerPubkey'
      '${_CacheKeys.keySeparator}$listId';

  static String _deletedKey(String ownerPubkey, String listId) =>
      '${_CacheKeys.deletedPrefix}$ownerPubkey'
      '${_CacheKeys.keySeparator}$listId';

  static bool _keyBelongsToOwner(String key, String ownerPubkey) {
    return _isListKey(key, ownerPubkey) || _isDeletedKey(key, ownerPubkey);
  }

  static bool _isListKey(String key, String ownerPubkey) {
    final prefix =
        '${_CacheKeys.listPrefix}$ownerPubkey${_CacheKeys.keySeparator}';
    return key.startsWith(prefix);
  }

  static String _followedKey(
    String viewerPubkey,
    String ownerPubkey,
    String listId,
  ) =>
      '${_CacheKeys.followedPrefix}$viewerPubkey'
      '${_CacheKeys.keySeparator}$ownerPubkey'
      '${_CacheKeys.keySeparator}$listId';

  /// Pubkeys are hex, so the separator after [viewerPubkey] cannot fall
  /// inside another viewer's key.
  static bool _isFollowedKey(String key, String viewerPubkey) {
    final prefix =
        '${_CacheKeys.followedPrefix}$viewerPubkey${_CacheKeys.keySeparator}';
    return key.startsWith(prefix);
  }

  static bool _isDeletedKey(String key, String ownerPubkey) {
    final prefix =
        '${_CacheKeys.deletedPrefix}$ownerPubkey'
        '${_CacheKeys.keySeparator}';
    return key.startsWith(prefix);
  }

  static String _listIdFromDeletedKey(String key, String ownerPubkey) {
    final prefix =
        '${_CacheKeys.deletedPrefix}$ownerPubkey'
        '${_CacheKeys.keySeparator}';
    return key.substring(prefix.length);
  }
}
