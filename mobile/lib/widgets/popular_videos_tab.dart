// ABOUTME: Popular Videos tab widget showing videos with the highest current watch volume
// ABOUTME: Uses REST API (sort=watching) with Nostr fallback (NIP-50 sort:hot) for active-watch ranking

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';
import 'package:openvine/widgets/trending_hashtags_section.dart';
import 'package:unified_logger/unified_logger.dart';

/// Cross-fade used when the feed swaps between loading, error and data —
/// including the native/classic variant switch.
const _feedStateTransitionDuration = Duration(milliseconds: 250);

/// Elapsed first-page load time past which the load is reported as slow.
const _slowFeedLoadThresholdMs = 5000;

/// Tab widget displaying popular videos by current watch volume.
///
/// Handles its own:
/// - Riverpod provider watching (videoEventsProvider)
/// - Analytics tracking (optional, for testability)
/// - Video sorting cache
/// - Loading/error/data states
/// - Full screen video navigation on tap
class PopularVideosTab extends ConsumerStatefulWidget {
  const PopularVideosTab({
    super.key,
    this.screenAnalytics,
    this.feedTracker,
    this.errorTracker,
    this.slowLoadThresholdMs = _slowFeedLoadThresholdMs,
  });

  /// Optional analytics overrides; each defaults to the app's shared instance.
  final ScreenAnalyticsService? screenAnalytics;
  final FeedPerformanceTracker? feedTracker;
  final ErrorAnalyticsTracker? errorTracker;

  /// Elapsed load time past which the load is reported as slow.
  ///
  /// Overridable because the elapsed time comes from the wall clock, which
  /// `fakeAsync` cannot advance — a test would otherwise have to sleep for
  /// [_slowFeedLoadThresholdMs] to reach the branch.
  final int slowLoadThresholdMs;

  @override
  ConsumerState<PopularVideosTab> createState() => _PopularVideosTabState();
}

class _PopularVideosTabState extends ConsumerState<PopularVideosTab> {
  late final ScreenAnalyticsService _screenAnalytics;
  late final FeedPerformanceTracker _feedTracker;
  late final ErrorAnalyticsTracker _errorTracker;
  DateTime? _feedLoadStartTime;
  FeedLoadHandle? _feedLoad;
  bool _slowFeedLoadReported = false;

  /// Page currently painted, together with the variant it belongs to.
  ///
  /// Keeps the previous grid on screen while a variant switch loads, so the
  /// toggle cross-fades between two feeds instead of dropping to a spinner.
  /// It also survives an error that arrives after a successful load, so a
  /// failed refresh leaves the working grid up instead of blanking it.
  ({PopularVideosVariant variant, VideoFeedState state})? _rendered;

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

  @override
  Widget build(BuildContext context) {
    // Use popularVideosFeedProvider which tries REST API (sort=watching) first,
    // then falls back to Nostr (NIP-50 sort:hot) if unavailable.
    final feedAsync = ref.watch(popularVideosFeedProvider);
    final selectedVariant = ref.watch(popularVideosVariantProvider);
    final loadedVariant = ref.watch(popularVideosLoadedVariantProvider);

    Log.debug(
      '🔍 PopularVideosTab: AsyncValue state - isLoading: ${feedAsync.isLoading}, '
      'hasValue: ${feedAsync.hasValue}, hasError: ${feedAsync.hasError}',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    // Track feed loading start
    if (feedAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _slowFeedLoadReported = false;
      _feedLoad = _feedTracker.startFeedLoad('popular');
    }

    // A held page outranks an in-flight load. A hard error outranks both.
    final feedState = feedAsync.value;
    final showsSelectedVariant =
        feedState != null && loadedVariant == selectedVariant;
    if (showsSelectedVariant) {
      // Captured here rather than from a listener because the very first
      // frame that carries the new variant must already paint it: a
      // `ref.listen` callback runs after this build, so the tab would paint
      // the outgoing page for one extra frame and the cross-fade would start
      // late. Assigning from build is safe because the value is derived
      // entirely from providers this build already read.
      _rendered = (variant: selectedVariant, state: feedState);
      _trackDataState(feedState.videos);
    }

    // While a variant switch loads, keep painting the page we last rendered,
    // keyed by its own variant, so the newly selected variant cross-fades in
    // instead of flashing a full-screen spinner.
    final rendered = _rendered;

    final Widget content;
    if (feedAsync.hasError && !showsSelectedVariant) {
      _trackErrorState(feedAsync.error);
      content = RefreshableFeedStateView(
        key: const ValueKey('error'),
        onRefresh: _refreshPopularVideos,
        child: const _PopularVideosErrorState(),
      );
    } else if (rendered != null) {
      _trackSlowLoadIfNeeded();
      content = _PopularVideosTrendingContent(
        key: ValueKey(rendered.variant),
        videos: rendered.state.videos,
        isLoadingMore: rendered.state.isLoadingMore,
        hasMoreContent: rendered.state.hasMoreContent,
      );
    } else {
      // Only show loading if we truly have no data yet
      _trackLoadingState();
      content = const _PopularVideosLoadingState(key: ValueKey('loading'));
    }

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _feedStateTransitionDuration,
      child: content,
    );
  }

