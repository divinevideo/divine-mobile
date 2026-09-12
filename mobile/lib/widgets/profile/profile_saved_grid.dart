// ABOUTME: Grid widget displaying user's saved (bookmarked) videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails. Own profile only — bookmarks are private.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
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

/// Grid widget displaying the current user's saved (bookmarked) videos.
///
/// Requires [ProfileSavedVideosBloc] to be provided in the widget tree.
/// Only ever shows the viewer's own bookmarks — they are private, so there
/// is no "other user's saved" variant. Hosted by `SavedVideosScreen`, which
/// the profile's Lists tab links to.
class ProfileSavedGrid extends StatefulWidget {
  const ProfileSavedGrid({required this.userIdHex, super.key});

  /// The hex public key of the profile being viewed (always the viewer's own).
  final String userIdHex;

  @override
  State<ProfileSavedGrid> createState() => _ProfileSavedGridState();
}

class _ProfileSavedGridState extends State<ProfileSavedGrid>
    with ScrollPaginationMixin {
  /// Resolved from the enclosing [PrimaryScrollController], which the host
  /// screen supplies.
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileSavedVideosBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileSavedVideosBloc>().add(
      const ProfileSavedVideosLoadMoreRequested(),
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
    return BlocBuilder<ProfileSavedVideosBloc, ProfileSavedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileSavedVideosStatus.initial ||
            state.status == ProfileSavedVideosStatus.syncing ||
            state.status == ProfileSavedVideosStatus.loading) {
          return const ProfileTabLoadingState();
        }

        // The settled states opt into overscroll for the host's
        // RefreshIndicator: with the tab's default clamping physics a pull
        // would stop working exactly when it is most wanted — after
        // unbookmarking the last video, or when a sync failed.
        //
        // A settled-empty tab is two different outcomes, and the state carries
        // both. Bookmarks that failed to resolve are a load failure, not an
        // empty list: telling that viewer to go bookmark something is telling
        // them to do what they already did.
        if (state.status == ProfileSavedVideosStatus.failure ||
            state.hasUnresolvedSaves) {
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingSaved,
            physics: const AlwaysScrollableScrollPhysics(),
          );
        }

        final savedVideos = state.videos;

        if (savedVideos.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoSavedVideosTitle,
            subtitle: context.l10n.profileSavedOwnEmpty,
            physics: const AlwaysScrollableScrollPhysics(),
          );
        }

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= savedVideos.length) {
                  return const SizedBox.shrink();
                }

                final videoEvent = savedVideos[index];
                return _SavedGridTile(
                  videoEvent: videoEvent,
                  index: index,
                  allVideos: savedVideos,
                  userIdHex: widget.userIdHex,
                );
              }, childCount: savedVideos.length),
            ),
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
}

/// Individual saved video tile in the grid.
class _SavedGridTile extends ConsumerWidget {
  const _SavedGridTile({
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
    identifier: SemanticIds.savedVideoThumbnail(index),
    label: context.l10n.profileVideoThumbnailLabel(index + 1),
    button: true,
    child: GestureDetector(
      onTap: () {
        Log.info(
          '🎯 ProfileSavedGrid TAP: gridIndex=$index, '
          'videoId=${videoEvent.id}',
          category: LogCategory.video,
        );
        final bloc = context.read<ProfileSavedVideosBloc>();
        context.push(
          PooledFullscreenVideoFeedScreen.pathForVideoId(videoEvent.id),
          extra: PooledFullscreenVideoFeedArgs(
            source: SavedViewSource(userIdHex),
            feedRepository: StreamFeedRepository(
              videos: bloc.stream
                  .map((state) => state.videos)
                  .startWith(allVideos),
              hasMore: bloc.stream
                  .map((state) => state.hasMoreContent)
                  .startWith(bloc.state.hasMoreContent),
              onLoadMore: () async =>
                  bloc.add(const ProfileSavedVideosLoadMoreRequested()),
            ),
            initialIndex: index,
            initialVideoId: videoEvent.id,
            trafficSource: ViewTrafficSource.profile,
          ),
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
