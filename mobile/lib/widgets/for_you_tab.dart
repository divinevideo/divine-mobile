// ABOUTME: For You tab widget showing ML-powered personalized video recommendations
// ABOUTME: Uses Gorse-based recommendations from Funnelcake REST API (staging only)

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying For You personalized recommendations.
///
/// Handles its own:
/// - Riverpod provider watching (forYouFeedProvider)
/// - Loading/error/data states
/// - Empty state when recommendations unavailable
class ForYouTab extends ConsumerStatefulWidget {
  const ForYouTab({super.key, this.feedTracker});

  /// Analytics tracker. Null unless a caller supplies one — this tab does not
  /// report feed-load timing in production (see #4743).
  final FeedPerformanceTracker? feedTracker;

  @override
  ConsumerState<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends ConsumerState<ForYouTab> {
  late final FeedPerformanceTracker? _feedTracker;
  DateTime? _feedLoadStartTime;

  @override
  void initState() {
    super.initState();
    _feedTracker = widget.feedTracker;
  }

  @override
  Widget build(BuildContext context) {
    final forYouAsync = ref.watch(forYouFeedProvider);
    final isAvailableAsync = ref.watch(forYouAvailableProvider);
    final isAvailable = isAvailableAsync;

    Log.debug(
      '🎯 ForYouTab: AsyncValue state - isLoading: ${forYouAsync.isLoading}, '
      'hasValue: ${forYouAsync.hasValue}, isAvailable: $isAvailable',
      name: 'ForYouTab',
      category: LogCategory.video,
    );

    // If not available, show unavailable state
    if (!isAvailable) {
      return RefreshableFeedStateView(
        autoRefresh: true,
        onRefresh: _refreshForYou,
        child: const _ForYouUnavailableState(),
      );
    }

    // Track feed loading start
    if (forYouAsync.isLoading && _feedLoadStartTime == null) {
      _feedLoadStartTime = DateTime.now();
      _feedTracker?.startFeedLoad('for_you');
    }

    // Check hasValue FIRST before isLoading
    if (forYouAsync.hasValue && forYouAsync.value != null) {
      return _buildDataState(forYouAsync.value!);
    }

    if (forYouAsync.hasError) {
      _feedTracker?.trackFeedError(
        'for_you',
        errorType: 'load_failed',
        errorMessage: forYouAsync.error.toString(),
      );
      _feedLoadStartTime = null;
      return RefreshableFeedStateView(
        onRefresh: _refreshForYou,
        child: const _ForYouErrorState(),
      );
    }

    // Show loading state
    return const _ForYouLoadingState();
  }

  Widget _buildDataState(VideoFeedState feedState) {
    final videos = feedState.videos;

    Log.info(
      '✅ ForYouTab: Data state - ${videos.length} videos',
      name: 'ForYouTab',
      category: LogCategory.video,
    );

    // Track feed loaded with videos
    if (_feedLoadStartTime != null) {
      _feedTracker?.markFirstVideosReceived('for_you', videos.length);
      _feedTracker?.markFeedDisplayed('for_you', videos.length);
      _feedLoadStartTime = null;
    }

    if (videos.isEmpty) {
      _feedTracker?.trackEmptyFeed('for_you');
    }

    return _ForYouContent(
      videos: videos,
      isLoadingMore: feedState.isLoadingMore,
      hasMoreContent: feedState.hasMoreContent,
    );
  }

  Future<void> _refreshForYou() async {
    ref.read(funnelcakeAvailableProvider.notifier).refresh();
    await ref.read(funnelcakeAvailableProvider.future);
    await ref.read(forYouFeedProvider.notifier).refresh();
  }
}

/// Content widget displaying personalized video recommendations grid.
///
/// Header pushes up as user scrolls down (1:1 with scroll distance).
/// When scrolling up, header slides back in as an overlay with animation.
class _ForYouContent extends ConsumerStatefulWidget {
  const _ForYouContent({
    required this.videos,
    required this.isLoadingMore,
    required this.hasMoreContent,
  });

  final List<VideoEvent> videos;
  final bool isLoadingMore;
  final bool hasMoreContent;

