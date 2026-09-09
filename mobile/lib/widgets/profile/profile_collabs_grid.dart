// ABOUTME: Grid widget displaying user's collab videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails for confirmed collaborator videos

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
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

/// Grid widget displaying user's collab videos.
///
/// Requires [ProfileCollabVideosBloc] to be provided in the widget tree.
class ProfileCollabsGrid extends ConsumerStatefulWidget {
  const ProfileCollabsGrid({
    required this.isOwnProfile,
    required this.userIdHex,
    super.key,
  });

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  /// The hex public key of the profile being viewed.
  final String userIdHex;

  @override
  ConsumerState<ProfileCollabsGrid> createState() => _ProfileCollabsGridState();
}

class _ProfileCollabsGridState extends ConsumerState<ProfileCollabsGrid>
    with GridPrefetchMixin, ScrollPaginationMixin {
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;
  List<VideoEvent>? _lastPrefetchedVideos;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileCollabVideosBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileCollabVideosBloc>().add(
      const ProfileCollabVideosLoadMoreRequested(),
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

  void _prefetchIfNeeded(List<VideoEvent> videos) {
    if (videos.isEmpty || videos == _lastPrefetchedVideos) return;
    _lastPrefetchedVideos = videos;
    prefetchGridVideos(videos);
  }

  void _onVideoTapped(int index, List<VideoEvent> allVideos) {
    Log.info(
      'ProfileCollabsGrid TAP: gridIndex=$index, '
      'videoId=${allVideos[index].id}',
      category: LogCategory.video,
    );

    // Pre-warm adjacent videos before navigation
    prefetchAroundIndex(index, allVideos);

    final bloc = context.read<ProfileCollabVideosBloc>();
    context.push(
      PooledFullscreenVideoFeedScreen.pathForVideoId(allVideos[index].id),
      extra: PooledFullscreenVideoFeedArgs(
        source: CollabsViewSource(widget.userIdHex),
        feedRepository: StreamFeedRepository(
          videos: bloc.stream.map((state) => state.videos).startWith(allVideos),
          hasMore: bloc.stream
              .map((state) => state.hasMoreContent)
              .startWith(bloc.state.hasMoreContent),
          onLoadMore: () async =>
              bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        ),
        initialIndex: index,
        initialVideoId: allVideos[index].id,
        trafficSource: ViewTrafficSource.profile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCollabVideosBloc, ProfileCollabVideosState>(
      builder: (context, state) {
        if (state.status == ProfileCollabVideosStatus.initial ||
            state.status == ProfileCollabVideosStatus.loading) {
          return const ProfileTabLoadingState();
        }

        if (state.status == ProfileCollabVideosStatus.failure) {
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingCollabs,
          );
        }

        final collabVideos = state.videos;

        if (collabVideos.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoCollabsTitle,
            subtitle: widget.isOwnProfile
                ? context.l10n.profileCollabsOwnEmpty
                : context.l10n.profileCollabsOtherEmpty,
          );
        }

        // Prefetch visible grid videos
        _prefetchIfNeeded(collabVideos);

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index >= collabVideos.length) {
                    return const SizedBox.shrink();
                  }

                  final videoEvent = collabVideos[index];
                  return _CollabGridTile(
                    videoEvent: videoEvent,
                    index: index,
                    onTap: () => _onVideoTapped(index, collabVideos),
                  );
                }, childCount: collabVideos.length),
              ),
            ),
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
}

/// Individual collab tile in the grid.
class _CollabGridTile extends StatelessWidget {
  const _CollabGridTile({
    required this.videoEvent,
    required this.index,
    required this.onTap,
  });

  final VideoEvent videoEvent;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    // The tile renders only a thumbnail, so without this it is a focusable,
    // tappable node with an empty accessible name (#6951).
    label: context.l10n.profileVideoThumbnailLabel(index + 1),
    button: true,
    child: GestureDetector(
      onTap: onTap,
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
