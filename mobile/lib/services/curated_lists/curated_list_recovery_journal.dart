// ABOUTME: Keeps minimal owner-scoped recovery evidence outside the list cache.
// ABOUTME: Retains accepted permission targets and pending NIP-09 event IDs.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';
import 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

export 'package:openvine/services/curated_lists/curated_list_recovery_record.dart';
export 'package:openvine/services/curated_lists/curated_list_recovery_storage.dart'
    show CuratedListRecoveryException, CuratedListRecoveryReadStatus;

part 'curated_list_recovery_repair.dart';

/// Captures authorization for a signed attempt's minimal accepted evidence.
class CuratedListRecoveryTicket {
  const CuratedListRecoveryTicket._({
    required this.owner,
    required this.listId,
    required this.ownerGeneration,
    required this.permissionEpoch,
  });

  final String owner;
  final String listId;
  final int ownerGeneration;
  final int permissionEpoch;
}

/// The account-session owner supplies the device-wide storage barrier.
///
/// Ordinary logout preserves these scoped buckets. Explicit deletion of an
/// account's local data removes only that account's bucket.
class CuratedListRecoveryJournal {
  CuratedListRecoveryJournal({
    required SharedPreferences prefs,
    required Future<bool> Function(Future<bool> Function()) runCurrent,
    Future<bool> Function(Future<bool> Function())? runEvidence,
  }) : _prefs = prefs,
       _runCurrent = runCurrent,
       _runEvidence = runEvidence ?? runCurrent;

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
  final Future<bool> Function(Future<bool> Function()) _runEvidence;

  /// Unknown accepted evidence blocks edits rather than implying empty state.
  bool get legacyNeedsRepair =>
      CuratedListRecoveryStorage.legacyNeedsRepair(_prefs);

  void validateLegacy() => CuratedListRecoveryStorage.legacyRows(_prefs);

  bool needsRepair(String owner) =>
      legacyNeedsRepair ||
      CuratedListRecoveryStorage.needsRepair(
        _prefs,
        storageKey(owner),
        owner,
      );

  /// Preserves malformed bytes before reads can resume with a publication hold.
  /// Refused preservation still reports a typed initialization failure.
  Future<void> prepare(String owner) async {
    await _runCurrent(() async {
      await CuratedListRecoveryStorage.refreshEvidence(_prefs);
      await CuratedListRecoveryStorage.normalizeLegacy(
        _prefs,
        legacyOwner: _prefs.getString('current_user_pubkey_hex'),
      );
      _generation(_prefs, owner);
      await CuratedListRecoveryStorage.normalize(
        _prefs,
        storageKey(owner),
        owner,
        records(owner),
      );
      if (!await _captureRows(
        _prefs,
        CuratedListRecoveryStorage.legacyRows(_prefs),
        owner,
        retireSuperseded: !CuratedListRecoveryStorage.legacyNeedsRepair(_prefs),
      )) {
        throw const CuratedListRecoveryException();
      }
      return true;
    });
  }

  /// Captured before sending; ordinary logout does not revoke evidence writes.
  Future<CuratedListRecoveryTicket?> ticket(String owner, String listId) async {
    CuratedListRecoveryTicket? captured;
    await _runCurrent(() async {
      if (needsRepair(owner)) return false;
      captured = CuratedListRecoveryTicket._(
        owner: owner,
        listId: listId,
        ownerGeneration: _generation(_prefs, owner),
        permissionEpoch: record(owner, listId)?.permissionEpoch ?? 0,
      );
      return true;
    });
    return captured;
  }

  static int _generation(SharedPreferences prefs, String owner) {
    final key = CuratedListRecoveryStorage.generationKey(owner);
    final value = prefs.get(key);
    if (value == null) return 0;
    if (value is! int || value < 0) {
      throw const CuratedListRecoveryException();
    }
    return value;
  }

  /// Runs under the cleanup barrier before deleting an owner's local data.
  static Future<void> invalidateOwner(
    SharedPreferences prefs,
    String owner,
  ) async {
    final key = CuratedListRecoveryStorage.generationKey(owner);
    final next = _generation(prefs, owner) + 1;
    if (!await CuratedListRecoveryStorage.persist(
      prefs,
      () => prefs.setInt(key, next),
    )) {
      throw const CuratedListRecoveryException();
    }
  }

