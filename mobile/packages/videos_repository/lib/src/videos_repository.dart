// ABOUTME: Repository for video operations with Nostr.
// ABOUTME: Orchestrates NostrClient for fetching and
// ABOUTME: VideoLocalStorage for caching.
// ABOUTME: Returns Future<List<VideoEvent>>, not streams -
// ABOUTME: loading is pagination-based.

import 'dart:async';
import 'dart:math';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/src/author_feed_result.dart';
import 'package:videos_repository/src/home_feed_result.dart';
import 'package:videos_repository/src/in_memory_feed_cache.dart';
import 'package:videos_repository/src/popular_videos_page.dart';
import 'package:videos_repository/src/profile_video_merge.dart';
import 'package:videos_repository/src/recommendation_session_seed.dart';
import 'package:videos_repository/src/seen_video_lookup.dart';
import 'package:videos_repository/src/video_content_filter.dart';
import 'package:videos_repository/src/video_event_filter.dart';
import 'package:videos_repository/src/video_local_storage.dart';
import 'package:videos_repository/src/video_route_lookup_result.dart';
import 'package:videos_repository/src/video_search_sort.dart';

export 'package:models/src/nip71_video_kinds.dart' show NIP71VideoKinds;

/// NIP-71 video event kind for addressable short videos.
const int _videoKind = EventKind.videoVertical;

/// Default number of videos to fetch per page.
const int _defaultLimit = 25;

class _FollowingFetchResult {
  const _FollowingFetchResult({required this.videos, this.pageCount = 0});

  final List<VideoEvent> videos;
  final int pageCount;
}

/// Author-feed REST page size used for the `hasMore` fallback heuristic when
/// the v2 envelope omits the flag. Mirrors `AppConstants.paginationBatchSize`
/// (50) in the app layer — kept here as a package-local const so the
/// Flutter-free package owns the author-feed composition (#3384 parity).
const int _authorFeedPaginationBatchSize = 50;

/// Author-feed "has more" threshold for the relay-only page (REST
/// unavailable). Mirrors `AppConstants.hasMoreContentThreshold` (10).
const int _authorFeedHasMoreThreshold = 10;

/// In-memory cache key prefix for a single author's feed.
const String _authorFeedCacheKeyPrefix = 'author:';

/// Timeout for relay search queries.
///
/// Set higher than the app-wide 5s default to accommodate slower
/// user-configured personal relays.
const Duration _relaySearchTimeout = Duration(seconds: 15);

/// Timeout for the Funnelcake bulk-stats hydration phase inside
/// [VideosRepository.fetchVideoWithStats].
///
/// On timeout the method returns the video without hydrated stats rather than
/// blocking the caller indefinitely. Three seconds is generous enough for
/// healthy Funnelcake responses while still bounding degraded-service latency.
const Duration _statsFetchTimeout = Duration(seconds: 3);

/// Bounds the relay freshness check used by manual New-feed refreshes.
///
/// The REST recent feed can lag briefly behind relays due to ingestion and edge
/// caching. Pull-to-refresh asks relays for just the first page too, but should
/// still complete quickly when a relay is slow.
const Duration _recentRelayRefreshTimeout = Duration(seconds: 3);

/// Per-call timeout for relay queries inside the route-lookup orchestrator.
///
/// `NostrClient.queryEvents` waits for EOSE from every relay in the pool with
/// a default 5-second timeout, and any relay still mid-connect during cold
/// start blocks the whole batch. Capping each route-lookup relay call at 3s
/// stops a stuck subscription from dominating deep-link UX once Funnelcake
/// has already been tried.
const Duration _routeRelayTimeout = Duration(seconds: 3);
const String _popularCacheKey = 'popular';
const String _popularLegacyBeforeCursorPrefix = 'before:';
const String _classicsCacheKey = 'classics';
const String _classicsOffsetCursorPrefix = 'classic-offset:';
const Duration _classicsFirstPageCacheTtl = Duration(minutes: 15);

/// Highest archive offset the Classics feed may open a session on.
///
/// The imported Vine archive is much deeper than the old 10k estimate, but
/// opening too deep can still bury users in the long tail. Starting anywhere
/// in the first couple thousand most-viewed classics gives meaningful variety
/// while keeping the opening slice recognizable. (`sort=loops` orders by views
/// first and loops as the tiebreak on this path, because the request carries a
/// `platform` filter and so misses Funnelcake's rank-ordered classic
/// snapshot.) Shared with the Explore → Classics tab so both surfaces draw
/// from the same window.
const int classicsMaxRandomStartOffset = 2000;

/// Archive pages one Classics fetch may read while trying to fill its page.
///
/// Filtering — blocked authors, content preferences, transport scheme — can
/// empty an otherwise full archive page, and a feed that opens on an empty
/// page cannot paginate its way out. Reading a couple of extra pages covers
/// that without turning a single fetch into a crawl through the archive.
const int _classicsMaxPageFetches = 3;

/// Result of a hashtag REST feed fetch.
class HashtagFeedVideosResult {
  /// Creates a successful hashtag feed result.
  const HashtagFeedVideosResult.success(this.videos) : succeeded = true;

  /// Creates a failed or skipped hashtag feed result.
  const HashtagFeedVideosResult.failure()
    : videos = const [],
      succeeded = false;

  /// Videos returned by the REST feed in display order.
  final List<VideoEvent> videos;

  /// Whether the REST fetch completed successfully.
  ///
  /// A successful fetch may still contain an empty [videos] list. Callers use
  /// this to distinguish a real empty feed from a transient failure, timeout,
  /// or unavailable client.
  final bool succeeded;
}

String _encodePopularLegacyBeforeCursor(int before) =>
    '$_popularLegacyBeforeCursorPrefix$before';

int? _decodePopularLegacyBeforeCursor(String? cursor) {
  if (cursor == null || !cursor.startsWith(_popularLegacyBeforeCursorPrefix)) {
    return null;
  }

  return int.tryParse(
    cursor.substring(_popularLegacyBeforeCursorPrefix.length),
  );
}

String _encodeClassicsOffsetCursor(int offset) =>
    '$_classicsOffsetCursorPrefix$offset';

int? _decodeClassicsOffsetCursor(String? cursor) {
  if (cursor == null || !cursor.startsWith(_classicsOffsetCursorPrefix)) {
    return null;
  }

  return int.tryParse(cursor.substring(_classicsOffsetCursorPrefix.length));
}

/// Cache-key suffix for the popular feed's viewer preferences.
///
/// Deliberately excludes the viewer country: it is resolved through a geo
/// lookup with a short timeout that yields null when the network is slow, so
/// including it made the key flip between two values and miss the cache
/// exactly when the network was worst.
String _popularPreferenceCacheSuffix({
  List<String> preferredLanguages = const [],
}) {
  final languages = preferredLanguages
      .map((language) => language.trim())
      .where((language) => language.isNotEmpty)
      .join(',');

  return languages.isEmpty ? '' : ':lang=$languages';
}

/// {@template videos_repository}
/// Repository for video operations with Nostr.
///
/// Coordinates between NostrClient (relay I/O) and local storage for
/// efficient video feed loading. Uses pagination-based loading (Futures)
/// rather than real-time subscriptions (Streams).
///
/// Optionally accepts a [VideoLocalStorage] for cache-first lookups.
/// When provided, methods like [getVideosByIds] will check the cache first
/// before querying relays.
///
/// Optionally accepts a [FunnelcakeApiClient] to fallback to REST API
/// for videos not found on Nostr relays (e.g., videos from Explore that
/// may not be on the app's configured relays).
///
/// {@endtemplate}
class VideosRepository {
  /// {@macro videos_repository}
  VideosRepository({
    required NostrClient nostrClient,
    VideoLocalStorage? localStorage,
    BlockedVideoFilter? blockFilter,
    DeletedVideoFilter? deletedFilter,
    this.removedVideoIds = const Stream<String>.empty(),
    VideoContentFilter? contentFilter,
    VideoWarningLabelsResolver? warningLabelsResolver,
    FunnelcakeApiClient? funnelcakeApiClient,
    InMemoryFeedCache? inMemoryFeedCache,
    SeenVideoLookup? seenVideoLookup,
    Random? random,
  }) : _nostrClient = nostrClient,
       _localStorage = localStorage,
       _blockFilter = blockFilter,
       _deletedFilter = deletedFilter,
       _contentFilter = contentFilter,
       _warningLabelsResolver = warningLabelsResolver,
       _funnelcakeApiClient = funnelcakeApiClient,
       _inMemoryFeedCache = inMemoryFeedCache,
       _seenVideoLookup = seenVideoLookup,
       _random = random ?? Random();

  final NostrClient _nostrClient;
  final VideoLocalStorage? _localStorage;
  final BlockedVideoFilter? _blockFilter;
  final DeletedVideoFilter? _deletedFilter;

  /// Emits IDs for videos removed by deletion handling.
  final Stream<String> removedVideoIds;

  final VideoContentFilter? _contentFilter;
  final VideoWarningLabelsResolver? _warningLabelsResolver;
  final FunnelcakeApiClient? _funnelcakeApiClient;
  final InMemoryFeedCache? _inMemoryFeedCache;
  final SeenVideoLookup? _seenVideoLookup;

  /// Randomness behind the Classics feed's per-session slice and shuffle.
  /// Injectable so tests can pin an order.
  final Random _random;

  String _recommendationSessionSeed = generateRecommendationSessionSeed();

  /// Whether [video] is already known deleted by the app-wide deletion
  /// contract supplied to this repository.
  bool isVideoKnownDeleted(VideoEvent video) =>
      _deletedFilter?.call(video) ?? false;

  /// Clears the in-memory feed cache.
  ///
  /// When [key] is provided, only that feed mode's cache is removed
  /// (e.g. `"latest"`, `"popular"`, `"classics"`). When omitted, all
  /// cached feeds are cleared.
  void clearInMemoryFeedCache({String? key}) {
    if (key != null) {
      _inMemoryFeedCache?.remove(key);
    } else {
      _inMemoryFeedCache?.clear();
    }
  }