  Future<void> _refreshPopularVideos() async {
    await ref.read(popularVideosFeedProvider.notifier).refresh();
  }

  void _trackDataState(List<VideoEvent> videos) {
    // Videos are already sorted by current watch volume from the provider
    // (REST API sort=watching, or NIP-50 sort:hot fallback) and filtered for
    // platform compatibility

    Log.info(
      '✅ PopularVideosTab: Data state - ${videos.length} videos '
      '(top loops: ${videos.isNotEmpty ? videos.first.originalLoops ?? 0 : 0})',
      name: 'PopularVideosTab',
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
        dataMetrics: {'tab': 'popular', 'video_count': videos.length},
      );
      _feedLoadStartTime = null;
    }

    // Track empty feed
    if (videos.isEmpty) {
      _feedTracker.trackEmptyFeed('popular');
    }
  }

  void _trackErrorState(Object? error) {
    Log.error(
      '❌ PopularVideosTab: Error state - $error',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    final loadTime = _feedLoadStartTime != null
        ? DateTime.now().difference(_feedLoadStartTime!).inMilliseconds
        : null;
    _feedTracker.trackFeedError(
      'popular',
      errorType: 'load_failed',
      errorMessage: error.toString(),
    );
    _errorTracker.trackFeedLoadError(
      feedType: 'popular',
      errorType: 'provider_error',
      errorMessage: error.toString(),
      loadTimeMs: loadTime,
    );
    final feedLoad = _feedLoad;
    if (feedLoad != null) _feedTracker.abandonFeedLoad(feedLoad);
    _feedLoad = null;
    _feedLoadStartTime = null;
  }

  void _trackLoadingState() {
    Log.info(
      '⏳ PopularVideosTab: Showing loading indicator',
      name: 'PopularVideosTab',
      category: LogCategory.video,
    );

    _trackSlowLoadIfNeeded();
  }

  /// Reports a slow first page regardless of what the tab is painting.
  ///
  /// A variant switch holds the previous page instead of the spinner, so
  /// gating this on the spinner branch would drop the signal for exactly
  /// the loads the user waits on.
  ///
  /// Reports at most once per load. The held-page branch runs on every
  /// rebuild while the switch is in flight and never clears
  /// [_feedLoadStartTime] the way [_trackDataState] does, so an unguarded
  /// report would emit one event per rebuild for a single slow load.
  void _trackSlowLoadIfNeeded() {
    final startedAt = _feedLoadStartTime;
    if (startedAt == null || _slowFeedLoadReported) return;

    final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
    if (elapsed <= widget.slowLoadThresholdMs) return;

    _slowFeedLoadReported = true;
    _errorTracker.trackSlowOperation(
      operation: 'popular_feed_load',
      durationMs: elapsed,
      thresholdMs: widget.slowLoadThresholdMs,
      location: 'explore_popular',
    );
  }

  @override
  void dispose() {
    final feedLoad = _feedLoad;
    if (feedLoad != null) _feedTracker.abandonFeedLoad(feedLoad);
    super.dispose();
  }
}

