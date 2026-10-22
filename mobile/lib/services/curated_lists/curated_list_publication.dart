// ABOUTME: Service publication adapter with selective cache reconciliation.
// ABOUTME: Preserves durable winners and bounded account/default authority.

part of '../curated_list_service.dart';

extension CuratedListPublication on CuratedListService {
  Future<bool> _publishListToNostr(
    CuratedList sourceList, {
    Event? signedRetry,
    bool confirmed = false,
    bool duringInitialization = false,
    bool explicitDefaultIntent = false,
    void Function()? onPublicationUnconfirmed,
  }) async {
    if (!isCurrentSession ||
        recoveryNeedsRepair ||
        (!isReadyForMutations && !duringInitialization)) {
      return false;
    }
    final target = sourceList.publicationTarget;
    if (!_defaultAuthority.authorizePublication(
      target,
      explicit: explicitDefaultIntent,
    )) {
      return false;
    }
    final published = await _publisher.publish(
      sourceList,
      signedRetry: signedRetry,
      confirmed: confirmed,
      onPublicationUnconfirmed: onPublicationUnconfirmed,
    );
    if (!published && isCurrentSession) {
      _cacheStore.refreshUnchangedLists(_lists);
    }
    return published;
  }

  Future<bool> _persistPublication(
    CuratedList current,
    CuratedList replacement,
  ) async {
    // A disposed account service or an explicitly cleared cache must not
    // recreate old rows when an in-flight acknowledgement arrives.
    if (!_isCurrent(current.pubkey) ||
        _prefs.getString(CuratedListService.listsStorageKey) == null) {
      return false;
    }
    final index = _listIndex(current.authorScopedId);
    if (index == -1 || _lists[index] != current) return false;
    _lists[index] = replacement;
    if (await _saveLists()) return true;
    // A rejected backing write can leave optimistic prefs cached. Restore
    // this candidate only; a newer reconciled row must never be overwritten.
    if (_isCurrent(current.pubkey) &&
        _prefs.getString(CuratedListService.listsStorageKey) != null &&
        getListById(current.authorScopedId) == replacement) {
      final owner = current.pubkey;
      _restoreList(owner == null ? current : _recovery.recover(current, owner));
    }
    return false;
  }

  /// Publishes owned lists that have never reached a relay or need retry.
  ///
  /// Before private lists were published, they existed only in
  /// SharedPreferences and died with the device; the same is true of any list
  /// created while the app could not reach a relay. Failed edits keep
  /// [CuratedList.nostrEventId] as the marker that a relay may still hold this
  /// coordinate, and set [CuratedList.pendingRepublish] for the retry.
  Future<bool> _backfillUnpublishedLists() async {
    if (!_authService.isAuthenticated || !isReadyForMutations) return false;

    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null) return false;

    final stranded = _lists
        .where(
          (list) =>
              _relayEvidence.allows(list) &&
              (list.nostrEventId == null ||
                  list.pendingRepublish ||
                  list.pendingPlaintextEventIds.isNotEmpty) &&
              (list.pubkey == owner || _isUnpublishedLocalList(list)),
        )
        .toList(growable: false);
    if (stranded.isEmpty) return true;

    Log.info(
      'Backing up ${stranded.length} list(s) that never reached a relay',
      name: 'CuratedListService',
      category: LogCategory.system,
    );

    for (final list in stranded) {
      final saved = await _serializeListOperation<bool>(list.id, () async {
        final currentOwner = _relayGateway.currentAuthenticatedPubkey();
        if (currentOwner == null ||
            currentOwner != owner ||
            !_isCurrent(owner)) {
          return false;
        }
        var current = getListById(list.authorScopedId);
        if (current == null) return false;
        if (!_cacheStore.hasUnambiguousOwnerEvidence(current)) return false;
        if (!_relayEvidence.allows(current)) return true;
        // An ACKed permission target is completed by the visible Sync now
        // action, never silently through a new edit or startup publication.
        if (current.hasPendingPermissionRecovery) return true;
        if (current.id == defaultListId &&
            !_defaultAuthority.authorizeCreation(
              current.copyWith(pubkey: currentOwner),
            )) {
          return true;
        }
        if (current.nostrEventId != null && !current.pendingRepublish) {
          await _publisher.retryPlaintextRedactions(current.authorScopedId);
          return _isCurrent(owner);
        }
        if (_isUnpublishedLocalList(current)) {
          final currentId = current.id;
          final currentIndex = _listIndex(currentId);
          if (currentIndex == -1) return false;
          final source = current;
          current = current.copyWith(pubkey: currentOwner);
          _lists[currentIndex] = current;
          if (!await _saveLists(
                ownershipClaims: {current.authorScopedId: source},
              ) ||
              !_isCurrent(owner)) {
            return false;
          }
        }
        if (current.pubkey != currentOwner) return false;
        await _publishListToNostr(current, confirmed: true);
        return _isCurrent(owner);
      }, cancelled: false);
      if (!saved) return false;
    }
    return true;
  }

  /// Retries this list's pending publication without changing its members.
  Future<bool> _retryListSync(String listId) => _serializeListOperation(
    listId,
    () async {
      final operationOwner = _relayGateway.currentAuthenticatedPubkey();
      if (operationOwner == null || !_isCurrent(operationOwner)) return false;
      final retainedList = getListById(listId);
      if (retainedList != null && !_relayEvidence.allows(retainedList)) {
        final event = _relayEvidence.retainedFor(retainedList);
        if (event == null ||
            !await _processReceivedListEvents(
              [event],
              isCurrentRead: () => _isCurrent(operationOwner),
            ) ||
            !_relayEvidence.allows(retainedList)) {
          return false;
        }
      }
      final list = getListById(listId);
      if (!isCurrentSession) return false;
      if (list == null) {
        final owner = _relayGateway.currentAuthenticatedPubkey();
        if (owner == null || !listId.startsWith('$owner:')) return false;
        final id = listId.substring(owner.length + 1);
        if (_recovery.record(owner, id) == null) return false;
        return _publisher.retryPlaintextRedactions(listId);
      }
      if (!isOwnedList(listId)) return false;
      Event? signedRetry;
      if (list.id == defaultListId) {
        final signed = await _defaultSignedIntentStore?.read(list.pubkey!);
        if (signed != null) {
          final items = await _relayGateway.unsealItemTags(signed);
          if (!isCurrentSession || getListById(listId) != list) return false;
          if (_defaultAuthority.restoreSignedRetry(signed, items, list)) {
            signedRetry = signed;
          }
        }
      }
      if (!_defaultAuthority.canRetrySavedPublication(list)) {
        return false;
      }
      if (list.nostrEventId != null &&
          !list.pendingRepublish &&
          list.pendingVisibility == null &&
          list.pendingPlaintextEventIds.isNotEmpty) {
        return _publisher.retryPlaintextRedactions(list.authorScopedId);
      }
      return _publishListToNostr(
        list,
        signedRetry: signedRetry,
        confirmed: true,
        explicitDefaultIntent: true,
      );
    },
    cancelled: false,
  );
}
