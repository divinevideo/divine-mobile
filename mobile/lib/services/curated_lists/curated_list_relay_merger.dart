// ABOUTME: Reconciles decoded relay lists with the device's curated-list cache.
// ABOUTME: Preserves unpublished items, privacy constraints and deletion records.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/curated_list_relay_gateway.dart';
import 'package:openvine/services/curated_lists/prefs_curated_list_store.dart';
import 'package:unified_logger/unified_logger.dart';

/// Applies relay revisions synchronously after the caller checks its session.
/// Persistence and asynchronous relay work remain the caller's responsibility.
class CuratedListRelayMerger {
  const CuratedListRelayMerger({
    required this.lists,
    required this.store,
    required this.subscribedListIds,
    required this.isSubscribedToList,
    required this.defaultListId,
    this.onParsedList,
    this.now = DateTime.now,
  });

  final List<CuratedList> lists;
  final PrefsCuratedListStore store;
  final Set<String> subscribedListIds;
  final bool Function(String) isSubscribedToList;
  final String defaultListId;
  final void Function(CuratedList)? onParsedList;
  final DateTime Function() now;

  /// A failed unseal never replaces a cached list with an empty public copy.
  void merge(
    Event event,
    UnsealedItemTags unsealedItemTags, {
    required String? ownerPubkey,
  }) {
    if (unsealedItemTags.status == UnsealItemTagsStatus.failed) {
      Log.warning(
        'Skipping list event ${event.id} because its private items '
        'could not be unsealed',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }

    final curatedList = CuratedListConverter.fromEvent(
      event,
      privateTags: unsealedItemTags.tags,
      isPrivateEvent: unsealedItemTags.status == UnsealItemTagsStatus.unsealed,
    );
    if (curatedList == null) {
      Log.warning(
        'Failed to parse list event: ${event.id}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }
    onParsedList?.call(curatedList);
    final dTag = curatedList.id;
    if (dTag == defaultListId && store.wasDefaultListDeleted()) {
      Log.debug(
        'Skipping deleted default list event from relay: ${event.id}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );
      return;
    }

    // Check if we already have this list locally
    final existingListIndex = lists.indexWhere(
      (list) =>
          list.id == dTag &&
          (list.pubkey == event.pubkey ||
              (list.pubkey == null &&
                  event.pubkey == ownerPubkey &&
                  !isSubscribedToList(list.id))),
    );

    if (existingListIndex != -1) {
      // Update existing list if relay version is newer
      final existingList = lists[existingListIndex];
      final isSameOwner =
          existingList.pubkey == event.pubkey ||
          (existingList.pubkey == null &&
              event.pubkey == ownerPubkey &&
              !subscribedListIds.contains(existingList.id));
      if (existingList.nostrEventId == null &&
          !existingList.pendingRepublish &&
          isSameOwner) {
        final merged = CuratedListConverter.mergeUnpublished(
          existingList,
          curatedList,
          mergedAt: now(),
        );
        if ((existingList.isCollaborative || curatedList.isCollaborative) &&
            !merged.isCollaborative) {
          Log.warning(
            'Keeping list $dTag private and dropping collaboration during relay merge',
            name: 'CuratedListService',
            category: LogCategory.system,
          );
        }
        lists[existingListIndex] = merged;
        Log.info(
          'Merged unpublished local and relay copies of list $dTag',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      if (event.createdAt >
          existingList.updatedAt.millisecondsSinceEpoch ~/ 1000) {
        Log.debug(
          'Updating existing list from relay: ${curatedList.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );

        final plaintextIds = <String>{
          ...existingList.pendingPlaintextEventIds,
          if (existingList.isPublic &&
              !curatedList.isPublic &&
              existingList.nostrEventId != null)
            existingList.nostrEventId!,
        };
        lists[existingListIndex] = curatedList.copyWith(
          createdAt: existingList.createdAt,
          pendingPlaintextEventIds: plaintextIds.toList(growable: false),
        );
      } else {
        Log.debug(
          'Skipping older relay version of list: ${curatedList.name}',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
      }
    } else {
      // Checked here rather than earlier so the tombstone only ever blocks a
      // resurrection. A list still present locally keeps syncing normally,
      // which is what should happen if a delete failed after recording it.
      if (store.wasListDeleted(event.pubkey, dTag)) {
        Log.debug(
          'Skipping deleted list event from relay: $dTag',
          name: 'CuratedListService',
          category: LogCategory.system,
        );
        return;
      }

      // Add new list from relay
      Log.debug(
        'Adding new list from relay: ${curatedList.name}',
        name: 'CuratedListService',
        category: LogCategory.system,
      );

      lists.add(curatedList);
    }
  }
}
