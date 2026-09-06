// ABOUTME: Router-aware liked videos screen that shows grid or feed based on URL
// ABOUTME: Reads route context to determine grid mode vs feed mode

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/profile/profile_liked_grid.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Router-aware liked videos screen that shows grid or feed based on route
class LikedVideosScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'liked-videos';

  /// Path for this route.
  static const String path = RoutePaths.likedVideos;

  /// Path for this route with index.
  static const pathWithIndex = '/liked-videos/:index';

  /// Build path for grid mode or specific index.
  static String pathForIndex(int? index) =>
      RoutePaths.likedVideosForIndex(index);

  const LikedVideosScreenRouter({super.key});

  @override
  ConsumerState<LikedVideosScreenRouter> createState() =>
      _LikedVideosScreenRouterState();
}

class _LikedVideosScreenRouterState
    extends ConsumerState<LikedVideosScreenRouter> {
  @override
  Widget build(BuildContext context) {
    final routeCtx = ref.watch(pageContextProvider).asData?.value;

    if (routeCtx == null || routeCtx.type != RouteType.likedVideos) {
      Log.warning(
        'LikedVideosScreenRouter: Invalid route context',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return Scaffold(
        backgroundColor: context.vineColors.background,
        body: Center(
          child: Text(
            context.l10n.likedVideosInvalidRoute,
            style: TextStyle(color: context.vineColors.primaryText),
          ),
        ),
      );
    }

    // Get services for ProfileLikedVideosBloc
    final likesRepository = ref.watch(likesRepositoryProvider);
    final videosRepository = ref.watch(videosRepositoryProvider);
    final contentBlocklistRepository = ref.watch(
      contentBlocklistRepositoryProvider,
    );
    final nostrService = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrService.publicKey;
    final videoIndex = routeCtx.videoIndex;

    // Grid mode: no video index
    if (videoIndex == null) {
      Log.info(
        'LikedVideosScreenRouter: Showing grid',
        name: 'LikedVideosRouter',
        category: LogCategory.ui,
      );
      return Scaffold(
        backgroundColor: context.vineColors.background,
        appBar: DiVineAppBar(
          title: context.l10n.likedVideosTitle,
          showBackButton: true,
          backgroundColor: context.vineColors.background,
          onBackPressed: () {
            // Navigate to own profile grid
            final authService = ref.read(authServiceProvider);
            final currentUserHex = authService.currentPublicKeyHex;
            if (currentUserHex != null) {
              final npub = NostrKeyUtils.encodePubKey(currentUserHex);
              context.go(ProfileScreenRouter.pathForNpub(npub));
            }
          },
        ),
        body: BlocProvider<ProfileLikedVideosBloc>(
          create: (_) => ProfileLikedVideosBloc(
            likesRepository: likesRepository,
            videosRepository: videosRepository,
            contentBlocklistRepository: contentBlocklistRepository,
            currentUserPubkey: currentUserPubkey,
            removedVideoIds: videosRepository.removedVideoIds,
            deletedVideoFilter: videosRepository.isVideoKnownDeleted,
          )..add(const ProfileLikedVideosSyncRequested()),
          child: ProfileLikedGrid(
            isOwnProfile: true,
            userIdHex: currentUserPubkey,
          ),
        ),
      );
    }

    // Feed mode: show video at specific index
    Log.info(
      'LikedVideosScreenRouter: Showing feed (index=$videoIndex)',
      name: 'LikedVideosRouter',
      category: LogCategory.ui,
    );

    return BlocProvider<ProfileLikedVideosBloc>(
      create: (_) => ProfileLikedVideosBloc(
        likesRepository: likesRepository,
        videosRepository: videosRepository,
        contentBlocklistRepository: contentBlocklistRepository,
        currentUserPubkey: currentUserPubkey,
        removedVideoIds: videosRepository.removedVideoIds,
        deletedVideoFilter: videosRepository.isVideoKnownDeleted,
      )..add(const ProfileLikedVideosSyncRequested()),
      child: _LikedVideosFeedView(
        videoIndex: videoIndex,
        userIdHex: currentUserPubkey,
      ),
    );
  }
}

/// Feed view that resolves the liked feed through a [FeedRepository].
class _LikedVideosFeedView extends ConsumerStatefulWidget {
  const _LikedVideosFeedView({
    required this.videoIndex,
    required this.userIdHex,
  });

  final int videoIndex;
  final String userIdHex;

  @override
  ConsumerState<_LikedVideosFeedView> createState() =>
      _LikedVideosFeedViewState();
}

class _LikedVideosFeedViewState extends ConsumerState<_LikedVideosFeedView> {
  late final ProfileLikedVideosBloc _bloc;
  late final FeedRepository _feedRepository;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<ProfileLikedVideosBloc>();
    _feedRepository = StreamFeedRepository(
      videos: _bloc.stream
          .map((state) => state.videos)
          .startWith(_bloc.state.videos),
      hasMore: _bloc.stream
          .map((state) => state.hasMoreContent)
          .startWith(_bloc.state.hasMoreContent),
      onLoadMore: () async =>
          _bloc.add(const ProfileLikedVideosLoadMoreRequested()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading) {
          return Scaffold(
            backgroundColor: context.vineColors.background,
            body: const Center(
              child: DivineCircularProgressIndicator(
                color: VineTheme.vineGreen,
              ),
            ),
          );
        }

        if (state.status == ProfileLikedVideosStatus.failure) {
          return Scaffold(
            backgroundColor: context.vineColors.background,
            body: Center(
              child: Text(
                context.l10n.profileErrorLoadingLiked,
                style: TextStyle(color: context.vineColors.primaryText),
              ),
            ),
          );
        }

        final videos = state.videos;

        if (videos.isEmpty) {
          return Scaffold(
            backgroundColor: context.vineColors.background,
            body: Center(
              child: Text(
                context.l10n.likedVideosEmpty,
                style: TextStyle(color: context.vineColors.primaryText),
              ),
            ),
          );
        }

        ref
            .read(screenAnalyticsServiceProvider)
            .markDataLoaded(
              'liked_videos',
              dataMetrics: {'video_count': videos.length},
            );

        final safeIndex = widget.videoIndex.clamp(0, videos.length - 1);

        return PooledFullscreenVideoFeedScreen(
          source: LikedViewSource(widget.userIdHex),
          feedRepository: _feedRepository,
          initialIndex: safeIndex,
          contextTitle: context.l10n.likedVideosTitle,
          trafficSource: ViewTrafficSource.profile,
        );
      },
    );
  }
}
