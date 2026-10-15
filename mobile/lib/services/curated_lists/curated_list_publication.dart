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

  /// Retries this list's pending publication without changing its members.
  Future<bool> _retryListSync(String listId) => _serializeListOperation(
    listId,
    () async {
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
