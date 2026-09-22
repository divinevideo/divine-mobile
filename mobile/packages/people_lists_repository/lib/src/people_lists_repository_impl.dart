// ABOUTME: NostrClient-backed implementation of PeopleListsRepository.
// ABOUTME: Treats publishEvent non-null return as submitted, never confirmed.

import 'dart:async';

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/src/followed_people_lists_store.dart';
import 'package:people_lists_repository/src/local_people_lists_cache.dart';
import 'package:people_lists_repository/src/nip51_people_list_codec.dart';
import 'package:people_lists_repository/src/people_list_publish_result.dart';
import 'package:people_lists_repository/src/people_list_search_result.dart';
import 'package:people_lists_repository/src/people_lists_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Logger name for repository-level diagnostics.
const String _logName = 'people_lists_repository.impl';

/// How long a read of public people lists waits before giving up.
///
/// Above the relay client's default 5-second query budget, which the startup
/// syncs exhaust on the first read after launch, and equal to the video-list
/// discovery budget (`kPublicCuratedListsRelayReadTimeout`), so the two
/// columns of the Explore Lists tab wait the same; the app pins the two
/// equal. Shared by discovery, search, a deep-linked list, and the refresh of
/// followed lists at account attach, which runs inside that same window.
const kPublicPeopleListsRelayReadTimeout = Duration(seconds: 12);

/// Filter callback for owner-authored people-list search results.
///
/// Returns `true` when content from [ownerPubkey] should be hidden.
typedef BlockedPeopleListOwnerFilter = bool Function(String ownerPubkey);

/// Concrete [PeopleListsRepository] backed by a [NostrClient] and a
/// [LocalPeopleListsCache].
///
/// Submission semantics: a non-null return from [NostrClient.publishEvent]
/// means the event was signed and submitted to at least one relay socket. The
/// repository does not wait for a relay `OK`. On a null return or thrown
/// error, the operation is reported as [PeopleListPublishStatus.failed] and
/// no optimistic cache write is performed.
///
/// Constructor injection only — the repository never resolves dependencies
/// implicitly. All mutable state lives in the injected cache and follow store;
/// the repository itself is effectively stateless.
class PeopleListsRepositoryImpl implements PeopleListsRepository {
  /// Creates a repository bound to [nostrClient], [cache] and
  /// [followedListsStore].
  PeopleListsRepositoryImpl({
    required NostrClient nostrClient,
    required LocalPeopleListsCache cache,
    required FollowedPeopleListsStore followedListsStore,
    BlockedPeopleListOwnerFilter? blockFilter,
  }) : _nostrClient = nostrClient,
       _cache = cache,
       _followedListsStore = followedListsStore,
       _blockFilter = blockFilter;

  final NostrClient _nostrClient;
  final LocalPeopleListsCache _cache;

  /// Which lists each viewer follows. [_cache] only mirrors their contents.
  final FollowedPeopleListsStore _followedListsStore;
  final BlockedPeopleListOwnerFilter? _blockFilter;

  @override
  Stream<List<UserList>> watchLists({required String ownerPubkey}) {
    return _cache.watchLists(ownerPubkey: ownerPubkey);
  }

  @override
  Future<List<UserList>> readLists({required String ownerPubkey}) {
    return _cache.readLists(ownerPubkey: ownerPubkey);
  }

  /// How long an authoritative read waits for every relay to settle.
  ///
  /// Deliberately shorter than the 5s default: an expiry reports `timedOut`,
  /// which refuses the mutation, so erring short errs toward not publishing
  /// over a list we could not read.
  static const _reconcileTimeout = Duration(seconds: 3);

  @override
  Future<void> syncOwner({required String ownerPubkey}) async {
    await _reconcileOwner(ownerPubkey);
  }

