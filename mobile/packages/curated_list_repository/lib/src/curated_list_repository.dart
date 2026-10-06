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

/// Newest kind-30005 events asked of each relay per search.
///
/// Every new account publishes an empty default list, and on production those
/// placeholders are all but a percent or two of the newest events, so a
/// 50-event window held nothing but placeholders whatever the query. 500 is
/// the relay gateway's default discovery window; the placeholders drop out
/// below because they carry no videos.
const _relaySearchWindow = 500;

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

  // BehaviorSubject replays last value to late subscribers, fixing race
  // condition where BLoC subscribes AFTER initial emission.
  final _subscribedListsSubject = BehaviorSubject<List<CuratedList>>.seeded(
    const [],
  );

  /// A stream of subscribed curated lists.
  ///
  /// Replays the last emitted value to new subscribers (BehaviorSubject).
  Stream<List<CuratedList>> get subscribedListsStream =>
      _subscribedListsSubject.stream;

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Replaces the current subscribed lists with [lists].
  ///
  /// This is a **transitional bridge** that lets the Page layer push data
  /// from the legacy Riverpod `CuratedListService` into the repository so
  /// BLoCs can consume it via [subscribedListsStream].
  ///
  /// Each list is keyed by its [CuratedList.id].
  ///
  /// Emits the new list on [subscribedListsStream].
  // TODO(curated-list-migration): Remove once the repository owns its own
  // data loading (Phase 2 — persistence + relay sync). At that point,
  // internal CRUD methods and relay fetch will emit on the stream directly.
  void setSubscribedLists(List<CuratedList> lists) {
    _subscribedLists
      ..clear()
      ..addEntries(lists.map((list) => MapEntry(list.id, list)));
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
      ..addEntries(lists.map((list) => MapEntry(list.id, list)));
  }

  // ---------------------------------------------------------------------------
  // Read-only queries
  // ---------------------------------------------------------------------------

  /// Returns the subscribed list with the given [id], or `null` if not found.
  CuratedList? getListById(String id) => _subscribedLists[id];

  /// Returns an unmodifiable snapshot of all subscribed lists.
  List<CuratedList> getSubscribedLists() =>
      List.unmodifiable(_subscribedLists.values.toList());

  /// Whether the user is subscribed to the list with [listId].
  bool isSubscribedToList(String listId) =>
      _subscribedLists.containsKey(listId);

  /// Whether [videoEventId] is in the subscribed list with [listId].
  ///
  /// Returns `false` if the list does not exist.
  bool isVideoInList(String listId, String videoEventId) {
    final list = _subscribedLists[listId];
    return list?.videoEventIds.contains(videoEventId) ?? false;
  }

  /// Whether the user's default "My List" is among the subscribed lists.
  bool hasDefaultList() => _subscribedLists.containsKey(defaultListId);

  /// Returns the user's default "My List", or `null` if not subscribed.
  CuratedList? getDefaultList() => _subscribedLists[defaultListId];

  /// Searches the public lists known locally, the viewer's own and the
  /// subscribed ones, by [query] against name, description, and tags
  /// (case-insensitive).
  ///
  /// Returns an empty list when [query] is blank.
  List<CuratedList> searchLists(String query) {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final matches = <String, CuratedList>{};
    for (final list in [..._ownLists.values, ..._subscribedLists.values]) {
      if (!list.isPublic) continue;
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
    final list = _subscribedLists[listId];
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
    int limit = _relaySearchWindow,
    Set<String>? excludeAuthorScopedIds,
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final excluded = excludeAuthorScopedIds ?? const {};

    final events = await _nostrClient.queryEvents([
      Filter(kinds: [_curatedListKind], limit: limit),
    ]);

    final seen = <String, CuratedList>{};
    for (final event in events) {
      if (_isBlocked(event.pubkey)) continue;
      final list = CuratedListConverter.fromEvent(event);
      if (list == null) continue;
      final key = list.authorScopedId;
      if (excluded.contains(key)) continue;
      if (!list.isPublic || !list.hasVideos) continue;
      if (!_matchesQuery(list, lowerQuery)) continue;

      // Dedup per author and d-tag, keep newest
      final existing = seen[key];
      if (existing != null && existing.updatedAt.isAfter(list.updatedAt)) {
        continue;
      }
      seen[key] = list;
    }

    return seen.values.toList();
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
    if (!_subscribedListsSubject.isClosed) {
      await _subscribedListsSubject.close();
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
    if (!_subscribedListsSubject.isClosed) {
      _subscribedListsSubject.add(
        List.unmodifiable(_subscribedLists.values.toList()),
      );
    }
  }
}
