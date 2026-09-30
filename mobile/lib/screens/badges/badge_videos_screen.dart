// ABOUTME: Paginated videos by every currently accepted holder of one badge.

import 'dart:async';

import 'package:badge_repository/badge_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/badges/badge_videos_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/feed_repository_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:unified_logger/unified_logger.dart';

/// Browse public videos by the accepted holders of [coordinate].
class BadgeVideosScreen extends ConsumerWidget {
  /// Creates the badge video browser.
  const BadgeVideosScreen({required this.coordinate, super.key});

  /// Route name.
  static const routeName = 'badgeVideos';

  /// Route path.
  static const path = '/badges/b/:naddr/videos';

  /// Path for [coordinate].
  static String pathFor(BadgeCoordinate coordinate) =>
      '/badges/b/${coordinate.toNaddr()}/videos';

  /// Badge whose holders supply the videos.
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgeRepository = ref.watch(badgeRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    return BlocProvider(
      key: ValueKey((badgeRepository, videosRepository)),
      create: (_) {
        final cubit = BadgeVideosCubit(
          badgeRepository: badgeRepository,
          videosRepository: videosRepository,
          coordinate: coordinate,
        );
        runDetached(
          cubit.load(),
          'load badge videos',
          logName: 'BadgeVideosScreen',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: BadgeVideosView(coordinate: coordinate),
    );
  }
}

/// The badge video grid, driven by [BadgeVideosCubit].
class BadgeVideosView extends ConsumerWidget {
  /// Creates the view.
  @visibleForTesting
  const BadgeVideosView({required this.coordinate, super.key});

  /// Badge whose holders supply the videos.
  final BadgeCoordinate coordinate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = context.watch<BadgeVideosCubit>().state;
    final cubit = context.read<BadgeVideosCubit>();
    return BlocListener<BadgeVideosCubit, BadgeVideosState>(
      listenWhen: (previous, current) =>
          previous.loadMoreFailures != current.loadMoreFailures,
      listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.feedFailedToLoadVideos,
          error: true,
        ),
      ),
      child: Scaffold(
        appBar: DiVineAppBar(title: context.l10n.profileVideosLabel),
        backgroundColor: context.vineColors.background,
        body: switch (state.status) {
          BadgeVideosStatus.initial || BadgeVideosStatus.loading =>
            const Center(child: BrandedLoadingIndicator(size: 60)),
          BadgeVideosStatus.failure => Center(
            child: DivineButton(
              onPressed: cubit.load,
              label: context.l10n.feedFailedToLoadVideos,
            ),
          ),
          BadgeVideosStatus.loaded => ComposableVideoGrid(
            videos: state.videos,
            useMasonryLayout: true,
            isLoadingMore: state.isLoadingMore,
            hasMoreContent: state.hasMore,
            onLoadMore: cubit.loadMore,
            onRefresh: cubit.load,
            emptyBuilder: () => Center(
              child: Text(context.l10n.exploreNoVideosAvailable),
            ),
            onVideoTap: (videos, index) => unawaited(
              context.push(
                PooledFullscreenVideoFeedScreen.pathForVideoId(
                  videos[index].id,
                ),
                extra: PooledFullscreenVideoFeedArgs(
                  source: VideoListViewSource(videos),
                  feedRepository: ref.read(feedRepositoryProvider),
                  initialIndex: index,
                  initialVideoId: videos[index].id,
                  trafficSource: ViewTrafficSource.discoveryBadges,
                  sourceDetail: coordinate.value,
                ),
              ),
            ),
          ),
        },
      ),
    );
  }
}
