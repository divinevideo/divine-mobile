// ABOUTME: Composable video grid widget with automatic broken video filtering
// ABOUTME: Reusable component for Explore, Hashtag, and Search screens

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/creator_delete_enforcement_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/feed_refresh_control.dart';
import 'package:openvine/widgets/owner_video_actions_sheet.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Extra off-screen distance the grid keeps built, expressed as a multiple of
/// the viewport height applied on each side of the visible area.
///
/// The grid's default cache extent is only 250px, so thumbnails just off-screen
/// are disposed and have to reload (re-flicker through their blurhash) the
/// moment they scroll back in during fast scrolling. Keeping a couple of
/// screens built on either side avoids that churn while still bounding memory.
const double _gridCacheExtentScreens = 2;

/// Composable video grid that automatically filters broken videos
/// and provides consistent styling across Explore, Hashtag, and Search screens.
///
/// Supports infinite scroll pagination via [onLoadMore] callback.
class ComposableVideoGrid extends ConsumerStatefulWidget {
  const ComposableVideoGrid({
    required this.videos,
    required this.onVideoTap,
    super.key,
    this.crossAxisCount = 2,
    this.thumbnailAspectRatio = 1,
    this.useMasonryLayout = false,
    this.padding,
    this.emptyBuilder,
    this.onRefresh,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMoreContent = false,
    this.loadMoreThreshold = 5,
    this.headerSlivers = const [],
    this.selectedVideoIds,
    this.topOuterRadius,
    this.showSubscribedListBadge = true,
    this.backgroundColor,
  });

  final List<VideoEvent> videos;
  final Function(List<VideoEvent> videos, int index) onVideoTap;
  final int crossAxisCount;
  final double thumbnailAspectRatio;

  /// When true, each item determines its own aspect ratio from video
  /// dimensions. Square videos use 1:1, vertical videos use 2:3.
  final bool useMasonryLayout;
  final EdgeInsets? padding;
  final Widget Function()? emptyBuilder;
  final Future<void> Function()? onRefresh;

  /// Called when user scrolls near the bottom to load more content.
  final Future<void> Function()? onLoadMore;

  /// Whether more content is currently being loaded.
  final bool isLoadingMore;

  /// Whether there is more content available to load.
  final bool hasMoreContent;

  /// Number of items from the bottom to trigger load more.
  final int loadMoreThreshold;

  /// Slivers rendered above the grid inside its scroll view, so they scroll
  /// away with the content (e.g. a list detail hero header). Also rendered
  /// above the empty state so the header survives an empty list.
  final List<Widget> headerSlivers;

  /// When non-null the grid is in selection mode: every tile shows a
  /// selection circle (checked for ids in this set), taps still go through
  /// [onVideoTap] — the caller decides they toggle — and the own-video
  /// long-press menu is suppressed.
  final Set<String>? selectedVideoIds;

  /// Whether tiles show the corner badge marking a video that is in one of
  /// the viewer's subscribed lists. A list detail screen turns this off —
  /// there the badge is true for every tile and says nothing.
  final bool showSubscribedListBadge;

  /// Panel color painted behind the grid content — and behind the empty
  /// state — below any [headerSlivers], with its top corners rounded by
  /// [topOuterRadius]. The panel extends to the bottom of the viewport when
  /// the content is shorter. `null` keeps the surface transparent.
  final Color? backgroundColor;

  /// Rounds the grid block's outer top corners by clipping the first row's
  /// outermost tiles (first tile's top-left, last first-row tile's
  /// top-right), so the grid reads as one container rounding into the
  /// surface above it. `null` keeps every tile on the default small radius.
  final double? topOuterRadius;

  @override
  ConsumerState<ComposableVideoGrid> createState() =>
      _ComposableVideoGridState();
}

