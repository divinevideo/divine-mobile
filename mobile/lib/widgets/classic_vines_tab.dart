// ABOUTME: Classics tab widget showing pre-2017 Vine archive videos
// ABOUTME: Uses REST API when available, falls back to Nostr videos with embedded loop stats

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/classic_viners_slider.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying Classics archive videos (pre-2017).
///
/// Handles its own:
/// - Riverpod provider watching (classicVinesFeedProvider)
/// - Loading/error/data states
/// - Empty state when REST API unavailable
class ClassicVinesTab extends ConsumerStatefulWidget {
  const ClassicVinesTab({super.key, this.feedTracker});

  /// Analytics tracker. Null unless a caller supplies one — this tab does not
  /// report feed-load timing in production (see #4743).
  final FeedPerformanceTracker? feedTracker;

  @override
  ConsumerState<ClassicVinesTab> createState() => _ClassicVinesTabState();
}

class _ClassicVinesTabState extends ConsumerState<ClassicVinesTab> {
  late final FeedPerformanceTracker? _feedTracker;
  DateTime? _feedLoadStartTime;

  @override
  void initState() {
    super.initState();
    _feedTracker = widget.feedTracker;
  }

  @override
  Widget build(BuildContext context) {
    final classicVinesAsync = ref.watch(classicVinesFeedProvider);
    final isAvailableAsync = ref.watch(classicVinesAvailableProvider);
    final isAvailable = isAvailableAsync.asData?.value;

    Log.debug(
      '🎬 ClassicVinesTab: AsyncValue state - isLoading: ${classicVinesAsync.isLoading}, '
      'hasValue: ${classicVinesAsync.hasValue}, isAvailable: $isAvailable',
      name: 'ClassicVinesTab',
      category: LogCategory.video,
    );

    if (isAvailableAsync.isLoading) {
      return const _ClassicVinesLoadingState();
    }

    // If REST API not available, show unavailable state
    if (isAvailable != true) {
      return RefreshableFeedStateView(
        autoRefresh: true,
        onRefresh: _refreshClassics,
        child: const _ClassicVinesUnavailableState(),
      );
    }

    // Track feed loading start
    if (classicVinesAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker?.startFeedLoad('classics');
    }

    // Check hasValue FIRST before isLoading
    if (classicVinesAsync.hasValue && classicVinesAsync.value != null) {
      return _buildDataState(classicVinesAsync.value!);
    }

    if (classicVinesAsync.hasError) {
      _feedTracker?.trackFeedError(
        'classics',
        errorType: 'load_failed',
        errorMessage: classicVinesAsync.error.toString(),
      );
      _feedLoadStartTime = null;
      return RefreshableFeedStateView(
        onRefresh: _refreshClassics,
        child: _ClassicVinesErrorState(
          error: classicVinesAsync.error.toString(),
        ),
      );
    }

    // Show loading state
    return const _ClassicVinesLoadingState();
  }

  Widget _buildDataState(VideoFeedState feedState) {
    final videos = feedState.videos;

    Log.info(
      '✅ ClassicVinesTab: Data state - ${videos.length} videos',
      name: 'ClassicVinesTab',
      category: LogCategory.video,
    );

    // Track feed loaded with videos
    if (_feedLoadStartTime != null) {
      _feedTracker?.markFirstVideosReceived('classics', videos.length);
      _feedTracker?.markFeedDisplayed('classics', videos.length);
      _feedLoadStartTime = null;
    }

    if (videos.isEmpty) {
      _feedTracker?.trackEmptyFeed('classics');
      return RefreshableFeedStateView(
        autoRefresh: true,
        onRefresh: _refreshClassics,
        child: const _ClassicVinesEmptyState(),
      );
    }

    return _ClassicVinesContent(
      videos: videos,
      isLoadingMore: feedState.isLoadingMore,
      hasMoreContent: feedState.hasMoreContent,
    );
  }

  Future<void> _refreshClassics() async {
    ref.read(funnelcakeAvailableProvider.notifier).refresh();
    await ref.read(funnelcakeAvailableProvider.future);
    // The widget can be disposed during any of these awaits (e.g. the Explore
    // TabController settling on another tab, or navigating away) while a
    // throttled-network refresh is still in flight. Using `ref` after that
    // throws a StateError, so bail out once unmounted. See issue #6157.
    if (!mounted) return;
    ref.invalidate(classicVinesAvailableProvider);
    await ref.read(classicVinesAvailableProvider.future);
    if (!mounted) return;
    await ref.read(classicVinesFeedProvider.notifier).refresh();
  }
}

