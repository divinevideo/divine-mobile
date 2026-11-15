// ABOUTME: Restores only the activated owner's private pending-list archive.
// ABOUTME: Fences every await and consumes archives only after verified cache save.

part of '../curated_list_service.dart';

extension _CuratedListDraftRestoration on CuratedListService {
  Future<T> _afterDraftRestoration<T>(
    String? owner,
    Future<T> Function() operation, {
    required T cancelled,
  }) {
    if (_draftArchive == null || _draftsRestored || owner == null) {
      return operation();
    }
    return _ensureDraftsRestored(owner).then((restored) {
      if (!restored || !_isCurrent(owner)) return cancelled;
      return operation();
    });
  }

  Future<bool> _ensureDraftsRestored(String? owner) async {
    if (_draftArchive == null || _draftsRestored || owner == null) return true;
    if (!_isCurrent(owner)) return false;
    final previous = _draftRestoration;
    if (previous != null) return previous;
    final operation = _restoreOwnerDrafts(owner);
    _draftRestoration = operation;
    try {
      return await operation;
    } finally {
      if (identical(_draftRestoration, operation)) _draftRestoration = null;
    }
  }

  Future<bool> _restoreOwnerDrafts(String owner) async {
    try {
      final archive = _draftArchive!;
      final snapshot = await archive.readOwner(owner);
      if (!_isCurrent(owner)) return false;
      if (snapshot == null) {
        _draftsRestored = true;
        return true;
      }
      if (snapshot.owner != owner) return false;
      final prepared = await _sessions.runCurrent<bool>(
        _sessionLease,
        () async {
          await _prefs.reload();
          if (!_isCurrent(owner) || recoveryNeedsRepair) return false;
          _loadLists();
          for (final retained in snapshot.lists) {
            if (retained.pubkey != owner) return false;
            if (_cacheStore.wasListDeleted(owner, retained.id) ||
                (retained.id == defaultListId &&
                    _cacheStore.wasDefaultListDeleted())) {
              continue;
            }
            final current = getListById(retained.authorScopedId);
            if (current == null) {
              _restoreList(retained);
            } else if (current.localEditDraft == null && current != retained) {
              // A concurrent accepted cache winner remains the displayed
              // baseline; explicit archived intent is kept behind a conflict.
              final draft =
                  retained.localEditDraft ??
                  CuratedListEditDraft(
                    baseline: current,
                    desired: retained,
                    canReplay: false,
                  );
              _restoreList(
                current.copyWith(
                  localEditDraft: draft,
                  hasRelayConflict: true,
                ),
              );
            }
          }
          return _isCurrent(owner);
        },
        cancelled: false,
      );
      if (!prepared || !_isCurrent(owner)) return false;
      if (!await _saveLists() || !_isCurrent(owner)) return false;
      final consumed = await _sessions.runCurrent<bool>(
        _sessionLease,
        () async {
          if (!_isCurrent(owner)) return false;
          return archive.consumeOwner(owner, snapshot.revision);
        },
        cancelled: false,
      );
      if (!consumed || !_isCurrent(owner)) return false;
      _draftsRestored = true;
      return true;
    } on Object catch (error) {
      Log.warning(
        'Pending list restoration failed (${error.runtimeType})',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }
}
