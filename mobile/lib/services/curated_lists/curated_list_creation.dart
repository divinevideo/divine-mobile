// ABOUTME: Creates owned curated lists: saves the new list locally, then
// ABOUTME: publishes it to relays without waiting for one to accept it.

part of '../curated_list_service.dart';

extension _CuratedListCreation on CuratedListService {
  Future<CuratedList?> _createList({
    required String name,
    bool duringInitialization = false,
    String? id,
    String? description,
    String? imageUrl,
    bool isPublic = true,
    List<String> tags = const [],
    bool isCollaborative = false,
    List<String> allowedCollaborators = const [],
    String? thumbnailEventId,
    PlayOrder playOrder = PlayOrder.chronological,
  }) async {
    try {
      if (!hasValidCuratedListVisibility(isPublic, isCollaborative)) {
        Log.warning(
          'Cannot create a private collaborative list - private items are '
          'encrypted to the owner only',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return null;
      }

      if (!isCurrentSession || recoveryNeedsRepair) return null;
      final now = clock.now();
      final listId = id ?? _cacheIndex.nextLocalId(now);
      final ownerPubkey = _relayGateway.currentAuthenticatedPubkey();

      final newList = CuratedList(
        id: listId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        videoEventIds: const [],
        pubkey: ownerPubkey,
        createdAt: now,
        updatedAt: now,
        isPublic: isPublic,
        tags: tags,
        isCollaborative: isCollaborative,
        allowedCollaborators: allowedCollaborators,
        thumbnailEventId: thumbnailEventId,
        playOrder: playOrder,
      );

      if (!_defaultAuthority.authorizeCreation(newList)) return null;
      if (ownerPubkey != null) {
        if (_cacheStore.wasListDeleted(ownerPubkey, listId) &&
            !await _recovery.retirePermissions(ownerPubkey, listId)) {
          return null;
        }
        await _cacheStore.forgetListDeletion(ownerPubkey, listId);
      }

      _lists.add(newList);
      if (!await _saveLists()) {
        _lists.remove(newList);
        notifyListeners();
        if (duringInitialization) {
          throw const CuratedCacheWriteException(
            CuratedCacheWriteStatus.storageRejected,
          );
        }
        return null;
      }

      if (_authService.isAuthenticated) {
        if (duringInitialization) {
          await _publishListToNostr(
            newList,
            confirmed: true,
            duringInitialization: true,
          );
        } else {
          await _serializeListOperation(listId, () async {
            final current = getListById(listId);
            if (current == null || current.nostrEventId != null) return;
            await _publishListToNostr(current, confirmed: true);
          });
        }
      }

      Log.info(
        'Created new curated list: $name ($listId)',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return isCurrentSession ? getListById(listId) ?? newList : null;
    } catch (e) {
      Log.error(
        'Failed to create curated list: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      if (duringInitialization) rethrow;
      return null;
    }
  }
}