  /// Fetches videos from followed users for the home feed, optionally
  /// merging in videos from subscribed curated lists.
  ///
  /// This is the "Home" feed mode - shows videos from followed users
  /// plus any videos referenced by subscribed curated lists.
  ///
  /// Strategy:
  /// 1. If [userPubkey] is provided and Funnelcake API is available, tries
  ///    the REST API first (faster, pre-computed feeds)
  /// 2. Falls back to Nostr relay query with [authors] filter
  /// 3. If [videoRefs] is non-empty, fetches list videos and merges them
  ///    with following videos, building attribution metadata
  ///
  /// Parameters:
  /// - [authors]: List of pubkeys to filter by (followed users)
  /// - [videoRefs]: Map of listId → video references from subscribed
  ///   curated lists. References can be 64-char hex event IDs or
  ///   addressable coordinates (`kind:pubkey:d-tag`). Defaults to empty.
  /// - [userPubkey]: The current user's pubkey for Funnelcake API lookups.
  ///   Required for API-first path; when null, goes directly to Nostr.
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  ///
  /// Returns a [HomeFeedResult] containing videos sorted by creation time
  /// (newest first) plus attribution metadata mapping videos to their
  /// source curated lists. Returns empty result if both [authors] is empty
  /// and [userPubkey] is null. When [userPubkey] is provided, the Funnelcake
  /// API is attempted even with an empty [authors] list (fast-path startup).
  Future<HomeFeedResult> getHomeFeedVideos({
    required List<String> authors,
    Map<String, List<String>> videoRefs = const {},
    String? userPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    if (authors.isEmpty && userPubkey == null) {
      return const HomeFeedResult(videos: []);
    }

    // 1. Fetch following videos (Funnelcake API → Nostr relay waterfall)
    final following = await _fetchFollowingVideos(
      authors: authors,
      userPubkey: userPubkey,
      limit: limit,
      until: until,
    );

    // 2. If no list refs, return following-only result (with seen demotion)
    if (videoRefs.isEmpty) {
      final ordered = await _orderBySeenFreshness(following.videos);
      final result = HomeFeedResult(
        videos: ordered,
        followingPageCount: following.pageCount,
      );
      return result;
    }

    // 3. Merge list videos with following videos
    final merged = await _mergeListVideos(
      followingVideos: following.videos,
      videoRefs: videoRefs,
    );
    final orderedVideos = await _orderBySeenFreshness(merged.videos);
    final result = HomeFeedResult(
      videos: orderedVideos,
      videoListSources: merged.videoListSources,
      listOnlyVideoIds: merged.listOnlyVideoIds,
      followingPageCount: following.pageCount,
    );
    return result;
  }

  /// Fetches videos from followed users via Funnelcake API or Nostr relays.
  Future<_FollowingFetchResult> _fetchFollowingVideos({
    required List<String> authors,
    String? userPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    final effectiveUserPubkey =
        userPubkey ??
        (_nostrClient.publicKey.isNotEmpty ? _nostrClient.publicKey : null);

    // Try Funnelcake API first (if user pubkey provided)
    if (effectiveUserPubkey != null &&
        _funnelcakeApiClient != null &&
        _funnelcakeApiClient.isAvailable) {
      try {
        return await _fetchVisibleHomeVideosFromStatsApi(
          userPubkey: effectiveUserPubkey,
          limit: limit,
          until: until,
        );
      } on FunnelcakeException {
        // Fall through to Nostr
      }
    }

    return _fetchVisibleHomeVideosFromRelays(
      authors: authors,
      limit: limit,
      until: until,
    );
  }

  Future<_FollowingFetchResult> _fetchVisibleHomeVideosFromStatsApi({
    required String userPubkey,
    required int limit,
    int? until,
  }) async {
    var cursor = until;
    final visible = <VideoEvent>[];
    final seenVideoKeys = <String>{};
    var pageCount = 0;

    // Intentionally walk until we have enough visible videos or the upstream
    // feed is exhausted. A hard page cap caused premature EOF on reply-dense
    // feeds by hiding visible videos behind reply-only raw pages.
    while (visible.length < limit) {
      pageCount++;
      final response = await _funnelcakeApiClient!.getHomeFeed(
        pubkey: userPubkey,
        limit: limit,
        before: cursor,
      );

      final videos = _transformVideoStats(response.videos);
      final hydratedVideos = await _hydrateVideosWithBulkStats(videos);
      _appendUniqueVideos(
        visible,
        hydratedVideos,
        seenVideoKeys: seenVideoKeys,
      );
      if (response.videos.length < limit || !response.hasMore) break;

      final nextCursor =
          response.nextCursor ?? _cursorBeforeOldestStats(response.videos);
      if (nextCursor == null || nextCursor == cursor) break;
      cursor = nextCursor;
    }

    return _FollowingFetchResult(
      videos: visible.take(limit).toList(),
      pageCount: pageCount,
    );
  }

  Future<_FollowingFetchResult> _fetchVisibleHomeVideosFromRelays({
    required List<String> authors,
    required int limit,
    int? until,
  }) async {
    // Nostr fallback — skip when authors list is empty (fast-path startup
    // before follow list is ready).
    if (authors.isEmpty) return const _FollowingFetchResult(videos: []);

    var cursor = until;
    final visible = <VideoEvent>[];
    final seenVideoKeys = <String>{};
    var pageCount = 0;

    while (visible.length < limit) {
      pageCount++;
      final filter = Filter(
        kinds: [_videoKind],
        authors: authors,
        limit: limit,
        until: cursor,
      );

      final events = await _nostrClient.queryEvents([filter]);
      if (events.isEmpty) break;

      final videos = _transformAndFilter(events);
      _appendUniqueVideos(
        visible,
        await _hydrateVideosWithBulkStats(videos),
        seenVideoKeys: seenVideoKeys,
      );
      if (events.length < limit) break;

      final nextCursor = _cursorBeforeOldestEvent(events);
      if (nextCursor == null || nextCursor == cursor) break;
      cursor = nextCursor;
    }

    return _FollowingFetchResult(
      videos: visible.take(limit).toList(),
      pageCount: pageCount,
    );
  }

  Future<List<VideoEvent>> _hydrateVideosWithBulkStats(
    List<VideoEvent> videos, {
    bool replaceInteractionCounts = false,
  }) async {
    if (videos.isEmpty ||
        _funnelcakeApiClient == null ||
        !_funnelcakeApiClient.isAvailable) {
      return videos;
    }

    final videosNeedingStats = videos
        .where(
          (video) =>
              video.id.isNotEmpty &&
              (replaceInteractionCounts ||
                  video.originalLoops == null ||
                  // Relay-sourced zeroes are frequently stale placeholders;
                  // treat them as missing so Funnelcake can reconcile counts.
                  video.originalLoops == 0 ||
                  video.rawTags['views'] == null ||
                  video.nostrLikeCount == null ||
                  video.nostrCommentCount == null ||
                  video.nostrRepostCount == null),
        )
        .toList();
    if (videosNeedingStats.isEmpty) return videos;

    try {
      final statsById = <String, BulkVideoStatsEntry>{};
      for (var i = 0; i < videosNeedingStats.length; i += 100) {
        final end = i + 100 > videosNeedingStats.length
            ? videosNeedingStats.length
            : i + 100;
        final chunk = videosNeedingStats.sublist(i, end);
        final response = await _funnelcakeApiClient.getBulkVideoStats(
          chunk.map((video) => video.id).toList(),
        );
        statsById.addAll(response.stats);
      }

      if (statsById.isEmpty) return videos;

      return videos.map((video) {
        final stats = statsById[video.id];
        if (stats == null) return video;

        return video.copyWith(
          // Only the archival embedded_loops may seed originalLoops; the
          // live computed stats.loops would clobber the Vine-era count and
          // double-count against the views tag in totalLoops.
          originalLoops: stats.embeddedLoops ?? video.originalLoops,
          originalLikes: video.originalLikes,
          originalComments: video.originalComments,
          originalReposts: video.originalReposts,
          // Bulk stats are live Nostr engagement counts. Keep archival import
          // tags in original* and fill only the live fields so display seeds
          // can add the two sources without double-counting.
          nostrLikeCount: replaceInteractionCounts
              ? stats.reactions
              : video.nostrLikeCount ?? stats.reactions,
          nostrCommentCount: replaceInteractionCounts
              ? stats.comments
              : video.nostrCommentCount ?? stats.comments,
          nostrRepostCount: replaceInteractionCounts
              ? stats.reposts
              : video.nostrRepostCount ?? stats.reposts,
          rawTags: video.rawTags['views'] == null && stats.views != null
              ? {...video.rawTags, 'views': stats.views.toString()}
              : video.rawTags,
        );
      }).toList();
    } on Object catch (e, stackTrace) {
      Log.error(
        'Failed to hydrate home feed videos with bulk stats',
        name: 'VideosRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return videos;
    }
  }

  /// Merges list videos with following videos and builds attribution.
  ///
  /// Deduplicates videos that appear in both following and lists.
  /// Builds [HomeFeedResult.videoListSources] mapping each list video
  /// to its source lists, and [HomeFeedResult.listOnlyVideoIds] for
  /// videos present only because of list subscriptions.
  ///
  // TODO(curated-list-migration): Optimize by fetching following and list
  // videos in parallel — currently list video fetches wait for following
  // to complete even though they don't depend on each other. Refactor
  // getHomeFeedVideos to launch both concurrently (Phase 3).
  Future<HomeFeedResult> _mergeListVideos({
    required List<VideoEvent> followingVideos,
    required Map<String, List<String>> videoRefs,
  }) async {
    // Build set of following video identities for dedup.
    final followingVideoKeys = <String>{
      for (final v in followingVideos) v.feedDedupKey,
    };
    final followingVideoIdsByKey = <String, String>{
      for (final v in followingVideos) v.feedDedupKey: v.id,
    };

    // Flatten all refs and separate by type
    final eventIds = <String>[];
    final addressableIds = <String>[];

    for (final refs in videoRefs.values) {
      for (final ref in refs) {
        if (ref.contains(':')) {
          addressableIds.add(ref);
        } else {
          eventIds.add(ref);
        }
      }
    }

    // Deduplicate refs
    final uniqueEventIds = eventIds.toSet().toList();
    final uniqueAddressableIds = addressableIds.toSet().toList();

    // Fetch list videos in parallel
    final results = await Future.wait([
      if (uniqueEventIds.isNotEmpty) getVideosByIds(uniqueEventIds),
      if (uniqueAddressableIds.isNotEmpty)
        getVideosByAddressableIds(uniqueAddressableIds),
    ]);

    // Build ref → video lookup
    final refToVideo = <String, VideoEvent>{};
    var resultIndex = 0;

    if (uniqueEventIds.isNotEmpty) {
      for (final video in results[resultIndex]) {
        refToVideo[video.id] = video;
      }
      resultIndex++;
    }
    if (uniqueAddressableIds.isNotEmpty) {
      for (final video in results[resultIndex]) {
        final ref = video.addressableId;
        if (ref != null) {
          refToVideo[ref] = video;
        }
      }
    }

    // Build attribution metadata
    final videoListSources = <String, Set<String>>{};
    final listOnlyVideoIds = <String>{};
    final listOnlyVideos = <VideoEvent>[];
    final seenListVideoKeys = <String>{};

    for (final entry in videoRefs.entries) {
      final listId = entry.key;
      for (final ref in entry.value) {
        final video = refToVideo[ref];
        if (video == null) continue;
        final displayedVideoId = followingVideoIdsByKey[video.feedDedupKey];

        // Track which lists reference this video
        videoListSources
            .putIfAbsent(displayedVideoId ?? video.id, () => <String>{})
            .add(listId);

        // If not from following, it's list-only
        if (!followingVideoKeys.contains(video.feedDedupKey)) {
          listOnlyVideoIds.add(video.id);

          // Add to merge list (dedup across lists)
          if (seenListVideoKeys.add(video.feedDedupKey)) {
            listOnlyVideos.add(video);
          }
        }
      }
    }

    // Merge following + list-only videos, sorted by createdAt descending
    final merged = [...followingVideos, ...listOnlyVideos]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return HomeFeedResult(
      videos: merged,
      videoListSources: videoListSources,
      listOnlyVideoIds: listOnlyVideoIds,
    );
  }

  /// Fetches videos for a specific curated list.
  ///
  /// Separates [videoRefs] into event IDs and addressable coordinates,
  /// fetches both, and returns videos in the ref order (preserving
  /// the list's ordering).
  ///
  /// Returns an empty list if [videoRefs] is empty or no videos are found.
  Future<List<VideoEvent>> getVideosForList(List<String> videoRefs) async {
    if (videoRefs.isEmpty) return [];

    // Separate refs by type
    final eventIds = <String>[];
    final addressableIds = <String>[];

    for (final ref in videoRefs) {
      if (ref.contains(':')) {
        addressableIds.add(ref);
      } else {
        eventIds.add(ref);
      }
    }

    // Fetch both types in parallel
    final results = await Future.wait([
      if (eventIds.isNotEmpty) getVideosByIds(eventIds),
      if (addressableIds.isNotEmpty) getVideosByAddressableIds(addressableIds),
    ]);

    // Build lookup map: ref → video
    final refToVideo = <String, VideoEvent>{};
    var resultIndex = 0;

    if (eventIds.isNotEmpty) {
      for (final video in results[resultIndex]) {
        refToVideo[video.id] = video;
      }
      resultIndex++;
    }
    if (addressableIds.isNotEmpty) {
      for (final video in results[resultIndex]) {
        final ref = video.addressableId;
        if (ref != null) {
          refToVideo[ref] = video;
        }
      }
    }

    // Return in ref order, omitting unresolved refs
    return deduplicateVideosPreservingOrder([
      for (final ref in videoRefs) ?refToVideo[ref],
    ]);
  }

  /// Fetches videos published by a specific author.
  ///
  /// This is for profile pages - shows all videos from a single user
  /// sorted by creation time (newest first).
  ///
  /// Parameters:
  /// - [authorPubkey]: The pubkey of the user whose videos to fetch
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  ///
  /// Returns a list of [VideoEvent] sorted by creation time (newest first).
  /// Returns an empty list if no videos are found or on error.
  Future<List<VideoEvent>> getProfileVideos({
    required String authorPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    final filter = Filter(
      kinds: [_videoKind],
      authors: [authorPubkey],
      limit: limit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([filter]);

    return _transformAndFilter(events);
  }

  /// Fetches the latest videos in chronological order (newest first).
  ///
  /// This is the "New" feed mode - shows all public videos sorted by
  /// creation time.
  ///
  /// Deliberately does not apply seen-freshness reordering. This feed is
  /// surfaced as "New", and that label is a chronological promise: a video
  /// watched in the last 24 hours keeps its position rather than sinking
  /// below older ones. Because reordering ran after pagination it also
  /// partitioned each page on its own, so timestamps descended, jumped
  /// backwards at the page's recently-seen block, then descended again from
  /// the next page's top — the feed read as unsorted rather than merely
  /// re-prioritised.
  ///
  /// Discovery surfaces that do want the bias keep it: [getHomeFeedVideos]
  /// still demotes via [prioritizeNotRecentlySeenVideos], and classics drop
  /// recently-seen entirely via [filterOutRecentlySeenVideos].
  ///
  /// Strategy:
  /// 1. If Funnelcake API is available, tries the REST API first (faster)
  /// 2. Falls back to Nostr relay query
  ///
  /// Parameters:
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination - pass `previousVideo.createdAt`)
  /// - [skipCache]: Full manual refresh (pull-to-refresh) — bypasses the
  ///   in-memory first-page cache and merges newer relay events into a
  ///   successful API first page.
  /// - [revalidate]: Bypasses the in-memory first-page cache read only,
  ///   without the relay merge. Use for session-start revalidation where a
  ///   fresh first page is wanted but the pull-to-refresh relay round-trip
  ///   is not.
  ///
  /// Returns a [HomeFeedResult] whose videos are sorted by creation time
  /// (newest first), with [HomeFeedResult.hasMore] reporting whether more
  /// sits behind this page — the source's own flag where it states one,
  /// otherwise whether the page filled.
  ///
  /// Callers must page on [HomeFeedResult.hasMore] rather than comparing the
  /// video count to [limit]: the home feed and the Explore tab request
  /// different page sizes but share the cached first page, so a page can
  /// legitimately be shorter than the limit that asked for it and still have
  /// more behind it.
  ///
  /// Returns an empty result if no videos are found or on error.
  Future<HomeFeedResult> getNewVideos({
    int limit = _defaultLimit,
    int? until,
    bool skipCache = false,
    bool revalidate = false,
  }) async {
    // Return in-memory cached result when available (initial page only).
    if (!skipCache && !revalidate && until == null) {
      final cached = _inMemoryFeedCache?.get('latest');
      if (cached != null) {
        return HomeFeedResult(
          videos: cached.videos,
          hasMore: cached.hasMore,
          paginationCursor: cached.paginationCursor,
        );
      }
    }

    // 1. Try Funnelcake API first
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final page = await _fetchVisibleRecentVideosFromStatsApi(
          limit: limit,
          until: until,
        );
        final mergedVideos = skipCache && until == null
            ? await _mergeRecentApiVideosWithRelayRefresh(
                page.videos,
                limit: limit,
              )
            : page.videos;
        // Hydrate views/loops — list endpoint omits them for some rows.
        final hydrated = await _hydrateVideosWithBulkStats(mergedVideos);
        return _recentVideosResult(
          hydrated,
          limit: limit,
          until: until,
          serverHasMore: page.serverHasMore,
        );
      } on FunnelcakeException {
        // Fall through to Nostr
      }
    }

    // 2. Nostr fallback
    final videos = await _fetchVisibleRecentVideosFromRelays(
      limit: limit,
      until: until,
    );
    final hydrated = await _hydrateVideosWithBulkStats(videos);
    return _recentVideosResult(hydrated, limit: limit, until: until);
  }

  /// Wraps a latest-feed page, recording whether more sits behind it so
  /// callers paginate on the flag instead of re-deriving it from a count they
  /// may not have requested.
  ///
  /// [serverHasMore] wins when the source stated it. Otherwise a filled page
  /// is the only available signal — both fetch paths top up until [limit] is
  /// reached, so falling short means the source stopped supplying rows.
  HomeFeedResult _recentVideosResult(
    List<VideoEvent> videos, {
    required int limit,
    required int? until,
    bool? serverHasMore,
  }) {
    final result = HomeFeedResult(
      videos: videos,
      hasMore: serverHasMore ?? videos.length >= limit,
    );
    if (until == null) {
      _inMemoryFeedCache?.set('latest', result);
    }
    return result;
  }

  Future<({List<VideoEvent> videos, bool? serverHasMore})>
  _fetchVisibleRecentVideosFromStatsApi({
    required int limit,
    int? until,
  }) async {
    var cursor = until;
    final visible = <VideoEvent>[];
    final seenVideoKeys = <String>{};
    bool? serverHasMore;

    while (visible.length < limit) {
      final page = await _funnelcakeApiClient!.getRecentVideosPage(
        limit: limit,
        before: cursor,
      );
      serverHasMore = page.hasMore;

      final videos = _transformVideoStats(page.videos);
      _appendUniqueVideos(visible, videos, seenVideoKeys: seenVideoKeys);

      // Compare the server's row count, not the surviving videos: dropping one
      // malformed row would otherwise read as the source running out and pin a
      // premature `hasMore: false` into the feed cache.
      if (page.serverItemCount < limit) break;

      final nextCursor = _cursorBeforeOldestStats(page.videos);
      if (nextCursor == null || nextCursor == cursor) break;
      cursor = nextCursor;
    }

    return (
      // Overshooting the limit means the trimmed remainder is more content,
      // whatever the last page claimed.
      videos: visible.take(limit).toList(),
      serverHasMore: visible.length > limit ? true : serverHasMore,
    );
  }

  Future<List<VideoEvent>> _mergeRecentApiVideosWithRelayRefresh(
    List<VideoEvent> apiVideos, {
    required int limit,
  }) async {
    try {
      final relayVideos = await _fetchVisibleRecentVideosFromRelays(
        limit: limit,
      ).timeout(_recentRelayRefreshTimeout);
      if (relayVideos.isEmpty) return apiVideos;

      final candidates = [...relayVideos, ...apiVideos]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final merged = <VideoEvent>[];
      _appendUniqueVideos(merged, candidates, seenVideoKeys: <String>{});
      return merged.take(limit).toList();
    } on Object catch (e) {
      Log.warning(
        'Recent relay refresh enrichment failed: $e',
        name: 'VideosRepository',
        category: LogCategory.video,
      );
      return apiVideos;
    }
  }

  Future<List<VideoEvent>> _fetchVisibleRecentVideosFromRelays({
    required int limit,
    int? until,
  }) async {
    var cursor = until;
    final visible = <VideoEvent>[];
    final seenVideoKeys = <String>{};

    while (visible.length < limit) {
      final filter = Filter(kinds: [_videoKind], limit: limit, until: cursor);
      final events = await _nostrClient.queryEvents([filter]);
      if (events.isEmpty) break;

      final videos = _transformAndFilter(events);
      _appendUniqueVideos(visible, videos, seenVideoKeys: seenVideoKeys);
      if (events.length < limit) break;

      final nextCursor = _cursorBeforeOldestEvent(events);
      if (nextCursor == null || nextCursor == cursor) break;
      cursor = nextCursor;
    }

    return visible.take(limit).toList();
  }

  /// Fetches classic Vine archive videos for the home feed's Classics mode.
  ///
  /// Reads the same offset-paginated archive as the standalone Explore →
  /// Classics tab — not Explore → Popular's "Classic" toggle, which is
  /// server-ordered and therefore opens on the same videos in the same order
  /// every time. Each fetch that misses the cache starts at a random offset
  /// within [classicsMaxRandomStartOffset] and shuffles the page, so two
  /// sessions do not see the same opening run. The next offset rides in
  /// [HomeFeedResult.paginationCursor], so the home feed paginates this like
  /// the For You feed. Filtering can empty an archive page, so up to
  /// [_classicsMaxPageFetches] pages are read to fill [limit] rather than
  /// handing back a page a feed cannot paginate out of. A topped-up page can
  /// therefore exceed [limit]; the cursor advances past every page actually
  /// read, so trimming to [limit] would drop those videos rather than defer
  /// them.
  ///
  /// The in-memory cache keeps the *first* page stable for a short window, so
  /// quick mode switches resume on the same opening run without pinning a
  /// long-lived iOS process to the same classics for days. Later pages are
  /// re-drawn and re-shuffled on re-entry. Pull-to-refresh ([skipCache] `true`)
  /// draws a fresh slice, and a cold start begins from an empty cache. An
  /// empty page is never cached, so a slice that filters down to nothing is
  /// redrawn on the next entry rather than pinned for the session.
  ///
  /// Funnelcake-only: returns an empty result when no Funnelcake relay is
  /// connected (relays do not expose the server-side `platform` filter).
  Future<HomeFeedResult> getClassicVideos({
    int limit = _defaultLimit,
    String? cursor,
    bool skipCache = false,
  }) async {
    final isFirstPage = cursor == null;
    if (!skipCache && isFirstPage) {
      final cached = _inMemoryFeedCache?.get(_classicsCacheKey);
      if (cached != null) {
        // Classics uses drop-filtering; cached page was already filtered &
        // shuffled, so re-apply freshness in case seen set grew since cache.
        await _seenVideoLookup?.ensureInitialized();
        final filtered = filterOutRecentlySeenVideos(
          cached.videos,
          seenVideoLookup: _seenVideoLookup,
          retainAllWhenAllSeen: false,
        );
        // If drop would empty it, return cached as-is to avoid empty feed.
        if (filtered.isEmpty || filtered.length == cached.videos.length) {
          return cached;
        }
        // For drop policy, filtered cache may be short; return filtered and
        // let pagination deep-fetch on next page rather than blocking here.
        return HomeFeedResult(
          videos: filtered..shuffle(_random),
          paginationCursor: cached.paginationCursor,
          hasMore: cached.hasMore,
        );
      }
    }

    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return const HomeFeedResult(videos: [], hasMore: false);
    }

    await _seenVideoLookup?.ensureInitialized();

    var offset = _decodeClassicsOffsetCursor(cursor) ?? _classicsOffset(limit);

    final collected = <VideoEvent>[];
    final seenVideoKeys = <String>{};
    var exhausted = false;
    var failed = false;
    // Deep-fetch budget: when filtering removes many videos we fetch deeper
    // to avoid short pages (heavy users have seen top 500). Variable page
    // sizes are fine for continuous feeds; we fetch until we have limit or
    // we've tried enough pages. _classicsMaxPageFetches covers transport
    // filtering; add extra budget for seen filtering (up to 8 total).
    const maxSeenFilteredFetches = 8;
    final maxFetches = _seenVideoLookup == null
        ? _classicsMaxPageFetches
        : maxSeenFilteredFetches;

    try {
      for (
        var fetch = 0;
        fetch < maxFetches && collected.length < limit && !exhausted;
        fetch++
      ) {
        final stats = await _funnelcakeApiClient.getClassicVines(
          limit: limit,
          offset: offset,
        );

        final pageVideos = _filterPopularVideosForVariant(
          await _hydrateVideosWithBulkStats(
            _transformVideoStats(stats, sortByCreatedAt: false),
            replaceInteractionCounts: true,
          ),
          PopularVideosVariant.classic,
        );

        // Apply seen filtering per-page: drop recently-seen when lookup
        // available (inventory is unlimited, so dropping is safe), but only
        // if we have not already filled limit via filtered results.
        final filteredPage = _seenVideoLookup == null
            ? pageVideos
            : filterOutRecentlySeenVideos(
                pageVideos,
                seenVideoLookup: _seenVideoLookup,
                retainAllWhenAllSeen: false,
              );

        // If filtering would drop an entire page but we have no filtered
        // results yet, don't let one leaderboard page trap us — we continue
        // fetching (the loop does). If filtering drops everything across
        // all pages, we will fall back to the unfiltered collected below.
        _appendUniqueVideos(
          collected,
          filteredPage,
          seenVideoKeys: seenVideoKeys,
        );

        exhausted = stats.isEmpty;
        offset += limit;
      }
    } on FunnelcakeException {
      failed = true;
    }

    // If filtering left us with nothing but upstream wasn't exhausted,
    // return empty with hasMore true so the feed can paginate to fresh
    // archive slices rather than showing nothing forever. If we did collect
    // something, shuffle as before (classic is leaderboard-sorted, shuffle
    // gives per-session variety).
    if (collected.isEmpty &&
        !exhausted &&
        !failed &&
        _seenVideoLookup != null) {
      // All fetched pages were recently seen and filtered — treat as not
      // exhausted and let caller fetch next cursor (which advances past the
      // filtered window). Return empty but paginatable.
      return HomeFeedResult(
        videos: const [],
        paginationCursor: _encodeClassicsOffsetCursor(offset),
        hasMore: true,
      );
    }

    collected.shuffle(_random);

    final hasMore = !exhausted && !failed;
    final result = HomeFeedResult(
      videos: collected,
      paginationCursor: hasMore ? _encodeClassicsOffsetCursor(offset) : null,
      hasMore: hasMore,
    );

    if (!failed && isFirstPage && collected.isNotEmpty) {
      _inMemoryFeedCache?.set(
        _classicsCacheKey,
        result,
        ttl: _classicsFirstPageCacheTtl,
      );
    }
    return result;
  }

  /// A random archive offset for a Classics session, aligned to [limit]-sized
  /// pages so successive cursors stay on page boundaries.
  int _classicsOffset(int limit) {
    final pageCount = (classicsMaxRandomStartOffset ~/ limit) + 1;
    return _random.nextInt(pageCount) * limit;
  }

  /// Fetches new divine videos from the popular leaderboard.
  ///
  /// This powers Explore → Popular. It uses Funnelcake's leaderboard endpoint
  /// with `exclude_platform=vine` so classic Vine archive imports do not occupy
  /// the default Popular surface while current divine creators try to go viral.
  /// Fetches a cursor-backed page from the v2 popular feed.
  ///
  /// This path is Funnelcake-only because relays do not expose the
  /// server-controlled `platform` / `exclude_platform` filters used by
  /// native/classic Popular.
  Future<PopularVideosPage> getPopularVideosPage({
    required PopularVideosVariant variant,
    int limit = _defaultLimit,
    int? until,
    String? cursor,
    bool skipCache = false,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    final preferenceCacheSuffix = _popularPreferenceCacheSuffix(
      preferredLanguages: preferredLanguages,
    );
    final cacheKey = 'popular:v2:${variant.name}$preferenceCacheSuffix';
    if (!skipCache && until == null && cursor == null) {
      final cached = _inMemoryFeedCache?.get(cacheKey);
      if (cached != null) {
        return PopularVideosPage(
          videos: cached.videos,
          hasMore: cached.hasMore ?? (cached.videos.length >= limit),
          nextCursor:
              cached.paginationCursor ??
              (cached.nextCursor == null
                  ? null
                  : _encodePopularLegacyBeforeCursor(cached.nextCursor!)),
        );
      }
    }

    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return const PopularVideosPage(videos: [], hasMore: false);
    }

    try {
      final legacyBeforeCursor = _decodePopularLegacyBeforeCursor(cursor);
      var pageCursor = legacyBeforeCursor == null ? cursor : null;
      var before = legacyBeforeCursor ?? (cursor == null ? until : null);
      final visible = <VideoEvent>[];
      final seenVideoKeys = <String>{};
      String? nextPageCursor;

      while (visible.length < limit) {
        final response = await _funnelcakeApiClient.getV2PopularVideosPage(
          variant: variant,
          limit: limit,
          cursor: pageCursor,
          before: before,
          preferredLanguages: preferredLanguages,
          viewerCountry: viewerCountry,
        );
        final stats = response.videos;
        if (stats.isEmpty) {
          final page = PopularVideosPage(videos: visible, hasMore: false);
          if (!skipCache && until == null && cursor == null) {
            _inMemoryFeedCache?.set(
              cacheKey,
              HomeFeedResult(
                videos: page.videos,
                paginationCursor: page.nextCursor,
                hasMore: page.hasMore,
              ),
            );
          }
          return page;
        }

        final pageVideos = _filterPopularVideosForVariant(
          await _hydrateVideosWithBulkStats(
            _transformVideoStats(stats, sortByCreatedAt: false),
            replaceInteractionCounts: true,
          ),
          variant,
        );
        _appendUniqueVideos(visible, pageVideos, seenVideoKeys: seenVideoKeys);

        final fallbackBefore = _cursorBeforeOldestStats(stats);
        final fallbackCursor = fallbackBefore == null
            ? null
            : _encodePopularLegacyBeforeCursor(fallbackBefore);
        nextPageCursor = response.nextCursor ?? fallbackCursor;
        final serverHasMore = response.hasMore;
        final sourceExhausted =
            serverHasMore == false ||
            (serverHasMore == null && stats.length < limit) ||
            nextPageCursor == null ||
            (pageCursor != null && nextPageCursor == pageCursor) ||
            (pageCursor == null &&
                before != null &&
                nextPageCursor == _encodePopularLegacyBeforeCursor(before));
        if (sourceExhausted) {
          final page = PopularVideosPage(
            videos: visible.take(limit).toList(),
            hasMore: false,
          );
          if (!skipCache && until == null && cursor == null) {
            _inMemoryFeedCache?.set(
              cacheKey,
              HomeFeedResult(
                videos: page.videos,
                paginationCursor: page.nextCursor,
                hasMore: page.hasMore,
              ),
            );
          }
          return page;
        }

        pageCursor = response.nextCursor;
        before = response.nextCursor == null ? fallbackBefore : null;
      }

      final page = PopularVideosPage(
        videos: visible.take(limit).toList(),
        hasMore: true,
        nextCursor: nextPageCursor,
      );
      if (!skipCache && until == null && cursor == null) {
        _inMemoryFeedCache?.set(
          cacheKey,
          HomeFeedResult(
            videos: page.videos,
            paginationCursor: page.nextCursor,
            hasMore: page.hasMore,
          ),
        );
      }
      return page;
    } on FunnelcakeException {
      return const PopularVideosPage(videos: [], hasMore: false);
    }
  }

  /// Fetches popular videos sorted by engagement score.
  ///
  /// This is the "Popular" feed mode - shows videos ranked by their
  /// engagement metrics (loops, likes, comments, reposts).
  ///
  /// Strategy:
  /// 1. If Funnelcake API is available, tries the REST API first (best
  ///    engagement data from ClickHouse)
  /// 2. Tries NIP-50 `sort:hot` server-side sorting (if relay supports)
  /// 3. Falls back to client-side sorting by engagement score if NIP-50
  ///    returns empty (relay doesn't support NIP-50)
  ///
  /// Parameters:
  /// - [limit]: Maximum number of videos to return (default 5)
  /// - [until]: Only return videos created before this Unix timestamp
  ///   (for pagination, used when [period] is null)
  /// - [offset]: Pagination offset for the leaderboard path (used when
  ///   [period] is non-null)
  /// - [period]: When set, switches to the funnelcake leaderboard endpoint
  ///   (time-windowed). Returns `[]` if funnelcake is unavailable or throws —
  ///   no NIP-50 fallback because relays do not expose time-window
  ///   leaderboards.
  /// - [fetchMultiplier]: How many more videos to fetch for client-side sorting
  ///   fallback (default 4x, so limit=5 fetches 20 videos to sort)
  ///
  /// Returns a list of [VideoEvent] sorted by engagement/popularity
  /// (highest first).
  /// Returns an empty list if no videos are found or on error.
  Future<List<VideoEvent>> getPopularVideos({
    int limit = _defaultLimit,
    int? until,
    int? offset,
    LeaderboardPeriod? period,
    PopularVideosVariant? variant,
    int fetchMultiplier = 4,
    bool skipCache = false,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    final preferenceCacheSuffix = _popularPreferenceCacheSuffix(
      preferredLanguages: preferredLanguages,
    );
    final cacheKey = variant != null
        ? 'popular:v2:${variant.name}$preferenceCacheSuffix'
        : period == null
        ? _popularCacheKey
        : 'popular:${period.wireValue}';

    // Return in-memory cached result when available (initial page only).
    if (!skipCache && until == null && offset == null) {
      final cached = _inMemoryFeedCache?.get(cacheKey);
      if (cached != null) return cached.videos;
    }

    // v2 platform-filtered popular feed path. Funnelcake-only: no relay
    // fallback because relays do not expose server-controlled platform fields.
    if (variant != null) {
      final page = await getPopularVideosPage(
        variant: variant,
        limit: limit,
        until: until,
        skipCache: skipCache,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
      return page.videos;
    }

    // Period-windowed leaderboard path. Funnelcake-only — no NIP-50 fallback,
    // because no relay exposes server-side time-window leaderboards yet.
    if (period != null) {
      if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
        return const [];
      }
      try {
        final stats = await _funnelcakeApiClient.getLeaderboardVideos(
          period: period,
          limit: limit,
          offset: offset,
        );
        final videos = await _hydrateVideosWithBulkStats(
          _transformVideoStats(stats, sortByCreatedAt: false),
          replaceInteractionCounts: true,
        );
        if (until == null && offset == null) {
          _inMemoryFeedCache?.set(cacheKey, HomeFeedResult(videos: videos));
        }
        return videos;
      } on FunnelcakeException {
        return const [];
      }
    }

    // 1. Try Funnelcake API first (best engagement data).
    // Popular tab uses sort=watching (24h CDN view count, no age decay):
    // surfaces what people are looking at right now, including classic
    // Vines getting current attention — not all-time loop count or
    // trending engagement score.
    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final videoStats = await _funnelcakeApiClient.getWatchingVideos(
          limit: limit,
          before: until,
        );

        // Preserve API order.
        final videos = _transformVideoStats(videoStats, sortByCreatedAt: false);
        if (until == null) {
          _inMemoryFeedCache?.set(cacheKey, HomeFeedResult(videos: videos));
        }
        return videos;
      } on FunnelcakeException {
        // Fall through to NIP-50
      }
    }

    // 2. Try NIP-50 server-side sorting
    final nip50Filter = Filter(
      kinds: [_videoKind],
      limit: limit,
      until: until,
      search: 'sort:hot', // NIP-50 sort by engagement
    );

    final nip50Events = await _nostrClient.queryEvents(
      [nip50Filter],
      useCache: false, // Relay ordering is source of truth
    );

    if (nip50Events.isNotEmpty) {
      // NIP-50 worked - relay returned sorted results
      // Preserve relay order (don't re-sort by createdAt)
      final videos = _transformAndFilter(nip50Events, sortByCreatedAt: false);
      if (until == null) {
        _inMemoryFeedCache?.set(cacheKey, HomeFeedResult(videos: videos));
      }
      return videos;
    }

    // 3. Fallback: relay doesn't support NIP-50, use client-side sorting
    // Fetch more videos than needed so we have a good pool to sort from
    final fetchLimit = limit * fetchMultiplier;

    final fallbackFilter = Filter(
      kinds: [_videoKind],
      limit: fetchLimit,
      until: until,
    );

    final events = await _nostrClient.queryEvents([fallbackFilter]);

    final videos = _transformAndFilter(events)
      // Sort by engagement score (uses VideoEvent's built-in comparator)
      ..sort(VideoEvent.compareByEngagementScore);

    // Return only the requested limit
    final result = videos.take(limit).toList();
    if (until == null) {
      _inMemoryFeedCache?.set(cacheKey, HomeFeedResult(videos: result));
    }
    return result;
  }

