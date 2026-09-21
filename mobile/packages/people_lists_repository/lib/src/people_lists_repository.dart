// ABOUTME: Abstract interface for NIP-51 kind 30000 people-list repository.
// ABOUTME: Defines publish, sync, and delete surface without leaking clients.

import 'package:models/models.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:people_lists_repository/src/people_list_search_result.dart';

/// Repository that owns NIP-51 kind `30000` people-list state.
///
/// Implementations compose a `NostrClient` for relay IO and a local cache for
/// offline reads. Callers interact with this interface only; they must not
/// reach into lower layers.
///
/// All publish operations return a [PeopleListPublishResult] that reports
/// whether the event was submitted to at least one relay socket. The
/// repository does **not** wait for relay `OK` acknowledgements.
abstract interface class PeopleListsRepository {
  /// Emits the current people lists owned by [ownerPubkey], then re-emits on
  /// every subsequent cache mutation for that owner.
  Stream<List<UserList>> watchLists({required String ownerPubkey});

  /// Reads the current people lists owned by [ownerPubkey] from the cache.
  Future<List<UserList>> readLists({required String ownerPubkey});

  /// Queries relays for kind `30000` events authored by [ownerPubkey] and
  /// merges the decoded lists into the local cache.
  ///
  /// Stale relay echoes older than the locally-stored state must not overwrite
  /// newer local data.
  Future<void> syncOwner({required String ownerPubkey});

  /// Creates a new people list for [ownerPubkey] with the given metadata and
  /// optional [initialPubkeys].
  Future<PeopleListPublishResult> createList({
    required String ownerPubkey,
    required String name,
    String? description,
    String? imageUrl,
    Iterable<String> initialPubkeys = const [],
  });

  /// Adds [pubkey] to the list identified by [listId] and publishes the
  /// replacement event.
  ///
  /// Returns a [PeopleListPublishResult] with status
  /// [PeopleListPublishStatus.noop] when [pubkey] is already a member.
  Future<PeopleListPublishResult> addPubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  });

  /// Removes [pubkey] from the list identified by [listId] and publishes the
  /// replacement event.
  ///
  /// Returns a [PeopleListPublishResult] with status
  /// [PeopleListPublishStatus.noop] when [pubkey] is not a member.
  Future<PeopleListPublishResult> removePubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  });

  /// Publishes a NIP-09 kind `5` deletion event for the list identified by
  /// [listId] and tombstones the list locally once submission succeeds.
  Future<PeopleListPublishResult> deleteList({
    required String ownerPubkey,
    required String listId,
  });

  /// Searches public kind `30000` people lists on connected relays whose
  /// decoded name or description contains [query] (case-insensitive).
  ///
  /// The stream emits **at most one** list of [PeopleListSearchResult], after
  /// the relay query completes. When the query is blank, when the relay
  /// returns no events, or when no decoded list matches the filters, the
  /// stream closes without emitting.
  ///
  /// Results are filtered so that:
  /// * lists with no `p` tag members are excluded,
  /// * app-managed lists (`d=block`, `d=notify`) are excluded,
  /// * duplicates sharing the addressable coordinate
  ///   (`kind:ownerPubkey:d-tag`) keep the newest by `updatedAt`.
  ///
  /// Two owners publishing a list with the same `d` tag both survive the
  /// dedup — [PeopleListSearchResult.ownerPubkey] preserves the distinction.
  Stream<List<PeopleListSearchResult>> searchPublicLists(
    String query, {
    int limit = 50,
  });

  /// Discovers public kind `30000` people lists on connected relays.
  ///
  /// The same relay query, decoding, filtering, and addressable-coordinate
  /// dedup as [searchPublicLists], without the text match. Results come
  /// newest first by `updatedAt`. Lists authored by [excludeAuthor] are
  /// dropped, so a discovery surface can keep the viewer's own lists on
  /// their profile instead.
  ///
  /// Returns an empty list when the relay returns no events or none survive
  /// the filters.
  Future<List<PeopleListSearchResult>> discoverPublicLists({
    int limit = 50,
    String? excludeAuthor,
  });

  /// Emits the public lists [viewerPubkey] follows, oldest follow first,
  /// then re-emits on every follow, unfollow or refreshed copy.
  ///
  /// Following is local to this device, like following a video list: nothing
  /// is published. Lists whose owner the viewer has blocked are left out, and
  /// so is a follow whose copy is not held at the moment, until
  /// [syncFollowedLists] brings it back.
  Stream<List<PeopleListSearchResult>> watchFollowedLists({
    required String viewerPubkey,
  });

  /// Reads the public lists [viewerPubkey] follows, oldest follow first,
  /// under the same rules as [watchFollowedLists].
  Future<List<PeopleListSearchResult>> readFollowedLists({
    required String viewerPubkey,
  });

  /// Follows [list], published by [ownerPubkey], on behalf of [viewerPubkey],
  /// keeping a read-only copy so its members are known offline.
  ///
  /// Following a list that is already followed keeps its place.
  Future<void> followList({
    required String viewerPubkey,
    required String ownerPubkey,
    required UserList list,
  });

  /// Stops [viewerPubkey] following the list [ownerPubkey] published as
  /// [listId]. A no-op when it is not followed.
  Future<void> unfollowList({
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  });

  /// Re-reads every list [viewerPubkey] follows from relays, replacing the
  /// copies that have a newer revision and restoring the ones a cache reset
  /// removed, so a followed list keeps up with the members its owner adds and
  /// removes.
  ///
  /// A relay failure is logged and leaves the stored copies as they are; a
  /// list relays no longer hold keeps its last copy. Never throws for a relay
  /// failure.
  Future<void> syncFollowedLists({required String viewerPubkey});

  /// Removes every list [viewerPubkey] follows, and the copies held for them,
  /// for when that account's data is deleted from the device.
  Future<void> clearFollowedLists({required String viewerPubkey});

  /// Fetches one public kind `30000` list addressed by author + `d` tag.
  ///
  /// Re-checks both against each result because relay/cache filter support
  /// can be loose, and dedup keeps the newest replaceable version. Returns
  /// `null` when relays hold no matching decodable list.
  Future<UserList?> fetchPublicList({
    required String ownerPubkey,
    required String listId,
  });
}
