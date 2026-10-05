// ABOUTME: Keeps minimal owner-scoped recovery evidence outside the list cache.
// ABOUTME: Retains accepted permission targets and pending NIP-09 event IDs.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal recovery data, never the name, description, item payload or keys.
class CuratedListRecoveryRecord {
  /// Creates a record belonging to the owner named by its storage bucket.
  const CuratedListRecoveryRecord({
    this.plaintextEventIds = const [],
    this.visibility,
    this.acceptedEventId,
    this.acceptedAt,
    this.requiresPrivateCommit = false,
  });

  /// Event-specific deletion requests still awaiting at least one relay ACK.
  final List<String> plaintextEventIds;

  /// A relay-confirmed permission target awaiting the local final commit.
  final CuratedListVisibility? visibility;

  /// Identity and timestamp of the accepted replacement, when known.
  final String? acceptedEventId;
  final DateTime? acceptedAt;

  /// An unpublished private union must commit before deleting its public copy.
  final bool requiresPrivateCommit;

  bool get isEmpty => plaintextEventIds.isEmpty && visibility == null;

  Map<String, dynamic> toJson() => {
    'plaintextEventIds': plaintextEventIds,
    if (visibility != null) 'visibility': visibility!.toJson(),
    if (acceptedEventId != null) 'acceptedEventId': acceptedEventId,
    if (acceptedAt != null) 'acceptedAt': acceptedAt!.toIso8601String(),
    if (requiresPrivateCommit) 'requiresPrivateCommit': true,
  };

  factory CuratedListRecoveryRecord.fromJson(Map<String, dynamic> json) {
    final visibility = json['visibility'] == null
        ? null
        : CuratedListVisibility.fromJson(
            json['visibility'] as Map<String, dynamic>,
          );
    return CuratedListRecoveryRecord(
      plaintextEventIds: List<String>.from(
        json['plaintextEventIds'] as List? ?? const [],
      ),
      // Ambiguous legacy proposals never become a recovery permission target.
      visibility: visibility?.relayAccepted == true ? visibility : null,
      acceptedEventId: json['acceptedEventId'] as String?,
      requiresPrivateCommit: json['requiresPrivateCommit'] as bool? ?? false,
      acceptedAt: json['acceptedAt'] == null
          ? null
          : DateTime.parse(json['acceptedAt'] as String),
    );
  }
}

/// The account-session owner supplies the device-wide storage barrier.
///
/// Ordinary logout preserves these scoped buckets. Explicit deletion of an
/// account's local data removes only that account's bucket.
class CuratedListRecoveryJournal {
  CuratedListRecoveryJournal({
    required SharedPreferences prefs,
    required Future<bool> Function(Future<bool> Function()) runCurrent,
  }) : _prefs = prefs,
       _runCurrent = runCurrent;

  static const storagePrefix = 'curated_list_recovery_v1:';

  // Retain a real ACK when disk refuses it. Shared preference identity lets
  // ordinary cleanup drain this evidence across retiring account containers.
  static final _pendingAccepted =
      Expando<Map<String, Map<String, CuratedListRecoveryRecord>>>();

  static Map<String, Map<String, CuratedListRecoveryRecord>> _pendingOwners(
    SharedPreferences prefs,
  ) => _pendingAccepted[prefs] ??= {};

  /// Destructive local account deletion also forgets its unsaved ACK evidence.
  static void discardPendingAccepted(SharedPreferences prefs, String owner) {
    _pendingOwners(prefs).remove(owner);
  }

  static String storageKey(String ownerPubkey) => '$storagePrefix$ownerPubkey';

  final SharedPreferences _prefs;
  final Future<bool> Function(Future<bool> Function()) _runCurrent;

  Map<String, CuratedListRecoveryRecord> records(String owner) =>
      _mergePending(_prefs, owner, _read(_prefs, owner));

  CuratedListRecoveryRecord? record(String owner, String listId) =>
      _pendingOwners(_prefs)[owner]?[listId] ?? records(owner)[listId];

  /// Reattaches only the current owner's recovery evidence to its cache row.
  CuratedList recover(CuratedList list, String owner) {
    if (list.pubkey != owner) return list;
    final saved = record(owner, list.id);
    if (saved == null) return list;
    final timestamp = saved.acceptedAt;
    final unsettled = needsPermissionRecovery(list, owner);
    return list.copyWith(
      pendingPlaintextEventIds: {
        ...list.pendingPlaintextEventIds,
        ...saved.plaintextEventIds,
      }.toList(growable: false),
      pendingVisibility: unsettled ? saved.visibility : list.pendingVisibility,
      pendingRepublish: unsettled || list.pendingRepublish,
      updatedAt: timestamp != null && timestamp.isAfter(list.updatedAt)
          ? timestamp
          : list.updatedAt,
    );
  }

