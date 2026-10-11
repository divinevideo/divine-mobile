// ABOUTME: Service publication adapter with selective cache reconciliation.
// ABOUTME: Preserves durable winners and bounded account/default authority.

part of '../curated_list_service.dart';

extension CuratedListPublication on CuratedListService {
  Future<bool> _publishListToNostr(
    CuratedList sourceList, {
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
}
