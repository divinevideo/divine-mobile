// ABOUTME: ClassicVines feed provider showing pre-2017 Vine archive videos
// ABOUTME: Uses REST API when available, falls back to Nostr videos with embedded stats

import 'dart:async';

import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'classic_vines_provider.g.dart';

/// ClassicVines feed provider - shows pre-2017 Vine archive sorted by loops
///
/// Uses REST API (Funnelcake) with offset pagination to load pages on demand.
/// Each page is 50 videos.
///
/// Pull-to-refresh selects a fresh random slice of classics while retrying
/// transient failures and empty pages.
@Riverpod(keepAlive: true)
class ClassicVinesFeed extends _$ClassicVinesFeed {
  static const int _pageSize = 50;
  static const int _initialRequestAttempts = 2;

  /// Repository cursor for the next page of the current loaded classics window.
  String? _paginationCursor;

  @override
  Future<VideoFeedState> build() async {
    // Watch content filter version — rebuilds when preferences change.
    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);

    // Watch blocklist version — rebuilds when block/unblock actions occur.
    ref.watch(blocklistVersionProvider);

    // Watch appReady gate
    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      '🎬 ClassicVinesFeed: Building feed (appReady: $isAppReady)',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      // Preserve existing data during background — don't wipe the feed
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          return existing.copyWith(
            videos: _filterRepositoryVideos(
              existing.videos,
              ref.read(videoEventServiceProvider),
            ),
          );
        }
      }
      return const VideoFeedState(videos: [], hasMoreContent: false);
    }

    final funnelcakeAvailable =
        ref.watch(funnelcakeAvailableProvider).asData?.value ?? false;

    _paginationCursor = null;

    return _loadFirstPage(funnelcakeAvailable: funnelcakeAvailable);
  }

  Future<VideoFeedState> _loadFirstPage({
    required bool funnelcakeAvailable,
    bool preserveCurrentOnEmptyFallback = false,
    bool skipCache = false,
  }) async {
    final videoEventService = ref.read(videoEventServiceProvider);
    Object? restError;
    StackTrace? restStackTrace;

    Future<HomeFeedResult> fetchRestPage({
      required bool retryOnError,
      String? cursor,
      bool skipCache = false,
    }) async {
      final repository = ref.read(videosRepositoryProvider);
      final attempts = retryOnError ? _initialRequestAttempts : 1;
      for (var attempt = 1; attempt <= attempts; attempt++) {
        try {
          final result = await repository.getClassicVideos(
            limit: _pageSize,
            cursor: cursor,
            skipCache: skipCache,
          );
          final filteredResult = _filterRepositoryResult(
            result,
            videoEventService,
          );

          if (filteredResult.videos.isNotEmpty ||
              (filteredResult.hasMore ?? false)) {
            return filteredResult;
          }

          if (attempt < attempts) {
            Log.warning(
              '🎬 ClassicVinesFeed: REST API returned no videos, retrying',
              name: 'ClassicVinesFeedProvider',
              category: LogCategory.video,
            );
            continue;
          }

          return filteredResult;
        } catch (e) {
          if (attempt < attempts) {
            Log.warning(
              '🎬 ClassicVinesFeed: REST API error, retrying: $e',
              name: 'ClassicVinesFeedProvider',
              category: LogCategory.video,
            );
            continue;
          }
          rethrow;
        }
      }

      throw StateError('Classics API retry loop exhausted');
    }

    VideoFeedState restFeedState({required HomeFeedResult result}) {
      _paginationCursor = result.paginationCursor;

      Log.info(
        '🎬 ClassicVinesFeed: Loaded ${result.videos.length} videos '
        '(next cursor: ${result.paginationCursor})',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );

      return VideoFeedState(
        videos: result.videos,
        hasMoreContent: result.hasMore ?? false,
        lastUpdated: DateTime.now(),
      );
    }

    // Try REST API first (Funnelcake has comprehensive classic Vine data)
    if (funnelcakeAvailable) {
      try {
        final firstPage = await fetchRestPage(
          retryOnError: true,
          skipCache: skipCache,
        );

        if (firstPage.videos.isNotEmpty) {
          return restFeedState(result: firstPage);
        }

        restError = StateError('Classics API returned no videos');
        Log.warning(
          '🎬 ClassicVinesFeed: REST API returned no videos, trying next page',
          name: 'ClassicVinesFeedProvider',
          category: LogCategory.video,
        );

        final recoveryPage = await fetchRestPage(
          cursor: firstPage.paginationCursor,
          retryOnError: false,
          skipCache: true,
        );

        if (recoveryPage.videos.isEmpty) {
          restError = StateError(
            'Classics API recovery page returned no videos',
          );
          Log.warning(
            '🎬 ClassicVinesFeed: REST API recovery page returned no videos, falling back to Nostr',
            name: 'ClassicVinesFeedProvider',
            category: LogCategory.video,
          );
          // Fall through to Nostr fallback.
        } else {
          return restFeedState(result: recoveryPage);
        }
      } catch (e, stackTrace) {
        restError = e;
        restStackTrace = stackTrace;
        Log.warning(
          '🎬 ClassicVinesFeed: REST API error, falling back to Nostr: $e',
          name: 'ClassicVinesFeedProvider',
          category: LogCategory.video,
        );
        // Fall through to Nostr fallback
      }
    }

    // Fallback: Get videos from Nostr that have embedded loop stats
    Log.info(
      '🎬 ClassicVinesFeed: Using Nostr fallback',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    final allVideos = videoEventService.discoveryVideos;
    final classicVideos = dedupeByFeedKey(
      videoEventService.filterVideoList(
        allVideos
            .where((v) => v.isOriginalVine)
            .where((v) => v.isSupportedOnCurrentPlatform)
            .toList(),
      ),
    )..sort((a, b) => (b.originalLoops ?? 0).compareTo(a.originalLoops ?? 0));

    // Take top entries then shuffle for variety
    final topClassics = classicVideos.take(_pageSize).toList()..shuffle();

    if (topClassics.isEmpty && preserveCurrentOnEmptyFallback) {
      final failure = restError;
      if (failure == null) {
        throw StateError('Classics API unavailable');
      }
      Error.throwWithStackTrace(failure, restStackTrace ?? StackTrace.current);
    }

    return VideoFeedState(
      videos: topClassics,
      hasMoreContent: classicVideos.length > _pageSize,
      error: restError?.toString(),
      lastUpdated: DateTime.now(),
    );
  }

  /// Refresh with a new random slice of classic vines.
  Future<void> refresh() async {
    final funnelcakeAvailable =
        ref.read(funnelcakeAvailableProvider).asData?.value ?? false;

    _paginationCursor = null;

    Log.info(
      '🎬 ClassicVinesFeed: Refreshing',
      name: 'ClassicVinesFeedProvider',
      category: LogCategory.video,
    );

    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: () => _loadFirstPage(
        funnelcakeAvailable: funnelcakeAvailable,
        preserveCurrentOnEmptyFallback: true,
        skipCache: true,
      ),
    );
  }

  /// Load more videos (append next sequential page from current offset)
  Future<void> loadMore() async {
    if (!state.hasValue || state.value == null) return;
    final currentState = state.value!;
    if (currentState.isLoadingMore) return;

    final repository = ref.read(videosRepositoryProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final funnelcakeAvailable =
        ref.read(funnelcakeAvailableProvider).asData?.value ?? false;

    if (!funnelcakeAvailable || !currentState.hasMoreContent) return;

    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final requestCursor = _paginationCursor;
      final page = await repository.getClassicVideos(
        limit: _pageSize,
        cursor: requestCursor,
        skipCache: true,
      );
      final filteredVideos = dedupeByFeedKey(
        _filterRepositoryVideos(page.videos, videoEventService),
        alreadySeen: currentState.videos.map((v) => v.feedDedupKey),
      );

      final allVideos = [...currentState.videos, ...filteredVideos];
      _paginationCursor = page.paginationCursor;

      Log.info(
        '🎬 ClassicVinesFeed: Loaded ${filteredVideos.length} more '
        '(cursor: $requestCursor, total: ${allVideos.length})',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );

      state = AsyncData(
        VideoFeedState(
          videos: allVideos,
          hasMoreContent: page.hasMore ?? false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e) {
      Log.error(
        '🎬 ClassicVinesFeed: Error loading more: $e',
        name: 'ClassicVinesFeedProvider',
        category: LogCategory.video,
      );
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  HomeFeedResult _filterRepositoryResult(
    HomeFeedResult result,
    VideoEventService videoEventService,
  ) {
    return HomeFeedResult(
      videos: _filterRepositoryVideos(result.videos, videoEventService),
      videoListSources: result.videoListSources,
      listOnlyVideoIds: result.listOnlyVideoIds,
      consumedItemCount: result.consumedItemCount,
      nextCursor: result.nextCursor,
      paginationCursor: result.paginationCursor,
      hasMore: result.hasMore,
    );
  }

  List<VideoEvent> _filterRepositoryVideos(
    List<VideoEvent> videos,
    VideoEventService videoEventService,
  ) {
    return videoEventService.filterVideoList(
      videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
    );
  }
}

/// Provider to check if classic vines feed is loading
@riverpod
bool classicVinesFeedLoading(Ref ref) {
  final asyncState = ref.watch(classicVinesFeedProvider);
  if (asyncState.isLoading) return true;

  final state = asyncState.hasValue ? asyncState.value : null;
  if (state == null) return false;

  return state.isLoadingMore;
}

/// Provider to get current classic vines feed video count
@riverpod
int classicVinesFeedCount(Ref ref) {
  final asyncState = ref.watch(classicVinesFeedProvider);
  return asyncState.hasValue ? (asyncState.value?.videos.length ?? 0) : 0;
}

/// Provider to check if classic vines are available
///
/// Delegates to the centralized funnelcakeAvailableProvider.
/// Classic vines require Funnelcake REST API to be available.
@riverpod
Future<bool> classicVinesAvailable(Ref ref) async {
  return ref.watch(funnelcakeAvailableProvider.future);
}

/// Data model for a top classic Viner
class ClassicViner {
  const ClassicViner({
    required this.pubkey,
    required this.totalLoops,
    required this.videoCount,
    this.authorName,
    this.authorAvatar,
  });

  final String pubkey;
  final int totalLoops;
  final int videoCount;

  /// Display name carried over from the classic Vine archive.
  ///
  /// Already well-formed UTF-16: [topClassicViners] only ever copies this from
  /// [VideoEvent.authorName], and that constructor is the sanitizing display
  /// boundary. Feeding it from anything else would need its own boundary —
  /// the viner slider renders this straight into a `Text`, and a lone
  /// surrogate throws out of Flutter's paragraph builder.
  final String? authorName;

  final String? authorAvatar; // Profile picture URL from API
}

/// Provider for top classic Viners derived from classic videos
///
/// Aggregates videos by pubkey and sorts by total loop count.
/// Also triggers profile prefetching for Viners without avatars.
@riverpod
Future<List<ClassicViner>> topClassicViners(Ref ref) async {
  final classicVinesAsync = ref.watch(classicVinesFeedProvider);

  // Wait for classic vines to load - check if has value
  if (!classicVinesAsync.hasValue || classicVinesAsync.value == null) {
    return const [];
  }

  final feedState = classicVinesAsync.value!;
  if (feedState.videos.isEmpty) {
    return const [];
  }

  // Aggregate by pubkey
  final vinerMap = <String, _VinerAggregator>{};

  for (final video in feedState.videos) {
    final aggregator = vinerMap.putIfAbsent(video.pubkey, _VinerAggregator.new);
    final loops = video.originalLoops ?? 0;
    aggregator.totalLoops = aggregator.totalLoops + loops;
    aggregator.videoCount += 1;
    // Capture author name from first video that has one
    if (aggregator.authorName == null && video.authorName != null) {
      aggregator.authorName = video.authorName;
    }
    // Capture author avatar from first video that has one
    if (aggregator.authorAvatar == null && video.authorAvatar != null) {
      aggregator.authorAvatar = video.authorAvatar;
    }
  }

  // Convert to ClassicViner list and sort by total loops
  final viners =
      vinerMap.entries
          .map(
            (e) => ClassicViner(
              pubkey: e.key,
              totalLoops: e.value.totalLoops,
              videoCount: e.value.videoCount,
              authorName: e.value.authorName,
              authorAvatar: e.value.authorAvatar,
            ),
          )
          .where((v) => v.totalLoops > 0)
          .toList()
        ..sort((a, b) => b.totalLoops.compareTo(a.totalLoops));

  Log.info(
    '🎬 TopClassicViners: Found ${viners.length} unique Viners',
    name: 'ClassicVinesProvider',
    category: LogCategory.video,
  );

  // Get top 20 Viners
  final topViners = viners.take(20).toList();

  // Prefetch profiles for Viners without avatars from REST API
  // This ensures avatar images are available when the slider renders
  final vinersNeedingProfiles = topViners
      .where((v) => v.authorAvatar == null || v.authorAvatar!.isEmpty)
      .map((v) => v.pubkey)
      .toList();

  if (vinersNeedingProfiles.isNotEmpty) {
    Log.info(
      '🎬 TopClassicViners: Prefetching ${vinersNeedingProfiles.length} profiles for Viners without avatars',
      name: 'ClassicVinesProvider',
      category: LogCategory.video,
    );
    // Fire-and-forget profile prefetch - don't await
    final profileRepository = ref.read(profileRepositoryProvider);
    // TODO(any): Consider making profile repository not nullable
    if (profileRepository != null) {
      unawaited(
        profileRepository.fetchBatchProfiles(pubkeys: vinersNeedingProfiles),
      );
    }
  }

  return topViners;
}

/// Helper class for aggregating Viner stats
class _VinerAggregator {
  int totalLoops = 0;
  int videoCount = 0;
  String? authorName; // Capture from first video with a name
  String? authorAvatar; // Capture from first video with an avatar
}
