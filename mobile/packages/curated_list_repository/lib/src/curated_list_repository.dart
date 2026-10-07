// ABOUTME(WIP): Repository for managing curated video list subscriptions.
// ABOUTME(WIP): Provides BehaviorSubject stream for reactive BLoC subscription,
// ABOUTME(WIP): read-only query methods, and in-memory state populated by the
// ABOUTME(WIP): Page layer. Persistence and relay sync come in later phases.

import 'package:curated_list_repository/src/curated_list_converter.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:rxdart/rxdart.dart';

/// Filter callback for search surfaces owned by a list author.
///
/// Returns `true` when content from [pubkey] should be hidden.
typedef BlockedCuratedListFilter = bool Function(String pubkey);

/// Returns `true` when a video must not appear in a list-card preview.
///
/// The app supplies its current content policy for parsed REST and relay
/// videos. Keeping the predicate here avoids app or UI dependencies.
typedef CuratedListVideoFilter = bool Function(VideoEvent video);

/// NIP-51 kind for curated video lists.
const _curatedListKind = 30005;

/// Well-known d-tag for the user's default "My List".
const defaultListId = 'my_vine_list';

/// Newest NIP-51 list events asked of each relay per read, for search and
/// discovery alike.
///
/// Every new account publishes an empty default list, and on production those
/// placeholders are all but a percent or two of the newest events, so a
/// 50-event window held nothing but placeholders whatever the query. The
/// placeholders drop out of every read because they carry no videos.
const kPublicListsRelayWindow = 500;

/// How long a relay read of public lists waits before giving up.
///
/// Shared by search and discovery, so a user-typed search is not cut off by
/// the client's default query budget while startup work holds the relay pool.
const kPublicCuratedListsRelayReadTimeout = Duration(seconds: 12);

/// An immutable subscription snapshot and its resolution readiness.
///
/// Readiness travels with the exact rows, so an asynchronous listener cannot
/// mistake an earlier partial emission for a later complete snapshot.
class CuratedListSubscriptionSnapshot {
  /// Copies [lists] into an unmodifiable snapshot.
  CuratedListSubscriptionSnapshot({
    required List<CuratedList> lists,
    required this.isComplete,
  }) : lists = List.unmodifiable(lists);

  /// The subscribed lists captured when this snapshot was published.
  final List<CuratedList> lists;

  /// Whether missing identities and unique legacy aliases may be finalized.
  final bool isComplete;
}

/// {@template curated_list_repository}
/// Repository for managing curated video list subscriptions.
///
/// Exposes a [subscribedListsStream] (BehaviorSubject) so that BLoCs can
/// reactively observe list changes, and provides read-only query methods
/// for lookups on subscribed lists.
///
/// The repository maintains in-memory state populated via [setSubscribedLists],
/// which is called by the Page layer to bridge from the current Riverpod
/// `CuratedListService`. When persistence and relay sync are added later,
/// [setSubscribedLists] will be replaced by internal loading.
/// {@endtemplate}
class CuratedListRepository {
  /// {@macro curated_list_repository}
  CuratedListRepository({
    required NostrClient nostrClient,
    required FunnelcakeApiClient funnelcakeApiClient,
    BlockedCuratedListFilter? blockFilter,
    CuratedListVideoFilter? videoFilter,
  }) : _nostrClient = nostrClient,
       _funnelcakeApiClient = funnelcakeApiClient,
       _blockFilter = blockFilter,
       _videoFilter = videoFilter;

  final NostrClient _nostrClient;
  final FunnelcakeApiClient _funnelcakeApiClient;
  final BlockedCuratedListFilter? _blockFilter;
  final CuratedListVideoFilter? _videoFilter;
  final Map<String, CuratedList> _subscribedLists = {};
  final Map<String, CuratedList> _ownLists = {};
  bool _hasCompleteSubscriptionSnapshot = false;

  /// Whether the bridge has supplied a complete subscription snapshot.
  ///
  /// Seeded or partial snapshots can expose cached exact identities, but must
  /// not authorize migration or removal of an unresolved saved selection.
  bool get hasCompleteSubscriptionSnapshot => _hasCompleteSubscriptionSnapshot;

