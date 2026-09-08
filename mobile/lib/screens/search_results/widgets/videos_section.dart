import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/search_section_empty_state.dart';
import 'package:openvine/screens/search_results/widgets/search_section_error_state.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:rxdart/rxdart.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Always-visible Videos section with a "Videos" header and optional
/// "See all" chevron.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class VideosSection extends StatelessWidget {
  const VideosSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results and hides the section header.
  final bool showAll;

  /// Called when the user taps the "Videos" header chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final status = context.select((VideoSearchBloc bloc) => bloc.state.status);
    final videos = context.select((VideoSearchBloc bloc) => bloc.state.videos);

    // In the All tab, hide entire section when results are empty and loaded.
    if (!showAll && status == VideoSearchStatus.success && videos.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(
              title: context.l10n.searchVideosSectionHeader,
              onTap: onSeeAll,
              semanticIdentifier: SemanticIds.searchSectionHeader('videos'),
            ),
          ),
        _VideosContent(showAll: showAll),
        if (showAll) const _VideosPaginationTrigger(),
      ],
    );
  }
}

class _VideosPaginationTrigger extends StatelessWidget {
  const _VideosPaginationTrigger();

  @override
  Widget build(BuildContext context) {
    final hasMore = context.select((VideoSearchBloc b) => b.state.hasMore);
    final isLoadingMore = context.select(
      (VideoSearchBloc b) => b.state.isLoadingMore,
    );
    return SliverPaginationTrigger(
      onLoadMore: () =>
          context.read<VideoSearchBloc>().add(const VideoSearchLoadMore()),
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }
}

class _VideosContent extends ConsumerStatefulWidget {
  const _VideosContent({this.showAll = false});

  final bool showAll;

  @override
  ConsumerState<_VideosContent> createState() => _VideosContentState();
}

class _VideosContentState extends ConsumerState<_VideosContent> {
  void _onVideoTap(List<VideoEvent> videos, int index) {
    final bloc = context.read<VideoSearchBloc>();
    context.push(
      PooledFullscreenVideoFeedScreen.pathForVideoId(videos[index].id),
      extra: PooledFullscreenVideoFeedArgs(
        source: SearchViewSource(bloc.state.query),
        feedRepository: StreamFeedRepository(
          videos: bloc.stream.map((state) => state.videos).startWith(videos),
          hasMore: bloc.stream
              .map((state) => state.hasMore)
              .startWith(bloc.state.hasMore),
          onLoadMore: () async => bloc.add(const VideoSearchLoadMore()),
        ),
        initialIndex: index,
        initialVideoId: videos[index].id,
        contextTitle: 'Search Results',
        trafficSource: ViewTrafficSource.search,
        sourceDetail: bloc.state.query,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _VideosGrid(showAll: widget.showAll, onVideoTap: _onVideoTap);
  }
}

class _VideosGrid extends StatelessWidget {
  const _VideosGrid({required this.showAll, required this.onVideoTap});

  final bool showAll;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context) {
    final status = context.select((VideoSearchBloc bloc) => bloc.state.status);
    final videos = context.select((VideoSearchBloc bloc) => bloc.state.videos);
    final query = context.select((VideoSearchBloc bloc) => bloc.state.query);

    if ((status == VideoSearchStatus.initial ||
            status == VideoSearchStatus.searching) &&
        videos.isEmpty) {
      return const _VideosSkeletonLoader();
    }

    if (status == VideoSearchStatus.failure) {
      return SearchSectionErrorState(
        onRetry: () =>
            context.read<VideoSearchBloc>().add(VideoSearchQueryChanged(query)),
      );
    }

    if (videos.isEmpty) {
      if (showAll) return SearchSectionEmptyState(query: query);
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.all(4),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childCount: videos.length,
        itemBuilder: (context, index) {
          return SearchVideoTile(
            video: videos[index],
            index: index,
            onTap: () => onVideoTap(videos, index),
          );
        },
      ),
    );
  }
}

/// A video thumbnail tile for search results with author name overlay.
///
/// Used by [VideosSection] to render each result in the videos grid.
class SearchVideoTile extends StatelessWidget {
  const SearchVideoTile({
    required this.video,
    required this.index,
    required this.onTap,
    super.key,
  });

  final VideoEvent video;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: SemanticIds.searchVideoTileAt(index),
      button: true,
      child: GestureDetector(
        onTap: onTap,
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
                    embeddedName: video.authorName,
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

class _VideosSkeletonLoader extends StatelessWidget {
  const _VideosSkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Semantics(
        identifier: 'videos_loading_indicator',
        label: context.l10n.searchVideosLoadingLabel,
        child: Skeletonizer(
          effect: vineSkeletonEffectOf(context),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            padding: const EdgeInsets.all(4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: List.generate(
              4,
              (_) => Skeleton.leaf(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.vineColors.skeleton,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
