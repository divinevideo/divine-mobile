// ABOUTME: Coordinates guarded draft mutations and explicit relay conflict recovery.
// ABOUTME: Keeps user intent through offline reads without authorizing stale sends.

part of '../curated_list_service.dart';

extension _CuratedListDraftRecovery on CuratedListService {
  Future<T> _serializeListOperation<T>(
    String listId,
    Future<T> Function() operation, {
    T? cancelled,
    bool recovering = false,
    bool allowOfflineDraft = false,
  }) {
    if (!isReadyForMutations) return Future.value(cancelled as T);
    final owner = _relayGateway.currentAuthenticatedPubkey();
    return _afterDraftRestoration(
      owner,
      () => _sessionLease.runListOperation(
        getListById(listId)?.authorScopedId ?? listId,
        () async {
          if (!await _reconcileListBeforeMutation(
            listId,
            owner,
            recovering: recovering,
            allowOfflineDraft: allowOfflineDraft,
          )) {
            return cancelled;
          }
          try {
            return await operation();
          } finally {
            _offlineListOperations.remove(listId);
          }
        },
        isCurrentOwner: () => isReadyForMutations && _isCurrent(owner),
        cancelled: cancelled,
      ),
      cancelled: cancelled as T,
    );
  }

  void _restoreList(CuratedList list) {
    final index = _lists.indexWhere(
      (item) => item.authorScopedId == list.authorScopedId,
    );
    if (index == -1) {
      _lists.add(list);
    } else {
      _lists[index] = list;
    }
    notifyListeners();
  }

  // Retaining intent grants no default-list publication authority. The normal
  // owner, evidence, permission-recovery and storage holds still apply.
  bool _canStageOfflineDraft(CuratedList list) =>
      isReadyForMutations &&
      _defaultAuthority.canMutate(list) &&
      !list.hasRelayConflict &&
      !list.hasPendingPermissionRecovery &&
      list.pubkey != null &&
      list.pubkey == _authService.currentPublicKeyHex &&
      !_recovery.needsPermissionRecovery(list, list.pubkey!) &&
      _relayEvidence.allows(list) &&
      _cacheStore.hasUnambiguousOwnerEvidence(list);

  /// Only an explicitly owned row or an unpublished local draft can change.
  /// Remembered owners may edit offline; relay signing still requires auth.
  bool _canMutateCachedList(CuratedList list) {
    if (!isReadyForMutations ||
        list.hasRelayConflict ||
        list.hasPendingPermissionDraft ||
        !_defaultAuthority.canMutate(list) ||
        !_relayEvidence.allows(list) ||
        !_cacheStore.hasUnambiguousOwnerEvidence(list)) {
      return false;
    }
    if (list.pubkey != null) {
      final owner = _authService.currentPublicKeyHex;
      return owner != null && owner.isNotEmpty && list.pubkey == owner;
    }
    return _isUnpublishedLocalList(list) &&
        (!_authService.isAuthenticated ||
            _relayGateway.currentAuthenticatedPubkey() != null);
  }

  /// Missing follow metadata is known empty; unreadable metadata is not proof
  /// that an ownerless row belongs to this account. Check both legacy aliases.
  bool _isUnpublishedLocalList(CuratedList list) {
    if (list.pubkey != null ||
        list.nostrEventId != null ||
        !_hasLoadedSubscriptionIds ||
        !_cacheStore.hasUnambiguousOwnerEvidence(list)) {
      return false;
    }
    // A local draft keeps its null coordinate for guests. Claiming it on
    // sign-in must not alias an already owned row, nor a duplicate local row.
    final owner = _relayGateway.currentAuthenticatedPubkey();
    final candidates = _lists.where(
      (cached) =>
          cached.id == list.id &&
          (cached.pubkey == null || cached.pubkey == owner),
    );
    if (candidates.length != 1) return false;
    final snapshot = readCuratedListSubscriptionSnapshot(
      preferences: _prefs,
      storageKey: CuratedListService.subscribedListsStorageKey,
      fallback: _subscribedListIds,
    );
    return snapshot.isReadable &&
        !snapshot.ids.contains(list.id) &&
        !snapshot.ids.contains(list.authorScopedId) &&
        !_subscribedListIds.contains(list.id) &&
        !_subscribedListIds.contains(list.authorScopedId) &&
        (owner == null ||
            _cacheStore.canClaimLocalList(list, '$owner:${list.id}'));
  }