class _ComposableVideoGridState extends ConsumerState<ComposableVideoGrid>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();
  late final OwnerVideoActionsCubit _ownerVideoActionsCubit;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() =>
      widget.onLoadMore != null &&
      widget.hasMoreContent &&
      !widget.isLoadingMore;

  @override
  FutureOr<void> onLoadMore() => widget.onLoadMore?.call();

  @override
  void initState() {
    super.initState();
    _ownerVideoActionsCubit = OwnerVideoActionsCubit(
      contentDeletionService: () =>
          ref.read(contentDeletionServiceProvider.future),
      videoEventService: () => ref.read(videoEventServiceProvider),
      enforcementRepository: () =>
          ref.read(creatorDeleteEnforcementRepositoryProvider),
    );
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    _ownerVideoActionsCubit.close();
    super.dispose();
  }

  /// Pubkey of the signed-in viewer, or `null` when signed out.
  ///
  /// `NostrClient.publicKey` is a plain cache read that starts empty and is not
  /// re-refreshed on a miss (#6813), so it cannot be the only source: an owner
  /// would silently lose the edit/delete affordance whenever the cache is cold.
  /// [AuthService.currentPublicKeyHex] resolves from the identity, key
  /// container or profile and is populated far earlier, so it leads and the
  /// client cache is the fallback — matching `video_providers.dart` and
  /// `ProfileVideosGrid`.
  String? _resolveViewerPubkey() {
    // Identity gating for UI, so the auth state is the right rebuild trigger:
    // signing readiness (`nostrSessionProvider`) is a different question.
    ref.watch(currentAuthStateProvider);
    final authService = ref.read(authServiceProvider);
    // Sign-out queues the client replacement, so the outgoing client can still
    // hand back its cached key on a rebuild. Neither identity source is
    // trustworthy until the session itself says it is authenticated.
    //
    // Read as a bool rather than comparing against `AuthState.authenticated`:
    // naming the enum would mean importing `services/auth_service.dart` into
    // the UI layer, which `check_ui_service_boundary.sh` forbids.
    // `AuthService.isAuthenticated` is defined as exactly that comparison.
    if (!authService.isAuthenticated) return null;

    final fromAuthService = authService.currentPublicKeyHex;
    if (fromAuthService != null && fromAuthService.isNotEmpty) {
      return fromAuthService;
    }
    final cached = ref.read(nostrServiceProvider).publicKey;
    return cached.isEmpty ? null : cached;
  }

  @override
  Widget build(BuildContext context) {
    // Watch broken video tracker asynchronously
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);
    final viewerPubkey = _resolveViewerPubkey();

    return brokenTrackerAsync.when(
      loading: () => Center(
        child: DivineCircularProgressIndicator(
          color: context.vineColors.accentPositive,
        ),
      ),
      error: (error, stack) {
        // Fallback: show all videos if tracker fails
        return _buildGrid(context, widget.videos, viewerPubkey);
      },
      data: (tracker) {
        // Filter out broken videos
        final filteredVideos = widget.videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();

        return _buildGrid(context, filteredVideos, viewerPubkey);
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<VideoEvent> videosToShow,
    String? viewerPubkey,
  ) {
    if (videosToShow.isEmpty && widget.emptyBuilder != null) {
      return _buildEmptyState(context);
    }

    // Get subscribed list cache to check if videos are in lists
    final subscribedListCache = ref.watch(subscribedListVideoCacheProvider);

    // Responsive column count: 3 for tablets/desktop (width >= 600),
    // 2 for phones
    final screenSize = MediaQuery.sizeOf(context);
    final responsiveCrossAxisCount = screenSize.width >= 600
        ? 3
        : widget.crossAxisCount;
    final cacheExtent = screenSize.height * _gridCacheExtentScreens;

    // Whether to render the load-more footer below the grid.
    final showLoadingIndicator =
        widget.isLoadingMore ||
        (widget.hasMoreContent && widget.onLoadMore != null);

    // Masonry fills the shortest column start to end, so the first
    // [responsiveCrossAxisCount] items are the top row in column order.
    // Directional, not physical: under RTL the render object mirrors the
    // columns, so index 0 paints at the right — topStart follows it there,
    // while a physical topLeft would round mid-edge (#8453 review).
    BorderRadiusGeometry tileRadiusFor(int index) {
      const inner = Radius.circular(4);
      final outer = widget.topOuterRadius;
      if (outer == null || index >= responsiveCrossAxisCount) {
        return const BorderRadius.all(inner);
      }
      return BorderRadiusDirectional.only(
        topStart: index == 0 ? Radius.circular(outer) : inner,
        topEnd: index == responsiveCrossAxisCount - 1
            ? Radius.circular(outer)
            : inner,
        bottomStart: inner,
        bottomEnd: inner,
      );
    }

    Widget buildItem(BuildContext context, int index) {
      final video = videosToShow[index];
      final listIds = widget.showSubscribedListBadge
          ? subscribedListCache?.getListsForVideo(video.id)
          : null;
      final isInSubscribedList = listIds != null && listIds.isNotEmpty;

      final isOwnVideo = viewerPubkey != null && viewerPubkey == video.pubkey;

      final selectedIds = widget.selectedVideoIds;
      return _VideoItem(
        borderRadius: tileRadiusFor(index),
        video: video,
        aspectRatio: widget.thumbnailAspectRatio,
        onVideoTap: widget.onVideoTap,
        index: index,
        displayedVideos: videosToShow,
        // In selection mode a long-press menu would fight the toggle gesture.
        onLongPress: isOwnVideo && selectedIds == null
            ? () => _showVideoContextMenu(context, video)
            : null,
        isInSubscribedList: isInSubscribedList,
        isSelected: selectedIds?.contains(video.id),
      );
    }

    final gridPadding =
        widget.padding ??
        (widget.useMasonryLayout
            ? const EdgeInsets.all(4)
            : const EdgeInsets.all(12));

    final gridSliver = widget.useMasonryLayout
        ? SliverMasonryGrid.count(
            crossAxisCount: responsiveCrossAxisCount,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childCount: videosToShow.length,
            itemBuilder: buildItem,
          )
        : SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: responsiveCrossAxisCount,
              childAspectRatio: widget.thumbnailAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: videosToShow.length,
            itemBuilder: buildItem,
          );

    final scrollView = CustomScrollView(
      controller: _scrollController,
      scrollCacheExtent: ScrollCacheExtent.pixels(cacheExtent),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...widget.headerSlivers,
        if (widget.backgroundColor case final panelColor?) ...[
          DecoratedSliver(
            decoration: _panelDecoration(panelColor),
            sliver: SliverPadding(padding: gridPadding, sliver: gridSliver),
          ),
          if (showLoadingIndicator)
            SliverToBoxAdapter(
              child: ColoredBox(
                color: panelColor,
                child: _LoadingMoreIndicator(isLoading: widget.isLoadingMore),
              ),
            ),
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: ColoredBox(color: panelColor),
          ),
        ] else ...[
          SliverPadding(padding: gridPadding, sliver: gridSliver),
          if (showLoadingIndicator)
            SliverToBoxAdapter(
              child: _LoadingMoreIndicator(isLoading: widget.isLoadingMore),
            ),
        ],
      ],
    );

    return _wrapWithRefreshIndicator(context, scrollView);
  }

  BoxDecoration _panelDecoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: widget.topOuterRadius == null
        ? null
        : BorderRadius.vertical(
            top: Radius.circular(widget.topOuterRadius!),
          ),
  );

  Widget _buildEmptyState(BuildContext context) {
    final bareEmptyState = widget.emptyBuilder!();
    final panelColor = widget.backgroundColor;
    final emptyState = panelColor == null
        ? bareEmptyState
        : DecoratedBox(
            decoration: _panelDecoration(panelColor),
            child: bareEmptyState,
          );

    // Nothing to scroll for: no header above and no pull-to-refresh.
    if (widget.onRefresh == null && widget.headerSlivers.isEmpty) {
      return emptyState;
    }

    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...widget.headerSlivers,
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: panelColor != null,
          child: emptyState,
        ),
      ],
    );

    return _wrapWithRefreshIndicator(context, scrollView);
  }

  Widget _wrapWithRefreshIndicator(BuildContext context, Widget child) {
    if (widget.onRefresh == null) {
      return child;
    }

    return FeedRefreshControl(
      onRefresh: widget.onRefresh!,
      scrollController: _scrollController,
      child: child,
    );
  }

  /// Show the owner action sheet for a long-pressed video tile.
  ///
  /// Ownership is decided in [_buildGrid] so a non-owned tile never wires the
  /// gesture — and therefore never advertises the action to assistive tech.
  Future<void> _showVideoContextMenu(BuildContext context, VideoEvent video) =>
      showOwnerVideoActionsSheet(
        context: context,
        video: video,
        cubit: _ownerVideoActionsCubit,
        onEditRequested: () => context.push(
          VideoMetadataEditScreen.pathFor(video.id),
          extra: video,
        ),
      );
}

