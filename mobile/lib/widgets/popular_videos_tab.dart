// ABOUTME: Popular Videos tab widget showing trending videos sorted by loop count
// ABOUTME: Extracted from ExploreScreen for better separation of concerns

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/error_analytics_tracker.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/trending_hashtags_section.dart';

/// Tab widget displaying popular/trending videos sorted by loop count.
///
/// Handles its own:
/// - Riverpod provider watching (videoEventsProvider)
/// - Analytics tracking (optional, for testability)
/// - Video sorting cache
/// - Loading/error/data states
class PopularVideosTab extends ConsumerStatefulWidget {
  const PopularVideosTab({
    super.key,
    required this.onVideoTap,
    this.screenAnalytics,
    this.feedTracker,
    this.errorTracker,
  });

  /// Callback when a video is tapped to enter feed mode
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  /// Optional analytics services (for testing, defaults to singletons)
  final ScreenAnalyticsService? screenAnalytics;
  final FeedPerformanceTracker? feedTracker;
  final ErrorAnalyticsTracker? errorTracker;

  @override
  ConsumerState<PopularVideosTab> createState() => _PopularVideosTabState();
}

class _PopularVideosTabState extends ConsumerState<PopularVideosTab> {
  // Analytics services - use provided or create defaults
  late final ScreenAnalyticsService? _screenAnalytics;
  late final FeedPerformanceTracker? _feedTracker;
  late final ErrorAnalyticsTracker? _errorTracker;
  DateTime? _feedLoadStartTime;

  @override
  void initState() {
    super.initState();
    _screenAnalytics = widget.screenAnalytics;
    _feedTracker = widget.feedTracker;
    _errorTracker = widget.errorTracker;
  }

  // Trending tab sort cache - avoid re-sorting videos on every rebuild
  List<VideoEvent>? _cachedTrendingVideos;
  List<VideoEvent>? _lastRawVideos;

  @override
  Widget build(BuildContext context) {
    final videoEventsAsync = ref.watch(videoEventsProvider);

    Log.debug(
      '🔍 PopularVinesTab: AsyncValue state - isLoading: ${videoEventsAsync.isLoading}, '
      'hasValue: ${videoEventsAsync.hasValue}, hasError: ${videoEventsAsync.hasError}, '
      'value length: ${videoEventsAsync.value?.length ?? 0}',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (videoEventsAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker?.startFeedLoad('trending');
    }

    // CRITICAL: Check hasValue FIRST before isLoading
    // StreamProviders can have both isLoading:true and hasValue:true during rebuilds
    if (videoEventsAsync.hasValue && videoEventsAsync.value != null) {
      return _buildDataState(videoEventsAsync.value!);
    }

    if (videoEventsAsync.hasError) {
      _trackErrorState(videoEventsAsync.error);
      return const _PopularVideosErrorState();
    }

    // Only show loading if we truly have no data yet
    _trackLoadingState();
    return const _PopularVideosLoadingState();
  }

  Widget _buildDataState(List<VideoEvent> allVideos) {
    // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
    final videos = allVideos
        .where((v) => v.isSupportedOnCurrentPlatform)
        .toList();

    Log.info(
      '✅ TrendingTab: Data state - ${videos.length} videos (filtered from ${allVideos.length} total)',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    // Track feed loaded with videos
    if (_feedLoadStartTime != null) {
      _feedTracker?.markFirstVideosReceived('trending', videos.length);
      _feedTracker?.markFeedDisplayed('trending', videos.length);
      _screenAnalytics?.markDataLoaded(
        'explore_screen',
        dataMetrics: {'tab': 'trending', 'video_count': videos.length},
      );
      _feedLoadStartTime = null;
    }

    // Track empty feed
    if (videos.isEmpty) {
      _feedTracker?.trackEmptyFeed('trending');
    }

    // PERFORMANCE OPTIMIZATION: Only re-sort if video list changed
    final List<VideoEvent> sortedVideos;
    if (identical(videos, _lastRawVideos) && _cachedTrendingVideos != null) {
      // Same video list object - use cached sort
      sortedVideos = _cachedTrendingVideos!;
      Log.debug(
        '✨ TRENDING CACHE HIT: Reusing sorted list (${sortedVideos.length} videos)',
        name: 'ExploreScreen',
        category: LogCategory.video,
      );
    } else {
      // New video list - sort and cache
      sortedVideos = List<VideoEvent>.from(videos);
      sortedVideos.sort((a, b) {
        final aLoops = a.originalLoops ?? 0;
        final bLoops = b.originalLoops ?? 0;
        return bLoops.compareTo(aLoops); // Descending order
      });

      // Update cache
      _lastRawVideos = videos;
      _cachedTrendingVideos = sortedVideos;

      Log.verbose(
        'Trending: sorted ${sortedVideos.length} videos by loop count',
        name: 'ExploreScreen',
        category: LogCategory.video,
      );
    }

    return _PopularVideosTrendingContent(
      videos: sortedVideos,
      onVideoTap: widget.onVideoTap,
    );
  }

  void _trackErrorState(Object? error) {
    Log.error(
      '❌ TrendingTab: Error state - $error',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    final loadTime = _feedLoadStartTime != null
        ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
        : null;
    _feedTracker?.trackFeedError(
      'trending',
      errorType: 'load_failed',
      errorMessage: error.toString(),
    );
    _errorTracker?.trackFeedLoadError(
      feedType: 'trending',
      errorType: 'provider_error',
      errorMessage: error.toString(),
      loadTimeMs: loadTime,
    );
    _feedLoadStartTime = null;
  }

  void _trackLoadingState() {
    Log.info(
      '⏳ TrendingTab: Showing loading indicator',
      name: 'ExploreScreen',
      category: LogCategory.video,
    );

    if (_feedLoadStartTime != null) {
      final elapsed = DateTime.now()
          .difference(_feedLoadStartTime!)
          .inMilliseconds;
      if (elapsed > 5000) {
        _errorTracker?.trackSlowOperation(
          operation: 'trending_feed_load',
          durationMs: elapsed,
          thresholdMs: 5000,
          location: 'explore_trending',
        );
      }
    }
  }
}

/// Content widget displaying trending hashtags and video grid
class _PopularVideosTrendingContent extends ConsumerWidget {
  const _PopularVideosTrendingContent({
    required this.videos,
    required this.onVideoTap,
  });

  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hashtags = TopHashtagsService.instance.getTopHashtags(limit: 20);

    return Column(
      children: [
        TrendingHashtagsSection(
          hashtags: hashtags,
          isLoading: !TopHashtagsService.instance.isLoaded,
        ),
        Expanded(
          child: ComposableVideoGrid(
            videos: videos,
            childAspectRatio: 0.72,
            thumbnailAspectRatio: 1.0,
            onVideoTap: onVideoTap,
            onRefresh: () async {
              Log.info(
                '🔄 ExploreScreen: Refreshing trending tab',
                category: LogCategory.video,
              );
              ref.invalidate(videoEventsProvider);
              await ref.read(videoEventsProvider.future);
            },
            emptyBuilder: () => const _PopularVideosEmptyState(),
          ),
        ),
      ],
    );
  }
}

/// Empty state widget for PopularVideosTab
class _PopularVideosEmptyState extends StatelessWidget {
  const _PopularVideosEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            'No videos in Popular Videos',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new content',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for PopularVideosTab
class _PopularVideosErrorState extends StatelessWidget {
  const _PopularVideosErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            'Failed to load trending videos',
            style: TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for PopularVideosTab
class _PopularVideosLoadingState extends StatelessWidget {
  const _PopularVideosLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: VineTheme.vineGreen));
  }
}