  /// Refresh the cached lists for [ownerPubkey] and report whether the answer
  /// was conclusive.
  ///
  /// Returns `false` when no relay settled the query — a timeout, or a fan-out
  /// no relay took. That is not the same as "this owner has no lists", and the
  /// difference decides whether it is safe to publish a replacement: these are
  /// addressable events, so a full replacement built on a stale cache drops
  /// every member only the relay's copy holds (#8273).
  ///
  /// [NostrClient.queryEvents] cannot express this — it drops `timedOut` and
  /// `noRelays` — which is why the detailed form is used, with
  /// `requireAllRelaysSettled` so a relay abandoned by the settle window
  /// arrives as a timeout rather than as an empty answer.
  ///
  /// [addPubkey] and [removePubkey] report an inconclusive answer as
  /// [PeopleListPublishResult.failed] rather than publishing over it — the
  /// bloc rolls its optimistic update back on that, and unlike a block or a
  /// follow there is no local-only meaning to preserve here: the list *is*
  /// the published artifact.
  Future<bool> _reconcileOwner(String ownerPubkey) async {
    final filter = Filter(
      kinds: const [Nip51PeopleListCodec.kind],
      authors: [ownerPubkey],
    );

    final result = await _nostrClient.queryEventsDetailed(
      [filter],
      requireAllRelaysSettled: true,
      timeout: _reconcileTimeout,
    );
    final conclusive = !result.timedOut && !result.noRelays;
    final events = result.events;
    if (events.isEmpty) return conclusive;

    final newestByListId = <String, ({Event event, UserList list})>{};
    for (final event in events) {
      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      final candidate = (event: event, list: list);
      final selected = newestByListId[list.id];
      if (selected == null || _isNewerRevision(candidate, selected)) {
        newestByListId[list.id] = candidate;
      }
    }

    final receivedAt = DateTime.now().toUtc();
    for (final candidate in newestByListId.values) {
      final event = candidate.event;
      final list = candidate.list;
      // Read the record rather than the list: whether the cached row carries a
      // publish source decides whether a relay revision may replace it.
      final current = await _cache.readRecord(
        ownerPubkey: ownerPubkey,
        listId: list.id,
      );
      if (current != null && !_shouldReplaceCached(current, list)) {
        continue;
      }
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: list,
        receivedAt: receivedAt,
        sourceTags: event.tags,
        sourceContent: event.content,
      );
    }
    return conclusive;
  }

  @override
  Future<PeopleListPublishResult> createList({
    required String ownerPubkey,
    required String name,
    String? description,
    String? imageUrl,
    Iterable<String> initialPubkeys = const [],
  }) async {
    final now = DateTime.now().toUtc();
    final list = UserList(
      id: _generateListId(now),
      name: name,
      description: description,
      imageUrl: imageUrl,
      pubkeys: List<String>.unmodifiable(initialPubkeys),
      createdAt: now,
      updatedAt: now,
    );
    return _publishListReplacement(ownerPubkey: ownerPubkey, list: list);
  }

  @override
  Future<PeopleListPublishResult> addPubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    // A replacement built on a stale cache drops members only the relay has.
    if (!await _reconcileOwner(ownerPubkey)) {
      return const PeopleListPublishResult.failed();
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) {
      return const PeopleListPublishResult.failed();
    }
    final existing = record.list;
    if (existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    if (!record.hasPublishSource) {
      Log.warning(
        'Cannot add a member of people list $listId: the cached row '
        'predates source preservation, so no complete replacement '
        'can be built from it',
        name: _logName,
        category: LogCategory.relay,
      );
      return const PeopleListPublishResult.failed();
    }
    final updated = existing.copyWith(
      pubkeys: [...existing.pubkeys, pubkey],
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: updated,
      sourceTags: record.sourceTags,
      sourceContent: record.sourceContent,
    );
  }

  @override
  Future<PeopleListPublishResult> removePubkey({
    required String ownerPubkey,
    required String listId,
    required String pubkey,
  }) async {
    // A replacement built on a stale cache drops members only the relay has.
    if (!await _reconcileOwner(ownerPubkey)) {
      return const PeopleListPublishResult.failed();
    }
    final record = await _findList(ownerPubkey: ownerPubkey, listId: listId);
    if (record == null) {
      return const PeopleListPublishResult.failed();
    }
    final existing = record.list;
    if (!existing.pubkeys.contains(pubkey)) {
      return const PeopleListPublishResult.noop();
    }
    if (!record.hasPublishSource) {
      Log.warning(
        'Cannot remove a member of people list $listId: the cached row '
        'predates source preservation, so no complete replacement '
        'can be built from it',
        name: _logName,
        category: LogCategory.relay,
      );
      return const PeopleListPublishResult.failed();
    }
    final updated = existing.copyWith(
      pubkeys: existing.pubkeys.where((p) => p != pubkey).toList(),
      updatedAt: DateTime.now().toUtc(),
    );
    return _publishListReplacement(
      ownerPubkey: ownerPubkey,
      list: updated,
      sourceTags: record.sourceTags,
      sourceContent: record.sourceContent,
    );
  }

  @override
  Future<PeopleListPublishResult> deleteList({
    required String ownerPubkey,
    required String listId,
  }) async {
    final addressableId = '${Nip51PeopleListCodec.kind}:$ownerPubkey:$listId';
    final tags = <List<String>>[
      ['a', addressableId],
      ['k', '${Nip51PeopleListCodec.kind}'],
    ];
    final event = Event(
      ownerPubkey,
      EventKind.eventDeletion,
      tags,
      'Deleted people list $listId',
    );

    try {
      final sent = await _nostrClient.publishEvent(event);
      if (sent is! PublishSuccess) {
        return const PeopleListPublishResult.failed();
      }
      await _cache.markDeleted(
        ownerPubkey: ownerPubkey,
        listId: listId,
        deletedAt: DateTime.now().toUtc(),
      );
      return PeopleListPublishResult.submitted(eventId: sent.event.id);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to publish people-list deletion for list $listId',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  }

  @override
  Stream<List<PeopleListSearchResult>> searchPublicLists(
    String query, {
    int limit = 50,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final lowerQuery = trimmed.toLowerCase();
    final results = await _queryPublicLists(
      limit: limit,
      logContext: 'for "$trimmed"',
      where: (list) =>
          list.name.toLowerCase().contains(lowerQuery) ||
          (list.description?.toLowerCase().contains(lowerQuery) ?? false),
    );

    if (results.isNotEmpty) {
      yield List.unmodifiable(results);
    }
  }

  @override
  Future<List<PeopleListSearchResult>> discoverPublicLists({
    int limit = 50,
    String? excludeAuthor,
  }) async {
    final results = await _queryPublicLists(
      limit: limit,
      logContext: 'for discovery',
      excludeAuthor: excludeAuthor,
    );
    results.sort((a, b) => b.list.updatedAt.compareTo(a.list.updatedAt));
    return List.unmodifiable(results);
  }

  @override
  Future<UserList?> fetchPublicList({
    required String ownerPubkey,
    required String listId,
  }) async {
    final results = await _queryPublicLists(
      limit: 10,
      logContext: 'for ${pubkeyForLogs(ownerPubkey)}/$listId',
      author: ownerPubkey,
      dTag: listId,
    );
    for (final result in results) {
      if (result.ownerPubkey == ownerPubkey && result.list.id == listId) {
        // Someone else's list: the members render, the owner affordances
        // (add people, delete) must not.
        return result.list.copyWith(isEditable: false);
      }
    }
    return null;
  }

  @override
  Stream<List<PeopleListSearchResult>> watchFollowedLists({
    required String viewerPubkey,
  }) {
    return Rx.combineLatest2(
      _followedListsStore.watch(viewerPubkey: viewerPubkey),
      _cache.watchFollowedCopies(viewerPubkey: viewerPubkey),
      _followedInOrder,
    ).map(_withoutBlockedOwners);
  }

  @override
  Future<List<PeopleListSearchResult>> readFollowedLists({
    required String viewerPubkey,
  }) async {
    final refs = await _followedListsStore.read(viewerPubkey: viewerPubkey);
    if (refs.isEmpty) return const [];
    final copies = await _cache.readFollowedCopies(viewerPubkey: viewerPubkey);
    return _withoutBlockedOwners(_followedInOrder(refs, copies));
  }

  @override
  Future<bool> isFollowingList({
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  }) async {
    final refs = await _followedListsStore.read(viewerPubkey: viewerPubkey);
    return refs.contains(
      FollowedPeopleListRef(ownerPubkey: ownerPubkey, listId: listId),
    );
  }

  /// The copies of the lists [refs] names, in follow order.
  ///
  /// A follow whose copy is not held yet is left out until a sync brings it
  /// back: after a cache reset there is no name or member to show for it. A
  /// copy no follow names is ignored, so an unfollow holds even when a late
  /// relay refresh rewrites the copy behind it.
  static List<PeopleListSearchResult> _followedInOrder(
    List<FollowedPeopleListRef> refs,
    List<PeopleListSearchResult> copies,
  ) {
    final copyByRef = {
      for (final copy in copies)
        FollowedPeopleListRef(
          ownerPubkey: copy.ownerPubkey,
          listId: copy.list.id,
        ): copy,
    };
    return List.unmodifiable([for (final ref in refs) ?copyByRef[ref]]);
  }

  List<PeopleListSearchResult> _withoutBlockedOwners(
    List<PeopleListSearchResult> lists,
  ) {
    final blockFilter = _blockFilter;
    if (blockFilter == null) return lists;
    return List.unmodifiable(
      lists.where((followed) => !blockFilter(followed.ownerPubkey)),
    );
  }

  @override
  Future<void> followList({
    required String viewerPubkey,
    required String ownerPubkey,
    required UserList list,
  }) async {
    // The copy first, so the follow never shows up with nothing to show.
    await _cache.putFollowedCopy(
      viewerPubkey: viewerPubkey,
      ownerPubkey: ownerPubkey,
      // Someone else's list: the copy must never offer the owner's
      // affordances, whatever the caller resolved it as.
      list: list.copyWith(isEditable: false),
    );
    try {
      await _followedListsStore.add(
        viewerPubkey: viewerPubkey,
        ref: FollowedPeopleListRef(ownerPubkey: ownerPubkey, listId: list.id),
      );
    } on Object {
      // The follow was not recorded, so the copy is nobody's: take it back
      // out rather than leave it in the box until account cleanup.
      await _removeCopyQuietly(
        viewerPubkey: viewerPubkey,
        ownerPubkey: ownerPubkey,
        listId: list.id,
      );
      rethrow;
    }
  }

  @override
  Future<void> unfollowList({
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  }) async {
    await _followedListsStore.remove(
      viewerPubkey: viewerPubkey,
      ref: FollowedPeopleListRef(ownerPubkey: ownerPubkey, listId: listId),
    );
    await _removeCopyQuietly(
      viewerPubkey: viewerPubkey,
      ownerPubkey: ownerPubkey,
      listId: listId,
    );
  }

  /// Removes the copy of a list no follow names.
  ///
  /// A copy that cannot be removed is left where it is: it is never shown,
  /// and the next follow of the same list replaces it. Failing the caller
  /// over it would report a failed unfollow that in fact held, or hide why
  /// a follow failed behind why its cleanup did.
  Future<void> _removeCopyQuietly({
    required String viewerPubkey,
    required String ownerPubkey,
    required String listId,
  }) async {
    try {
      await _cache.removeFollowedCopy(
        viewerPubkey: viewerPubkey,
        ownerPubkey: ownerPubkey,
        listId: listId,
      );
    } on Object catch (error, stackTrace) {
      Log.warning(
        'Failed to remove the copy of a people list that is not followed',
        name: _logName,
        category: LogCategory.storage,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<void> syncFollowedLists({required String viewerPubkey}) async {
    final refs = await _followedListsStore.read(viewerPubkey: viewerPubkey);
    if (refs.isEmpty) return;

    final List<Event> events;
    try {
      // One filter for the whole set. Authors and `d` tags combine as AND, so
      // it can also match an owner's other list that shares a followed
      // list's `d` tag; the lookup below drops those.
      events = await _nostrClient.queryEvents(
        [
          Filter(
            kinds: const [Nip51PeopleListCodec.kind],
            authors: {for (final ref in refs) ref.ownerPubkey}.toList(),
            d: {for (final ref in refs) ref.listId}.toList(),
          ),
        ],
        timeout: kPublicPeopleListsRelayReadTimeout,
      );
    } on Exception catch (error, stackTrace) {
      Log.warning(
        'Failed to refresh followed people lists; keeping the stored copies',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return;
    }

    final followed = refs.toSet();
    final newest = <FollowedPeopleListRef, UserList>{};
    for (final event in events) {
      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      final ref = FollowedPeopleListRef(
        ownerPubkey: event.pubkey,
        listId: list.id,
      );
      if (!followed.contains(ref)) continue;
      final existing = newest[ref];
      if (existing != null && !_supersedes(list, existing)) continue;
      newest[ref] = list;
    }

    for (final MapEntry(key: ref, value: list) in newest.entries) {
      await _cache.refreshFollowedCopy(
        viewerPubkey: viewerPubkey,
        ownerPubkey: ref.ownerPubkey,
        list: list.copyWith(isEditable: false),
      );
    }
  }

  @override
  Future<void> clearFollowedLists({required String viewerPubkey}) async {
    await _followedListsStore.clear(viewerPubkey: viewerPubkey);
    await _cache.clearFollowedCopies(viewerPubkey: viewerPubkey);
  }

  /// Shared relay query + decode + filter + coordinate-dedup pipeline behind
  /// [searchPublicLists], [discoverPublicLists], and [fetchPublicList].
  Future<List<PeopleListSearchResult>> _queryPublicLists({
    required int limit,
    required String logContext,
    bool Function(UserList list)? where,
    String? excludeAuthor,
    String? author,
    String? dTag,
  }) async {
    final List<Event> events;
    try {
      events = await _nostrClient.queryEvents(
        [
          Filter(
            kinds: const [Nip51PeopleListCodec.kind],
            limit: limit,
            authors: author == null ? null : [author],
            d: dTag == null ? null : [dTag],
          ),
        ],
        timeout: kPublicPeopleListsRelayReadTimeout,
      );
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to query public people lists $logContext',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    final seen = <String, PeopleListSearchResult>{};
    for (final event in events) {
      if (excludeAuthor != null && event.pubkey == excludeAuthor) continue;
      final blockFilter = _blockFilter;
      if (blockFilter != null && blockFilter(event.pubkey)) continue;

      final list = Nip51PeopleListCodec.decode(event);
      if (list == null) continue;
      if (list.pubkeys.isEmpty) continue;
      if (Nip51PeopleListCodec.machineryDTags.contains(list.id)) continue;
      if (where != null && !where(list)) continue;

      final result = PeopleListSearchResult(
        ownerPubkey: event.pubkey,
        list: list,
      );
      final existing = seen[result.addressableId];
      if (existing != null && !_supersedes(list, existing.list)) {
        continue;
      }
      seen[result.addressableId] = result;
    }

    return seen.values.toList();
  }

  Future<PeopleListPublishResult> _publishListReplacement({
    required String ownerPubkey,
    required UserList list,
    List<List<String>>? sourceTags,
    String? sourceContent,
  }) async {
    try {
      // encode throws ArgumentError on a malformed or mismatched source, so
      // it belongs inside the catch: callers only ever see the documented
      // failure result, never a raw programming-invariant throw.
      final payload = Nip51PeopleListCodec.encode(
        list,
        sourceTags: sourceTags,
        sourceContent: sourceContent,
      );
      final event = Event(
        ownerPubkey,
        payload.kind,
        payload.tags,
        payload.content,
      );
      final sent = await _nostrClient.publishEvent(event);
      if (sent is! PublishSuccess) {
        return const PeopleListPublishResult.failed();
      }
      final persisted = list.copyWith(nostrEventId: sent.event.id);
      // Cache what was published, not what was handed to publishEvent: the
      // client rebinds event.tags while applying the NIP-89 client tag, so the
      // payload never sees it. Storing the payload would pair sourceTags with
      // a nostrEventId those tags cannot hash to.
      await _cache.putList(
        ownerPubkey: ownerPubkey,
        list: persisted,
        receivedAt: DateTime.now().toUtc(),
        sourceTags: sent.event.tags,
        sourceContent: sent.event.content,
      );
      return PeopleListPublishResult.submitted(eventId: sent.event.id);
    } on Object catch (error, stackTrace) {
      Log.error(
        'Failed to publish people-list replacement for list ${list.id}',
        name: _logName,
        category: LogCategory.relay,
        error: error,
        stackTrace: stackTrace,
      );
      return PeopleListPublishResult.failed(error: error);
    }
  }

  Future<CachedPeopleListRecord?> _findList({
    required String ownerPubkey,
    required String listId,
  }) => _cache.readRecord(ownerPubkey: ownerPubkey, listId: listId);

  /// Whether relay revision [incoming] should replace cached record [current].
  ///
  /// [UserList.updatedAt] is derived from the relay event's `created_at` by
  /// [Nip51PeopleListCodec], so comparing the two normally detects a stale
  /// relay echo. If the codec ever stops sourcing `updatedAt` from
  /// `created_at`, revisit this guard.
  ///
  /// A row written before this repository preserved publish sources is the
  /// exception. Its `updatedAt` is the millisecond `DateTime.now()` the
  /// publish stamped, so it always reads as newer than the second-resolution
  /// `created_at` of the very event it came from — and with no source tags it
  /// can never drive another membership edit. A matching `nostrEventId` proves
  /// the relay holds that same event, so adopting it loses nothing and is what
  /// keeps the list editable.
  static bool _shouldReplaceCached(
    CachedPeopleListRecord current,
    UserList incoming,
  ) {
    final cached = current.list;
    if (cached.updatedAt.isAfter(incoming.updatedAt)) {
      return !current.hasPublishSource &&
          cached.nostrEventId != null &&
          cached.nostrEventId == incoming.nostrEventId;
    }
    // NIP-01 breaks a created_at tie on the lowest event id. If either id is
    // absent, this guard does not apply and the incoming revision is adopted,
    // preserving the existing behavior for incomplete identifiers.
    final cachedId = cached.nostrEventId;
    final incomingId = incoming.nostrEventId;
    if (cached.updatedAt == incoming.updatedAt &&
        cachedId != null &&
        incomingId != null &&
        cachedId != incomingId &&
        cachedId.compareTo(incomingId) < 0) {
      return false;
    }
    return true;
  }

  /// Whether revision [candidate] supersedes [selected] under NIP-01
  /// replaceable-event ordering: the later `updatedAt` wins, and a tie is
  /// broken on the lowest event id. An absent id on either side leaves the tie
  /// unbroken, so the already-selected revision is kept.
  static bool _supersedes(UserList candidate, UserList selected) {
    if (candidate.updatedAt != selected.updatedAt) {
      return candidate.updatedAt.isAfter(selected.updatedAt);
    }
    final candidateId = candidate.nostrEventId;
    final selectedId = selected.nostrEventId;
    if (candidateId == null || selectedId == null) return false;
    return candidateId.compareTo(selectedId) < 0;
  }

  static bool _isNewerRevision(
    ({Event event, UserList list}) candidate,
    ({Event event, UserList list}) selected,
  ) {
    final createdAtComparison = candidate.event.createdAt.compareTo(
      selected.event.createdAt,
    );
    if (createdAtComparison != 0) return createdAtComparison > 0;
    return candidate.event.id.compareTo(selected.event.id) < 0;
  }

  /// Generates a NIP-33 `d`-tag list identifier from [instant].
  ///
  /// NIP-33 parameterised replaceable events are identified by
  /// `kind:pubkey:d-tag`; callers pick any string. We combine the instant's
  /// microsecond epoch with a short entropy tail derived from a fresh
  /// `Object` identity hash so two `createList` calls that land in the same
  /// microsecond still produce distinct ids and do not clobber each other
  /// via NIP-33 replacement.
  String _generateListId(DateTime instant) {
    final entropy = Object().hashCode.toRadixString(36);
    return 'list-${instant.microsecondsSinceEpoch}-$entropy';
  }
}