class _VideoItem extends StatelessWidget {
  const _VideoItem({
    required this.video,
    required this.aspectRatio,
    required this.onVideoTap,
    required this.index,
    required this.displayedVideos,
    this.onLongPress,
    this.isInSubscribedList = false,
    this.isSelected,
    this.borderRadius = const BorderRadius.all(Radius.circular(4)),
  });

  final VideoEvent video;
  final double aspectRatio;
  final Function(List<VideoEvent> videos, int index) onVideoTap;

  /// Opens the own-video actions sheet; `null` for videos the viewer does not
  /// own, so neither the gesture nor the semantics action is offered.
  final VoidCallback? onLongPress;
  final int index;
  final List<VideoEvent> displayedVideos;
  final bool isInSubscribedList;

  /// Selection-mode state: `null` outside selection mode, otherwise whether
  /// this tile is currently selected.
  final bool? isSelected;

  /// Clip radius for this tile; the grid enlarges the outer top corners of
  /// the first row when [ComposableVideoGrid.topOuterRadius] is set.
  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'video_thumbnail_$index',
      label: context.l10n.profileVideoThumbnailLabel(index + 1),
      button: true,
      selected: isSelected,
      onLongPress: onLongPress,
      onLongPressHint: onLongPress == null
          ? null
          : context.l10n.videoGridOptionsTitle,
      child: GestureDetector(
        onTap: () => onVideoTap(displayedVideos, index),
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            children: [
              _VideoThumbnail(video: video),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _VideoInfoSection(video: video, index: index),
              ),
              if (isInSubscribedList)
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: VineTheme.vineGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DivineIcon(
                      icon: DivineIconName.images,
                      size: 14,
                      color: context.vineColors.primaryText,
                    ),
                  ),
                ),
              if (isSelected case final isSelected?)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: _SelectionBadge(isSelected: isSelected),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selection-mode circle drawn on a tile: an outlined circle when