  /// Fetches videos by their event IDs.
  ///
  /// This is used for fetching videos that a user has liked (Kind 7 reactions
  /// reference videos by their event ID).
  ///
  /// Implements cache-first lookup:
  /// 1. Check local storage for cached events
  /// 2. Query relays for missing events
  /// 3. Optionally save fetched events to cache
  ///
  /// Parameters:
  /// - [eventIds]: List of event IDs to fetch
  /// - [cacheResults]: If true, saves fetched events to local storage.
  ///   Defaults to false to avoid cache bloat from pagination.
  ///   Set to true for first-page loads that should be cached.
  ///
  /// Returns a list of [VideoEvent] in the same order as [eventIds].
  /// Videos that couldn't be found or failed to parse are omitted.
  ///
  /// When a Funnelcake API client is configured and available, results are
  /// merged with that client's bulk video stats endpoint so relay-sourced rows
  /// (e.g. profile Liked / Saved tabs) get loop and engagement totals like the
  /// home feed — unless [hydrateBulkStats] is false.
  ///
  /// Use [hydrateBulkStats] `false` when the caller will run bulk-stats
  /// hydration under its own timeout or policy ([fetchVideoWithStats] does
  /// this so a slow Funnelcake call cannot block indefinitely on the relay
  /// fetch+hydrate path).
  Future<List<VideoEvent>> getVideosByIds(
    List<String> eventIds, {
    bool cacheResults = false,
    bool hydrateBulkStats = true,
  }) async {
    if (eventIds.isEmpty) return [];

    // Build a map for results
    final eventMap = <String, Event>{};

    // 1. Check cache first (if available)
    if (_localStorage != null) {
      final cachedEvents = await _localStorage.getEventsByIds(eventIds);
      for (final event in cachedEvents) {
        eventMap[event.id] = event;
      }
    }

    // 2. Find missing IDs and query relay
    final missingIds = eventIds
        .where((id) => !eventMap.containsKey(id))
        .toList();

    if (missingIds.isNotEmpty) {
      final filter = Filter(
        ids: missingIds,
        kinds: NIP71VideoKinds.getAllVideoKinds(),
      );

      final relayEvents = await _nostrClient.queryEvents([filter]);

      for (final event in relayEvents) {
        eventMap[event.id] = event;
      }

      // 3. Optionally save fetched events to cache
      if (cacheResults && _localStorage != null && relayEvents.isNotEmpty) {
        await _localStorage.saveEventsBatch(relayEvents);
      }
    }

    // Transform and filter, preserving input order
    final videos = <VideoEvent>[];
    for (final id in eventIds) {
      final event = eventMap[id];
      if (event == null) continue;

      final video = _tryParseAndFilter(event);
      if (video != null) videos.add(video);
    }

    if (!hydrateBulkStats) {
      return videos;
    }
    return _hydrateVideosWithBulkStats(videos);
  }

