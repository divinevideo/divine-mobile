// ABOUTME: Hive-backed local cache for NIP-51 kind 30000 people lists.
// ABOUTME: Scopes entries by owner pubkey and enforces deletion tombstones.

import 'dart:async';

import 'package:hive_ce/hive_ce.dart';
import 'package:models/models.dart';
import 'package:unified_logger/unified_logger.dart';

/// Key prefix constants and JSON field names for the Hive box.
abstract class _CacheKeys {
  static const String listPrefix = 'list:';
  static const String deletedPrefix = 'deleted:';
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
    late StreamController<List<UserList>> controller;
    StreamSubscription<BoxEvent>? subscription;

    Future<void> start() async {
      try {
        final box = await _box();
        if (controller.isClosed) return;
        controller.add(_collectLists(box, ownerPubkey));
        subscription = box.watch().listen((event) {
          final key = event.key;
          if (key is! String || !_keyBelongsToOwner(key, ownerPubkey)) {
            return;
          }
          controller.add(_collectLists(box, ownerPubkey));
        });
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) {
          controller.addError(error, stackTrace);
          await controller.close();
        }
      }
    }

    controller = StreamController<List<UserList>>(
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
  /// Throws if the Hive box cannot be opened or the underlying write fails.
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

  /// Decodes a single stored record into a [UserList].
  ///
  /// Returns `null` and logs a warning when the record is shaped unexpectedly
  /// or when [UserList.fromJson] throws. A single malformed row must not
  /// poison the whole `readLists`/`watchLists` result.
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
