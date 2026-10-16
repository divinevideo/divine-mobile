// ABOUTME: Applies playlist ordering through the curated-list mutation boundary.
// ABOUTME: Keeps manual validation and playback order modes together.

part of '../curated_list_service.dart';

extension _CuratedListPlaylist on CuratedListService {
  Future<bool> _reorderVideos(String listId, List<String> newOrder) async {
    try {
      final listIndex = _listIndex(listId);
      if (listIndex == -1) {
        Log.warning(
          'List not found: $listId',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final list = _lists[listIndex];

      // Validate that all current videos are included in the new order
      final currentVideos = Set<String>.from(list.videoEventIds);
      final newOrderSet = Set<String>.from(newOrder);

      if (currentVideos.difference(newOrderSet).isNotEmpty ||
          newOrderSet.difference(currentVideos).isNotEmpty) {
        Log.warning(
          'Invalid reorder: video lists do not match',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return false;
      }

      final updatedList = list.copyWith(
        videoEventIds: newOrder,
        playOrder: PlayOrder.manual, // Set to manual when reordering
        updatedAt: clock.now(),
      );

      if (!await _commitListMutation(updatedList)) return false;

      Log.debug(
        '📱 Reordered videos in list "${list.name}"',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      return true;
    } catch (e) {
      Log.error(
        'Failed to reorder videos: $e',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return false;
    }
  }

  List<String> _getOrderedVideoIds(String listId) {
    final list = getListById(listId);
    if (list == null) return [];

    switch (list.playOrder) {
      case PlayOrder.chronological:
        return list.videoEventIds; // Already in chronological order
      case PlayOrder.reverse:
        return list.videoEventIds.reversed.toList();
      case PlayOrder.manual:
        return list.videoEventIds; // Manual order as stored
      case PlayOrder.shuffle:
        final shuffled = List<String>.from(list.videoEventIds);
        shuffled.shuffle();
        return shuffled;
    }
  }
}
