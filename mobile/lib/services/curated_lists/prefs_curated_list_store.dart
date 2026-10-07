// ABOUTME: Adapts SharedPreferences to the shared curated cache write coordinator.
// ABOUTME: Also keeps the record of deleted lists and the default-list flag.

import 'dart:async';
import 'dart:convert';

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_subscription_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Stores the curated lists, their subscriptions, the record of deleted lists
/// and the default-list flag in [SharedPreferences].
///
/// Saves merge through the shared [CuratedListCacheWriteCoordinator]. A
/// baseline advances only after the whole save lands, so the next save repeats
/// whatever a rejected write dropped.
class PrefsCuratedListStore {
  /// Creates a store over [prefs] that keeps the lists, the subscriptions and
  /// the default-list flag under the given keys.
  ///
  /// The caller names these keys because the account-switch sweep references
  /// them by the same constants.
  PrefsCuratedListStore({
    required SharedPreferences prefs,
    required CuratedListCacheWriteCoordinator writeCoordinator,
    required String listsStorageKey,
    required String subscriptionsStorageKey,
    required String defaultListDeletedStorageKey,
    bool Function()? isCurrentSession,
  }) : _prefs = prefs,
       _isCurrentSession = isCurrentSession,
       _writes = writeCoordinator,
       _listsKey = listsStorageKey,
       _subscriptionsKey = subscriptionsStorageKey,
       _defaultListDeletedKey = defaultListDeletedStorageKey;

  /// Where this install records the lists it has deleted.
  ///
  /// The account-switch sweep does not clear it: each entry embeds its owner,
  /// so one account's record never hides another's list, and clearing it would
  /// let a relay that ignored the deletion bring the list back. Declared here
  /// rather than injected so `check_prefs_key_classification.sh` still sees it.
  static const String deletedCoordinatesStorageKey =
      'deleted_curated_list_coordinates';

  final SharedPreferences _prefs;
  final bool Function()? _isCurrentSession;
  final CuratedListCacheWriteCoordinator _writes;
  final String _listsKey;
  final String _subscriptionsKey;
  final String _defaultListDeletedKey;
  List<CuratedList> _savedLists = const [];
  Set<String> _savedSubscriptions = const {};
  Future<void> _tail = Future<void>.value();
  List<CuratedList>? _lastRequestedLists;
  Set<String>? _lastRequestedSubscriptions;
  final _pendingOwnershipClaims = <String, CuratedList>{};
  var _pendingLists = 0;
  var _pendingSubscriptions = 0;
  String? _ownerEvidenceJson;
  _RawListOwnerEvidence? _ownerEvidence;

  /// Sets [lists], as just loaded from storage, as the baseline the next
  /// [saveLists] diffs against.
  void listsLoaded(List<CuratedList> lists) {
    _savedLists = List.unmodifiable(lists);
  }

  /// Sets [ids], as just loaded from storage, as the baseline the next
  /// [saveSubscriptions] diffs against.
  void subscriptionsLoaded(Set<String> ids) {
    _savedSubscriptions = Set.unmodifiable(ids);
  }

  /// Decodes the existing list cache through the same guarded codec as saves.
  List<CuratedList> loadLists() =>
      _storedLists(fallback: const [], preserveDecoded: true);

  /// Loads IDs and their readability together from one storage read.
  ///
  /// An absent record is a known empty snapshot. Malformed metadata remains
  /// incomplete, so callers cannot treat the empty fallback as an unfollow.
  /// IDs are immutable and the same decoded snapshot captures the write baseline.
  ({Set<String> ids, bool isReadable}) loadSubscriptionSnapshot() {
    final snapshot = _readStoredSubscriptions(fallback: const {});
    subscriptionsLoaded(snapshot.ids);
    return snapshot;
  }

  /// Loads the existing subscription cache and captures its write baseline.
  Set<String> loadSubscriptions() =>
      Set<String>.of(loadSubscriptionSnapshot().ids);

  /// Saves what changed in [lists] since the last load or successful save,
  /// keeping lists another writer stored in the meantime. Returns whether
  /// every change was stored.
  ///
  /// Undecodable rows may fall back to the baseline, but a save refuses
  /// unreadable ownership evidence so it cannot replace pending privacy work.
  Future<bool> saveLists(List<CuratedList> lists) async =>
      (await saveListsWithResult(lists)).succeeded;