  /// A refused final list commit needs recovery; journal cleanup alone does not
  /// block edits after the true permission state is already durable and visible.
  bool needsPermissionRecovery(CuratedList list, String owner) {
    final saved = record(owner, list.id);
    final target = saved?.visibility;
    if (target == null) return list.hasPendingPermissionRecovery;
    if (_hasNewerCommittedRevision(list, saved!)) return false;
    return list.hasPendingPermissionRecovery ||
        list.pendingRepublish ||
        list.nostrEventId == null ||
        CuratedListVisibility.fromList(list, relayAccepted: true) != target ||
        (saved.acceptedAt != null && saved.acceptedAt!.isAfter(list.updatedAt));
  }

  /// Matches cache revision precedence, with NIP-33 event ID ordering on ties.
  /// Recovery evidence remains stored when a newer durable writer supersedes it.
  static bool _hasNewerCommittedRevision(
    CuratedList list,
    CuratedListRecoveryRecord saved,
  ) {
    if (list.nostrEventId == null ||
        list.nostrEventId == saved.acceptedEventId ||
        list.pendingRepublish ||
        list.pendingVisibility != null ||
        saved.acceptedAt == null) {
      return false;
    }
    return list.updatedAt.isAfter(saved.acceptedAt!) ||
        (list.updatedAt == saved.acceptedAt &&
            saved.acceptedEventId != null &&
            list.nostrEventId!.compareTo(saved.acceptedEventId!) < 0);
  }

  /// Migrates embedded legacy outboxes before any list-cache write or wipe.
  Future<bool> captureRows(List<CuratedList> lists, String owner) =>
      _runCurrent(() => _captureRows(_prefs, lists, owner));

  /// Stores accepted evidence before the final local visibility commit.
  Future<bool> accepted({
    required String owner,
    required String listId,
    required CuratedListVisibility visibility,
    required String eventId,
    required DateTime acceptedAt,
    required Iterable<String> plaintextEventIds,
  }) {
    if (!visibility.relayAccepted) return Future.value(false);
    return _runCurrent(() async {
      final pending = _pendingOwners(_prefs).putIfAbsent(owner, () => {});
      pending[listId] = CuratedListRecoveryRecord(
        plaintextEventIds: {
          ...?pending[listId]?.plaintextEventIds,
          ...plaintextEventIds,
        }.toList(growable: false),
        visibility: visibility,
        acceptedEventId: eventId,
        acceptedAt: acceptedAt,
        requiresPrivateCommit: !visibility.isPublic,
      );
      // Retain the ACK before reading/writing storage, including exceptions.
      final entries = records(owner);
      pending[listId] = entries[listId]!;
      final saved = await _write(_prefs, owner, entries);
      if (saved) pending.remove(listId);
      return saved;
    });
  }

  /// Clears only the permission evidence whose revision just committed.
  Future<bool> visibilityCommitted(
    String owner,
    String listId,
    CuratedList committed,
  ) => _runCurrent(() async {
    final entries = records(owner);
    final previous = entries[listId];
    if (previous == null) return true;
    final superseded = _hasNewerCommittedRevision(committed, previous);
    if (!superseded &&
        previous.visibility != null &&
        (previous.visibility !=
                CuratedListVisibility.fromList(
                  committed,
                  relayAccepted: true,
                ) ||
            (previous.acceptedAt != null &&
                previous.acceptedAt!.isAfter(committed.updatedAt)))) {
      return false;
    }
    entries[listId] = CuratedListRecoveryRecord(
      plaintextEventIds: previous.plaintextEventIds,
      acceptedEventId: previous.acceptedEventId,
      acceptedAt: previous.acceptedAt,
      requiresPrivateCommit:
          previous.requiresPrivateCommit &&
          (committed.isPublic ||
              committed.nostrEventId == null ||
              committed.pendingRepublish),
    );
    return _write(_prefs, owner, entries);
  });

  /// At least one relay accepted a request; this does not promise erasure.
  Future<bool> redactionAccepted(String owner, String listId, String eventId) =>
      _runCurrent(() async {
        final entries = records(owner);
        final previous = entries[listId];
        if (previous == null) return true;
        entries[listId] = CuratedListRecoveryRecord(
          plaintextEventIds: previous.plaintextEventIds
              .where((id) => id != eventId)
              .toList(growable: false),
          visibility: previous.visibility,
          acceptedEventId: previous.acceptedEventId,
          acceptedAt: previous.acceptedAt,
          requiresPrivateCommit: previous.requiresPrivateCommit,
        );
        return _write(_prefs, owner, entries);
      });