/// Content widget displaying classic Viners slider and video grid.
///
/// Uses a simple vertical layout (no scroll-to-hide) to ensure pull-to-refresh
/// works reliably. The slider scrolls away naturally as user scrolls the grid.
/// Supports infinite scroll pagination via scroll detection.
class _ClassicVinesContent extends ConsumerStatefulWidget {
  const _ClassicVinesContent({
    required this.videos,
    this.isLoadingMore = false,
    this.hasMoreContent = false,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_ClassicVinesContent> createState() =>
      _ClassicVinesContentState();
}

class _ClassicVinesContentState extends ConsumerState<_ClassicVinesContent>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => widget.hasMoreContent && !widget.isLoadingMore;

  @override
  Future<void> onLoadMore() async {
    Log.info(
      '📜 ClassicVinesTab: Loading more classics',
      name: 'ClassicVinesTab',
      category: LogCategory.video,
    );
    await ref.read(classicVinesFeedProvider.notifier).loadMore();
  }

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classicVinesFeedNotifier = ref.read(
      classicVinesFeedProvider.notifier,
    );

    return FeedRefreshControl(
      scrollController: _scrollController,
      onRefresh: () async {
        Log.info(
          '🔄 ClassicVinesTab: Spinning to next batch of classics',
          name: 'ClassicVinesTab',
          category: LogCategory.video,
        );
        ref.read(funnelcakeAvailableProvider.notifier).refresh();
        await ref.read(funnelcakeAvailableProvider.future);
        await classicVinesFeedNotifier.refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Viners slider at top
          const SliverToBoxAdapter(child: ClassicVinersSlider()),
          // Video grid below
          _ClassicVideosSliverGrid(
            videos: widget.videos,
            onVideoTap: (videos, index) {
              Log.info(
                '🎯 ClassicVinesTab TAP: gridIndex=$index, '
                'videoId=${videos[index].id}',
                category: LogCategory.video,
              );
              context.push(
                PooledFullscreenVideoFeedScreen.pathForVideoId(
                  videos[index].id,
                ),
                extra: PooledFullscreenVideoFeedArgs(
                  source: const ClassicVinesViewSource(),
                  feedRepository: ref.read(feedRepositoryProvider),
                  initialIndex: index,
                  initialVideoId: videos[index].id,
                  contextTitle: context.l10n.exploreTabClassics,
                  trafficSource: ViewTrafficSource.discoveryClassic,
                ),
              );
            },
          ),
          // Loading indicator at bottom
          if (widget.isLoadingMore || widget.hasMoreContent)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: widget.isLoadingMore
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: DivineCircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.vineColors.accentPositive,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sliver grid for classic videos using masonry layout
class _ClassicVideosSliverGrid extends ConsumerWidget {
  const _ClassicVideosSliverGrid({
    required this.videos,
    required this.onVideoTap,
  });

  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch broken video tracker
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Center(child: DivineCircularProgressIndicator()),
      ),
      error: (_, _) => _buildGrid(context, ref, videos),
      data: (tracker) {
        final filteredVideos = videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();
        return _buildGrid(context, ref, filteredVideos);
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<VideoEvent> videosToShow,
  ) {
    if (videosToShow.isEmpty) {
      return const SliverToBoxAdapter(child: _ClassicVinesEmptyState());
    }

    // Responsive column count
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return SliverPadding(
      // Explore grids are edge-to-edge; the 4px gap between columns comes
      // from `crossAxisSpacing` below, not from outer side padding.
      padding: const EdgeInsets.symmetric(vertical: 4),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childCount: videosToShow.length,
        itemBuilder: (context, index) {
          final video = videosToShow[index];
          return _ClassicVideoItem(
            video: video,
            index: index,
            videos: videosToShow,
            onVideoTap: onVideoTap,
          );
        },
      ),
    );
  }
}

/// Individual video item for the classics grid
class _ClassicVideoItem extends StatelessWidget {
  const _ClassicVideoItem({
    required this.video,
    required this.index,
    required this.videos,
    required this.onVideoTap,
  });

  final VideoEvent video;
  final int index;
  final List<VideoEvent> videos;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.classicVideoTile(index),
      button: true,
      label: video.displayTitle,
      child: GestureDetector(
        onTap: () => onVideoTap(videos, index),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              VideoThumbnailWidget(video: video),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.only(
                    left: 8,
                    right: 8,
                    bottom: 6,
                    top: 24,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [VineTheme.transparent, VineTheme.scrim80],
                    ),
                  ),
                  child: UserName.fromPubKey(
                    video.pubkey,
                    embeddedName: video.displayAuthorName,
                    maxLines: 1,
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: VineTheme.scrim50,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unavailable state when REST API is not connected
class _ClassicVinesUnavailableState extends StatelessWidget {
  const _ClassicVinesUnavailableState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: context.vineColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.classicsUnavailableTitle,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.classicsUnavailableDescription,
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DivineInfoCard(
              compact: true,
              message: context.l10n.classicsUnavailableSettingsHint,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for ClassicVinesTab
class _ClassicVinesEmptyState extends StatelessWidget {
  const _ClassicVinesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.classicsEmptyTitle,
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.classicsEmptyDescription,
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

/// Error state widget for ClassicVinesTab
class _ClassicVinesErrorState extends StatelessWidget {
  const _ClassicVinesErrorState({required this.error});

  final String error;

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
            context.l10n.classicsErrorTitle,
            style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: TextStyle(
              color: context.vineColors.secondaryText,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for ClassicVinesTab
class _ClassicVinesLoadingState extends StatelessWidget {
  const _ClassicVinesLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}