  /// Number of filters to batch in a single relay query.
  ///
  /// Batching improves performance while staying compatible with relays
  /// that may have issues with too many filters in one REQ.
  static const int _addressableIdBatchSize = 20;

  /// Fetches videos by their addressable IDs.
  ///
  /// Addressable IDs follow the format: `kind:pubkey:d-tag`
  /// This is used for fetching videos that a user has reposted (Kind 16
  /// generic reposts reference addressable events via the 'a' tag).
  ///
  /// Strategy:
  /// 1. First tries Nostr relays via NostrClient
  /// 2. For videos not found on relays, tries Funnelcake REST API fallback
  ///    (if configured) - useful for videos from Explore that may not be
  ///    on the app's configured relays
  /// 3. Optionally saves fetched events to local storage
  ///
  /// Parameters:
  /// - [addressableIds]: List of addressable IDs in `kind:pubkey:d-tag` format
  /// - [cacheResults]: If true, saves fetched events to local storage.
  ///   Defaults to false to avoid cache bloat from pagination.
  ///   Set to true for first-page loads that should be cached.
  ///
  /// Returns a list of [VideoEvent] in the same order as [addressableIds].
  /// Videos that couldn't be found or failed to parse are omitted.
  ///
  /// When a Funnelcake API client is configured and available, results are
  /// merged with that client's bulk video stats endpoint (same as
  /// [getVideosByIds]) so repost tabs and other addressable lookups show
  /// accurate loop counts.
  Future<List<VideoEvent>> getVideosByAddressableIds(
    List<String> addressableIds, {
    bool cacheResults = false,
  }) async {
    if (addressableIds.isEmpty) return [];

    // Parse addressable IDs and build filters
    final filters = <Filter>[];

    for (final addressableId in addressableIds) {
      final parsed = AId.fromString(addressableId);
      if (parsed != null && NIP71VideoKinds.isVideoKind(parsed.kind)) {
        // Note: No limit needed - addressable events are unique by
        // kind:pubkey:d-tag, so there's only one latest version per ID.
        // Adding limit:1 per filter causes issues when batching multiple
        // filters, as relays may apply a global limit.
        filters.add(
          Filter(
            kinds: [parsed.kind],
            authors: [parsed.pubkey],
            d: [parsed.dTag],
          ),
        );
      }
    }

    if (filters.isEmpty) return [];

    // Batch filters to balance performance with relay compatibility.
    // Some relays have issues with too many filters in a single REQ,
    // so we batch them in chunks rather than sending all at once or
    // querying one at a time.
    final futures = <Future<List<Event>>>[];
    for (var i = 0; i < filters.length; i += _addressableIdBatchSize) {
      final batchEnd = (i + _addressableIdBatchSize).clamp(0, filters.length);
      final batch = filters.sublist(i, batchEnd);
      futures.add(_nostrClient.queryEvents(batch));
    }

    final results = await Future.wait(futures);
    final events = results.expand((e) => e).toList();

    // Optionally save fetched events to cache
    if (cacheResults && _localStorage != null && events.isNotEmpty) {
      await _localStorage.saveEventsBatch(events);
    }

    // Build a map keyed by addressable ID for ordering
    final foundVideos = <String, VideoEvent>{};
    for (final event in events) {
      final dTag = event.dTagValue;
      if (dTag.isNotEmpty) {
        final addressableId = '${event.kind}:${event.pubkey}:$dTag';
        final video = _tryParseAndFilter(event);
        if (video != null) {
          foundVideos[addressableId] = video;
        }
      }
    }

    // Find which IDs weren't found on Nostr
    final missingIds = addressableIds
        .where((id) => !foundVideos.containsKey(id))
        .toList();

    // Try Funnelcake API fallback for missing videos
    if (missingIds.isNotEmpty &&
        _funnelcakeApiClient != null &&
        _funnelcakeApiClient.isAvailable) {
      await _fetchMissingVideosFromFunnelcake(missingIds, foundVideos);
    }

    // Build result list preserving original order
    final videos = <VideoEvent>[];
    for (final addressableId in addressableIds) {
      final video = foundVideos[addressableId];
      if (video != null) {
        videos.add(video);
      }
    }

    return _hydrateVideosWithBulkStats(videos);
  }

  /// Fetches missing videos from Funnelcake API and adds them to [foundVideos].
  ///
  /// Groups missing IDs by author pubkey to batch API requests.
  Future<void> _fetchMissingVideosFromFunnelcake(
    List<String> missingIds,
    Map<String, VideoEvent> foundVideos,
  ) async {
    // Group missing IDs by pubkey to batch queries
    final missingByPubkey = <String, List<String>>{};
    for (final addressableId in missingIds) {
      final parsed = AId.fromString(addressableId);
      if (parsed != null) {
        missingByPubkey.putIfAbsent(parsed.pubkey, () => []).add(parsed.dTag);
      }
    }

    // Query Funnelcake API for each author's videos
    for (final entry in missingByPubkey.entries) {
      final pubkey = entry.key;
      final dTags = entry.value.toSet();

      try {
        // Fetch videos by author from Funnelcake API
        final result = await _funnelcakeApiClient!.getVideosByAuthor(
          pubkey: pubkey,
        );

        // Find videos matching our d-tags and convert to VideoEvent
        for (final videoStats in result.videos) {
          final video = videoStats.toVideoEvent();
          final videoAddressableId = video.addressableId;
          if (videoAddressableId != null &&
              dTags.contains(video.addressableDTag)) {
            if (_blockFilter?.call(video.pubkey) ?? false) continue;
            if (_deletedFilter?.call(video) ?? false) continue;
            if (!video.hasVideo) continue;
            // Reject non-loopback http:// URLs that the OS layer blocks
            // under release transport security (#3836).
            if (!_hasAllowedTransportScheme(video)) continue;
            if (video.isExpired) continue;

            final processed = _applyContentPreferences(video);
            if (processed == null) continue;

            foundVideos[videoAddressableId] = processed;
          }
        }
      } on FunnelcakeException {
        // Silently ignore Funnelcake API failures - this is a fallback,
        // so we don't want to fail the whole operation if it doesn't work.
        // The video simply won't be included in the results.
      }
    }
  }

