// ABOUTME: New Videos feed provider showing videos by original publication time
// ABOUTME: Uses VideosRepository.getNewVideos so Explore New is distinct from Popular

import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/providers/feed_refresh_helpers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/video_nostr_enrichment.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:videos_repository/videos_repository.dart';

part 'new_videos_feed_provider.g.dart';

/// New Videos feed provider - shows newest videos first.
///
/// Delegates video fetching to [VideosRepository.getNewVideos] so the Explore
/// New Videos tab does not share the popular/trending source.
@Riverpod(keepAlive: true)
class NewVideosFeed extends _$NewVideosFeed {
  int? _nextCursor;
  String? _paginationCursor;
  int _paginationGeneration = 0;
  final _enrichmentAttemptTracker = NostrTagEnrichmentAttemptTracker();

  @override
  Future<VideoFeedState> build() async {
    _nextCursor = null;
    _paginationCursor = null;

    ref.watch(contentFilterVersionProvider);
    ref.watch(divineHostFilterVersionProvider);
    ref.watch(blocklistVersionProvider);

    final isAppReady = ref.watch(appReadyProvider);

    Log.info(
      'NewVideosFeed: Building (appReady: $isAppReady)',
      name: 'NewVideosFeedProvider',
      category: LogCategory.video,
    );

    if (!isAppReady) {
      if (state.hasValue && state.value != null) {
        final existing = state.value!;
        if (existing.videos.isNotEmpty) {
          return existing.copyWith(videos: _filterVideos(existing.videos));
        }
      }
      return const VideoFeedState(videos: [], hasMoreContent: true);
    }

    return _loadFirstPage();
  }

  Future<VideoFeedState> _loadFirstPage({
    bool bypassRepositoryCache = false,
  }) async {
    try {
      final videosRepository = ref.read(videosRepositoryProvider);
      final page = await videosRepository.getNewVideos(
        limit: AppConstants.paginationBatchSize,
        skipCache: bypassRepositoryCache,
      );
      final videos = page.videos;

      if (!ref.mounted) {
        return const VideoFeedState(videos: [], hasMoreContent: true);
      }

      _paginationGeneration++;
      _nextCursor = getOldestTimestamp(videos);
      _paginationCursor = page.paginationCursor;

      if (videos.isEmpty) {
        Log.warning(
          'NewVideosFeed: No videos returned',
          name: 'NewVideosFeedProvider',
          category: LogCategory.video,
        );
        return VideoFeedState(
          videos: const [],
          hasMoreContent: page.hasMore ?? false,
        );
      }

      final filteredVideos = filterNewFeedVideos(_filterVideos(videos));
      _scheduleEnrichment(filteredVideos);

      Log.info(
        'NewVideosFeed: Got ${filteredVideos.length} newest videos',
        name: 'NewVideosFeedProvider',
        category: LogCategory.video,
      );

      return VideoFeedState(
        videos: filteredVideos,
        // The repository reports this: the cached first page can be shorter
        // than this feed's page size when the home feed warmed it with a
        // smaller one, and it still has more behind it.
        hasMoreContent: page.hasMore ?? false,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      Log.error(
        'NewVideosFeed: Error loading videos: $e',
        name: 'NewVideosFeedProvider',
        category: LogCategory.video,
      );
      return VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        error: e.toString(),
      );
    }
  }

  /// Load more videos for pagination.
  Future<void> loadMore() async {
    final currentState = await future;

    if (!ref.mounted || currentState.isLoadingMore) return;
    if (!currentState.hasMoreContent) return;

    final paginationGeneration = _paginationGeneration;
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final videosRepository = ref.read(videosRepositoryProvider);
      while (true) {
        final requestedUntil = _nextCursor;
        final requestedCursor = _paginationCursor;
        final page = await videosRepository.getNewVideos(
          limit: AppConstants.paginationBatchSize,
          until: requestedCursor == null ? requestedUntil : null,
          cursor: requestedCursor,
        );

        // Refresh owns the new window and its cursors once it commits.
        if (!ref.mounted || paginationGeneration != _paginationGeneration) {
          return;
        }
        _nextCursor = getOldestTimestamp(page.videos);
        _paginationCursor = page.paginationCursor;
        final progressed = _paginationCursor != null
            ? _paginationCursor != requestedCursor
            : _nextCursor != null &&
                  (requestedUntil == null || _nextCursor! < requestedUntil);
        final hasMore = page.hasMore ?? false;
        final dedupedNew = dedupeByFeedKey(
          page.videos,
          alreadySeen: currentState.videos.map((v) => v.feedDedupKey),
        );
        final allVideos = filterNewFeedVideos([
          ...currentState.videos,
          ..._filterVideos(dedupedNew),
        ]);
        final filteredNew = allVideos.skip(currentState.videos.length).toList();

        // A page with nothing new to show (capped, filtered or already
        // shown) must not strand the viewer at the end of the window.
        if (filteredNew.isEmpty && hasMore && progressed) continue;

        state = AsyncData(
          currentState.copyWith(
            videos: allVideos,
            hasMoreContent: hasMore && filteredNew.isNotEmpty,
            isLoadingMore: false,
            error: null,
            lastUpdated: DateTime.now(),
          ),
        );
        _scheduleEnrichment(filteredNew);
        return;
      }
    } catch (e) {
      Log.error(
        'NewVideosFeed: Error loading more: $e',
        name: 'NewVideosFeedProvider',
        category: LogCategory.video,
      );

      if (!ref.mounted || paginationGeneration != _paginationGeneration) return;
      state = AsyncData(
        currentState.copyWith(isLoadingMore: false, error: e.toString()),
      );
    }
  }

  /// Refresh the feed by resetting cursor and rebuilding.
  Future<void> refresh() async {
    Log.info(
      'NewVideosFeed: Refreshing',
      name: 'NewVideosFeedProvider',
      category: LogCategory.video,
    );

    _nextCursor = null;
    _paginationCursor = null;

    await staleWhileRevalidate(
      getCurrentState: () => state,
      isMounted: () => ref.mounted,
      setState: (s) => state = s,
      fetchFresh: () => _loadFirstPage(bypassRepositoryCache: true),
    );
  }

  List<VideoEvent> _filterVideos(List<VideoEvent> videos) {
    final videoEventService = ref.read(videoEventServiceProvider);
    return videoEventService.filterVideoList(
      videos.where((v) => v.isSupportedOnCurrentPlatform).toList(),
    );
  }

  void _scheduleEnrichment(List<VideoEvent> videos) {
    if (videos.isEmpty) return;

    enrichVideosInBackground(
      videos,
      nostrService: ref.read(nostrServiceProvider),
      callerName: 'NewVideosFeedProvider',
      attemptTracker: _enrichmentAttemptTracker,
      onEnriched: (enrichedVideos) {
        if (!ref.mounted || !state.hasValue) return;

        final currentState = state.value;
        if (currentState == null || currentState.videos.isEmpty) return;

        final mergedVideos = mergeEnrichedVideos(
          existing: currentState.videos,
          enriched: enrichedVideos,
        );

        if (videoListsEqual(currentState.videos, mergedVideos)) {
          return;
        }

        state = AsyncData(
          currentState.copyWith(
            videos: mergedVideos,
            lastUpdated: DateTime.now(),
          ),
        );

        Log.info(
          'NewVideosFeed: Applied background Nostr enrichment to ${enrichedVideos.length} videos',
          name: 'NewVideosFeedProvider',
          category: LogCategory.video,
        );
      },
    );
  }
}