  /// Removes only this owner's evidence under cleanup's exclusive barrier.
  /// The caller first durably invalidates the owner's outstanding tickets.
  static Future<List<String>> removeOwnerEvidence(
    SharedPreferences prefs,
    String owner,
  ) async {
    final removed = <String>[];
    for (final key in [
      storageKey(owner),
      CuratedListRecoveryStorage.quarantineKey(owner),
    ]) {
      if (!prefs.containsKey(key)) continue;
      if (!await CuratedListRecoveryStorage.persist(
        prefs,
        () => prefs.remove(key),
      )) {
        throw const CuratedListRecoveryException();
      }
      removed.add(key);
    }
    discardPendingAccepted(prefs, owner);
    return removed;
  }

  Map<String, CuratedListRecoveryRecord> records(String owner) =>
      _mergePending(_prefs, owner, _read(_prefs, owner));

  CuratedListRecoveryRecord? record(String owner, String listId) =>
      records(owner)[listId];

  /// Reattaches only the current owner's recovery evidence to its cache row.
  CuratedList recover(CuratedList list, String owner) {
    if (list.pubkey != owner) return list;
    final saved = record(owner, list.id);
    if (saved == null) return list;
    if (saved.permissionsRetired) {
      return list.copyWith(
        clearPendingVisibility: true,
        pendingPlaintextEventIds: {
          ...list.pendingPlaintextEventIds,
          ...saved.plaintextEventIds,
        }.toList(growable: false),
      );
    }
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
    final target = saved?.permissionsRetired == true ? null : saved?.visibility;
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
    CuratedListRecoveryTicket? ticket,
  }) {
    if (!visibility.relayAccepted) return Future.value(false);
    final run = ticket == null ? _runCurrent : _runEvidence;
    return run(() async {
      if (ticket != null &&
          (ticket.owner != owner ||
              ticket.listId != listId ||
              ticket.ownerGeneration != _generation(_prefs, owner) ||
              ticket.permissionEpoch !=
                  (record(owner, listId)?.permissionEpoch ?? 0))) {
        return false;
      }
      final previous = record(owner, listId);
      final pending = _pendingOwners(_prefs).putIfAbsent(owner, () => {});
      pending[listId] = CuratedListRecoveryRecord(
        plaintextEventIds: {
          ...?pending[listId]?.plaintextEventIds,
          ...plaintextEventIds,
        }.toList(growable: false),
        visibility: visibility,
        acceptedEventId: eventId,
        acceptedAt: acceptedAt,
        requiresPrivateCommit:
            !visibility.isPublic || previous?.requiresPrivateCommit == true,
        permissionEpoch:
            ticket?.permissionEpoch ??
            record(owner, listId)?.permissionEpoch ??
            0,
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
      permissionEpoch: previous.permissionEpoch,
      permissionsRetired: previous.permissionsRetired,
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
          permissionEpoch: previous.permissionEpoch,
          permissionsRetired: previous.permissionsRetired,
          requiresPrivateCommit: previous.requiresPrivateCommit,
        );
        return _write(_prefs, owner, entries);
      });

  /// Retires accepted permissions while preserving advisory deletion evidence.
  Future<bool> retirePermissions(
    String owner,
    String listId, {
    bool coordinateDeletionAccepted = false,
  }) => _runCurrent(() async {
    final entries = records(owner);
    final previous = entries[listId];
    if (previous?.permissionsRetired == true) return true;
    entries[listId] = CuratedListRecoveryRecord(
      plaintextEventIds: previous?.plaintextEventIds ?? const [],
      acceptedEventId: previous?.acceptedEventId,
      acceptedAt: previous?.acceptedAt,
      requiresPrivateCommit:
          !coordinateDeletionAccepted &&
          previous?.requiresPrivateCommit == true,
      permissionEpoch: (previous?.permissionEpoch ?? 0) + 1,
      permissionsRetired: true,
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
    await CuratedListRecoveryStorage.normalizeLegacy(
      prefs,
      legacyOwner: legacyOwner,
    );
    final owners = <String>{
      ..._pendingOwners(prefs).keys,
      for (final key in prefs.getKeys())
        if (key.startsWith(storagePrefix)) key.substring(storagePrefix.length),
    };
    for (final owner in owners) {
      if (owner == deletingOwner) continue;
      if (!await _captureRows(prefs, const [], owner)) {
        throw StateError('Could not preserve acknowledged curated recovery');
      }
    }
    final groups = <String, List<CuratedList>>{};
    for (final list in CuratedListRecoveryStorage.legacyRows(prefs)) {
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
        retireSuperseded: !CuratedListRecoveryStorage.legacyNeedsRepair(prefs),
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
          permissionEpoch: prior.permissionEpoch,
          permissionsRetired: prior.permissionsRetired,
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
        permissionEpoch: previous?.permissionEpoch ?? 0,
        permissionsRetired: previous?.permissionsRetired ?? false,
        visibility: previous?.permissionsRetired == true
            ? null
            : previous?.visibility ?? pending,
        acceptedEventId: previous?.acceptedEventId,
        acceptedAt:
            previous?.acceptedAt ?? (pending == null ? null : list.updatedAt),
      );
    }
    final after = jsonEncode({
      for (final e in entries.entries) e.key: e.value.toJson(),
    });
    final needsDrain = _pendingOwners(prefs)[owner]?.isNotEmpty == true;
    final repair = CuratedListRecoveryStorage.needsRepair(
      prefs,
      storageKey(owner),
      owner,
    );
    if (repair) {
      await CuratedListRecoveryStorage.normalize(
        prefs,
        storageKey(owner),
        owner,
        entries,
      );
    }
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
      final stored = entries[entry.key];
      final selected = stored != null && _preferStored(stored, accepted)
          ? stored
          : accepted;
      entries[entry.key] = CuratedListRecoveryRecord(
        plaintextEventIds: {
          ...?stored?.plaintextEventIds,
          ...accepted.plaintextEventIds,
        }.toList(growable: false),
        visibility: selected.visibility,
        acceptedEventId: selected.acceptedEventId,
        acceptedAt: selected.acceptedAt,
        requiresPrivateCommit: selected.requiresPrivateCommit,
        permissionEpoch: selected.permissionEpoch,
        permissionsRetired: selected.permissionsRetired,
      );
    }
    return entries;
  }

  static bool _preferStored(
    CuratedListRecoveryRecord stored,
    CuratedListRecoveryRecord accepted,
  ) {
    if (stored.permissionEpoch != accepted.permissionEpoch) {
      return stored.permissionEpoch > accepted.permissionEpoch;
    }
    if (stored.permissionsRetired != accepted.permissionsRetired) {
      return !stored.permissionsRetired;
    }
    final storedAt = stored.acceptedAt;
    final acceptedAt = accepted.acceptedAt;
    if (storedAt == null || acceptedAt == null) return false;
    if (storedAt != acceptedAt) return storedAt.isAfter(acceptedAt);
    return stored.acceptedEventId != null &&
        accepted.acceptedEventId != null &&
        stored.acceptedEventId!.compareTo(accepted.acceptedEventId!) < 0;
  }

  static Map<String, CuratedListRecoveryRecord> _read(
    SharedPreferences prefs,
    String owner,
  ) {
    final read = CuratedListRecoveryStorage.read(prefs, storageKey(owner));
    try {
      return {
        ...read.records,
        ...CuratedListRecoveryStorage.preservedRecords(
          prefs,
          owner,
          liveKey: storageKey(owner),
        ),
      };
    } on CuratedListRecoveryException {
      return read.records;
    }
  }

  static Future<bool> _write(
    SharedPreferences prefs,
    String owner,
    Map<String, CuratedListRecoveryRecord> entries, {
    bool verify = false,
  }) async {
    final json = {
      for (final entry in entries.entries)
        if (!entry.value.isEmpty) entry.key: entry.value.toJson(),
    };
    if (CuratedListRecoveryStorage.needsRepair(
      prefs,
      storageKey(owner),
      owner,
    )) {
      await CuratedListRecoveryStorage.normalize(
        prefs,
        storageKey(owner),
        owner,
        entries,
      );
      // Existing authorized ACKs may still drain into the healthy journal.
      // The archive's unresolved hold blocks fresh attempts, not evidence.
    }
    var saved = verify && json.isNotEmpty
        ? await CuratedListRecoveryStorage.writeVerified(
            prefs,
            storageKey(owner),
            jsonEncode(json),
          )
        : await CuratedListRecoveryStorage.persist(
            prefs,
            () => json.isEmpty
                ? prefs.remove(storageKey(owner))
                : prefs.setString(storageKey(owner), jsonEncode(json)),
          );
    if (verify && json.isEmpty && saved) {
      await prefs.reload();
      saved = !prefs.containsKey(storageKey(owner));
    }
    if (saved) _pendingOwners(prefs).remove(owner);
    return saved;
  }
}