  /// Transforms [VideoStats] from Funnelcake API into filtered [VideoEvent]s.
  ///
  /// Converts each [VideoStats] to a [VideoEvent] via [VideoStats.toVideoEvent]
  /// then applies the same filtering pipeline as [_transformAndFilter]:
  /// - Block filter (pubkey blocklist)
  /// - Video URL validation
  /// - Expiration check (NIP-40)
  /// - Content filter (NSFW, etc.)
  ///
  /// By default, sorts by creation time (newest first). Set [sortByCreatedAt]
  /// to false to preserve the API's original order (e.g., trending sort).
  List<VideoEvent> _transformVideoStats(
    List<VideoStats> videoStatsList, {
    bool sortByCreatedAt = true,
  }) {
    final videos = <VideoEvent>[];

    for (final stats in videoStatsList) {
      if (_isReplyOnlyVideoStats(stats)) continue;

      final video = stats.toVideoEvent();

      if (_blockFilter?.call(video.pubkey) ?? false) continue;
      if (_deletedFilter?.call(video) ?? false) continue;

      // Skip videos without a playable URL
      if (!video.hasVideo) continue;

      // Reject non-loopback http:// URLs that the OS layer blocks under
      // release transport security (#3836).
      if (!_hasAllowedTransportScheme(video)) continue;

      // Skip expired videos (NIP-40)
      if (video.isExpired) continue;

      final processed = _applyContentPreferences(video);
      if (processed != null) {
        videos.add(processed);
      }
    }

    if (sortByCreatedAt) {
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return videos;
  }

  /// Attempts to parse an event into a VideoEvent and apply filters.
  ///
  /// Returns the [VideoEvent] if it passes all filters, or null if:
  /// - The event kind is not a video kind
  /// - The pubkey is blocked
  /// - The video has no playable URL
  /// - The video is expired (NIP-40)
  /// - The video fails content filtering
  VideoEvent? _tryParseAndFilter(
    Event event, {
    bool permissive = false,
    bool ignoreBlockFilter = false,
    void Function(VideoEvent video)? onContentFiltered,
  }) {
    // Skip events that aren't valid video kinds
    final isSupported = permissive
        ? NIP71VideoKinds.isAcceptableVideoKind(event.kind)
        : NIP71VideoKinds.isVideoKind(event.kind);
    if (!isSupported) return null;
    if (_isReplyOnlyVideoEvent(event)) return null;

    // Block filter - check pubkey before parsing for efficiency
    if (!ignoreBlockFilter && (_blockFilter?.call(event.pubkey) ?? false)) {
      return null;
    }

    final video = VideoEvent.fromNostrEvent(event, permissive: permissive);

    if (_deletedFilter?.call(video) ?? false) return null;

    // Skip videos without a playable URL
    if (!video.hasVideo) return null;

    // Reject non-loopback http:// URLs that the OS layer blocks under
    // release transport security (#3836).
    if (!_hasAllowedTransportScheme(video)) return null;

    // Skip expired videos (NIP-40)
    if (video.isExpired) return null;

    final permitted = _applyContentPreferences(video);
    if (permitted == null) onContentFiltered?.call(video);
    return permitted;
  }

  bool _isReplyOnlyVideoEvent(Event event) {
    if (event.kind != _videoKind) return false;
    var hasRootTag = false;
    var hasParentTag = false;
    var isFeedVisibleReply = false;

    for (final rawTag in event.tags) {
      final tag = rawTag as List<dynamic>;
      if (tag.length < 2) continue;
      final tagName = tag[0] as String;
      if (tagName == 'E' || tagName == 'A') {
        hasRootTag = true;
      } else if (tagName == 'e' || tagName == 'a') {
        hasParentTag = true;
      } else if (tagName == videoReplyVisibilityTagName &&
          tag[1] == videoReplyVisibilityFeedValue) {
        isFeedVisibleReply = true;
      }
    }

    return hasRootTag && hasParentTag && !isFeedVisibleReply;
  }

  bool _isReplyOnlyVideoStats(VideoStats stats) {
    if (stats.kind != _videoKind) return false;
    // rawTags is first-occurrence-only, which is sufficient here because this
    // filter only needs boolean presence checks for reply/feed-visibility tags.
    final tags = stats.rawTags;
    final hasRootTag =
        (tags['E']?.isNotEmpty ?? false) || (tags['A']?.isNotEmpty ?? false);
    final hasParentTag =
        (tags['e']?.isNotEmpty ?? false) || (tags['a']?.isNotEmpty ?? false);
    final isFeedVisibleReply =
        tags[videoReplyVisibilityTagName] == videoReplyVisibilityFeedValue;
    return hasRootTag && hasParentTag && !isFeedVisibleReply;
  }

  int? _cursorBeforeOldestEvent(List<Event> events) {
    if (events.isEmpty) return null;
    final oldest = events
        .map((event) => event.createdAt)
        .reduce((a, b) => a < b ? a : b);
    return oldest - 1;
  }

  void _appendUniqueVideos(
    List<VideoEvent> target,
    List<VideoEvent> incoming, {
    required Set<String> seenVideoKeys,
  }) {
    for (final video in incoming) {
      if (!seenVideoKeys.add(video.feedDedupKey)) continue;
      target.add(video);
    }
  }

  int? _cursorBeforeOldestStats(List<VideoStats> stats) {
    if (stats.isEmpty) return null;
    final oldest = stats
        .map((stat) => stat.createdAt.millisecondsSinceEpoch ~/ 1000)
        .reduce((a, b) => a < b ? a : b);
    return oldest - 1;
  }

  List<VideoEvent> _filterPopularVideosForVariant(
    List<VideoEvent> videos,
    PopularVideosVariant variant,
  ) {
    return switch (variant) {
      PopularVideosVariant.native =>
        videos.where((video) => !video.isOriginalVine).toList(),
      PopularVideosVariant.classic =>
        videos.where((video) => video.isOriginalVine).toList(),
    };
  }

  VideoEvent? _applyContentPreferences(VideoEvent video) {
    if (_contentFilter?.call(video) ?? false) return null;

    final warnLabels = _warningLabelsResolver?.call(video) ?? const <String>[];
    if (warnLabels.isEmpty) {
      return video.warnLabels.isEmpty
          ? video
          : video.copyWith(warnLabels: const <String>[]);
    }

    return video.copyWith(warnLabels: warnLabels);
  }

  /// Whether [video]'s primary playable URL uses a transport scheme that
  /// the OS will actually load on the platforms we ship.
  ///
  /// Release-build native transport-security on Android, iOS, and macOS
  /// rejects every cleartext request to a non-loopback host at the OS
  /// layer (see #3358 / PR #3788). A `kind:22` event whose `videoUrl` is
  /// non-loopback `http://` would be rejected by the OS at playback time;
  /// the in-feed retry logic in `FullscreenFeedBloc` would then treat
  /// the rejection as transient and keep the un-loadable entry visible
  /// forever. Reject at repository ingest so it never reaches the player.
  ///
  /// Loopback `http://` (`10.0.2.2`, `localhost`, `127.0.0.1`) is allowed
  /// so the local-stack development workflow keeps working. The host list
  /// is pinned to match the loopback allowlist in the native configs:
  ///   - mobile/android/app/src/main/res/xml/network_security_config.xml
  ///   - mobile/ios/Runner/Info.plist (NSAllowsLocalNetworking)
  ///   - mobile/macos/Runner/Info.plist (NSAllowsLocalNetworking)
  bool _hasAllowedTransportScheme(VideoEvent video) {
    final url = video.videoUrl;
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'https') return true;
    if (scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    return host == '10.0.2.2' || host == 'localhost' || host == '127.0.0.1';
  }

  /// Applies the injected block filter, content filter, and warning-labels
  /// resolver to an already-parsed list of [VideoEvent]s.
  ///
  /// Use this when you have videos that were not produced by this
  /// repository's own parsing paths (e.g. entries restored from a local
  /// cache). Videos that fail the block filter, transport-scheme check
  /// (#3836), or content filter are removed; surviving videos have their
  /// `warnLabels` rewritten to reflect the current resolver output.
  ///
  /// This is a pure, synchronous operation. It does not touch the network
  /// or local storage.
  List<VideoEvent> applyContentPreferences(List<VideoEvent> videos) {
    final out = <VideoEvent>[];
    for (final video in videos) {
      if (_blockFilter?.call(video.pubkey) ?? false) continue;
      if (_deletedFilter?.call(video) ?? false) continue;
      if (!_hasAllowedTransportScheme(video)) continue;
      final processed = _applyContentPreferences(video);
      if (processed != null) out.add(processed);
    }
    return out;
  }

  /// Transforms raw Nostr events to VideoEvents and filters invalid ones.
  ///
  /// Applies two-stage filtering:
  /// 1. [_blockFilter] - pubkey-based filtering (blocklist/mutes) BEFORE
  ///    parsing for efficiency
  /// 2. [_contentFilter] - content-based filtering (NSFW, etc.) AFTER
  ///    parsing when video metadata is available
  ///
  /// Also:
  /// - Applies content filter (blocklist/mutes) if configured
  /// - Parses events using [VideoEvent.fromNostrEvent]
  /// - Filters out videos without a valid video URL
  /// - Filters out expired videos (NIP-40)
  /// - Sorts by creation time (newest first) by default, unless
  ///   [sortByCreatedAt] is false (e.g., for NIP-50 results where
  ///   relay order should be preserved)
  List<VideoEvent> _transformAndFilter(
    List<Event> events, {
    bool sortByCreatedAt = true,
  }) {
    final videos = <VideoEvent>[];

    for (final event in events) {
      final video = _tryParseAndFilter(event);
      if (video != null) videos.add(video);
    }

    // Sort by creation time (newest first) unless preserving relay order
    if (sortByCreatedAt) {
      videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return videos;
  }

  /// Searches local cache for videos matching [query].
  ///
  /// Text-matches cached events by title, content, and hashtags (instant,
  /// no network). Returns empty if [query] is blank or no local storage
  /// is configured.
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty if blank.
  ///
  /// Returns a list of matching [VideoEvent]s (unsorted — call
  /// [deduplicateAndSortVideos] to rank).
  Future<List<VideoEvent>> searchVideosLocally({required String query}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _localStorage == null) return [];

    // Phase 1: SQL-level content search (fast, reduces event count)
    final contentMatches = await _localStorage.searchEvents(query: trimmed);

    // Phase 2: Hashtag search (tags stored as JSON, need separate query)
    final hashtagMatches = await _localStorage.getEventsByHashtags(
      hashtags: [trimmed],
      limit: 100,
    );

    // Merge and deduplicate by event ID
    final allMatches = <String, Event>{};
    for (final event in contentMatches) {
      allMatches[event.id] = event;
    }
    for (final event in hashtagMatches) {
      allMatches[event.id] = event;
    }

    // Transform to VideoEvent (now on ~20-50 events instead of 500)
    final localVideos = _transformAndFilter(allMatches.values.toList());

    // Precise in-memory refinement on parsed fields
    final queryLower = trimmed.toLowerCase();
    return localVideos
        .where(
          (v) =>
              (v.title?.toLowerCase().contains(queryLower) ?? false) ||
              v.content.toLowerCase().contains(queryLower) ||
              v.hashtags.any((h) => h.toLowerCase().contains(queryLower)),
        )
        .toList();
  }

  /// Counts local video matches without remote search.
  ///
  /// This still relies on local cache search, but avoids the remote API and
  /// relay phases when a tab only needs a badge count.
  Future<int> countVideosLocally({required String query}) async {
    final matches = await searchVideosLocally(query: query);
    return matches.length;
  }

  /// Searches NIP-50 relays for videos matching [query].
  ///
  /// Full-text search via [NostrClient.searchVideos] with a 5-second
  /// timeout to avoid blocking the caller. Returns empty on timeout or
  /// failure.
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty if blank.
  /// - [limit]: Maximum number of results (default 100).
  ///
  /// Returns a list of matching [VideoEvent]s (unsorted — call
  /// [deduplicateAndSortVideos] to rank).
  Future<List<VideoEvent>> searchVideosOnRelays({
    required String query,
    int limit = 100,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final events = await _nostrClient
          .searchVideos(trimmed, limit: limit)
          .timeout(_relaySearchTimeout, onTimeout: (sink) => sink.close())
          .toList();
      return _transformAndFilter(events, sortByCreatedAt: false);
    } on Exception catch (e, stackTrace) {
      Log.error(
        'searchVideosOnRelays failed for "$trimmed"',
        name: 'VideosRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  /// Searches videos via the Funnelcake REST API.
  ///
  /// Returns empty list if the query is blank, the API client is null,
  /// or the API is unavailable. Results are converted from [VideoStats]
  /// to [VideoEvent] via [_transformVideoStats].
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty if blank.
  /// - [limit]: Maximum number of results (default 50).
  ///
  /// Returns a record of matching [VideoEvent]s in API order and the total API
  /// result count.
  Future<({List<VideoEvent> videos, int totalCount, bool hasMore})>
  searchVideosViaApi({
    required String query,
    int limit = 50,
    int offset = 0,
    VideoSearchSort sort = defaultVideoSearchSort,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return (videos: <VideoEvent>[], totalCount: 0, hasMore: false);
    }
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return (videos: <VideoEvent>[], totalCount: 0, hasMore: false);
    }

    try {
      final response = await _funnelcakeApiClient.searchVideos(
        query: trimmed,
        limit: limit,
        offset: offset,
        sort: sort.apiValue,
      );
      final videos = _transformVideoStats(
        response.videos,
        sortByCreatedAt: false,
      );
      return (
        videos: videos,
        totalCount: response.totalCount,
        hasMore: response.hasMore,
      );
    } on FunnelcakeException catch (e, stackTrace) {
      Log.error(
        'searchVideosViaApi failed for "$trimmed"',
        name: 'VideosRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return (videos: <VideoEvent>[], totalCount: 0, hasMore: false);
    }
  }

  /// Fetches the hashtag feed from the Funnelcake REST API.
  ///
  /// Fetches trending and classic videos for [hashtag] in parallel and
  /// interleaves them 1:1 (trending first), deduplicating classics that
  /// also appear in trending (by event ID or vine ID, case-insensitive).
  /// Both lists pass through the same filtering pipeline as
  /// [_transformVideoStats] — block filter, transport scheme, expiration,
  /// content preferences. The endpoint is anonymous, so the injected
  /// block filter is the only block/mute enforcement on this path (#948).
  ///
  /// Returns a failed result when [hashtag] is blank, the API client is
  /// unavailable, or the fetch fails or exceeds [timeout] — the REST feed
  /// is a fast-path enrichment; callers keep their relay source/cache.
  Future<HashtagFeedVideosResult> getHashtagFeedVideos({
    required String hashtag,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final trimmed = hashtag.trim();
    if (trimmed.isEmpty) return const HashtagFeedVideosResult.failure();
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return const HashtagFeedVideosResult.failure();
    }

    try {
      final results = await Future.wait([
        getVideosByHashtag(hashtag: trimmed, limit: 50),
        getClassicVideosByHashtag(hashtag: trimmed, limit: 50),
      ]).timeout(timeout);

      return HashtagFeedVideosResult.success(
        _interleaveHashtagVideos(results[0], results[1]),
      );
    } on Exception catch (e, stackTrace) {
      Log.error(
        'getHashtagFeedVideos failed for "#$trimmed"',
        name: 'VideosRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      return const HashtagFeedVideosResult.failure();
    }
  }

  /// Interleaves trending and classic hashtag videos 1:1 for a balanced
  /// feed. Classics that already appear in trending (by event ID or vine
  /// ID, case-insensitive) are dropped; when one list runs out, the
  /// remainder of the other is appended.
  List<VideoEvent> _interleaveHashtagVideos(
    List<VideoEvent> trending,
    List<VideoEvent> classics,
  ) {
    final trendingIds = <String>{};
    for (final video in trending) {
      if (video.id.isNotEmpty) trendingIds.add(video.id.toLowerCase());
      final vineId = video.vineId;
      if (vineId != null && vineId.isNotEmpty) {
        trendingIds.add(vineId.toLowerCase());
      }
    }

    final uniqueClassics = classics.where((video) {
      final vineId = video.vineId;
      return !trendingIds.contains(video.id.toLowerCase()) &&
          (vineId == null || !trendingIds.contains(vineId.toLowerCase()));
    }).toList();

    final result = <VideoEvent>[];
    final maxLen = trending.length > uniqueClassics.length
        ? trending.length
        : uniqueClassics.length;
    for (var i = 0; i < maxLen; i++) {
      if (i < trending.length) result.add(trending[i]);
      if (i < uniqueClassics.length) result.add(uniqueClassics[i]);
    }
    return result;
  }

  /// Deduplicates videos by logical feed identity and sorts by popularity
  /// (loops then time).
  ///
  /// Use this to combine results from [searchVideosLocally] and
  /// [searchVideosOnRelays] into a single ranked list.
  List<VideoEvent> deduplicateAndSortVideos(List<VideoEvent> videos) =>
      deduplicateVideosPreservingOrder(videos)
        ..sort(VideoEvent.compareByLoopsThenTime);

  /// Deduplicates videos by logical feed identity while preserving the first
  /// occurrence order.
  List<VideoEvent> deduplicateVideosPreservingOrder(List<VideoEvent> videos) {
    final seenVideoKeys = <String>{};
    return videos.where((v) {
      if (seenVideoKeys.contains(v.feedDedupKey)) return false;
      seenVideoKeys.add(v.feedDedupKey);
      return true;
    }).toList();
  }

  /// Searches videos across all sources, yielding progressively.
  ///
  /// Returns a [Stream] that emits accumulated [VideoEvent] lists as each
  /// source completes:
  /// 1. Local cache results (instant)
  /// 2. Funnelcake API results (fast, ~1s)
  /// 3. NIP-50 relay results (slower, ~5s)
  ///
  /// Each emission contains the full deduplicated+sorted result set so far.
  /// Each phase is isolated — a failure in one phase does not prevent
  /// subsequent phases from yielding results.
  ///
  /// Parameters:
  /// - [query]: The search query string. Returns empty stream if blank.
  /// - [limit]: Maximum results per remote source (default 50).
  Stream<List<VideoEvent>> searchVideos({
    required String query,
    int limit = 50,
    VideoSearchSort sort = defaultVideoSearchSort,
  }) async* {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // Phase 1: Local cache (instant)
    final local = await searchVideosLocally(query: trimmed);
    var accumulated = deduplicateAndSortVideos(local);
    yield accumulated;

    // Phase 2: Funnelcake API (fast)
    try {
      final apiResult = await searchVideosViaApi(
        query: trimmed,
        limit: limit,
        sort: sort,
      );
      if (apiResult.videos.isNotEmpty) {
        accumulated = deduplicateVideosPreservingOrder([
          ...apiResult.videos,
          ...accumulated,
        ]);
        yield accumulated;
      }
    } on Exception catch (e, stackTrace) {
      Log.error(
        'searchVideos API phase failed for "$trimmed"',
        name: 'VideosRepository',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
    }

    // Phase 3: NIP-50 relay search (slower)
    // Note: searchVideosOnRelays handles exceptions internally and returns []
    // on failure, so no outer try-catch is needed.
    final relayResults = await searchVideosOnRelays(
      query: trimmed,
      limit: limit,
    );
    if (relayResults.isNotEmpty) {
      accumulated = deduplicateVideosPreservingOrder([
        ...accumulated,
        ...relayResults,
      ]);
      yield accumulated;
    }
  }

  /// Fetches confirmed collaborator videos for [taggedPubkey].
  ///
  /// Confirmed profile collabs come from Funnelcake's collaborator edge
  /// endpoint. Raw relay p-tag queries are intentionally not used here because
  /// a p-tag can represent a pending invite or generic mention, not a confirmed
  /// collaborator relationship.
  ///
  /// Returns an empty list while Funnelcake is unavailable or when the endpoint
  /// has no confirmed collabs for the profile.
  Future<List<VideoEvent>> getCollabVideos({
    required String taggedPubkey,
    int limit = _defaultLimit,
    int? until,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }

    try {
      final stats = await _funnelcakeApiClient.getCollabVideos(
        pubkey: taggedPubkey,
        limit: limit,
        before: until,
      );
      return _transformVideoStats(stats);
    } on FunnelcakeNotFoundException {
      return [];
    }
  }

  /// Fetches videos sorted by loop count (most looped first).
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getVideosByLoops({
    int limit = 20,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getVideosByLoops(
      limit: limit,
      before: before,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches videos for a specific hashtag.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getVideosByHashtag({
    required String hashtag,
    int limit = 20,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getVideosByHashtag(
      hashtag: hashtag,
      limit: limit,
      before: before,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches classic videos (pre-Nostr) for a specific hashtag.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getClassicVideosByHashtag({
    required String hashtag,
    int limit = 20,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getClassicVideosByHashtag(
      hashtag: hashtag,
      limit: limit,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches classic Vine videos (pre-Nostr archive).
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getClassicVines({
    String sort = 'popular',
    int limit = 20,
    int? offset,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final stats = await _funnelcakeApiClient.getClassicVines(
      sort: sort,
      limit: limit,
      offset: offset ?? 0,
      before: before,
    );
    return _transformVideoStats(stats, sortByCreatedAt: false);
  }

  /// Fetches videos by a specific author from the Funnelcake API.
  ///
  /// Returns empty list if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<List<VideoEvent>> getVideosByAuthor({
    required String pubkey,
    int limit = 20,
    int? before,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return [];
    }
    final result = await _funnelcakeApiClient.getVideosByAuthor(
      pubkey: pubkey,
      limit: limit,
      before: before,
    );
    return _transformVideoStats(result.videos);
  }

  /// Composes a single author's video feed page (profile feed).
  ///
  /// Strategy (mirrors [getNewVideos], adapted to offset pagination):
  /// 1. On the initial page (`offset == null`) returns the in-memory cached
  ///    [AuthorFeedResult] when present, marked [AuthorFeedResult.isFromCache]
  ///    so callers can instant-reseed and then refresh (#4164, #4933).
  /// 2. REST-first: fetches the Funnelcake author page at [offset], reading the
  ///    v2 envelope (`totalCount`/`nextOffset`/`hasMore`); maps via
  ///    `toVideoEvents()` (drops NIP-40 expired only — **no** block/content
  ///    filtering, so the cubit can re-filter on every emit, #4782); hydrates
  ///    engagement counts (bulk-stats then per-video views, filling live
  ///    `nostr*` counts only so the display seed can't double-count, #3384);
  ///    drops backend-leaked p-tagged collaborator events
  ///    (`v.pubkey != authorPubkey`); merges with [relaySeed] under the #3384
  ///    cross-source max policy; caches the initial page.
  /// 3. When Funnelcake is not configured, or throws [FunnelcakeException]
  ///    while [relaySeed] is non-empty, returns the [relaySeed] alone — the
  ///    relay/realtime source is owned by the caller (the profile cubit, over
  ///    `VideoEventService`); this package stays Flutter-free and does not
  ///    query relays here.
  ///
  /// [relaySeed] is the caller's current relay snapshot for the author, merged
  /// as the cross-source "primary" set. Pass `const []` for load-more pages
  /// (the caller accumulates new pages into its existing list via
  /// [mergeProfileFeedVideoLists]).
  ///
  /// Returned videos are **unfiltered** (see [AuthorFeedResult]).
  ///
  /// Throws:
  ///
  /// * [FunnelcakeException] when the API call fails and [relaySeed] is empty,
  ///   so there is nothing to serve instead. An empty result here would be
  ///   indistinguishable from an author who genuinely has no videos, and the
  ///   profile would render "No videos yet" for a network failure. Load-more
  ///   pages pass no seed, so they always surface the failure.
  /// * any non-[FunnelcakeException] error, unchanged.
  Future<AuthorFeedResult> getAuthorFeed({
    required String authorPubkey,
    int? offset,
    List<VideoEvent> relaySeed = const [],
    bool skipCache = false,
  }) async {
    final cacheKey = '$_authorFeedCacheKeyPrefix$authorPubkey';
    final isInitialPage = offset == null;

    if (!skipCache && isInitialPage) {
      final cached = _inMemoryFeedCache?.getAuthorFeed(cacheKey);
      if (cached != null) return cached.copyWith(isFromCache: true);
    }

    if (_funnelcakeApiClient != null && _funnelcakeApiClient.isAvailable) {
      try {
        final response = await _funnelcakeApiClient.getVideosByAuthor(
          pubkey: authorPubkey,
          offset: offset,
        );
        final restVideos = response.videos.toVideoEvents();
        final hydrated = await _hydrateAuthorRestVideos(restVideos);
        // Guard: the backend author endpoint can leak videos where the pubkey
        // is a p-tagged collaborator rather than the event author.
        final authored = hydrated
            .where((video) => !video.isRepost && video.pubkey == authorPubkey)
            .toList();
        final merged = mergeProfileFeedVideoLists(relaySeed, authored);

        final result = AuthorFeedResult(
          authorPubkey: authorPubkey,
          videos: merged,
          totalCount: response.totalCount,
          nextOffset: _nextAuthorFeedOffset(
            response: response,
            offset: offset,
            fetchedCount: hydrated.length,
          ),
          hasMore: _authorFeedHasMore(
            response: response,
            offset: offset,
            fetchedCount: hydrated.length,
          ),
        );

        if (isInitialPage) {
          _inMemoryFeedCache?.setAuthorFeed(cacheKey, result);
        }
        return result;
      } on FunnelcakeException {
        // The client already exhausted its retry budget, so this means the
        // API was unreachable — not that the author has no videos. Serving an
        // empty result here is indistinguishable from an empty account, and
        // the profile renders "No videos yet" for a network failure. Fall
        // through only when the relay seed can still show something.
        if (relaySeed.isEmpty) rethrow;
      }
    }

    final seedOnly = mergeProfileFeedVideoLists(relaySeed, const []);
    return AuthorFeedResult(
      authorPubkey: authorPubkey,
      videos: seedOnly,
      hasMore: seedOnly.length >= _authorFeedHasMoreThreshold,
    );
  }

  int? _nextAuthorFeedOffset({
    required VideosByAuthorResponse response,
    required int? offset,
    required int fetchedCount,
  }) {
    final currentOffset = offset ?? 0;
    if (response.nextOffset != null) return response.nextOffset;
    if (!_authorFeedHasMore(
      response: response,
      offset: offset,
      fetchedCount: fetchedCount,
    )) {
      return null;
    }
    return currentOffset + fetchedCount;
  }

  bool _authorFeedHasMore({
    required VideosByAuthorResponse response,
    required int? offset,
    required int fetchedCount,
  }) {
    if (response.hasMore != null) return response.hasMore!;
    final totalCount = response.totalCount;
    final currentOffset = offset ?? 0;
    if (totalCount != null) return currentOffset + fetchedCount < totalCount;
    return fetchedCount >= _authorFeedPaginationBatchSize;
  }

  /// Hydrates author REST videos with engagement counts: bulk-stats first
  /// (loops/views), then a per-video views-endpoint pass for rows still missing
  /// a view count.
  ///
  /// Bulk stats are **live** Nostr engagement counts, so reactions/comments/
  /// reposts fill only the live `nostr*Count` fields (via `??`); the archival
  /// import counts in `original*` are left untouched. Keeping the two sources
  /// split is what lets the display seed (archival `original*` + live `nostr*`)
  /// add them without double-counting (#3384).
  Future<List<VideoEvent>> _hydrateAuthorRestVideos(
    List<VideoEvent> videos,
  ) async {
    if (videos.isEmpty) return videos;
    final client = _funnelcakeApiClient;
    if (client == null) return videos;
    final withBulkStats = await _hydrateAuthorVideosWithBulkStats(
      videos,
      client,
    );
    return _hydrateAuthorVideosWithViewsEndpoint(withBulkStats, client);
  }

  Future<List<VideoEvent>> _hydrateAuthorVideosWithBulkStats(
    List<VideoEvent> videos,
    FunnelcakeApiClient client,
  ) async {
    final idList = videos
        .map((video) => video.id)
        .where((id) => id.isNotEmpty)
        .toList();
    if (idList.isEmpty) return videos;

    final statsById = <String, BulkVideoStatsEntry>{};
    for (var i = 0; i < idList.length; i += 100) {
      final end = i + 100 > idList.length ? idList.length : i + 100;
      final chunk = idList.sublist(i, end);
      final response = await client.getBulkVideoStats(chunk);
      statsById.addAll(response.stats);
    }

    if (statsById.isEmpty) return videos;

    return videos.map((video) {
      final stats = statsById[video.id];
      if (stats == null) return video;

      final mergedTags = <String, String>{...video.rawTags};
      // rawTags['loops'] means "archival Vine loop count"; only the
      // embedded_loops value qualifies — live computed loops do not.
      if (stats.embeddedLoops != null) {
        mergedTags['loops'] = stats.embeddedLoops!.toString();
      }
      if (stats.views != null) {
        mergedTags['views'] = stats.views!.toString();
      }

      return video.copyWith(
        rawTags: mergedTags,
        originalLoops: stats.embeddedLoops ?? video.originalLoops,
        originalLikes: video.originalLikes,
        originalComments: video.originalComments,
        originalReposts: video.originalReposts,
        nostrLikeCount: video.nostrLikeCount ?? stats.reactions,
        nostrCommentCount: video.nostrCommentCount ?? stats.comments,
        nostrRepostCount: video.nostrRepostCount ?? stats.reposts,
      );
    }).toList();
  }

  Future<List<VideoEvent>> _hydrateAuthorVideosWithViewsEndpoint(
    List<VideoEvent> videos,
    FunnelcakeApiClient client,
  ) async {
    final missingViews = videos
        .where(
          (video) =>
              !_authorVideoHasViewLikeCount(video) && video.id.isNotEmpty,
        )
        .toList();
    if (missingViews.isEmpty) return videos;

    final fetchedViews = <String, int>{};
    for (var i = 0; i < missingViews.length; i += 12) {
      final end = i + 12 > missingViews.length ? missingViews.length : i + 12;
      final chunk = missingViews.sublist(i, end);
      final counts = await Future.wait(
        chunk.map((video) => client.getVideoViews(video.id)),
      );
      for (var j = 0; j < chunk.length; j++) {
        fetchedViews[chunk[j].id] = counts[j];
      }
    }

    if (fetchedViews.isEmpty) return videos;

    return videos.map((video) {
      final count = fetchedViews[video.id];
      if (count == null) return video;
      return video.copyWith(
        rawTags: <String, String>{...video.rawTags, 'views': '$count'},
      );
    }).toList();
  }

  bool _authorVideoHasViewLikeCount(VideoEvent video) {
    final viewTags = [
      video.rawTags['views'],
      video.rawTags['view_count'],
      video.rawTags['total_views'],
      video.rawTags['unique_views'],
      video.rawTags['unique_viewers'],
    ];
    for (final value in viewTags) {
      if (value == null) continue;
      final normalized = value.replaceAll(',', '').trim();
      if (normalized.isEmpty) continue;
      if (int.tryParse(normalized) != null) return true;
      if (double.tryParse(normalized) != null) return true;
    }
    return false;
  }

  /// Fetches a single video by event ID and enriches it with REST-side stats
  /// (loop counts, view counts) from the Funnelcake bulk-stats endpoint.
  ///
  /// Delegates to [getVideosByIds] for cache→relay lookup and content
  /// filtering, then runs bulk-stats enrichment in a second step bounded by
  /// [_statsFetchTimeout] (relay fetch completes first via
  /// `getVideosByIds(..., hydrateBulkStats: false)`).
  ///
  /// Returns `null` when the event is not found or fails content filtering.
  /// The Funnelcake stats hydration is bounded by [_statsFetchTimeout]: on
  /// timeout the video is returned without hydrated stats rather than blocking
  /// the caller indefinitely.
  ///
  /// Intended for code paths that fetch a single video by ID outside of a
  /// feed context: notification taps and `divine.video/video/:id` deep-links.
  Future<VideoEvent?> fetchVideoWithStats(String eventId) async {
    if (eventId.isEmpty) return null;
    final videos = await getVideosByIds([eventId], hydrateBulkStats: false);
    if (videos.isEmpty) return null;
    final hydrated = await _hydrateVideosWithBulkStats(
      videos,
    ).timeout(_statsFetchTimeout, onTimeout: () => videos);
    return hydrated.firstOrNull;
  }

  /// Resolves a video route identifier and returns the hydrated video.
  ///
  /// Supports raw event IDs, plain stable IDs / d-tags, and NIP-19
  /// `note1...`, `nevent1...`, and `naddr1...` references.
  ///
  /// Lookup order is tuned for `divine.video/video/<id>` deep-links: local
  /// cache → Funnelcake REST → relay queries. REST runs before the WebSocket
  /// fallback because it answers in <1s without waiting on relay connection
  /// state, and the hash in a divine.video share URL is the canonical
  /// d-tag/sha256 served by Funnelcake. Relay queries are kept as a fallback
  /// for events that only exist on user-configured personal relays.
  ///
  /// Each relay branch caps its own `queryEvents` call at [_routeRelayTimeout]
  /// (the only thing that can block on cold-start EOSE) and bounds bulk-stats
  /// hydration with [_statsFetchTimeout] (degrades to the unhydrated video
  /// rather than restalling the spinner). The orchestrator deliberately does
  /// not wrap the helpers themselves — a successful relay result followed by
  /// slow stats enrichment must not be killed as if the relay had hung.
  ///
  /// Returns `null` when every candidate came back empty without an error —
  /// a confirmed absence, an unparseable route ID, or relay-only lookups that
  /// returned nothing. Callers may render "not found" on `null`.
  ///
  /// Throws:
  ///
  /// * [FunnelcakeException] when a lookup could not reach the API and neither
  ///   the relay fallbacks nor any [fallbackRouteIds] produced a video.
  ///   Absence was never established, so callers must offer a retry rather
  ///   than claim the video is missing.
  Future<VideoEvent?> fetchVideoWithStatsForRouteId(
    String routeId, {
    List<String> fallbackRouteIds = const [],
  }) async {
    final result = await lookupVideoForRouteId(
      routeId,
      fallbackRouteIds: fallbackRouteIds,
    );
    return result is VideoRouteFound ? result.video : null;
  }

  /// Resolves a `/video/<route-id>` reference, distinguishing a video no
  /// source could supply from one the viewer's content filters removed.
  ///
  /// Both collapsed to null before, so a video that exists and plays —
  /// often the viewer's own — rendered as a permanent "video not found"
  /// with nothing naming the setting responsible and no way to act on it
  /// (#7892). Callers that only need the video keep using
  /// [fetchVideoWithStatsForRouteId].
  Future<VideoRouteLookupResult> lookupVideoForRouteId(
    String routeId, {
    List<String> fallbackRouteIds = const [],
  }) async {
    FunnelcakeException? apiFailure;
    final attempted = <String>{};

    // Any source may parse the video and then have it filtered; keep the
    // first so the caller can explain the outcome instead of guessing.
    VideoEvent? filtered;
    void onContentFiltered(VideoEvent video) => filtered ??= video;

    for (final candidateRouteId in [routeId, ...fallbackRouteIds]) {
      if (!attempted.add(candidateRouteId)) continue;
      try {
        final video = await _fetchVideoWithStatsForSingleRouteId(
          candidateRouteId,
          onContentFiltered: onContentFiltered,
        );
        if (video != null) return VideoRouteFound(video);
      } on FunnelcakeException catch (e) {
        // Keep going: a fallback route is a different query shape (an
        // author-scoped addressable resolves against relays alone) and can
        // still answer while the API is unreachable.
        apiFailure ??= e;
      }
    }

    // Every candidate is exhausted here and nowhere else: the per-candidate
    // helper cannot tell a miss that a later fallback rescues from a net
    // failure, so it reports at INFO and this is the only WARNING.
    Log.warning(
      'Route lookup failed for every candidate: ${attempted.join(', ')}',
      name: 'VideosRepository',
      category: LogCategory.video,
    );

    final failure = apiFailure;
    if (failure != null) throw failure;

    final hidden = filtered;
    if (hidden != null) return VideoRouteHiddenByFilter(hidden);

    return const VideoRouteMissing();
  }

  Future<VideoEvent?> _fetchVideoWithStatsForSingleRouteId(
    String routeId, {
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    final candidate = _VideoRouteCandidate.parse(routeId);
    if (candidate == null) {
      Log.warning(
        'Route lookup could not parse route id: $routeId',
        name: 'VideosRepository',
        category: LogCategory.video,
      );
      return null;
    }

    // Sources that answered "no", in the order they were tried. A null from
    // this method renders a permanent "video not found", so the misses are
    // reported alongside whichever source finally answered — otherwise the
    // failure is indistinguishable from the video genuinely not existing.
    final missed = <String>[];

    VideoEvent resolved(String source, VideoEvent video) {
      Log.info(
        'Route lookup resolved $routeId via $source'
        '${missed.isEmpty ? '' : ' (missed: ${missed.join(', ')})'}',
        name: 'VideosRepository',
        category: LogCategory.video,
      );
      return video;
    }

    final cached = await _fetchRouteVideoFromLocalCache(
      candidate,
      onContentFiltered: onContentFiltered,
    );
    if (cached != null) return resolved('localCache', cached);
    missed.add('localCache');

    FunnelcakeException? apiFailure;
    final funnelcakeRouteId = candidate.stableId ?? candidate.eventId;
    if (funnelcakeRouteId != null) {
      try {
        final byFunnelcake = await _fetchVideoFromRouteApi(
          funnelcakeRouteId,
          expectedPubkey: candidate.addressablePubkey,
          permissive: true,
          onContentFiltered: onContentFiltered,
        );
        if (byFunnelcake != null) {
          return resolved('funnelcake', byFunnelcake);
        }
        missed.add('funnelcake');
      } on FunnelcakeException catch (e, stackTrace) {
        Log.error(
          'Funnelcake route lookup failed; falling back to relay',
          name: 'VideosRepository',
          category: LogCategory.video,
          error: e,
          stackTrace: stackTrace,
        );
        missed.add('funnelcake=error');
        apiFailure = e;
      }
    }

    if (candidate.eventId != null) {
      final byEventId = await _fetchRouteVideoByEventIdFromRelay(
        candidate.eventId!,
        onContentFiltered: onContentFiltered,
      );
      if (byEventId != null) return resolved('relayEventId', byEventId);
      missed.add('relayEventId');
    }

    if (candidate.addressableId != null) {
      final byAddressable = await _fetchAddressableVideoFromRelay(
        candidate.addressableId!,
        onContentFiltered: onContentFiltered,
      );
      if (byAddressable != null) {
        return resolved('relayAddressable', byAddressable);
      }
      missed.add('relayAddressable');
    }

    if (candidate.stableId != null) {
      final byStableId = await _fetchVideoByStableIdFromRelay(
        candidate.stableId!,
        onContentFiltered: onContentFiltered,
      );
      if (byStableId != null) return resolved('relayStableId', byStableId);
      missed.add('relayStableId');
    }

    Log.info(
      'Route lookup exhausted every source for $routeId '
      '(eventId=${candidate.eventId}, '
      'addressableId=${candidate.addressableId}, '
      'stableId=${candidate.stableId}); missed: ${missed.join(', ')}',
      name: 'VideosRepository',
      category: LogCategory.video,
    );

    // Nothing answered. When the API was unreachable we cannot claim the video
    // is missing: null renders a permanent "could be gone, out of reach, or
    // hidden by your settings" for a video the API serves fine once the
    // connection recovers. A confirmed 404 still returns null below.
    if (apiFailure != null) throw apiFailure;

    return null;
  }

  /// Fetches stats for a single video.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<VideoStats?> getVideoStats(String eventId) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getVideoStats(eventId);
  }

  /// Fetches view count for a single video.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<int?> getVideoViews(String eventId) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getVideoViews(eventId);
  }

  /// Fetches bulk video stats for multiple event IDs.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<BulkVideoStatsResponse?> getBulkVideoStats(
    List<String> eventIds,
  ) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getBulkVideoStats(eventIds);
  }

  /// Fetches For You videos from the recommendations endpoint.
  ///
  /// - [skipCache]: Full manual refresh — bypasses the in-memory first-page
  ///   cache and draws a new recommendation session seed, so the first page
  ///   is reshuffled while later pages stay consistent with it.
  /// - [revalidate]: Bypasses the in-memory first-page cache read only and
  ///   keeps the current recommendation session seed, so session-start
  ///   revalidation refetches the first page without reshuffling the
  ///   session.
  Future<HomeFeedResult> getRecommendedVideos({
    required String? userPubkey,
    int limit = _defaultLimit,
    int? until,
    String? cursor,
    bool skipCache = false,
    bool revalidate = false,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    final effectiveUserPubkey =
        userPubkey ??
        (_nostrClient.publicKey.isNotEmpty ? _nostrClient.publicKey : null);
    final preferenceCacheSuffix = _popularPreferenceCacheSuffix(
      preferredLanguages: preferredLanguages,
    );
    final cacheKey =
        'recommended:${effectiveUserPubkey ?? 'anonymous'}'
        '$preferenceCacheSuffix';
    if (!skipCache && !revalidate && until == null && cursor == null) {
      final cached = _inMemoryFeedCache?.get(cacheKey);
      if (cached != null) return _withSeenFreshnessOrdering(cached);
    }

    final isFirstPage = until == null && cursor == null;
    final requestSeed = skipCache && isFirstPage
        ? generateRecommendationSessionSeed()
        : _recommendationSessionSeed;

    if (effectiveUserPubkey == null ||
        _funnelcakeApiClient == null ||
        !_funnelcakeApiClient.isAvailable) {
      return _popularVideosInsteadOfRecommendations(
        reason: 'recommendations unavailable',
        limit: limit,
        until: until,
        skipCache: skipCache,
        revalidate: revalidate,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
    }

    final recommendationCursor = cursor ?? until?.toString();
    late final RecommendationsResponse response;
    try {
      response = await _fetchRecommendationsPage(
        pubkey: effectiveUserPubkey,
        limit: limit,
        cursor: recommendationCursor,
        seed: requestSeed,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
    } on FunnelcakeException catch (e) {
      if (recommendationCursor != null) rethrow;
      return _popularVideosInsteadOfRecommendations(
        reason: 'first page failed: $e',
        limit: limit,
        until: until,
        skipCache: skipCache,
        revalidate: revalidate,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
    }

    final result = await _buildRecommendedVideosResult(
      response: response,
      pubkey: effectiveUserPubkey,
      limit: limit,
      requestSeed: requestSeed,
      recommendationCursor: recommendationCursor,
      preferredLanguages: preferredLanguages,
      viewerCountry: viewerCountry,
    );

    if (result.videos.isEmpty) {
      return _popularVideosInsteadOfRecommendations(
        reason: 'no recommendations survived filtering',
        limit: limit,
        until: until,
        skipCache: skipCache,
        revalidate: revalidate,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
    }

    if (isFirstPage) {
      _recommendationSessionSeed = requestSeed;
    }
    if (until == null && cursor == null) {
      _inMemoryFeedCache?.set(cacheKey, result);
    }
    return result;
  }

  /// Serves popular videos when the For You feed cannot be personalized.
  ///
  /// The returned [HomeFeedResult] is indistinguishable from a recommendation
  /// result at the call site, so the substitution is logged here — otherwise
  /// nothing records that a viewer saw popular videos under the For You tab.
  Future<HomeFeedResult> _popularVideosInsteadOfRecommendations({
    required String reason,
    required int limit,
    required int? until,
    required bool skipCache,
    required bool revalidate,
    required List<String> preferredLanguages,
    required String? viewerCountry,
  }) async {
    Log.warning(
      'For You falling back to popular videos: $reason',
      name: 'VideosRepository',
      category: LogCategory.video,
    );
    return HomeFeedResult(
      videos: await _orderBySeenFreshness(
        await getPopularVideos(
          limit: limit,
          until: until,
          // This legacy, no-variant popular call has no heavier refresh
          // semantics, so revalidation bypasses its cache like manual refresh.
          skipCache: skipCache || revalidate,
          preferredLanguages: preferredLanguages,
          viewerCountry: viewerCountry,
        ),
      ),
    );
  }

  Future<RecommendationsResponse> _fetchRecommendationsPage({
    required String pubkey,
    required int limit,
    required String? cursor,
    required String seed,
    required List<String> preferredLanguages,
    required String? viewerCountry,
  }) {
    if (cursor == null) {
      return _funnelcakeApiClient!.getRecommendations(
        pubkey: pubkey,
        limit: limit,
        seed: seed,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
    }

    return _funnelcakeApiClient!.getRecommendations(
      pubkey: pubkey,
      limit: limit,
      cursor: cursor,
      seed: seed,
      preferredLanguages: preferredLanguages,
      viewerCountry: viewerCountry,
    );
  }

  Future<HomeFeedResult> _buildRecommendedVideosResult({
    required RecommendationsResponse response,
    required String pubkey,
    required int limit,
    required String requestSeed,
    required String? recommendationCursor,
    required List<String> preferredLanguages,
    required String? viewerCountry,
  }) async {
    await _seenVideoLookup?.ensureInitialized();

    // Recommendation responses can carry the same addressable video more than
    // once in a page: the server's emitted-id cursor dedupes by event id, so a
    // republished coordinate (same kind:pubkey:d-tag, fresh event id) slips
    // through. Dedupe by feedDedupKey here — as getNewVideos already does — so
    // the forYou feed never shows the same video twice.
    final videos = <VideoEvent>[];
    final seenVideoKeys = <String>{};
    var currentResponse = response;
    var nextCursor = currentResponse.nextCursor;
    var hasMore = currentResponse.hasMore;
    var fetchedCursor = recommendationCursor;
    var pageCount = 1;

    while (true) {
      _appendUniqueVideos(
        videos,
        _transformVideoStats(currentResponse.videos),
        seenVideoKeys: seenVideoKeys,
      );

      if (videos.isEmpty ||
          _seenVideoLookup == null ||
          _hasNotRecentlySeenCandidate(videos) ||
          !hasMore ||
          nextCursor == null ||
          nextCursor == fetchedCursor) {
        break;
      }

      fetchedCursor = nextCursor;
      currentResponse = await _fetchRecommendationsPage(
        pubkey: pubkey,
        limit: limit,
        cursor: fetchedCursor,
        seed: requestSeed,
        preferredLanguages: preferredLanguages,
        viewerCountry: viewerCountry,
      );
      pageCount++;
      nextCursor = currentResponse.nextCursor;
      hasMore = currentResponse.hasMore;
    }

    return HomeFeedResult(
      videos: prioritizeNotRecentlySeenVideos(
        videos,
        seenVideoLookup: _seenVideoLookup,
      ),
      paginationCursor: nextCursor,
      hasMore: hasMore,
      recommendationPageCount: pageCount,
    );
  }

  bool _hasNotRecentlySeenCandidate(List<VideoEvent> videos) {
    final lookup = _seenVideoLookup;
    if (lookup == null) return true;
    return videos.any(
      (video) =>
          video.id.isEmpty ||
          !lookup.wasSeenRecently(
            video.id,
            within: defaultRecentlySeenVideoWindow,
          ),
    );
  }

  Future<List<VideoEvent>> _orderBySeenFreshness(
    List<VideoEvent> videos,
  ) async {
    await _seenVideoLookup?.ensureInitialized();
    return prioritizeNotRecentlySeenVideos(
      videos,
      seenVideoLookup: _seenVideoLookup,
    );
  }

  Future<HomeFeedResult> _withSeenFreshnessOrdering(
    HomeFeedResult result,
  ) async {
    final orderedVideos = await _orderBySeenFreshness(result.videos);
    if (identical(orderedVideos, result.videos)) return result;
    return HomeFeedResult(
      videos: orderedVideos,
      videoListSources: result.videoListSources,
      listOnlyVideoIds: result.listOnlyVideoIds,
      consumedItemCount: result.consumedItemCount,
      nextCursor: result.nextCursor,
      paginationCursor: result.paginationCursor,
      hasMore: result.hasMore,
    );
  }

  /// Fetches personalized video recommendations.
  ///
  /// Returns null if Funnelcake API is unavailable.
  ///
  /// Throws [FunnelcakeException] subtypes on API errors.
  Future<RecommendationsResponse?> getRecommendations({
    required String pubkey,
    int limit = 20,
    String fallback = 'popular',
    String? category,
    List<String> preferredLanguages = const [],
    String? viewerCountry,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }
    return _funnelcakeApiClient.getRecommendations(
      pubkey: pubkey,
      limit: limit,
      fallback: fallback,
      category: category,
      preferredLanguages: preferredLanguages,
      viewerCountry: viewerCountry,
    );
  }

  /// Returns a hydrated video from local storage when either the candidate's
  /// event id or stable id (d-tag) hits the cache.
  ///
  /// Shared links should be able to reopen a video on a cold start before the
  /// relay layer has finished connecting and before the REST fallback returns.
  /// Addressable coordinates remain author-scoped even through this fast path:
  /// a same-d-tag cache hit from another creator must fall through to the
  /// author-filtered relay lookup instead of satisfying the route.
  Future<VideoEvent?> _fetchRouteVideoFromLocalCache(
    _VideoRouteCandidate candidate, {
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    if (_localStorage == null) return null;

    final candidates = <Event>[];

    if (candidate.eventId != null && candidate.eventId!.isNotEmpty) {
      candidates.addAll(
        await _localStorage.getEventsByIds([candidate.eventId!]),
      );
    }

    if (candidates.isEmpty &&
        candidate.stableId != null &&
        candidate.stableId!.isNotEmpty) {
      candidates.addAll(
        await _localStorage.getEventsByDTag(candidate.stableId!),
      );
    }

    if (candidate.addressablePubkey != null) {
      candidates.removeWhere(
        (event) => event.pubkey != candidate.addressablePubkey,
      );
    }

    if (candidates.isEmpty) return null;
    return _parseAndHydrateFirstRouteVideo(
      candidates,
      onContentFiltered: onContentFiltered,
    );
  }

  Future<VideoEvent?> _fetchRouteVideoByEventIdFromRelay(
    String eventId, {
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    if (eventId.isEmpty) return null;

    final events = await _nostrClient
        .queryEvents([
          Filter(
            ids: [eventId],
            kinds: NIP71VideoKinds.getAllAcceptableVideoKinds(),
          ),
        ])
        .timeout(_routeRelayTimeout, onTimeout: () => const <Event>[]);
    return _parseAndHydrateFirstRouteVideo(
      events,
      onContentFiltered: onContentFiltered,
    );
  }

  Future<VideoEvent?> _fetchVideoByStableIdFromRelay(
    String stableId, {
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    final events = await _nostrClient
        .queryEvents([
          Filter(
            // Route-specific lookups accept all supported NIP-71 video kinds so
            // older shared links still resolve instead of failing as not found.
            kinds: NIP71VideoKinds.getAllAcceptableVideoKinds(),
            d: [stableId],
            limit: 10,
          ),
        ])
        .timeout(_routeRelayTimeout, onTimeout: () => const <Event>[]);
    return _parseAndHydrateFirstRouteVideo(
      events,
      onContentFiltered: onContentFiltered,
    );
  }

  /// Fetches a video by addressable id (`kind:pubkey:d-tag`) from relay only.
  ///
  /// Distinct from [getVideosByAddressableIds] which also runs Funnelcake
  /// fallback and bulk-stats hydration in the same pipeline. The route
  /// orchestrator caps relay I/O via [_routeRelayTimeout]; that cap belongs
  /// around the relay query specifically, not around enrichment that has its
  /// own timeout. Stats hydration here is bounded by [_statsFetchTimeout]
  /// so a stalled stats endpoint cannot re-stall deep-link UX.
  ///
  /// Funnelcake fallback for missing addressable ids is intentionally not
  /// duplicated here. The orchestrator already tries Funnelcake REST as
  /// step 2 with `funnelcakeRouteId = candidate.stableId ?? candidate.eventId`,
  /// and `_VideoRouteCandidate.parse` populates `stableId` from
  /// `decoded.id` / `aid.dTag` for both naddr and raw `kind:pubkey:d-tag`
  /// inputs — so REST has already been attempted by the time we get here.
  ///
  /// Accepts every kind in [NIP71VideoKinds.getAllAcceptableVideoKinds] for
  /// parity with [_fetchRouteVideoByEventIdFromRelay] /
  /// [_fetchVideoByStableIdFromRelay]. Older share links pointing at legacy
  /// kinds (e.g. 21, 22, 34235) reach this branch via naddr1 references and
  /// must resolve the same way they do via raw event id or bare d-tag.
  Future<VideoEvent?> _fetchAddressableVideoFromRelay(
    String addressableId, {
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    final parsed = AId.fromString(addressableId);
    if (parsed == null || !NIP71VideoKinds.isAcceptableVideoKind(parsed.kind)) {
      return null;
    }

    final events = await _nostrClient
        .queryEvents([
          Filter(
            kinds: [parsed.kind],
            authors: [parsed.pubkey],
            d: [parsed.dTag],
          ),
        ])
        .timeout(_routeRelayTimeout, onTimeout: () => const <Event>[]);
    return _parseAndHydrateFirstRouteVideo(
      events,
      onContentFiltered: onContentFiltered,
    );
  }

  Future<VideoEvent?> _fetchVideoFromRouteApi(
    String routeId, {
    String? expectedPubkey,
    bool permissive = false,
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    if (_funnelcakeApiClient == null || !_funnelcakeApiClient.isAvailable) {
      return null;
    }

    final event = await _funnelcakeApiClient.getVideoEvent(routeId);
    if (event == null) return null;

    final video = _tryParseAndFilter(
      event,
      permissive: permissive,
      ignoreBlockFilter: true,
      onContentFiltered: onContentFiltered,
    );
    if (video == null) return null;
    if (expectedPubkey != null && video.pubkey != expectedPubkey) return null;

    return _hydrateFirstRouteVideo([video]);
  }

  Future<VideoEvent?> _parseAndHydrateFirstRouteVideo(
    List<Event> events, {
    void Function(VideoEvent video)? onContentFiltered,
  }) async {
    if (events.isEmpty) return null;

    events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final videos = <VideoEvent>[];
    for (final event in events) {
      final video = _tryParseAndFilter(
        event,
        permissive: true,
        ignoreBlockFilter: true,
        onContentFiltered: onContentFiltered,
      );
      if (video != null) {
        videos.add(video);
      }
    }

    return _hydrateFirstRouteVideo(videos);
  }

  Future<VideoEvent?> _hydrateFirstRouteVideo(List<VideoEvent> videos) async {
    if (videos.isEmpty) return null;

    final hydrated = await _hydrateVideosWithBulkStats(
      videos,
    ).timeout(_statsFetchTimeout, onTimeout: () => videos);
    return hydrated.firstOrNull;
  }
}

class _VideoRouteCandidate {
  const _VideoRouteCandidate({
    this.eventId,
    this.addressableId,
    this.addressablePubkey,
    this.stableId,
  });

  final String? eventId;
  final String? addressableId;
  final String? addressablePubkey;
  final String? stableId;

  static _VideoRouteCandidate? parse(String routeId) {
    final trimmed = routeId.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.length == 64 &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(trimmed)) {
      return _VideoRouteCandidate(
        eventId: trimmed.toLowerCase(),
        stableId: trimmed,
      );
    }

    if (Nip19.isNoteId(trimmed)) {
      final eventId = Nip19.decode(trimmed);
      return eventId.isEmpty ? null : _VideoRouteCandidate(eventId: eventId);
    }

    if (NIP19Tlv.isNevent(trimmed)) {
      final decoded = NIP19Tlv.decodeNevent(trimmed);
      return decoded == null ? null : _VideoRouteCandidate(eventId: decoded.id);
    }

    if (NIP19Tlv.isNaddr(trimmed)) {
      final decoded = NIP19Tlv.decodeNaddr(trimmed);
      if (decoded == null) return null;
      return _VideoRouteCandidate(
        addressableId: AId(
          kind: decoded.kind,
          pubkey: decoded.author,
          dTag: decoded.id,
        ).toAString(),
        addressablePubkey: decoded.author,
        stableId: decoded.id,
      );
    }

    // Raw NIP-33 addressable coordinate: "kind:pubkey:d-tag"
    // Produced by VideoNotification.videoAddressableId for stable notification
    // navigation and by DM share-card fallbacks, which can reference any
    // acceptable NIP-71 kind (e.g. 34235). Accepts the same kinds as the
    // naddr branch above; the 34236-only isVideoKind check would let a
    // 34235 coordinate fall through to an unmatched d-tag lookup.
    final aid = AId.fromString(trimmed);
    if (aid != null && NIP71VideoKinds.isAcceptableVideoKind(aid.kind)) {
      return _VideoRouteCandidate(
        addressableId: trimmed,
        addressablePubkey: aid.pubkey,
        stableId: aid.dTag,
      );
    }

    return _VideoRouteCandidate(stableId: trimmed);
  }
}
