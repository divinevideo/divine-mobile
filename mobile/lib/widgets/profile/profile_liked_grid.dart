// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unified_logger/unified_logger.dart';

/// Grid widget displaying user's liked videos
///
/// Requires [ProfileLikedVideosBloc] to be provided in the widget tree.
class ProfileLikedGrid extends StatefulWidget {
  const ProfileLikedGrid({
    required this.isOwnProfile,
    required this.userIdHex,
    super.key,
  });

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// The hex public key of the profile being viewed.
  final String userIdHex;

  @override
  State<ProfileLikedGrid> createState() => _ProfileLikedGridState();
}

class _ProfileLikedGridState extends State<ProfileLikedGrid>
    with ScrollPaginationMixin {
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileLikedVideosBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileLikedVideosBloc>().add(
      const ProfileLikedVideosLoadMoreRequested(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (_primaryScrollController != primary) {
      if (_primaryScrollController != null) disposePagination();
      _primaryScrollController = primary;
      initPagination();
    }
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      builder: (context, state) {
        final likedVideos = state.videos;

        // Cold open with no cached content yet (initial / syncing / loading):
        // full-screen spinner. `success` (→ empty state) and `failure`
        // (→ error screen) are the only settled empty states.
        if (likedVideos.isEmpty &&
            state.status != ProfileLikedVideosStatus.success &&
            state.status != ProfileLikedVideosStatus.failure) {
          return const ProfileTabLoadingState();
        }

        // Only surface the failure screen when there is nothing cached to
        // show; a failed background refresh keeps the cached grid on screen.
        //
        // Unlike Saved and Reposts, this tab deliberately does NOT treat
        // "liked IDs but no videos" as a failure. `_onBlocklistChanged` emits
        // videos without touching `likedEventIds`, so blocking the author of
        // every liked video reaches that shape with nothing having failed —
        // see #7627.
        if (state.status == ProfileLikedVideosStatus.failure &&
            likedVideos.isEmpty) {
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingLiked,
          );
        }

        if (likedVideos.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoLikedVideosTitle,
            subtitle: widget.isOwnProfile
                ? context.l10n.profileLikedOwnEmpty
                : context.l10n.profileLikedOtherEmpty,
          );
        }

        // The revalidation bar lives in the pinned tab bar header (see
        // _SliverAppBarDelegate in profile_grid.dart) so it stays sticky
        // directly under the tabs while scrolling — a body overlay would be
        // painted behind the pinned header.
        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= likedVideos.length) {
                  return const SizedBox.shrink();
                }

                final videoEvent = likedVideos[index];
                return _LikedGridTile(
                  videoEvent: videoEvent,
                  index: index,
                  allVideos: likedVideos,
                  userIdHex: widget.userIdHex,
                );
              }, childCount: likedVideos.length),
            ),
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
}

/// Individual liked video tile in the grid with heart badge
class _LikedGridTile extends ConsumerWidget {
  const _LikedGridTile({
    required this.videoEvent,
    required this.index,
    required this.allVideos,
    required this.userIdHex,
  });

  final VideoEvent videoEvent;
  final int index;
  final List<VideoEvent> allVideos;
  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    identifier: SemanticIds.likedVideoThumbnail(index),
    label: context.l10n.profileVideoThumbnailLabel(index + 1),
    button: true,
    child: GestureDetector(
      onTap: () {
        Log.info(
          '🎯 ProfileLikedGrid TAP: gridIndex=$index, '
          'videoId=${videoEvent.id}',
          category: LogCategory.video,
        );
        final bloc = context.read<ProfileLikedVideosBloc>();
        context.push(
          PooledFullscreenVideoFeedScreen.pathForVideoId(videoEvent.id),
          extra: PooledFullscreenVideoFeedArgs(
            source: LikedViewSource(userIdHex),
            feedRepository: StreamFeedRepository(
              videos: bloc.stream
                  .map((state) => state.videos)
                  .startWith(allVideos),
              hasMore: bloc.stream
                  .map((state) => state.hasMoreContent)
                  .startWith(bloc.state.hasMoreContent),
              onLoadMore: () async =>
                  bloc.add(const ProfileLikedVideosLoadMoreRequested()),
            ),
            initialIndex: index,
            initialVideoId: videoEvent.id,
            trafficSource: ViewTrafficSource.profile,
          ),
        );
        Log.info(
          '✅ ProfileLikedGrid: Called pushVideoFeed with '
          'LikedVideosFeedSource at index $index',
          category: LogCategory.video,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: context.vineColors.card),
          child: ProfileTabThumbnail(
            thumbnailUrl: videoEvent.thumbnailUrl,
            blurhash: videoEvent.blurhash,
          ),
        ),
      ),
    ),
  );
}