/// unselected, a filled check when selected.
///
/// Sits on a video frame, so its colors are fixed media chrome
/// ([VineTheme] constants), not adaptive tokens. The state is announced via
/// the tile's `Semantics(selected:)`, so the badge itself stays decorative.
class _SelectionBadge extends StatelessWidget {
  const _SelectionBadge({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? VineTheme.vineGreen : VineTheme.scrim15,
          border: isSelected
              ? null
              : Border.all(color: VineTheme.whiteText, width: 2),
        ),
        child: isSelected
            ? const Center(
                child: DivineIcon(
                  icon: DivineIconName.check,
                  size: 14,
                  color: VineTheme.whiteText,
                ),
              )
            : null,
      ),
    );
  }
}

class _VideoInfoSection extends StatelessWidget {
  const _VideoInfoSection({required this.video, required this.index});

  final VideoEvent video;
  final int index;

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        (video.displayTitle ?? video.displayContent).isNotEmpty;

    // Always show the info section with username (using bestDisplayName
    // fallback). UserName.fromPubKey handles fallback to truncated npub when
    // no profile name.
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VineTheme.transparent, VineTheme.scrim50],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Always show username - UserName.fromPubKey uses bestDisplayName
          // which falls back to truncated npub when no profile name is set
          Semantics(
            identifier: 'video_thumbnail_author_$index',
            container: true,
            explicitChildNodes: true,
            label: context.l10n.videoGridAuthorSemanticLabel(
              video.displayAuthorName ?? '',
            ),
            child: UserName.fromPubKey(
              video.pubkey,
              embeddedName: video.displayAuthorName,
              maxLines: 1,
              style: VineTheme.titleTinyFont(color: VineTheme.whiteText)
                  .copyWith(
                    decoration: TextDecoration.none,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: VineTheme.scrim15,
                      ),
                    ],
                  ),
            ),
          ),
          if (hasDescription)
            Semantics(
              identifier: 'video_thumbnail_description_$index',
              container: true,
              explicitChildNodes: true,
              label: context.l10n.videoGridDescriptionSemanticLabel(
                video.displayTitle ?? video.displayContent,
              ),
              child: Text(
                video.displayTitle ?? video.displayContent,
                style: VineTheme.bodyMediumFont(color: VineTheme.whiteText)
                    .copyWith(
                      decoration: TextDecoration.none,
                      shadows: const [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 2,
                          color: VineTheme.scrim15,
                        ),
                      ],
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.card,
      child: VideoThumbnailWidget(video: video),
    );
  }
}

/// Loading indicator shown centered below the grid during pagination.
class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      return const SizedBox.shrink();
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: BrandedLoadingIndicator(size: 48)),
    );
  }
}
