// ABOUTME: Explore Latest and New tabs: videos sorted by publication time,
// ABOUTME: New keeping only creators who debuted recently.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/new_videos_feed_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying videos sorted by publication time.
///
/// [feed] picks the Explore tab: [PublicationFeed.latest] for Latest (every
/// new video) or [PublicationFeed.newCreators] for New (videos from creators
/// who debuted recently).
///
/// Handles its own:
/// - Riverpod provider watching (newVideosFeedProvider)
/// - Analytics tracking (optional, for testability)
/// - Loading/error/data states
/// - Full screen video navigation on tap
class NewVideosTab extends ConsumerStatefulWidget {
  const NewVideosTab({
    super.key,
    this.feed = PublicationFeed.latest,
    this.screenAnalytics,
    this.feedTracker,
    this.errorTracker,
  });

  /// Which publication-ordered feed this tab shows.
  final PublicationFeed feed;

  /// Optional analytics overrides; each defaults to the app's shared instance.
  final ScreenAnalyticsService? screenAnalytics;
  final FeedPerformanceTracker? feedTracker;
  final ErrorAnalyticsTracker? errorTracker;

  @override
  ConsumerState<NewVideosTab> createState() => _NewVideosTabState();
}

class _NewVideosTabState extends ConsumerState<NewVideosTab> {
  late final ScreenAnalyticsService _screenAnalytics;
  late final FeedPerformanceTracker _feedTracker;
  late final ErrorAnalyticsTracker _errorTracker;
  DateTime? _feedLoadStartTime;
  FeedLoadHandle? _feedLoad;

  @override
  void initState() {
    super.initState();
    _screenAnalytics =
        widget.screenAnalytics ?? ref.read(screenAnalyticsServiceProvider);
    _feedTracker =
        widget.feedTracker ?? ref.read(feedPerformanceTrackerProvider);
    _errorTracker =
        widget.errorTracker ?? ref.read(errorAnalyticsTrackerProvider);
  }

  /// Analytics name of the feed. Latest keeps `new_vines`, the name it had
  /// as the New tab, so its history stays continuous.
  String get _feedName => switch (widget.feed) {
    PublicationFeed.latest => 'new_vines',
    PublicationFeed.newCreators => 'new_creators',
  };

  @override
  Widget build(BuildContext context) {
    final newVideosAsync = ref.watch(newVideosFeedProvider(widget.feed));

    Log.debug(
      '🔍 NewVinesTab: AsyncValue state - isLoading: ${newVideosAsync.isLoading}, '
      'hasValue: ${newVideosAsync.hasValue}, hasError: ${newVideosAsync.hasError}',
      name: 'NewVideosTab',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (newVideosAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedLoad = _feedTracker.startFeedLoad(_feedName);
    }

    // CRITICAL: Check hasValue FIRST before isLoading
    // Async providers can have both isLoading:true and hasValue:true during rebuilds
    if (newVideosAsync.hasValue && newVideosAsync.value != null) {
      final allVideos = newVideosAsync.value!.videos;
      // Filter out WebM videos on iOS/macOS (not supported by AVPlayer)
      final videos = allVideos
          .where((v) => v.isSupportedOnCurrentPlatform)
          .toList();

      Log.info(
        '✅ NewVinesTab: Data state - ${videos.length} videos '
        '(filtered from ${allVideos.length} total)',
        name: 'NewVideosTab',
        category: LogCategory.video,
      );

      // Track feed loaded with videos
      if (_feedLoadStartTime != null) {
        final feedLoad = _feedLoad;
        if (feedLoad != null) {
          _feedTracker.markFirstVideosReceived(feedLoad, videos.length);
          _feedTracker.markFeedDisplayed(feedLoad, videos.length);
        }
        _feedLoad = null;
        _screenAnalytics.markDataLoaded(
          'explore_screen',
          dataMetrics: {'tab': _feedName, 'video_count': videos.length},
        );
        _feedLoadStartTime = null;
      }

      // Track empty feed
      if (videos.isEmpty) {
        _feedTracker.trackEmptyFeed(_feedName);
      }

      // Get feed state for pagination info
      final feedState = newVideosAsync.value!;
      return _NewVideosContent(
        feed: widget.feed,
        videos: videos,
        isLoadingMore: feedState.isLoadingMore,
        hasMoreContent: feedState.hasMoreContent,
      );
    }

    if (newVideosAsync.hasError) {
      _trackErrorState(newVideosAsync.error);
      return RefreshableFeedStateView(
        onRefresh: _refreshNewVideos,
        child: _NewVideosErrorState(error: newVideosAsync.error),
      );
    }

    // Only show loading if we truly have no data yet
    _trackLoadingState();
    return const _NewVideosLoadingState();
  }

  Future<void> _refreshNewVideos() async {
    await ref.read(newVideosFeedProvider(widget.feed).notifier).refresh();
  }

  void _trackLoadingState() {
    Log.info(
      '⏳ NewVinesTab: Showing loading indicator',
      name: 'NewVideosTab',
      category: LogCategory.video,
    );

    // Track slow loading after 5 seconds
    if (_feedLoadStartTime != null) {
      final elapsed = DateTime.now()
          .difference(_feedLoadStartTime!)
          .inMilliseconds;
      if (elapsed > 5000) {
        _errorTracker.trackSlowOperation(
          operation: '${_feedName}_feed_load',
          durationMs: elapsed,
          thresholdMs: 5000,
          location: 'explore_$_feedName',
        );
      }
    }
  }

  void _trackErrorState(Object? error) {
    Log.error(
      '❌ NewVinesTab: Error state - $error',
      name: 'NewVideosTab',
      category: LogCategory.video,
    );

    // Track error
    final loadTime = _feedLoadStartTime != null
        ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
        : null;
    _feedTracker.trackFeedError(
      _feedName,
      errorType: 'load_failed',
      errorMessage: error.toString(),
    );
    _errorTracker.trackFeedLoadError(
      feedType: _feedName,
      errorType: 'provider_error',
      errorMessage: error.toString(),
      loadTimeMs: loadTime,
    );
    final feedLoad = _feedLoad;
    if (feedLoad != null) _feedTracker.abandonFeedLoad(feedLoad);
    _feedLoad = null;
    _feedLoadStartTime = null;
  }

  @override
  void dispose() {
    final feedLoad = _feedLoad;
    if (feedLoad != null) _feedTracker.abandonFeedLoad(feedLoad);
    super.dispose();
  }
}

/// Content widget displaying the video grid
class _NewVideosContent extends ConsumerStatefulWidget {
  const _NewVideosContent({
    required this.feed,
    required this.videos,
    this.isLoadingMore = false,
    this.hasMoreContent = false,
  });

