// ABOUTME: Authenticated service entry points for audited privacy recovery.
// ABOUTME: Repairs records without replaying raw archives into an incoming owner.

part of '../curated_list_service.dart';

extension CuratedListRecoveryService on CuratedListService {
  /// Repair tools must carry the snapshot and a complete audited journal;
  /// public relay results alone cannot release unknown permission/deletion work.
  String? get recoveryRepairSnapshot {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    return owner == null || !_isCurrent(owner)
        ? null
        : _recovery.repairSnapshot(owner);
  }

  /// Returns true only when all holds affecting this account are resolved.
  /// A per-owner journal can be durably repaired while a device hold remains.
  Future<bool> repairRecoveryFromVerifiedJournal({
    required String expectedSnapshot,
    required String reconstructedJournal,
  }) async {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null || !_isCurrent(owner)) return false;
    return _performVerifiedRecovery(
      owner,
      () => _recovery.repairVerifiedJournal(
        owner: owner,
        expectedSnapshot: expectedSnapshot,
        reconstructedJournal: reconstructedJournal,
      ),
    );
  }

  Future<bool> repairSharedRecoveryFromVerifiedJournals({
    required String expectedSnapshot,
    required Map<String, String> reconstructedJournals,
  }) async {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null || !_isCurrent(owner)) return false;
    return _performVerifiedRecovery(
      owner,
      () => _recovery.repairVerifiedShared(
        activeOwner: owner,
        expectedSnapshot: expectedSnapshot,
        reconstructedJournals: reconstructedJournals,
      ),
    );
  }

  Future<bool> _performVerifiedRecovery(
    String owner,
    Future<bool> Function() repair,
  ) async {
    _recoveryPreparations++;
    var completed = false;
    try {
      completed = await CuratedListRecoveryStorage.holdRepair(_prefs, () async {
        final saved = await repair();
        if (!saved || !_isCurrent(owner)) return false;
        _loadLists();
        _isInitialized = false;
        // Rebuild reads while every container remains held; no default or
        // publication may race an optimistic final marker.
        await initialize();
        return _isCurrent(owner) && _initializationError == null;
      });
    } finally {
      _recoveryPreparations--;
      _notifyRecoveryChanged(owner);
    }
    if (!completed || !_isCurrent(owner) || recoveryNeedsRepair) return false;
    // The marker and live journal are now durably verified. Resume ordinary
    // initialization only after the shared hold has been released.
    _isInitialized = false;
    await initialize();
    return _isCurrent(owner) && isReadyForMutations;
  }
}
