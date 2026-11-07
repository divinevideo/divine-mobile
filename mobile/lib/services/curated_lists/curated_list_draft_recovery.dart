// ABOUTME: Durable local edits and explicit adoption of a complete relay revision.
// ABOUTME: Keeps user intent through offline reads without authorizing stale sends.

part of '../curated_list_service.dart';

extension _CuratedListDraftRecovery on CuratedListService {
  /// Discards only this coordinate's pending edit, after a complete fresh read.
  /// Call only for an explicit owner action; startup and retries never adopt it.
  Future<bool> _discardLocalEditsAndAdoptRelay(String listId) {
    final original = getListById(listId);
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (!isReadyForMutations ||
        original == null ||
        owner == null ||
        original.pubkey != owner ||
        original.hasPendingPermissionRecovery ||
        !_cacheStore.hasUnambiguousOwnerEvidence(original) ||
        _recovery.needsPermissionRecovery(original, owner)) {
      return Future.value(false);
    }
    return _sessionLease.runListOperation<bool>(
      original.authorScopedId,
      () async {
        final current = getListById(original.authorScopedId);
        if (current == null ||
            current != original ||
            current.pubkey != owner ||
            current.hasPendingPermissionRecovery ||
            _recovery.needsPermissionRecovery(current, owner)) {
          return false;
        }
        final cancel = Completer<void>();
        _relaySyncCancels.add(cancel);
        try {
          final snapshot = await _relayGateway.readOwnedListForMutation(
            owner,
            current.id,
            timeout: _relaySyncTimeout,
            cancelled: cancel.future,
          );
          if (!snapshot.completedNormally ||
              cancel.isCompleted ||
              !_isCurrent(owner) ||
              getListById(current.authorScopedId) != current) {
            return false;
          }
          final events = CuratedListConverter.latestRevisions(snapshot.events)
              .where(
                (event) =>
                    event.pubkey == owner &&
                    CuratedListConverter.extractDTag(event) == current.id,
              )
              .toList();
          if (events.length != 1) return false;
          final event = events.single;
          if (!event.isValid ||
              !event.isSigned ||
              !await _relayEvidence.observe(event)) {
            return false;
          }
          final items = await _relayGateway.unsealItemTags(
            event,
            canRun: () => !cancel.isCompleted && _isCurrent(owner),
          );
          if (cancel.isCompleted ||
              !_isCurrent(owner) ||
              getListById(current.authorScopedId) != current ||
              _recovery.needsPermissionRecovery(current, owner) ||
              !_relayEvidence.decoded(event, items)) {
            return false;
          }
          _defaultAuthority.beginObservation(event);
          _defaultAuthority.observe(event, items);
          if (current.id == defaultListId &&
              !_defaultAuthority.hasReadableRevision(event)) {
            return false;
          }
          final decoded = CuratedListConverter.fromEvent(
            event,
            privateTags: items.tags,
            isPrivateEvent: items.status == UnsealItemTagsStatus.unsealed,
          );
          if (decoded == null ||
              decoded.authorScopedId != current.authorScopedId ||
              !hasValidCuratedListVisibility(
                decoded.isPublic,
                decoded.isCollaborative,
              )) {
            return false;
          }
          _publishClock.observe(decoded);
          final replacement = decoded.copyWith(
            createdAt: current.createdAt,
            pendingPlaintextEventIds: {
              ...current.pendingPlaintextEventIds,
              if (current.isPublic &&
                  !decoded.isPublic &&
                  current.nostrEventId != null)
                current.nostrEventId!,
            }.toList(),
          );
          _restoreList(replacement);
          if (!await _saveLists()) {
            if (_isCurrent(owner) &&
                getListById(current.authorScopedId) == replacement) {
              _restoreList(current);
            }
            return false;
          }
          if (!_isCurrent(owner)) return false;
          await _relayEvidence.reconciled([event]);
          if (!_isCurrent(owner)) return false;
          notifyListeners();
          return _relayEvidence.allows(replacement);
        } on Object {
          return false;
        } finally {
          _relaySyncCancels.remove(cancel);
        }
      },
      isCurrentOwner: () => isReadyForMutations && _isCurrent(owner),
      cancelled: false,
    );
  }
}
