// ABOUTME: Applies complete verified recovery reconstructions under the queue.
// ABOUTME: Rejects stale/reset proposals and retains original archived evidence.

part of 'curated_list_recovery_journal.dart';

extension CuratedListRecoveryRepair on CuratedListRecoveryJournal {
  /// Opaque repair proposal identity, including live ACKs and account fences.
  String repairSnapshot(String owner) =>
      CuratedListRecoveryStorage.repairSnapshot(_prefs, owner);

  /// An audited reconstruction of local recovery evidence, not relay EOSE or
  /// a newly fetched public list. Empty/reset proposals cannot clear a hold.
  Future<bool> repairVerifiedJournal({
    required String owner,
    required String expectedSnapshot,
    required String reconstructedJournal,
  }) => CuratedListRecoveryStorage.holdRepair(
    _prefs,
    () => _runCurrent(() async {
      if (!needsRepair(owner) || repairSnapshot(owner) != expectedSnapshot) {
        return false;
      }
      Map<String, CuratedListRecoveryRecord> recovered;
      try {
        recovered = CuratedListRecoveryStorage.validateRepairRecords(
          reconstructedJournal,
        );
        if (!CuratedListRecoveryStorage.coversUnresolved(
          _prefs,
          owner,
          recovered,
        )) {
          return false;
        }
      } on Object {
        return false;
      }
      final merged = _mergeVerified(records(owner), recovered);
      if (!await CuratedListRecoveryJournal._write(
        _prefs,
        owner,
        merged,
        verify: true,
      )) {
        return false;
      }
      return CuratedListRecoveryStorage.markRepaired(
        _prefs,
        CuratedListRecoveryStorage.quarantineKey(owner),
      );
    }),
  );

  /// Unknown-owner shared bytes need a complete owner-qualified reconstruction.
  /// The retained raw cache stays archived and is never backfilled into whoever
  /// happens to be signed in while the repair is applied.
  Future<bool> repairVerifiedShared({
    required String activeOwner,
    required String expectedSnapshot,
    required Map<String, String> reconstructedJournals,
  }) => CuratedListRecoveryStorage.holdRepair(
    _prefs,
    () => _runCurrent(() async {
      if (!CuratedListRecoveryStorage.canRepairShared(_prefs) ||
          repairSnapshot(activeOwner) != expectedSnapshot ||
          reconstructedJournals.isEmpty) {
        return false;
      }
      final recovered = <String, Map<String, CuratedListRecoveryRecord>>{};
      try {
        for (final entry in reconstructedJournals.entries) {
          if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(entry.key)) return false;
          recovered[entry.key] =
              CuratedListRecoveryStorage.validateRepairRecords(
                entry.value,
              );
        }
      } on Object {
        return false;
      }
      for (final entry in recovered.entries) {
        if (!await CuratedListRecoveryJournal._write(
          _prefs,
          entry.key,
          _mergeVerified(
            records(entry.key),
            entry.value,
          ),
          verify: true,
        )) {
          return false;
        }
      }
      return CuratedListRecoveryStorage.markRepaired(
        _prefs,
        CuratedListRecoveryStorage.sharedQuarantineKey,
      );
    }),
  );

  static Map<String, CuratedListRecoveryRecord> _mergeVerified(
    Map<String, CuratedListRecoveryRecord> live,
    Map<String, CuratedListRecoveryRecord> recovered,
  ) {
    final merged = Map<String, CuratedListRecoveryRecord>.of(live);
    for (final entry in recovered.entries) {
      final current = live[entry.key];
      // A verified old reconstruction cannot replace a newer live ACK or a
      // retired coordinate, nor resurrect IDs already removed from that row.
      final sameAcceptedRevision =
          current != null &&
          current.acceptedEventId != null &&
          current.acceptedEventId == entry.value.acceptedEventId &&
          current.acceptedAt == entry.value.acceptedAt &&
          current.permissionEpoch == entry.value.permissionEpoch;
      if (current != null &&
          (sameAcceptedRevision ||
              CuratedListRecoveryJournal._preferStored(current, entry.value) ||
              current.permissionsRetired &&
                  current.permissionEpoch >= entry.value.permissionEpoch ||
              current.acceptedAt != null && entry.value.acceptedAt == null)) {
        continue;
      }
      final recoveredRecord = entry.value;
      merged[entry.key] = CuratedListRecoveryRecord(
        plaintextEventIds: {
          ...?current?.plaintextEventIds,
          ...recoveredRecord.plaintextEventIds,
        }.toList(growable: false),
        visibility: recoveredRecord.visibility,
        acceptedEventId: recoveredRecord.acceptedEventId,
        acceptedAt: recoveredRecord.acceptedAt,
        requiresPrivateCommit: recoveredRecord.requiresPrivateCommit,
        permissionEpoch: recoveredRecord.permissionEpoch,
        permissionsRetired: recoveredRecord.permissionsRetired,
      );
    }
    return merged;
  }
}