  Future<bool> _commitListMutation(CuratedList updatedList) async {
    if (recoveryNeedsRepair) return false;
    final listIndex = _lists.indexWhere(
      (list) => list.authorScopedId == updatedList.authorScopedId,
    );
    if (listIndex == -1) return false;

    final previous = _lists[listIndex];
    if (!_canMutateCachedList(previous)) return false;
    if (!updatedList.isPublic &&
        !_relayGateway.privateItemPayloadFits(updatedList)) {
      return false;
    }
    final ownedUpdate = updatedList.copyWith(
      pubkey: updatedList.pubkey ?? _relayGateway.currentAuthenticatedPubkey(),
    );
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (previous.hasPendingPermissionRecovery ||
        (previous.pubkey != null &&
            _recovery.needsPermissionRecovery(previous, previous.pubkey!))) {
      return false;
    }
    _publishClock.observe(previous);
    final changesPermissions =
        CuratedListVisibility.fromList(previous) !=
        CuratedListVisibility.fromList(ownedUpdate);
    if (changesPermissions && !_authService.isAuthenticated) return false;
    final intent = _defaultAuthority.reserveMutation(previous, ownedUpdate);
    if (intent == null) return false;
    final retainPermissions =
        _offlineListOperations.contains(previous.id) ||
        _offlineListOperations.contains(previous.authorScopedId);
    final draft = CuratedListDraftReconciler.stage(
      previous,
      retainPermissions
          ? ownedUpdate
          : ownedUpdate.copyWith(
              isPublic: previous.isPublic,
              isCollaborative: previous.isCollaborative,
              allowedCollaborators: previous.allowedCollaborators,
            ),
    );
    final locallySaved = ownedUpdate
        .stageVisibilityFrom(previous)
        .copyWith(
          localEditDraft: draft,
        );
    _lists[listIndex] = locallySaved;
    if (!await _saveLists(
      ownershipClaims: previous.pubkey == null && ownedUpdate.pubkey != null
          ? {ownedUpdate.authorScopedId: previous}
          : const {},
    )) {
      intent.rollback();
      if (_isCurrent(owner) &&
          _prefs.getString(CuratedListService.listsStorageKey) != null &&
          getListById(previous.authorScopedId) == locallySaved) {
        _restoreList(
          owner == null ? previous : _recovery.recover(previous, owner),
        );
      }
      return false;
    }

    if (_offlineListOperations.contains(previous.id) ||
        _offlineListOperations.contains(previous.authorScopedId)) {
      return !_authService.isAuthenticated;
    }
    if (_authService.isAuthenticated &&
        !await _publishListToNostr(
          ownedUpdate.copyWith(localEditDraft: draft),
        )) {
      final currentIndex = _lists.indexWhere(
        (list) => list.authorScopedId == ownedUpdate.authorScopedId,
      );
      if (currentIndex != -1 && _lists[currentIndex] == locallySaved) {
        _lists[currentIndex] = _lists[currentIndex].copyWith(
          pendingRepublish: true,
        );
        await _saveLists();
      }
      return false;
    }
    return true;
  }

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
          final draft = current.localEditDraft;
          if (events.isEmpty &&
              current.nostrEventId == null &&
              draft != null &&
              draft.baseline.nostrEventId == null &&
              _relayEvidence.allows(current) &&
              _defaultAuthority.canMutate(current)) {
            // No remote replacement exists. The original local list is the
            // only proven baseline for this explicit discard choice.
            final replacement = draft.baseline.copyWith(
              createdAt: current.createdAt,
              pendingPlaintextEventIds: current.pendingPlaintextEventIds,
              clearLocalEditDraft: true,
              hasRelayConflict: false,
            );
            _restoreList(replacement);
            if (!await _saveLists()) {
              if (_isCurrent(owner) &&
                  getListById(current.authorScopedId) == replacement) {
                _restoreList(current);
              }
              return false;
            }
            return _isCurrent(owner);
          }
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