  final PublicationFeed feed;
  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_NewVideosContent> createState() => _NewVideosContentState();
}

class _NewVideosContentState extends ConsumerState<_NewVideosContent> {
  @override
  Widget build(BuildContext context) {
    final newVideosFeedNotifier = ref.read(
      newVideosFeedProvider(widget.feed).notifier,
    );
    final l10n = context.l10n;

    return ComposableVideoGrid(
      videos: widget.videos,
      useMasonryLayout: true,
      // Explore grids are edge-to-edge; the 4px gap between columns comes
      // from `crossAxisSpacing` inside ComposableVideoGrid, not from
      // outer side padding.
      padding: const EdgeInsets.symmetric(vertical: 4),
      onVideoTap: (videoList, index) {
        Log.info(
          '🎯 NewVideosTab TAP: gridIndex=$index, '
          'videoId=${videoList[index].id}',
          category: LogCategory.video,
        );
        runDetached(
          context.push<void>(
            PooledFullscreenVideoFeedScreen.pathForVideoId(videoList[index].id),
            extra: switch (widget.feed) {
              PublicationFeed.latest => PooledFullscreenVideoFeedArgs(
                source: const NewVideosViewSource(),
                feedRepository: ref.read(feedRepositoryProvider),
                initialIndex: index,
                initialVideoId: videoList[index].id,
                contextTitle: l10n.exploreTabLatest,
                trafficSource: ViewTrafficSource.discoveryNew,
              ),
              PublicationFeed.newCreators => PooledFullscreenVideoFeedArgs(
                source: const NewCreatorsViewSource(),
                feedRepository: ref.read(feedRepositoryProvider),
                initialIndex: index,
                initialVideoId: videoList[index].id,
                contextTitle: l10n.exploreTabNewDiviners,
                trafficSource: ViewTrafficSource.discoveryNewCreators,
              ),
            },
          ),
          'open new video',
          logName: 'NewVideosTab',
          category: LogCategory.ui,
        );
      },
      onRefresh: () async {
        Log.info(
          '🔄 NewVideosTab: Refreshing feed',
          category: LogCategory.video,
        );
        await newVideosFeedNotifier.refresh();
      },
      onLoadMore: () async {
        Log.info('📜 NewVideosTab: Loading more', category: LogCategory.video);
        await newVideosFeedNotifier.loadMore();
      },
      isLoadingMore: widget.isLoadingMore,
      hasMoreContent: widget.hasMoreContent,
      emptyBuilder: () => _NewVideosEmptyState(feed: widget.feed),
    );
  }
}

/// Empty state widget for NewVideosTab
class _NewVideosEmptyState extends StatelessWidget {
  const _NewVideosEmptyState({required this.feed});

  final PublicationFeed feed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            switch (feed) {
              PublicationFeed.latest => context.l10n.latestVideosTabEmptyTitle,
              PublicationFeed.newCreators =>
                context.l10n.newVideosTabEmptyTitle,
            },
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.newVideosTabEmptySubtitle,
            style: TextStyle(
              color: context.vineColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for NewVideosTab
class _NewVideosErrorState extends StatelessWidget {
  const _NewVideosErrorState({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: VineTheme.likeRed,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.feedFailedToLoadVideos,
            style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            style: TextStyle(
              color: context.vineColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for NewVideosTab
class _NewVideosLoadingState extends StatelessWidget {
  const _NewVideosLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}