  /// Serializes the baseline read, coordinated write and baseline advancement.
  Future<CuratedCacheWriteResult<List<CuratedList>>> saveListsWithResult(
    List<CuratedList> lists, {
    bool Function()? isCurrent,
    Map<String, CuratedList> ownershipClaims = const {},
  }) {
    _pendingOwnershipClaims.addAll(ownershipClaims);
    final claims = Map<String, CuratedList>.unmodifiable(
      _pendingOwnershipClaims,
    );
    final snapshot = List<CuratedList>.unmodifiable(lists);
    final preceding = _pendingLists == 0 ? null : _lastRequestedLists;
    _lastRequestedLists = snapshot;
    _pendingLists++;
    return _serialize(() async {
      final baseline = _savedLists;
      final requested = preceding == null
          ? snapshot
          : CuratedCacheWriteSnapshots.rebaseLists(
              baseline,
              preceding,
              snapshot,
            );
      // A queued edit may see an optimistic stamped row before its source
      // claim finishes. Keep that precondition until our baseline acknowledges
      // the authored coordinate; a failed claim cannot grant later authority.
      final activeClaims = {
        for (final claim in claims.entries)
          if (!baseline.any((row) => row.authorScopedId == claim.key))
            claim.key: claim.value,
      };
      var storedListsReadable = true;
      var ownerEvidence = const _RawListOwnerEvidence(readable: true);
      final result = await _writes.saveListsWithResult(
        baseline: baseline,
        current: requested,
        cacheKey: _listsKey,
        isCurrent: () =>
            (_isCurrentSession?.call() ?? true) && (isCurrent?.call() ?? true),
        read: () {
          final raw = _prefs.getString(_listsKey);
          ownerEvidence = _ownerEvidenceFromJson(raw);
          return _decodeStoredLists(
            raw,
            fallback: baseline,
            onUnreadable: () => storedListsReadable = false,
          );
        },
        isReadValid: () => storedListsReadable && ownerEvidence.readable,
        preflightConflicts: (acknowledged) => {
          ...ownerEvidence.mutationConflicts(baseline, requested),
          if (activeClaims.isNotEmpty)
            ..._ownershipClaimConflicts(
              activeClaims,
              acknowledged,
              ownerEvidence: ownerEvidence,
            ),
        },
        write: (merged) =>
            _writeString(_listsKey, jsonEncode(ownerEvidence.encode(merged))),
      );
      _savedLists = result.nextBaseline;
      return result;
    }).whenComplete(() {
      _pendingLists--;
      if (_pendingLists == 0) {
        _lastRequestedLists = null;
        _pendingOwnershipClaims.clear();
      }
    });
  }

  /// Saves and reconciles only this request's coordinates in [lists].
  ///
  /// Callers with a failure-returning public API can catch the typed exception;
  /// they must not publish or return success after an unpersisted local edit.
  Future<void> saveListsOrThrow(
    List<CuratedList> lists, {
    required bool Function() isCurrent,
    Map<String, CuratedList> ownershipClaims = const {},
  }) async {
    final result = await saveListsWithResult(
      lists,
      isCurrent: isCurrent,
      ownershipClaims: ownershipClaims,
    );
    if (isCurrent()) {
      final reconciled = result.reconcile(lists);
      lists
        ..clear()
        ..addAll(reconciled);
    }
    if (!result.succeeded) throw CuratedCacheWriteException(result.status);
  }

  /// A read-only early check also prevents misleading duplicate success.
  /// The coordinated save repeats this condition after all queued writers.
  bool canClaimLocalList(CuratedList source, String destination) {
    var readable = true;
    final raw = _prefs.getString(_listsKey);
    final evidence = _ownerEvidenceFromJson(raw);
    final stored = _decodeStoredLists(
      raw,
      fallback: _savedLists,
      onUnreadable: () => readable = false,
    );
    if (!readable || !evidence.readable) return false;
    final acknowledged = _writes.readAcknowledgedLists(
      cacheKey: _listsKey,
      read: () => stored,
    );
    return _ownershipClaimConflicts(
      {destination: source},
      acknowledged,
      ownerEvidence: evidence,
    ).isEmpty;
  }