  // BehaviorSubject replays last value to late subscribers, fixing race
  // condition where BLoC subscribes AFTER initial emission.
  var _subscriptionSnapshot = CuratedListSubscriptionSnapshot(
    lists: const [],
    isComplete: false,
  );
  late final _subscriptionSnapshotsSubject =
      BehaviorSubject<CuratedListSubscriptionSnapshot>.seeded(
        _subscriptionSnapshot,
      );

  /// The exact latest snapshot, for rejecting superseded queued emissions.
  CuratedListSubscriptionSnapshot get subscriptionSnapshot =>
      _subscriptionSnapshot;

  /// Replays subscribed rows paired with their captured completeness.
  Stream<CuratedListSubscriptionSnapshot> get subscriptionSnapshots =>
      _subscriptionSnapshotsSubject.stream;

  /// A stream of subscribed curated lists.
  ///
  /// Replays the last emitted value to new subscribers (BehaviorSubject).
  Stream<List<CuratedList>> get subscribedListsStream =>
      subscriptionSnapshots.map((snapshot) => snapshot.lists);

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Replaces the current subscribed lists with [lists].
  ///
  /// This is a **transitional bridge** that lets the Page layer push data
  /// from the legacy Riverpod `CuratedListService` into the repository so
  /// BLoCs can consume it via [subscribedListsStream].
  ///
  /// Each list is keyed by its complete [CuratedList.authorScopedId].
  ///
  /// [isComplete] must be false while subscription metadata or followed copies
  /// are unavailable. Completeness is updated before the stream emits.
  ///
  /// Emits the new list on [subscribedListsStream].
  // TODO(curated-list-migration): Remove once the repository owns its own
  // data loading (Phase 2 — persistence + relay sync). At that point,
  // internal CRUD methods and relay fetch will emit on the stream directly.
  void setSubscribedLists(
    List<CuratedList> lists, {
    bool isComplete = true,
  }) {
    _hasCompleteSubscriptionSnapshot =
        isComplete && !_subscriptionSnapshotsSubject.isClosed;
    _subscribedLists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.authorScopedId, list)));
    _emitSubscribedLists();
  }

  /// Replaces the lists the current user owns with [lists].
  ///
  /// The same transitional bridge as [setSubscribedLists]: the Page layer
  /// pushes `CuratedListService.myLists` so [searchLists] can match the
  /// viewer's own lists, which are not among the subscribed ones. Owned lists
  /// take part in search only; the subscribed stream and lookups are
  /// unaffected. Goes away with [setSubscribedLists] once the repository
  /// loads its own data.
  void setOwnLists(List<CuratedList> lists) {
    _ownLists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.authorScopedId, list)));
  }

  // ---------------------------------------------------------------------------
  // Read-only queries
  // ---------------------------------------------------------------------------

  /// Returns a subscribed list by its complete author-qualified [id].
  ///
  /// A legacy raw d-tag resolves only when exactly one subscribed identity
  /// matches. A missing qualified identity never aliases another author.
  CuratedList? getListById(String id) {
    final exact = _subscribedLists[id];
    if (exact != null || _coordinatePrefix.hasMatch(id)) return exact;

    CuratedList? match;
    for (final list in _subscribedLists.values) {
      if (list.id != id) continue;
      if (match != null) return null;
      match = list;
    }
    return match;
  }

  // Leading or repeated colons remain part of legacy raw d-tags. Only a full
  // Nostr pubkey establishes an explicitly author-qualified missing identity.
  static final _coordinatePrefix = RegExp('^[0-9a-fA-F]{64}:');

  /// Returns an unmodifiable snapshot of all subscribed lists.
  List<CuratedList> getSubscribedLists() =>
      List.unmodifiable(_subscribedLists.values.toList());

  /// Whether the user is subscribed to the list with [listId].
  bool isSubscribedToList(String listId) => getListById(listId) != null;

  /// Whether [videoEventId] is in the subscribed list with [listId].
  ///
  /// Returns `false` if the list does not exist.
  bool isVideoInList(String listId, String videoEventId) {
    final list = getListById(listId);
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Whether [ownerPubkey]'s default "My List" is subscribed.
  bool hasDefaultList({required String ownerPubkey}) =>
      getDefaultList(ownerPubkey: ownerPubkey) != null;

  /// Returns [ownerPubkey]'s default "My List", or `null` if not subscribed.
  ///
  /// This subscribed-list query does not infer ownership for authorless rows
  /// or include the viewer's unsubscribed own lists.
  CuratedList? getDefaultList({required String ownerPubkey}) {
    if (ownerPubkey.isEmpty) return null;
    return _subscribedLists['$ownerPubkey:$defaultListId'];
  }

  /// Searches the public lists known locally, the viewer's own and the
  /// subscribed ones, by [query] against name, description, and tags
  /// (case-insensitive).
  ///
  /// A list with no videos is left out, as it is from relay results: search
  /// only surfaces lists with something to watch. Returns an empty list when
  /// [query] is blank.
  List<CuratedList> searchLists(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final matches = <String, CuratedList>{};
    for (final list in [..._ownLists.values, ..._subscribedLists.values]) {
      if (!list.isPublic || !list.hasVideos) continue;
      if (_isBlocked(list.pubkey)) continue;
      if (!_matchesQuery(list, lowerQuery)) continue;
      matches.putIfAbsent(list.authorScopedId, () => list);
    }
    return List.unmodifiable(matches.values);
  }

  static bool _matchesQuery(CuratedList list, String lowerQuery) =>
      list.name.toLowerCase().contains(lowerQuery) ||
      (list.description?.toLowerCase().contains(lowerQuery) ?? false) ||
      list.tags.any((tag) => tag.toLowerCase().contains(lowerQuery));

  /// Returns subscribed public lists that contain the given [tag].
  List<CuratedList> getListsByTag(String tag) {
    return _subscribedLists.values
        .where((list) => list.isPublic && list.tags.contains(tag.toLowerCase()))
        .toList();
  }

  /// Returns all unique tags across subscribed public lists, sorted
  /// alphabetically.
  List<String> getAllTags() {
    final allTags = <String>{};
    for (final list in _subscribedLists.values) {
      if (list.isPublic) {
        allTags.addAll(list.tags);
      }
    }
    return allTags.toList()..sort();
  }

  /// Returns all subscribed lists that contain [videoEventId].
  List<CuratedList> getListsContainingVideo(String videoEventId) {
    return _subscribedLists.values
        .where((list) => list.videoEventIds.contains(videoEventId))
        .toList();
  }

  /// Returns video IDs from the list with [listId], ordered according to the
  /// list's [PlayOrder].
  ///
  /// Returns an empty list if the list does not exist.
  List<String> getOrderedVideoIds(String listId) {
    final list = getListById(listId);
    if (list == null) return [];

    return switch (list.playOrder) {
      PlayOrder.chronological => List.of(list.videoEventIds),
      PlayOrder.reverse => list.videoEventIds.reversed.toList(),
      PlayOrder.manual => List.of(list.videoEventIds),
      PlayOrder.shuffle => (List.of(list.videoEventIds)..shuffle()),
    };
  }

  /// Returns a human-readable summary of which subscribed lists contain
  /// [videoEventId].
  String getVideoListSummary(String videoEventId) {
    final listsContaining = getListsContainingVideo(videoEventId);

    if (listsContaining.isEmpty) {
      return 'Not in any lists';
    }

    if (listsContaining.length == 1) {
      return 'In "${listsContaining.first.name}"';
    }

    if (listsContaining.length <= 3) {
      final names = listsContaining.map((list) => '"${list.name}"').join(', ');
      return 'In $names';
    }

    return 'In ${listsContaining.length} lists';
  }

  // ---------------------------------------------------------------------------
  // Relay search
  // ---------------------------------------------------------------------------

  /// Queries Nostr relays for curated lists matching [query] without
  /// resolving thumbnails.
  Future<List<CuratedList>> _queryListsFromRelays({
    required String query,
    int limit = kPublicListsRelayWindow,
    Set<String>? excludeAuthorScopedIds,
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final excluded = excludeAuthorScopedIds ?? const {};

    final events = await _nostrClient.queryEvents(
      [
        Filter(kinds: [_curatedListKind], limit: limit),
      ],
      timeout: kPublicCuratedListsRelayReadTimeout,
    );

    final results = <CuratedList>[];
    // The newest revision wins before any filter, or an older populated one
    // would surface for a list its author has since emptied or renamed.
    for (final event in CuratedListConverter.latestRevisions(events)) {
      if (_isBlocked(event.pubkey)) continue;
      final list = CuratedListConverter.fromEvent(event);
      if (list == null) continue;
      if (excluded.contains(list.authorScopedId)) continue;
      if (!list.isPublic || !list.hasVideos) continue;
      if (!_matchesQuery(list, lowerQuery)) continue;
      results.add(list);
    }

    return results;
  }

  bool _isBlocked(String? pubkey) {
    final blockFilter = _blockFilter;
    if (blockFilter == null || pubkey == null || pubkey.isEmpty) {
      return false;
    }
    return blockFilter(pubkey);
  }

  /// Searches both local subscribed lists and relay lists for [query].
  ///
  /// Yields results progressively so the UI can render list names immediately
  /// while thumbnails resolve in the background:
  ///
  /// 1. Local matches (no thumbnails)
  /// 2. Local matches with thumbnails resolved
  /// 3. Local + relay matches merged (relay items without thumbnails)
  /// 4. Fully enriched (relay thumbnails resolved)
  ///
  /// Deduplicates by author-qualified list coordinate (pubkey + d-tag).
  Stream<List<CuratedList>> searchAllLists(
    String query, {
    int maxThumbnails = 5,
  }) async* {
    if (query.trim().isEmpty) return;

    final localResults = [
      for (final list in searchLists(query))
        list.copyWith(thumbnailUrls: const []),
    ];
    final merged = <String, CuratedList>{
      for (final list in localResults) list.authorScopedId: list,
    };

    // Yield 1: local results immediately (no thumbnails)
    yield List.unmodifiable(merged.values.toList());

    // Yield 2: local results with thumbnails resolved
    final enrichedLocal = await _resolveAllThumbnails(
      merged.values.toList(),
      maxThumbnails: maxThumbnails,
    );
    merged
      ..clear()
      ..addEntries(enrichedLocal.map((l) => MapEntry(l.authorScopedId, l)));
    yield List.unmodifiable(merged.values.toList());

    // Yield 3: relay results merged (no thumbnails on new items)
    final relayResults = await _queryListsFromRelays(
      query: query,
      excludeAuthorScopedIds: merged.keys.toSet(),
    );
    for (final list in relayResults) {
      merged[list.authorScopedId] = list;
    }
    yield List.unmodifiable(merged.values.toList());

    // Yield 4: relay thumbnails resolved
    final enrichedRelay = await _resolveAllThumbnails(
      relayResults,
      maxThumbnails: maxThumbnails,
    );
    for (final list in enrichedRelay) {
      merged[list.authorScopedId] = list;
    }
    yield List.unmodifiable(merged.values.toList());
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Releases resources held by this repository.
  ///
  /// Idempotent — safe to call multiple times.
  Future<void> dispose() async {
    _hasCompleteSubscriptionSnapshot = false;
    _subscriptionSnapshot = CuratedListSubscriptionSnapshot(
      lists: getSubscribedLists(),
      isComplete: false,
    );
    if (!_subscriptionSnapshotsSubject.isClosed) {
      await _subscriptionSnapshotsSubject.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Thumbnail resolution
  // ---------------------------------------------------------------------------

  /// Regular expression matching a 64-character lowercase hex string
  /// (Nostr event ID). Non-matching entries are addressable coordinates.
  static final _hexEventIdPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Resolves up to [maxThumbnails] thumbnail URLs for each of [lists].
  ///
  /// The same funnelcake-first, batched-relay-fallback pipeline the search
  /// stream uses to enrich its results, exposed for discovery surfaces that
  /// fetch their lists elsewhere (the relay discovery stream) and render
  /// thumbnail collages.
  Future<List<CuratedList>> resolveListThumbnails(
    List<CuratedList> lists, {
    int maxThumbnails = 5,
  }) => _resolveAllThumbnails(lists, maxThumbnails: maxThumbnails);

  /// Resolves thumbnail URLs for a batch of [lists] concurrently.
  ///
  /// Each list gets up to [maxThumbnails] thumbnail URLs populated from
  /// its [CuratedList.videoEventIds]. Resolution is best-effort — lists
  /// that fail silently keep their original (empty) thumbnailUrls.
  Future<List<CuratedList>> _resolveAllThumbnails(
    List<CuratedList> lists, {
    required int maxThumbnails,
  }) async {
    final futures = lists.map(
      (list) => _resolveThumbnails(list, maxThumbnails: maxThumbnails),
    );
    return Future.wait(futures);
  }

  /// Resolves up to [maxThumbnails] thumbnail URLs for a single [list].
  ///
  /// Strategy per video reference:
  /// 1. Hex event ID → try FunnelCake API (`getVideoStats`), use
  ///    parsed video metadata and its thumbnail.
  /// 2. If FunnelCake fails or a permitted result has no thumbnail → fall back
  ///    to Nostr relay, parse as `VideoEvent`, use `effectiveThumbnailUrl`.
  /// 3. Addressable coordinate → query relay with appropriate filter,
  ///    parse as `VideoEvent`, use `effectiveThumbnailUrl`.
  /// 4. Apply the current author and video policy; hidden or unresolved videos
  ///    become placeholders in the UI.
  ///
  /// Returns the list with [CuratedList.thumbnailUrls] populated.
  Future<CuratedList> _resolveThumbnails(
    CuratedList list, {
    required int maxThumbnails,
  }) async {
    if (list.videoEventIds.isEmpty) {
      return list.copyWith(thumbnailUrls: const []);
    }

    final candidates = list.videoEventIds.take(maxThumbnails).toList();

    // Phase 1: Try FunnelCake for each hex ID (parallel HTTP calls).
    final fcResults = await Future.wait(candidates.map(_tryFunnelcake));

    // Phase 2: Only unavailable or permitted thumbnail-less REST results may
    // fall back. Less complete relay metadata must not erase a known denial.
    final deniedRefs = <String>{};
    final needsRelay = <String>[];
    for (var i = 0; i < candidates.length; i++) {
      final video = fcResults[i];
      if (video != null && _shouldHidePreview(video)) {
        deniedRefs.add(candidates[i]);
      } else if (video?.effectiveThumbnailUrl == null) {
        needsRelay.add(candidates[i]);
      }
    }

    final relayVideos = await _batchRelayVideos(needsRelay);

    // Merge results in candidate order.
    final urls = <String>[];
    for (var i = 0; i < candidates.length; i++) {
      if (deniedRefs.contains(candidates[i])) continue;
      final restVideo = fcResults[i];
      final video = restVideo?.effectiveThumbnailUrl != null
          ? restVideo
          : relayVideos[candidates[i]];
      if (video == null || _shouldHidePreview(video)) {
        continue;
      }
      final url = video.effectiveThumbnailUrl;
      if (url != null) urls.add(url);
    }

    return list.copyWith(thumbnailUrls: urls);
  }

  /// Tries FunnelCake API for a hex event ID.
  ///
  /// Returns parsed video metadata, or `null` if [videoRef] is not a hex ID
  /// or FunnelCake has no metadata. Thumbnail-less metadata still carries
  /// policy evidence and cannot be discarded before deciding to use a relay.
  Future<VideoEvent?> _tryFunnelcake(String videoRef) async {
    if (!_hexEventIdPattern.hasMatch(videoRef)) return null;
    try {
      final stats = await _funnelcakeApiClient.getVideoStats(videoRef);
      if (stats != null) {
        return stats.toVideoEvent();
      }
    } on Exception {
      // Fall through to relay fallback.
    }
    return null;
  }

  bool _shouldHidePreview(VideoEvent video) =>
      _isBlocked(video.pubkey) || (_videoFilter?.call(video) ?? false);

  /// Resolves relay-side video metadata for a batch of video references.
  ///
  /// Batches all relay lookups into a single `queryEvents` call: hex IDs
  /// go into one `Filter(ids: [...])` and addressable coordinates become
  /// individual filters in the same request.
  ///
  /// Returns parsed videos keyed by their exact event ID or coordinate.
  Future<Map<String, VideoEvent>> _batchRelayVideos(List<String> refs) async {
    if (refs.isEmpty) return {};

    final hexIds = <String>[];
    final coordRefs = <String>[];
    final coordFilters = <Filter>[];

    for (final ref in refs) {
      if (_hexEventIdPattern.hasMatch(ref)) {
        hexIds.add(ref);
      } else {
        final filter = _buildAddressableFilter(ref);
        if (filter != null) {
          coordRefs.add(ref);
          coordFilters.add(filter);
        }
      }
    }

    final filters = <Filter>[
      if (hexIds.isNotEmpty) Filter(ids: hexIds),
      ...coordFilters,
    ];

    if (filters.isEmpty) return {};

    List<Event> events;
    try {
      events = await _nostrClient.queryEvents(filters);
    } on Exception {
      return {};
    }

    // Select raw revisions before parsing or discarding thumbnail-less videos.
    // A current revision must not reveal an older revision's thumbnail when
    // its metadata is hidden, unavailable, or unparseable.
    final selectedEvents = <String, Event>{};
    for (final event in events) {
      // An immutable event ID remains independent of coordinate revisions.
      if (hexIds.contains(event.id)) {
        selectedEvents[event.id] = event;
      }

      // NIP-01 coordinates use the first raw d-tag, including an empty d-tag.
      for (final ref in coordRefs) {
        final parts = ref.split(':');
        if (int.tryParse(parts[0]) == event.kind &&
            parts[1] == event.pubkey &&
            parts.sublist(2).join(':') == event.dTagValue) {
          final selected = selectedEvents[ref];
          if (selected == null ||
              event.createdAt > selected.createdAt ||
              (event.createdAt == selected.createdAt &&
                  event.id.compareTo(selected.id) < 0)) {
            selectedEvents[ref] = event;
          }
          break;
        }
      }
    }

    final results = <String, VideoEvent>{};
    for (final entry in selectedEvents.entries) {
      try {
        final videoEvent = VideoEvent.fromNostrEvent(
          entry.value,
          permissive: true,
        );
        if (!_hexEventIdPattern.hasMatch(entry.key)) {
          final parts = entry.key.split(':');
          // Policy lookups must use the same identity as the requested
          // coordinate. Contradictory parsed metadata cannot revive an older
          // image or redirect this preview to a different coordinate.
          if (int.tryParse(parts[0]) != videoEvent.eventKind ||
              parts[1] != videoEvent.pubkey ||
              parts.sublist(2).join(':') != videoEvent.addressableDTag) {
            continue;
          }
        }
        if (videoEvent.effectiveThumbnailUrl == null) continue;
        results[entry.key] = videoEvent;
      } on Object {
        // Skip unparseable events (e.g. non-video kinds throw
        // ArgumentError from VideoEvent.fromNostrEvent).
        continue;
      }
    }

    return results;
  }

  /// Builds a [Filter] for an addressable coordinate (`kind:pubkey:d-tag`).
  ///
  /// Returns `null` if the coordinate format is invalid.
  static Filter? _buildAddressableFilter(String coordinate) {
    final parts = coordinate.split(':');
    if (parts.length < 3) return null;

    final kind = int.tryParse(parts[0]);
    if (kind == null) return null;

    final pubkey = parts[1];
    final dTag = parts.sublist(2).join(':');

    return Filter(kinds: [kind], authors: [pubkey], d: [dTag], limit: 1);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  void _emitSubscribedLists() {
    _subscriptionSnapshot = CuratedListSubscriptionSnapshot(
      lists: getSubscribedLists(),
      isComplete: _hasCompleteSubscriptionSnapshot,
    );
    if (!_subscriptionSnapshotsSubject.isClosed) {
      _subscriptionSnapshotsSubject.add(_subscriptionSnapshot);
    }
  }
}