  @override
  ConsumerState<_ForYouContent> createState() => _ForYouContentState();
}

class _ForYouContentState extends ConsumerState<_ForYouContent>
    with ScrollToHideMixin {
  void _showAlgorithmExplainer(BuildContext context) {
    VineBottomSheet.show(
      context: context,
      // Long-form content: keep the pre-design-system sizing so the explainer
      // still opens nearly full-height instead of the 0.6 default.
      initialChildSize: 0.85,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      maxChildSize: 0.95,
      buildScrollBody: (scrollController) =>
          _AlgorithmExplainerSheet(scrollController: scrollController),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forYouFeedNotifier = ref.read(forYouFeedProvider.notifier);

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
                  '🎯 ForYouTab TAP: gridIndex=$index, '
                  'videoId=${videoList[index].id}',
                  category: LogCategory.video,
                );
                context.push(
                  PooledFullscreenVideoFeedScreen.pathForVideoId(
                    videoList[index].id,
                  ),
                  extra: PooledFullscreenVideoFeedArgs(
                    source: const ForYouViewSource(),
                    feedRepository: ref.read(feedRepositoryProvider),
                    initialIndex: index,
                    initialVideoId: videoList[index].id,
                    contextTitle: context.l10n.feedModeForYou,
                    trafficSource: ViewTrafficSource.discoveryForYou,
                  ),
                );
              },
              onRefresh: () async {
                Log.info(
                  '🔄 ForYouTab: Refreshing recommendations',
                  name: 'ForYouTab',
                  category: LogCategory.video,
                );
                await forYouFeedNotifier.refresh();
              },
              onLoadMore: () async {
                Log.info(
                  '📜 ForYouTab: Loading more recommendations',
                  name: 'ForYouTab',
                  category: LogCategory.video,
                );
                await forYouFeedNotifier.loadMore();
              },
              isLoadingMore: widget.isLoadingMore,
              hasMoreContent: widget.hasMoreContent,
              emptyBuilder: () => const _ForYouEmptyState(),
            ),
          ),
        ),
        // Header overlay on top, animated when returning
        AnimatedPositioned(
          duration: headerFullyHidden
              ? const Duration(milliseconds: 250)
              : Duration.zero,
          curve: Curves.easeOut,
          top: headerOffset,
          left: 0,
          right: 0,
          child: Semantics(
            button: true,
            // The visible title is the button's name; the hint says what
            // activating it does.
            hint: context.l10n.forYouAlgorithmHowItWorksTitle,
            child: GestureDetector(
              key: headerKey,
              onTap: () => _showAlgorithmExplainer(context),
              child: ColoredBox(
                color: context.vineColors.background,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      DivineIcon(
                        icon: DivineIconName.sparkle,
                        color: context.vineColors.accentPositive,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.l10n.forYouAlgorithmTitle,
                          style: VineTheme.labelLargeFont(
                            color: context.vineColors.accentPositive,
                          ),
                        ),
                      ),
                      // The row and the button open the same sheet, so the row
                      // owns the semantics — otherwise a screen reader
                      // announces one action twice.
                      ExcludeSemantics(
                        child: DivineIconButton(
                          icon: DivineIconName.info,
                          size: DivineIconButtonSize.small,
                          backgroundColor: VineTheme.transparent,
                          foregroundColor: context.vineColors.secondaryText,
                          showShadow: false,
                          tooltip: context.l10n.forYouAlgorithmHowItWorksTitle,
                          onPressed: () => _showAlgorithmExplainer(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet explaining how the Divine Algorithm works
class _AlgorithmExplainerSheet extends StatelessWidget {
  const _AlgorithmExplainerSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      controller: scrollController,
      children: [
        // Title
        Row(
          spacing: 12,
          children: [
            DivineIcon(
              icon: DivineIconName.sparkle,
              color: context.vineColors.accentPositive,
              size: 28,
            ),
            Expanded(
              child: Text(
                context.l10n.forYouAlgorithmTitle,
                style: VineTheme.titleLargeFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.forYouAlgorithmSubtitle,
          style: VineTheme.bodySmallFont(
            color: context.vineColors.accentPositive,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 24),

        // Section: How it works
        _SectionTitle(context.l10n.forYouAlgorithmHowItWorksTitle),
        const SizedBox(height: 12),
        Text(
          context.l10n.forYouAlgorithmHowItWorksBody,
          style: _bodyTextStyleOf(context),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.forYouAlgorithmInteractionsIntro,
          style: _bodyTextStyleOf(context),
        ),
        const SizedBox(height: 12),

        // Interaction weights
        _InteractionItem(
          icon: DivineIconName.repeat,
          title: context.l10n.metadataRepostsLabel,
          description: context.l10n.forYouAlgorithmRepostsDescription,
        ),
        _InteractionItem(
          icon: DivineIconName.chat,
          title: context.l10n.profileCommentsSection,
          description: context.l10n.forYouAlgorithmCommentsDescription,
        ),
        _InteractionItem(
          icon: DivineIconName.heart,
          title: context.l10n.forYouAlgorithmReactionsTitle,
          description: context.l10n.forYouAlgorithmReactionsDescription,
        ),
        _InteractionItem(
          icon: DivineIconName.playCircle,
          title: context.l10n.analyticsViews,
          description: context.l10n.forYouAlgorithmViewsDescription,
        ),
        const SizedBox(height: 24),

        // Section: Cold start
        _SectionTitle(context.l10n.forYouAlgorithmNewToDivineTitle),
        const SizedBox(height: 12),
        Text(
          context.l10n.forYouAlgorithmNewToDivineBody1,
          style: _bodyTextStyleOf(context),
        ),
        const SizedBox(height: 12),
        Text(
          context.l10n.forYouAlgorithmNewToDivineBody2,
          style: _bodyTextStyleOf(context),
        ),
        const SizedBox(height: 24),

        // Section: Future vision
        _SectionTitle(context.l10n.forYouAlgorithmChoiceTitle),
        const SizedBox(height: 12),
        Text(
          context.l10n.forYouAlgorithmChoiceBody,
          style: _bodyTextStyleOf(context),
        ),
        const SizedBox(height: 12),
        _FutureFeatureItem(context.l10n.forYouAlgorithmChoicePersonalizedFeed),
        _FutureFeatureItem(context.l10n.forYouAlgorithmChoiceChronological),
        _FutureFeatureItem(context.l10n.forYouAlgorithmChoiceTrending),
        _FutureFeatureItem(context.l10n.forYouAlgorithmChoiceCustomFeeds),
        const SizedBox(height: 16),
        Text(
          context.l10n.forYouAlgorithmChoiceClosing,
          style: _bodyTextStyleOf(context),
        ),
        const SizedBox(height: 24),

        DivineInfoCard(
          icon: DivineIconName.bracketsAngle,
          compact: true,
          title: context.l10n.forYouAlgorithmOpenSourceTitle,
          message: context.l10n.forYouAlgorithmOpenSourceBody,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

TextStyle _bodyTextStyleOf(BuildContext context) =>
    VineTheme.bodyMediumFont(color: context.vineColors.primaryText);

/// Heading for one section of the algorithm explainer.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
    );
  }
}

/// One interaction weight row: badge icon, label and description.
class _InteractionItem extends StatelessWidget {
  const _InteractionItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final DivineIconName icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.vineColors.card,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DivineIcon(
              icon: icon,
              color: context.vineColors.accentPositive,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: VineTheme.labelLargeFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One bullet in the "what's coming" list.
class _FutureFeatureItem extends StatelessWidget {
  const _FutureFeatureItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          DivineIcon(
            icon: DivineIconName.checkCircle,
            color: context.vineColors.accentPositive,
            size: 18,
          ),
          Expanded(child: Text(text, style: _bodyTextStyleOf(context))),
        ],
      ),
    );
  }
}

/// Unavailable state when recommendations are not available
class _ForYouUnavailableState extends StatelessWidget {
  const _ForYouUnavailableState();

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
              context.l10n.forYouUnavailableTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.forYouUnavailableDescription,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state widget for ForYouTab
class _ForYouEmptyState extends StatelessWidget {
  const _ForYouEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DivineIcon(
            icon: DivineIconName.sparkle,
            size: 64,
            color: context.vineColors.secondaryText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.forYouEmptyTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.forYouEmptyDescription,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error state widget for ForYouTab
class _ForYouErrorState extends StatelessWidget {
  const _ForYouErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: VineTheme.likeRed),
          const SizedBox(height: 16),
          Text(
            context.l10n.forYouErrorTitle,
            style: VineTheme.titleMediumFont(color: VineTheme.likeRed),
          ),
        ],
      ),
    );
  }
}

/// Loading state widget for ForYouTab
class _ForYouLoadingState extends StatelessWidget {
  const _ForYouLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}