  /// Secondary labels cannot establish an absent or contradictory primary.
  /// The cache model intentionally does not decode those raw ownership fields.
  bool hasUnambiguousOwnerEvidence(CuratedList source) {
    final evidence = _rawOwnerEvidence();
    return evidence.readable && !evidence.isUncertain(source.authorScopedId);
  }

  _RawListOwnerEvidence _rawOwnerEvidence() {
    final String? raw;
    try {
      raw = _prefs.getString(_listsKey);
    } on Object {
      return const _RawListOwnerEvidence(readable: false);
    }
    return _ownerEvidenceFromJson(raw);
  }

  _RawListOwnerEvidence _ownerEvidenceFromJson(String? raw) {
    if (_ownerEvidence != null && raw == _ownerEvidenceJson) {
      return _ownerEvidence!;
    }
    _ownerEvidenceJson = raw;
    return _ownerEvidence = _RawListOwnerEvidence.fromJson(raw);
  }

  /// Author stamping may only consume the exact acknowledged local draft.
  /// Timestamp precedence cannot establish ownership of an existing coordinate.
  Set<String> _ownershipClaimConflicts(
    Map<String, CuratedList> claims,
    List<CuratedList> acknowledged, {
    _RawListOwnerEvidence? ownerEvidence,
  }) {
    var followsReadable = true;
    final follows = _writes.readAcknowledgedSubscriptions(
      cacheKey: _subscriptionsKey,
      read: () => readCuratedListSubscriptionSnapshot(
        preferences: _prefs,
        storageKey: _subscriptionsKey,
        fallback: _savedSubscriptions,
        onMissing: () => _writes.cacheKeyRemoved(_subscriptionsKey),
        onUnreadable: (_, _) => followsReadable = false,
      ).ids,
    );
    final conflicts = <String>{};
    for (final claim in claims.entries) {
      final source = claim.value;
      final storedSources = acknowledged.where(
        (list) => list.authorScopedId == source.authorScopedId,
      );
      final evidence = ownerEvidence ?? _rawOwnerEvidence();
      if (!followsReadable ||
          !evidence.readable ||
          evidence.isUncertain(source.authorScopedId) ||
          source.pubkey != null ||
          source.nostrEventId != null ||
          storedSources.length != 1 ||
          storedSources.single != source ||
          acknowledged.any((list) => list.authorScopedId == claim.key) ||
          follows.contains(source.id) ||
          follows.contains(source.authorScopedId)) {
        conflicts
          ..add(source.authorScopedId)
          ..add(claim.key);
      }
    }
    return conflicts;
  }

  /// Saves subscription deltas and reports confirmed backing-store success.
  Future<bool> saveSubscriptions(Set<String> ids) async =>
      (await saveSubscriptionsWithResult(ids)).succeeded;

  /// Serializes subscription baseline capture and advancement with its save.
  Future<CuratedCacheWriteResult<Set<String>>> saveSubscriptionsWithResult(
    Set<String> ids, {
    bool Function()? isCurrent,
  }) {
    final snapshot = Set<String>.unmodifiable(ids);
    final preceding = _pendingSubscriptions == 0
        ? null
        : _lastRequestedSubscriptions;
    _lastRequestedSubscriptions = snapshot;
    _pendingSubscriptions++;
    return _serialize(() async {
      final baseline = _savedSubscriptions;
      final requested = preceding == null
          ? snapshot
          : CuratedCacheWriteSnapshots.rebaseSubscriptions(
              baseline,
              preceding,
              snapshot,
            );
      final result = await _writes.saveSubscriptionsWithResult(
        baseline: baseline,
        current: requested,
        cacheKey: _subscriptionsKey,
        isCurrent: () =>
            (_isCurrentSession?.call() ?? true) && (isCurrent?.call() ?? true),
        read: () => _storedSubscriptions(fallback: baseline),
        write: (merged) => _writeString(
          _subscriptionsKey,
          jsonEncode(merged.toList(growable: false)),
        ),
      );
      if (result.succeeded) _savedSubscriptions = requested;
      return result;
    }).whenComplete(() {
      _pendingSubscriptions--;
      if (_pendingSubscriptions == 0) _lastRequestedSubscriptions = null;
    });
  }