  /// Runs inside the cleanup owner's already-exclusive storage boundary.
  /// A refused migration must stop cleanup before the legacy cache is wiped.
  static Future<void> migrateEmbeddedRecords(
    SharedPreferences prefs, {
    String? legacyOwner,
    String? deletingOwner,
  }) async {
    for (final owner in _pendingOwners(prefs).keys.toList(growable: false)) {
      if (owner == deletingOwner) continue;
      if (!await _captureRows(prefs, const [], owner)) {
        throw StateError('Could not preserve acknowledged curated recovery');
      }
    }
    final encoded = prefs.get('curated_lists');
    if (encoded is! String) return;
    final dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      // A cache that is not JSON contains no decodable recovery evidence.
      return;
    }
    if (decoded is! List) return;
    final groups = <String, List<CuratedList>>{};
    for (final row in decoded) {
      if (row is! Map<String, dynamic>) continue;
      final list = CuratedList.fromJson(row);
      final owner = list.pubkey ?? legacyOwner;
      if (deletingOwner != null && owner == deletingOwner) continue;
      if (list.pendingPlaintextEventIds.isEmpty &&
          !list.hasPendingPermissionRecovery &&
          (owner == null || _read(prefs, owner)[list.id] == null)) {
        continue;
      }
      if (owner == null || !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(owner)) {
        throw StateError('Could not attribute curated-list recovery');
      }
      (groups[owner] ??= []).add(list);
    }
    for (final group in groups.entries) {
      if (!await _captureRows(
        prefs,
        group.value,
        group.key,
        retireSuperseded: true,
      )) {
        throw StateError('Could not preserve curated-list recovery');
      }
    }
  }

  static Future<bool> _captureRows(
    SharedPreferences prefs,
    List<CuratedList> lists,
    String owner, {
    bool retireSuperseded = false,
  }) async {
    final stored = _read(prefs, owner);
    final before = jsonEncode({
      for (final e in stored.entries) e.key: e.value.toJson(),
    });
    final entries = _mergePending(prefs, owner, stored);
    for (final list in lists) {
      if (list.pubkey != owner && list.pubkey != null) continue;
      final prior = entries[list.id];
      if (retireSuperseded &&
          prior != null &&
          _hasNewerCommittedRevision(list, prior)) {
        entries[list.id] = CuratedListRecoveryRecord(
          plaintextEventIds: prior.plaintextEventIds,
          acceptedEventId: prior.acceptedEventId,
          acceptedAt: prior.acceptedAt,
          requiresPrivateCommit: prior.requiresPrivateCommit && list.isPublic,
        );
      }
      final pending = list.pendingVisibility?.relayAccepted == true
          ? list.pendingVisibility
          : null;
      if (pending == null && list.pendingPlaintextEventIds.isEmpty) continue;
      final previous = entries[list.id];
      entries[list.id] = CuratedListRecoveryRecord(
        plaintextEventIds: {
          ...?previous?.plaintextEventIds,
          ...list.pendingPlaintextEventIds,
        }.toList(growable: false),
        requiresPrivateCommit:
            previous?.requiresPrivateCommit == true ||
            (pending != null && !pending.isPublic) ||
            (list.nostrEventId == null &&
                !list.isPublic &&
                list.pendingPlaintextEventIds.isNotEmpty),
        visibility: previous?.visibility ?? pending,
        acceptedEventId: previous?.acceptedEventId,
        acceptedAt:
            previous?.acceptedAt ?? (pending == null ? null : list.updatedAt),
      );
    }
    final after = jsonEncode({
      for (final e in entries.entries) e.key: e.value.toJson(),
    });
    final needsDrain = _pendingOwners(prefs)[owner]?.isNotEmpty == true;
    final saved =
        (!needsDrain && before == after) || await _write(prefs, owner, entries);
    if (saved) _pendingOwners(prefs).remove(owner);
    return saved;
  }

  static Map<String, CuratedListRecoveryRecord> _mergePending(
    SharedPreferences prefs,
    String owner,
    Map<String, CuratedListRecoveryRecord> entries,
  ) {
    for (final entry in (_pendingOwners(prefs)[owner] ?? {}).entries) {
      final accepted = entry.value;
      entries[entry.key] = CuratedListRecoveryRecord(
        plaintextEventIds: {
          ...?entries[entry.key]?.plaintextEventIds,
          ...accepted.plaintextEventIds,
        }.toList(growable: false),
        visibility: accepted.visibility,
        acceptedEventId: accepted.acceptedEventId,
        acceptedAt: accepted.acceptedAt,
        requiresPrivateCommit: accepted.requiresPrivateCommit,
      );
    }
    return entries;
  }

  static Map<String, CuratedListRecoveryRecord> _read(
    SharedPreferences prefs,
    String owner,
  ) {
    final encoded = prefs.getString(storageKey(owner));
    if (encoded == null) return {};
    final json = jsonDecode(encoded) as Map<String, dynamic>;
    return {
      for (final entry in json.entries)
        entry.key: CuratedListRecoveryRecord.fromJson(
          entry.value as Map<String, dynamic>,
        ),
    };
  }

  static Future<bool> _write(
    SharedPreferences prefs,
    String owner,
    Map<String, CuratedListRecoveryRecord> entries,
  ) async {
    final json = {
      for (final entry in entries.entries)
        if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
    };
    final saved = json.isEmpty
        ? await prefs.remove(storageKey(owner))
        : await prefs.setString(storageKey(owner), jsonEncode(json));
    // SharedPreferences caches a refused write optimistically. Reload the
    // actual durable value before another operation can regard it as evidence.
    if (!saved) {
      await prefs.reload();
    } else {
      _pendingOwners(prefs).remove(owner);
    }
    return saved;
  }
}