/// Content widget displaying trending hashtags and video grid.
///
/// Hashtags push up as user scrolls down (1:1 with scroll distance).
/// When scrolling up, hashtags slide back in as an overlay with animation.
class _PopularVideosTrendingContent extends ConsumerStatefulWidget {
  const _PopularVideosTrendingContent({
    required this.videos,
    required this.isLoadingMore,
    required this.hasMoreContent,
    super.key,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_PopularVideosTrendingContent> createState() =>
      _PopularVideosTrendingContentState();
}

class _PopularVideosTrendingContentState
    extends ConsumerState<_PopularVideosTrendingContent>
    with ScrollToHideMixin {
  @override
  Widget build(BuildContext context) {
    final popularVideosFeedNotifier = ref.read(
      popularVideosFeedProvider.notifier,
    );
    final topHashtags = ref.read(topHashtagsServiceProvider);
    final hashtags = topHashtags.getTopHashtags(limit: 20);

    measureHeaderHeight();

    return Stack(
      children: [
        // Grid takes full space
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: handleScrollNotification,
            child: ComposableVideoGrid(
              videos: widget.videos,
              useMasonryLayout: true,
              // Explore grids are edge-to-edge; the 4px gap between columns
              // comes from `crossAxisSpacing` inside ComposableVideoGrid, not
              // from outer side padding.
              padding: EdgeInsets.only(
                bottom: 4,
                top: headerHeight > 0 ? headerHeight + 4 : 4,
              ),
              onVideoTap: (videoList, index) {
                Log.info(
                  '🎯 PopularVideosTab TAP: gridIndex=$index, '
                  'videoId=${videoList[index].id}',
                  category: LogCategory.video,
                );
                context.push(
                  PooledFullscreenVideoFeedScreen.pathForVideoId(
                    videoList[index].id,
                  ),
                  extra: PooledFullscreenVideoFeedArgs(
                    source: const PopularViewSource(),
                    feedRepository: ref.read(feedRepositoryProvider),
                    initialIndex: index,
                    initialVideoId: videoList[index].id,
                    contextTitle: context.l10n.popularVideosContextTitle,
                    trafficSource: ViewTrafficSource.discoveryPopular,
                  ),
                );
              },
              onRefresh: () async {
                Log.info(
                  '🔄 PopularVideosTab: Refreshing',
                  category: LogCategory.video,
                );
                await popularVideosFeedNotifier.refresh();
              },
              onLoadMore: () async {
                Log.info(
                  '📜 PopularVideosTab: Loading more',
                  category: LogCategory.video,
                );
                await popularVideosFeedNotifier.loadMore();
              },
              isLoadingMore: widget.isLoadingMore,
              hasMoreContent: widget.hasMoreContent,
              emptyBuilder: () => const _PopularVideosEmptyState(),
            ),
          ),
        ),
        // Hashtags overlay on top, animated when returning
        AnimatedPositioned(
          duration: headerFullyHidden
              ? const Duration(milliseconds: 250)
              : Duration.zero,
          curve: Curves.easeOut,
          top: headerOffset,
          left: 0,
          right: 0,
          child: TrendingHashtagsSection(
            key: headerKey,
            hashtags: hashtags,
            isLoading: !topHashtags.isLoaded,
            leading: const _PopularFeedVariantToggle(),
          ),
        ),
      ],
    );
  }
}

class _PopularFeedVariantToggle extends ConsumerWidget {
  const _PopularFeedVariantToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(popularVideosVariantProvider);

    return Semantics(
      label: context.l10n.popularVideosFeedSourceLabel,
      child: Container(
        key: const Key('popular-feed-variant-toggle'),
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: context.vineColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.vineColors.outlineMuted),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PopularFeedVariantButton(
              label: context.l10n.categoryGallerySortNew,
              variant: PopularVideosVariant.native,
              selected: selected == PopularVideosVariant.native,
            ),
            _PopularFeedVariantButton(
              label: context.l10n.categoryGallerySortClassic,
              variant: PopularVideosVariant.classic,
              selected: selected == PopularVideosVariant.classic,
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularFeedVariantButton extends ConsumerWidget {
  const _PopularFeedVariantButton({
    required this.label,
    required this.variant,
    required this.selected,
  });

  final String label;
  final PopularVideosVariant variant;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (selected) return;
          ref.read(popularVideosVariantProvider.notifier).state = variant;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 28,
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? VineTheme.vineGreen : VineTheme.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.labelMediumFont(
              color: selected
                  ? VineTheme.primaryDarkGreen
                  : context.vineColors.onSurfaceMuted,
            ),
          ),
        ),
      ),
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
          Icon(
            Icons.video_library,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.popularVideosEmptyTitle,
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.popularVideosEmptySubtitle,
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

/// Error state widget for PopularVideosTab
class _PopularVideosErrorState extends StatelessWidget {
  const _PopularVideosErrorState();

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
            context.l10n.popularVideosErrorTitle,
            style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for PopularVideosTab
class _PopularVideosLoadingState extends StatelessWidget {
  const _PopularVideosLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}