  /// Restores failed subscription deltas without touching unrelated follows.
  Future<void> saveSubscriptionsOrThrow(
    Set<String> ids, {
    required bool Function() isCurrent,
  }) async {
    final result = await saveSubscriptionsWithResult(ids, isCurrent: isCurrent);
    if (isCurrent()) {
      final reconciled = result.reconcile(ids);
      ids
        ..clear()
        ..addAll(reconciled);
    }
    if (!result.succeeded) throw CuratedCacheWriteException(result.status);
  }

  Future<bool> _writeString(String key, String value) =>
      _persist(() => _prefs.setString(key, value));

  Future<bool> _persist(Future<bool> Function() write) async {
    try {
      return await write();
    } on Exception catch (error, stackTrace) {
      // Platform errors can include private cache fragments in their message.
      // Programming Errors still propagate instead of becoming disk failures.
      Log.error(
        'Failed to persist curated cache (${error.runtimeType})',
        name: 'PrefsCuratedListStore',
        category: LogCategory.system,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final completed = Completer<void>();
    _tail = completed.future;
    try {
      await previous;
      return await operation();
    } finally {
      completed.complete();
    }
  }

  /// Finishes persisted follow/default state after an owned row was removed.
  /// Leaves foreign rows and legacy aliases shared by surviving rows intact.
  Future<Set<String>> recoverRemovedListSubscriptions(
    List<CuratedList> lists,
    Set<String> subscriptions, {
    required String owner,
    required String defaultListId,
    required Future<void> Function() saveSubscriptions,
  }) async {
    bool missingOwned(String id) =>
        !lists.any((list) => list.authorScopedId == '$owner:$id') &&
        wasListDeleted(owner, id);
    final pendingDefault =
        missingOwned(defaultListId) && hasPendingDefaultListDeletion(owner);
    if (pendingDefault) {
      await markDefaultListDeleted();
      await finishDefaultListDeletion(owner);
    }
    final coordinates = <String>{};
    for (final subscription in subscriptions.toList(growable: false)) {
      final qualified = subscription.startsWith('$owner:');
      final id = qualified
          ? subscription.substring(owner.length + 1)
          : subscription;
      if (!missingOwned(id)) continue;
      if (!qualified && lists.any((list) => list.id == id)) continue;
      subscriptions.remove(subscription);
      coordinates.add('$owner:$id');
    }
    if (coordinates.isNotEmpty) await saveSubscriptions();
    return coordinates;
  }

  /// Owner-scoped recovery for a durable removal whose default flag failed.
  /// A tombstone alone must still allow the existing explicit restore flow.
  static String pendingDefaultDeletionKey(String ownerPubkey) =>
      'curated_list_default_cleanup:$ownerPubkey';

  bool hasPendingDefaultListDeletion(String ownerPubkey) =>
      _prefs.getBool(pendingDefaultDeletionKey(ownerPubkey)) ?? false;

  Future<void> beginDefaultListDeletion(String ownerPubkey) =>
      _saveDefaultDeletionRecovery(
        () => _prefs.setBool(pendingDefaultDeletionKey(ownerPubkey), true),
      );

  Future<void> finishDefaultListDeletion(String ownerPubkey) =>
      _saveDefaultDeletionRecovery(
        () => _prefs.remove(pendingDefaultDeletionKey(ownerPubkey)),
      );

  Future<void> _saveDefaultDeletionRecovery(
    Future<bool> Function() write,
  ) async {
    final saved = await _writes.runExclusive(() async {
      if (!(_isCurrentSession?.call() ?? true)) return false;
      return _persist(write);
    });
    if (!saved || !(_isCurrentSession?.call() ?? true)) {
      throw CuratedCacheWriteException(
        (_isCurrentSession?.call() ?? true)
            ? CuratedCacheWriteStatus.storageRejected
            : CuratedCacheWriteStatus.superseded,
      );
    }
  }

  /// Whether the signed-in account deleted its default list.
  ///
  /// Unlike the deletion record, the account-switch sweep clears this flag.
  bool wasDefaultListDeleted() =>
      _prefs.getBool(_defaultListDeletedKey) ?? false;

  /// Remembers that the default list was deleted.
  Future<void> markDefaultListDeleted() async {
    final saved = await _writes.runExclusive(() async {
      if (!(_isCurrentSession?.call() ?? true)) return false;
      return _persist(() => _prefs.setBool(_defaultListDeletedKey, true));
    });
    if (!saved || !(_isCurrentSession?.call() ?? true)) {
      throw CuratedCacheWriteException(
        (_isCurrentSession?.call() ?? true)
            ? CuratedCacheWriteStatus.storageRejected
            : CuratedCacheWriteStatus.superseded,
      );
    }
  }

  /// Whether this install has deleted the list [ownerPubkey] published as
  /// [listId].
  bool wasListDeleted(String ownerPubkey, String listId) =>
      _deletedCoordinates().contains(_coordinate(ownerPubkey, listId));

  /// Remembers that [ownerPubkey]'s list [listId] was deleted.
  Future<bool> recordListDeletion(String ownerPubkey, String listId) async {
    final before = _deletedCoordinates();
    final coordinates = Set<String>.of(before)
      ..add(_coordinate(ownerPubkey, listId));
    return (await _saveDeletedCoordinates(before, coordinates)).succeeded;
  }

  /// Lifts the tombstone so a re-created list can sync again.
  Future<void> forgetListDeletion(String ownerPubkey, String listId) async {
    final before = _deletedCoordinates();
    final coordinates = Set<String>.of(before);
    if (!coordinates.remove(_coordinate(ownerPubkey, listId))) return;
    final result = await _saveDeletedCoordinates(before, coordinates);
    if (!result.succeeded) throw CuratedCacheWriteException(result.status);
  }

  Future<CuratedCacheWriteResult<Set<String>>> _saveDeletedCoordinates(
    Set<String> before,
    Set<String> coordinates,
  ) => _writes.saveSubscriptionsWithResult(
    baseline: before,
    current: coordinates,
    cacheKey: deletedCoordinatesStorageKey,
    isCurrent: _isCurrentSession,
    read: _rawDeletedCoordinates,
    write: (merged) => _persist(
      () => _prefs.setStringList(
        deletedCoordinatesStorageKey,
        merged.toList(growable: false),
      ),
    ),
  );

  /// The stored lists, or [fallback] when they cannot be decoded.
  ///
  /// The coordinator writes only what changed since the baseline, so the
  /// baseline as [fallback] makes it rewrite every list the caller holds. An
  /// absent key is empty, not unreadable: the account-switch sweep removes it,
  /// and the lists of the previous account must not be written back.
  List<CuratedList> _decodeStoredLists(
    String? json, {
    required List<CuratedList> fallback,
    void Function()? onUnreadable,
    bool preserveDecoded = false,
  }) {
    if (json == null) {
      _writes.cacheKeyRemoved(_listsKey);
      return const [];
    }
    final decoded = <CuratedList>[];
    try {
      for (final row in jsonDecode(json) as List<dynamic>) {
        decoded.add(CuratedList.fromJson(row as Map<String, dynamic>));
      }
      return decoded;
    } on Object catch (error, stackTrace) {
      onUnreadable?.call();
      _logUnreadable('lists', error, stackTrace);
      return preserveDecoded ? decoded : fallback;
    }
  }

  /// The stored ids, or [fallback] when they cannot be decoded.
  Set<String> _storedSubscriptions({required Set<String> fallback}) =>
      _readStoredSubscriptions(fallback: fallback).ids;

  ({Set<String> ids, bool isReadable}) _readStoredSubscriptions({
    required Set<String> fallback,
  }) => readCuratedListSubscriptionSnapshot(
    preferences: _prefs,
    storageKey: _subscriptionsKey,
    fallback: fallback,
    onMissing: () => _writes.cacheKeyRemoved(_subscriptionsKey),
    onUnreadable: (error, stackTrace) =>
        _logUnreadable('subscriptions', error, stackTrace),
  );

  void _logUnreadable(String what, Object error, StackTrace stackTrace) {
    // The error is left out: FormatException.toString() quotes the stored text.
    Log.error(
      'Stored curated $what cannot be read (${error.runtimeType})',
      name: 'PrefsCuratedListStore',
      category: LogCategory.system,
      stackTrace: stackTrace,
    );
  }

  /// The `<pubkey>:<d-tag>` form of a kind 30005 coordinate.
  ///
  /// A `d` tag is only unique per author, so a deletion has to be remembered
  /// against its owner. Keying on the identifier alone would suppress a list
  /// that merely shares it — another account on this device, or someone
  /// else's list arriving from a relay.
  String _coordinate(String ownerPubkey, String listId) =>
      '$ownerPubkey:$listId';

  /// Coordinates this install has deleted.
  ///
  /// NIP-09 is advisory: a relay may never see the deletion request, or may
  /// decline it, and keep replaying the original event. Without a local record
  /// the next sync adds the list straight back. The set is not pruned — an
  /// entry is a few dozen bytes, deletions are rare, and there is no point at
  /// which every relay is known to have honoured the request.
  Set<String> _deletedCoordinates() => _writes.readAcknowledgedSubscriptions(
    cacheKey: deletedCoordinatesStorageKey,
    read: _rawDeletedCoordinates,
  );

  Set<String> _rawDeletedCoordinates() {
    final coordinates = _prefs.getStringList(deletedCoordinatesStorageKey);
    if (coordinates == null) {
      _writes.cacheKeyRemoved(deletedCoordinatesStorageKey);
      return const {};
    }
    return coordinates.toSet();
  }
}

/// Retains ownership fields that the typed cache row does not represent.
class _RawListOwnerEvidence {
  const _RawListOwnerEvidence({required this.readable, this.rows = const {}});

  factory _RawListOwnerEvidence.fromJson(String? raw) {
    if (raw == null) return const _RawListOwnerEvidence(readable: true);
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final rows = <String, List<Map<String, dynamic>>>{};
      for (final value in decoded) {
        final fields = value as Map<String, dynamic>;
        if (!fields.containsKey('ownerPubkey') &&
            !fields.containsKey('authorPubkey')) {
          continue;
        }
        final id = fields['id'] as String;
        final primary = fields['pubkey'] as String?;
        final coordinate = '${primary ?? ''}:$id';
        (rows[coordinate] ??= []).add(Map.unmodifiable(fields));
      }
      return _RawListOwnerEvidence(readable: true, rows: rows);
    } on Object {
      return const _RawListOwnerEvidence(readable: false);
    }
  }

  final bool readable;
  final Map<String, List<Map<String, dynamic>>> rows;

  bool isUncertain(String coordinate) =>
      rows[coordinate]?.any(_hasUncertainOwner) ?? false;

  static bool _hasUncertainOwner(Map<String, dynamic> row) {
    final primary = row['pubkey'];
    if (primary is! String || !NostrHexUtils.isValidPubkey(primary)) {
      return true;
    }
    for (final field in ['ownerPubkey', 'authorPubkey']) {
      if (!row.containsKey(field)) continue;
      final secondary = row[field];
      if (secondary is! String ||
          !NostrHexUtils.isValidPubkey(secondary) ||
          secondary.toLowerCase() != primary.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  Set<String> mutationConflicts(
    List<CuratedList> baseline,
    List<CuratedList> requested,
  ) {
    final before = {for (final list in baseline) list.authorScopedId: list};
    final after = {for (final list in requested) list.authorScopedId: list};
    return {
      for (final coordinate in rows.keys)
        if (isUncertain(coordinate) && before[coordinate] != after[coordinate])
          coordinate,
    };
  }

  List<Map<String, dynamic>> encode(List<CuratedList> lists) {
    final coordinates = lists.map((list) => list.authorScopedId).toSet();
    return [
      for (final list in lists)
        if (isUncertain(list.authorScopedId))
          // Preconditions prohibit editing these rows; preserve every raw copy.
          ...rows[list.authorScopedId]!
        else if (rows[list.authorScopedId] case final evidence?)
          {...evidence.last, ...list.toJson()}
        else
          list.toJson(),
      for (final entry in rows.entries)
        // Invalid title/date fields can keep raw evidence out of typed lists.
        if (!coordinates.contains(entry.key) && isUncertain(entry.key))
          ...entry.value,
    ];
  }
}
