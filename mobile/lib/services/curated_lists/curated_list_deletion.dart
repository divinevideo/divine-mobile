// ABOUTME: Completes owned-list deletion and durable subscription recovery.
// ABOUTME: Retires permission targets without dropping advisory event IDs.

part of '../curated_list_service.dart';

extension _CuratedListDeletion on CuratedListService {
  Future<bool> _deleteOwnedList(String listId) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        return false;
      }

      final list = _lists[listIndex];
      if (!isOwnedList(listId) ||
          !_cacheStore.hasUnambiguousOwnerEvidence(list)) {
        Log.warning(
          'Cannot delete list not owned by current user: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      if (list.nostrEventId != null || list.pendingRepublish) {
        if (!await _relayGateway.publishListDeletion(
          list.id,
          ownerPubkey: list.pubkey!,
          createdAt: _publishClock.next(
            ownerPubkey: list.pubkey!,
            listId: list.id,
          ),
        )) {
          return false;
        }
      }

      // Recorded whatever the local event id says. A null id does not mean no
      // relay holds this coordinate — another device can have published the
      // same stable d-tag independently, which is the case the unpublished
      // merge in [_processListEvent] exists to handle. Record before removing
      // the local list so relay sync never sees an unprotected absence.
      if (!isCurrentSession) return false;
      if (!await _cacheStore.recordListDeletion(list.pubkey!, list.id) ||
          !await _removeListAndSubscription(list)) {
        return false;
      }

      Log.info(
        'Deleted owned curated list: ${list.name} ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to delete owned curated list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Removes the captured coordinate after the deletion publish completes.
  Future<bool> _removeListAndSubscription(CuratedList list) async {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (list.id == CuratedListService.defaultListId) {
      await _cacheStore.beginDefaultListDeletion(list.pubkey!);
    }
    _lists.removeWhere((item) => item.authorScopedId == list.authorScopedId);
    // Keep the follow until the list removal is durably saved.
    if (!await _saveLists()) {
      if (_isCurrent(owner) &&
          _prefs.getString(CuratedListService.listsStorageKey) != null &&
          getListById(list.authorScopedId) == null) {
        _restoreList(owner == null ? list : _recovery.recover(list, owner));
      }
      return false;
    }
    if (!await _recovery.retirePermissions(
      list.pubkey!,
      list.id,
      coordinateDeletionAccepted:
          list.nostrEventId != null || list.pendingRepublish,
    )) {
      return false;
    }
    if (list.id == CuratedListService.defaultListId) {
      await _cacheStore.markDefaultListDeleted();
      await _cacheStore.finishDefaultListDeletion(list.pubkey!);
    }
    _subscribedListIds.remove(list.authorScopedId);
    if (!_lists.any((item) => item.id == list.id)) {
      _subscribedListIds.remove(list.id);
    }
    if (!await _saveSubscribedListIds()) return false;
    if (isCurrentSession) _onListUnsubscribed?.call(list.authorScopedId);
    return isCurrentSession;
  }

  /// Finishes follow cleanup after an owned list was durably removed.
  ///
  /// Tombstones distinguish this from an arbitrary missing foreign list. Do
  /// not restore an already relay-deleted row to imitate an atomic disk write.
  Future<void> _recoverDeletedSubscriptions() async {
    final owner = _relayGateway.currentAuthenticatedPubkey();
    if (owner == null || !isCurrentSession) return;
    final coordinates = await _cacheStore.recoverRemovedListSubscriptions(
      _lists,
      _subscribedListIds,
      owner: owner,
      defaultListId: CuratedListService.defaultListId,
      saveSubscriptions: () async {
        if (!await _saveSubscribedListIds()) {
          throw CuratedCacheWriteException(
            isCurrentSession
                ? CuratedCacheWriteStatus.storageRejected
                : CuratedCacheWriteStatus.superseded,
          );
        }
      },
    );
    if (!_isCurrent(owner)) return;
    final onUnsubscribed = _onListUnsubscribed;
    if (onUnsubscribed != null) coordinates.forEach(onUnsubscribed);
  }
}
