// ABOUTME: Screen for displaying videos from a curated NIP-51 kind 30005 list
// ABOUTME: Hero header + masonry grid, owner actions sheet, manage-posts mode

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_cubit.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/view_traffic_source.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/share_sheet.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:unified_logger/unified_logger.dart';

/// Owner actions offered by the `...` bottom sheet.
enum _CuratedListAction { editInfo, managePosts, share, delete }

class CuratedListFeedScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'list';

  /// Base path for list routes.
  static const String basePath = RoutePaths.curatedListFeedBase;

  /// Path for this route.
  static const path = '/list/:listId';

  /// Build path for a specific list.
  static String pathForId(String listId) =>
      RoutePaths.curatedListFeedForId(listId);

  const CuratedListFeedScreen({
    required this.listId,
    required this.listName,
    this.videoIds,
    this.authorPubkey,
    this.discoveredList,
    super.key,
  });

  final String listId;
  final String listName;

  /// Optional video IDs to display directly (for discovered lists not in local storage)
  final List<String>? videoIds;

  /// Optional author pubkey to display who created the list
  final String? authorPubkey;

  /// The relay-resolved list for a deep link the local store doesn't hold.
  ///
  /// Share and the hero's description/visibility read the list record, and
  /// without this they would stay hidden until a Follow caches it — which
  /// breaks re-sharing the share URL itself. Local storage still wins when
  /// the list is there.
  final CuratedList? discoveredList;

  @override
  ConsumerState<CuratedListFeedScreen> createState() =>
      _CuratedListFeedScreenState();
}

class _CuratedListFeedScreenState extends ConsumerState<CuratedListFeedScreen> {
  int? _activeVideoIndex;
  bool _isTogglingSubscription = false;

  /// Live while manage-posts mode is active; each entry into the mode gets a
  /// fresh cubit so the captured service never outlives its auth session.
  CuratedListManagePostsCubit? _manageCubit;

  bool get _managing => _manageCubit != null;

  @override
  void dispose() {
    _manageCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Frozen navigation-time ids are only for lists the local store cannot
    // resolve. Once the list is local (owned, or followed), the store is the
    // source of truth — otherwise removal and refresh invalidate providers
    // this screen never watches, and tiles stick (#8453 review).
    final localList = _localList();
    final useFrozenIds = widget.videoIds != null && localList == null;
    final videosAsync = useFrozenIds
        ? ref.watch(videoEventsByIdsProvider(widget.videoIds!))
        : ref.watch(curatedListVideoEventsProvider(widget.listId));

    // Managing posts needs loaded, non-empty content: an empty list has
    // nothing to remove and an error view has no posts to manage.
    // hasError, not just a value check: an error kept a previous value in
    // the AsyncValue, but the body routes it to the error view regardless.
    final canManagePosts =
        !videosAsync.hasError && (videosAsync.value?.isNotEmpty ?? false);

    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final isOwned =
        serviceAsync.whenOrNull(
          data: (_) => service?.isOwnedList(widget.listId),
        ) ??
        false;
    final isSubscribed =
        serviceAsync.whenOrNull(
          data: (_) => service?.isSubscribedToList(widget.listId),
        ) ??
        false;
    final list = localList ?? widget.discoveredList;
    final isShareable = (list?.isPublic ?? false) && list?.pubkey != null;

    final PreferredSizeWidget? appBar;
    if (_activeVideoIndex != null) {
      appBar = null;
    } else if (_managing) {
      appBar = DiVineAppBar(
        titleWidget: Text(
          list?.name ?? widget.listName,
          style: VineTheme.titleLargeFont(color: context.vineColors.onNav),
        ),
        showBackButton: true,
        onBackPressed: _exitManageMode,
      );
    } else {
      appBar = DiVineAppBar(
        // The list title lives in the hero header below, so this bar is
        // intentionally title-less; the empty widget satisfies the app bar's
        // title-or-titleWidget contract without rendering anything.
        titleWidget: const SizedBox.shrink(),
        showBackButton: true,
        // safePop: on a cold-start deep link this screen can be the only
        // route, and a raw pop would throw GoError.
        onBackPressed: context.safePop,
        actions: [
          if (isOwned)
            DiVineAppBarAction(
              icon: SvgIconSource(DivineIconName.dotsThree.assetPath),
              onPressed: () =>
                  _showOwnerActions(canManagePosts: canManagePosts),
              tooltip: context.l10n.curatedListActionsTooltip,
            ),
        ],
        customActions: [
          if (!isOwned)
            _FollowListButton(
              isSubscribed: isSubscribed,
              isBusy: _isTogglingSubscription,
              onPressed: _toggleSubscription,
            ),
          if (!isOwned && isShareable)
            DivineAppBarIconButton(
              icon: SvgIconSource(DivineIconName.shareFat.assetPath),
              onPressed: _shareList,
              tooltip: context.l10n.listShareAction,
              semanticLabel: context.l10n.listShareAction,
              // Match the bar's own action chrome (the back button): green
              // glyph on the bordered surface container.
              backgroundColor: context.vineColors.surfaceContainer,
              borderSide: BorderSide(
                color: context.vineColors.outlineMuted,
                width: 2,
              ),
              iconColor: context.vineColors.isLight
                  ? VineTheme.primaryAccessible
                  : VineTheme.primary,
            ),
        ],
      );
    }

    final scaffold = Scaffold(
      // One surface for app bar, hero, and grid — the design renders the
      // whole list page on bg/surface (the nav token), not the black
      // screen background.
      backgroundColor: context.vineColors.nav,
      appBar: appBar,
      body: videosAsync.when(
        // Keep the current grid on screen while the provider re-runs after a
        // blocklist version bump, instead of flashing the spinner and resetting
        // scroll (#5104).
        skipLoadingOnReload: true,
        data: (videos) {
          ref
              .read(screenAnalyticsServiceProvider)
              .markDataLoaded(
                'curated_list',
                dataMetrics: {'video_count': videos.length},
              );

          // If in video mode, show fullscreen video player
          if (_activeVideoIndex != null) {
            return _ListVideoPlayerMode(
              videos: videos,
              activeIndex: _activeVideoIndex!,
              listName: widget.listName,
              onExit: _exitVideoMode,
            );
          }

          if (_manageCubit case final cubit?) {
            return BlocSelector<
              CuratedListManagePostsCubit,
              CuratedListManagePostsState,
              Set<String>
            >(
              bloc: cubit,
              selector: (state) => state.selectedVideoIds,
              builder: (context, selectedVideoIds) => _RoundedGridViewport(
                child: ComposableVideoGrid(
                  videos: videos,
                  useMasonryLayout: true,
                  // Edge-to-edge like the Explore grids: the 4px column gap
                  // comes from the grid's spacing, not outer side padding.
                  // No top padding, so the first row sits flush on the
                  // panel's rounded top edge.
                  padding: const EdgeInsets.only(bottom: 4),
                  topOuterRadius: VineTheme.shellInnerCornerRadius,
                  backgroundColor: context.vineColors.surfaceContainerHigh,
                  showSubscribedListBadge: false,
                  selectedVideoIds: selectedVideoIds,
                  onVideoTap: (videoList, index) =>
                      cubit.togglePost(videoList[index].id),
                  emptyBuilder: () => const _EmptyListMessage(),
                ),
              ),
            );
          }

          return _RoundedGridViewport(
            child: ComposableVideoGrid(
              videos: videos,
              useMasonryLayout: true,
              // Edge-to-edge like the Explore grids: the 4px column gap comes
              // from the grid's spacing, not outer side padding. No top
              // padding, so the first row sits flush on the panel's rounded
              // top edge.
              padding: const EdgeInsets.only(bottom: 4),
              topOuterRadius: VineTheme.shellInnerCornerRadius,
              backgroundColor: context.vineColors.surfaceContainerHigh,
              showSubscribedListBadge: false,
              headerSlivers: [
                SliverToBoxAdapter(
                  child: _ListHeroHeader(
                    name: list?.name ?? widget.listName,
                    videoCount:
                        list?.videoEventIds.length ??
                        widget.videoIds?.length ??
                        0,
                    description: list?.description,
                    authorPubkey: isOwned
                        ? null
                        : widget.authorPubkey ?? list?.pubkey,
                    isPublic: list?.isPublic,
                    onAuthorTap: _openAuthorProfile,
                  ),
                ),
              ],
              onVideoTap: (videoList, index) {
                Log.info(
                  'Tapped video in curated list: ${videoList[index].id}',
                  category: LogCategory.ui,
                );
                setState(() {
                  _activeVideoIndex = index;
                });
              },
              onRefresh: () async {
                _refreshListVideos();
              },
              emptyBuilder: () => const _EmptyListMessage(),
            ),
          );
        },
        loading: () => const _ListLoadingView(),
        error: (error, stack) => _ListErrorView(
          error: error,
          onRetry: _refreshListVideos,
        ),
      ),
      bottomNavigationBar: _manageCubit == null
          ? null
          : _ManageRemoveBar(cubit: _manageCubit!),
    );

    final cubit = _manageCubit;
    if (cubit == null) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _exitManageMode();
      },
      child:
          BlocListener<
            CuratedListManagePostsCubit,
            CuratedListManagePostsState
          >(
            bloc: cubit,
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                (current.status == CuratedListManagePostsStatus.success ||
                    current.status == CuratedListManagePostsStatus.failure),
            listener: _onRemovalFinished,
            child: scaffold,
          ),
    );
  }

  void _exitVideoMode() {
    setState(() {
      _activeVideoIndex = null;
    });
  }

  void _openAuthorProfile(String authorPubkey) {
    final npub = NostrKeyUtils.encodePubKey(authorPubkey);
    context.push(OtherProfileScreen.pathForNpub(npub));
  }

  void _enterManageMode() {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    if (service == null || _managing) {
      return;
    }
    setState(() {
      _manageCubit = CuratedListManagePostsCubit(
        service: service,
        listId: widget.listId,
      );
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      context.l10n.listManageVideosAction,
      Directionality.of(context),
    );
  }

  void _exitManageMode() {
    final cubit = _manageCubit;
    if (cubit == null) {
      return;
    }
    // Closing mid-removal drops the terminal emit while the publishes keep
    // going: no refresh, no snackbar, stale grid. Hold the mode until the
    // batch settles — the remove bar is already showing its progress.
    if (cubit.state.status == CuratedListManagePostsStatus.removing) {
      return;
    }
    setState(() {
      _manageCubit = null;
    });
    cubit.close();
  }

  /// Drop both cached layers: the id-list provider and the video stream
  /// that watches it. Invalidating only the stream re-runs it against the
  /// id provider's cached value, which is how a removed post kept its
  /// tile on screen.
  void _refreshListVideos() {
    ref
      ..invalidate(curatedListVideosProvider(widget.listId))
      ..invalidate(curatedListVideoEventsProvider(widget.listId));
    // The discovered-list path watches the frozen-ids provider instead, and
    // Retry after a fetch error has to re-run that one.
    if (widget.videoIds case final ids?) {
      ref.invalidate(videoEventsByIdsProvider(ids));
    }
  }

  void _onRemovalFinished(
    BuildContext context,
    CuratedListManagePostsState state,
  ) {
    final failed = state.status == CuratedListManagePostsStatus.failure;
    // On failure some removals may still have landed, so refresh either way.
    _refreshListVideos();
    final message = failed
        ? context.l10n.listRemoveVideosFailure(state.failedCount)
        : context.l10n.listRemoveVideosSuccess(state.removedCount);
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: failed ? VineTheme.error : VineTheme.vineGreen,
      ),
    );
    _exitManageMode();
  }

  CuratedList? _localList() => ref
      .read(curatedListsStateProvider.notifier)
      .service
      ?.getListById(widget.listId);

  Future<void> _showOwnerActions({required bool canManagePosts}) async {
    final list = _localList();
    // Sharing needs an author pubkey for the canonical URL, so a public
    // list without one must not offer a no-op sheet entry.
    final isShareable = (list?.isPublic ?? false) && list?.pubkey != null;

    final action = await VineBottomSheet.show<_CuratedListAction>(
      context: context,
      expanded: false,
      scrollable: false,
      children: [
        _OwnerActionTile(
          identifier: 'list_edit_info_option',
          label: context.l10n.listEditInfoAction,
          icon: DivineIconName.info,
          action: _CuratedListAction.editInfo,
        ),
        _OwnerActionTile(
          identifier: 'list_manage_posts_option',
          label: context.l10n.listManageVideosAction,
          icon: DivineIconName.pencilSimple,
          action: _CuratedListAction.managePosts,
          enabled: canManagePosts,
        ),
        if (isShareable)
          _OwnerActionTile(
            identifier: 'list_share_option',
            label: context.l10n.listShareAction,
            icon: DivineIconName.share,
            action: _CuratedListAction.share,
          ),
        _OwnerActionTile(
          identifier: 'list_delete_option',
          label: context.l10n.listDeleteAction,
          icon: DivineIconName.trash,
          action: _CuratedListAction.delete,
          isDestructive: true,
        ),
      ],
    );

    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _CuratedListAction.editInfo:
        await _editList();
      case _CuratedListAction.managePosts:
        _enterManageMode();
      case _CuratedListAction.share:
        await _shareList();
      case _CuratedListAction.delete:
        await _confirmDeleteList();
    }
  }

  Future<void> _editList() async {
    final list = _localList();
    if (list == null) return;
    await context.showVideoPausingDialog<void>(
      builder: (_) => CreateListDialog(existingList: list),
    );
  }

  Future<void> _shareList() async {
    final list = _localList() ?? widget.discoveredList;
    final authorPubkey = list?.pubkey;
    if (list == null || !list.isPublic || authorPubkey == null) return;

    final path = CuratedListByAuthorScreen.pathFor(
      pubkey: authorPubkey,
      listId: list.id,
    );
    final url = 'https://divine.video$path';
    try {
      await showShareSheet(
        context,
        ShareParams(
          text: context.l10n.listShareText(list.name, url),
          subject: context.l10n.listShareSubject(list.name),
        ),
      );
    } catch (e) {
      Log.error('Failed to share list: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.listShareFailed)));
      }
    }
  }

  Future<void> _confirmDeleteList() async {
    final l10n = context.l10n;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.surfaceContainer,
        title: Text(
          l10n.curatedListDeleteConfirmTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          l10n.curatedListDeleteConfirmBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.popModalIfMounted(false),
            child: Text(
              l10n.commonCancel,
              style: VineTheme.labelMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          ),
          TextButton(
            onPressed: () => dialogContext.popModalIfMounted(true),
            child: Text(
              l10n.commonDelete,
              style: VineTheme.labelMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    await _deleteOwnedList();
  }

  Future<void> _deleteOwnedList() async {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    final didDelete = await service?.deleteOwnedList(widget.listId) ?? false;

    if (!mounted) {
      return;
    }

    if (!didDelete) {
      final message = context.l10n.curatedListDeleteFailed;
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: VineTheme.error),
      );
      return;
    }

    ref.invalidate(curatedListsProvider);
    final message = context.l10n.curatedListDeletedSnack;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: VineTheme.vineGreen),
    );

    if (context.canPop()) {
      context.pop();
    }
  }

  Future<void> _toggleSubscription() async {
    final service = ref.read(curatedListsStateProvider.notifier).service;
    if (service == null || _isTogglingSubscription) {
      return;
    }

    setState(() {
      _isTogglingSubscription = true;
    });

    try {
      if (service.isSubscribedToList(widget.listId)) {
        await service.unsubscribeFromList(widget.listId);
        Log.info(
          'Unsubscribed from list: ${widget.listName}',
          category: LogCategory.ui,
        );
      } else {
        // Prefer the relay-resolved record: the synthetic fallback has no
        // description or image, and whatever subscribes here is what the
        // cache serves from then on.
        final list =
            service.getListById(widget.listId) ??
            widget.discoveredList ??
            CuratedList(
              id: widget.listId,
              name: widget.listName,
              pubkey: widget.authorPubkey,
              videoEventIds: widget.videoIds ?? const [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
        await service.subscribeToList(widget.listId, list);
        Log.info(
          'Subscribed to list: ${widget.listName}',
          category: LogCategory.ui,
        );
      }

      // Invalidate providers so the Lists tab updates
      ref.invalidate(curatedListsProvider);
    } catch (e) {
      Log.error('Failed to toggle subscription: $e', category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.discoverListsFailedToUpdateSubscription),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTogglingSubscription = false;
        });
      }
    }
  }
}

/// Clips the scrolling grid region's top corners, so content sliding under
/// the app bar keeps the same rounded seam the design's radius cap draws.
///
/// Complements [ComposableVideoGrid.topOuterRadius]: that rounds the grid
/// block itself at rest, this rounds the viewport while scrolled.
class _RoundedGridViewport extends StatelessWidget {
  const _RoundedGridViewport({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: child,
    );
  }
}

/// Follow/Following pill shown to non-owners in the app bar.
class _FollowListButton extends StatelessWidget {
  const _FollowListButton({
    required this.isSubscribed,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isSubscribed;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: isSubscribed
          ? context.l10n.listFollowingButton
          : context.l10n.listFollowButton,
      size: DivineButtonSize.small,
      type: isSubscribed
          ? DivineButtonType.secondary
          : DivineButtonType.primary,
      leadingIcon: isSubscribed ? DivineIconName.check : DivineIconName.plus,
      isLoading: isBusy,
      onPressed: isBusy ? null : onPressed,
    );
  }
}

/// Hero block scrolled with the grid: list title, video count, description
/// and the creator/visibility attribution.
class _ListHeroHeader extends StatelessWidget {
  const _ListHeroHeader({
    required this.name,
    required this.videoCount,
    this.description,
    this.authorPubkey,
    this.isPublic,
    this.onAuthorTap,
  });

  final String name;
  final int videoCount;
  final String? description;

  /// Creator to credit; `null` for an owned list (no self-attribution).
  final String? authorPubkey;

  /// List visibility; `null` when the list is not in local storage.
  final bool? isPublic;

  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final authorPubkey = this.authorPubkey;
    final isPublic = this.isPublic;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            name,
            style: VineTheme.headlineSmallFont(
              color: context.vineColors.primaryText,
            ),
          ),
          Text(
            context.l10n.listVideoCount(videoCount),
            style: VineTheme.labelLargeFont(
              color: context.vineColors.primaryText,
            ),
          ),
          if (description != null && description.isNotEmpty)
            Text(
              description,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
          if (authorPubkey != null)
            _ListAuthorAttribution(
              authorPubkey: authorPubkey,
              onTap: () => onAuthorTap?.call(authorPubkey),
            )
          else if (isPublic != null)
            Text(
              isPublic
                  ? context.l10n.listVisibilityPublic
                  : context.l10n.listVisibilityPrivate,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tappable "By {creator}" row for a list the viewer does not own.
class _ListAuthorAttribution extends StatelessWidget {
  const _ListAuthorAttribution({
    required this.authorPubkey,
    required this.onTap,
  });

  final String authorPubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.listByAuthorPrefix,
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            Flexible(
              child: UserName.fromPubKey(
                authorPubkey,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.primaryText,
                ).copyWith(fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the owner actions sheet; pops the sheet with its [action].
///
/// A disabled row renders muted and ignores taps instead of hiding, so the
/// owner can still see the option exists.
class _OwnerActionTile extends StatelessWidget {
  const _OwnerActionTile({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.action,
    this.isDestructive = false,
    this.enabled = true,
  });

  final String identifier;
  final String label;
  final DivineIconName icon;
  final _CuratedListAction action;
  final bool isDestructive;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // onErrorContainer, not fixed likeRed/error: the sheet surface follows
    // the palette and the token keeps destructive contrast in both
    // appearances (#7147, matching the comment options sheet).
    final Color color;
    if (!enabled) {
      color = context.vineColors.onSurfaceMuted;
    } else if (isDestructive) {
      color = context.vineColors.onErrorContainer;
    } else {
      color = context.vineColors.onSurface;
    }

    void select() => Navigator.of(context).pop(action);

    return Semantics(
      identifier: identifier,
      button: true,
      enabled: enabled,
      label: label,
      // excludeSemantics drops the child subtree — including the
      // GestureDetector's tap action — so the action is re-declared here.
      onTap: enabled ? select : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? select : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            spacing: 16,
            children: [
              DivineIcon(icon: icon, color: color),
              Expanded(
                child: Text(
                  label,
                  style: VineTheme.titleMediumFont(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom bar in manage-posts mode: removes the selected posts.
class _ManageRemoveBar extends StatelessWidget {
  const _ManageRemoveBar({required this.cubit});

  final CuratedListManagePostsCubit cubit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child:
          BlocBuilder<CuratedListManagePostsCubit, CuratedListManagePostsState>(
            bloc: cubit,
            builder: (context, state) {
              final count = state.selectedVideoIds.length;
              final removing =
                  state.status == CuratedListManagePostsStatus.removing;
              return DivineButton(
                label: context.l10n.listRemoveVideosButton(count),
                type: DivineButtonType.secondary,
                expanded: true,
                isLoading: removing,
                onPressed: count == 0 || removing ? null : cubit.removeSelected,
              );
            },
          ),
    );
  }
}

/// Fullscreen playback mode for a tapped grid tile.
class _ListVideoPlayerMode extends StatelessWidget {
  const _ListVideoPlayerMode({
    required this.videos,
    required this.activeIndex,
    required this.listName,
    required this.onExit,
  });

  final List<VideoEvent> videos;
  final int activeIndex;
  final String listName;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty || activeIndex >= videos.length) {
      return Center(
        child: Text(
          context.l10n.curatedListVideoNotAvailable,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      );
    }

    // Embedded as this screen's "video mode": both the feed's own app-bar back
    // button ([onBack]) and the system back gesture ([PopScope]) return to the
    // grid instead of popping the whole route, so the user sees a single back
    // button and hardware back stays consistent with it.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onExit();
      },
      child: PooledFullscreenVideoFeedScreen(
        source: VideoListViewSource(videos),
        feedRepository: StaticFeedRepository(),
        initialIndex: activeIndex,
        contextTitle: listName,
        trafficSource: ViewTrafficSource.search,
        onBack: onExit,
      ),
    );
  }
}

/// Empty-list body rendered under the hero header.
class _EmptyListMessage extends StatelessWidget {
  const _EmptyListMessage();

  @override
  Widget build(BuildContext context) {
    // The design's empty-state component: title/medium over body/medium,
    // both on on-surface-muted, centered with 48px side margins and an 8px
    // gap. The icon and copy stay ours; the component's button is omitted.
    final muted = context.vineColors.onSurfaceMuted;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            DivineIcon(
              icon: DivineIconName.filmSlate,
              size: 64,
              color: context.vineColors.secondaryText,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.curatedListEmptyTitle,
              style: VineTheme.titleMediumFont(color: muted),
              textAlign: TextAlign.center,
            ),
            Text(
              context.l10n.curatedListEmptySubtitle,
              style: VineTheme.bodyMediumFont(color: muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading body shown while the list's videos resolve.
class _ListLoadingView extends StatelessWidget {
  const _ListLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          const DivineCircularProgressIndicator(color: VineTheme.vineGreen),
          Text(
            context.l10n.curatedListLoadingVideos,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error body with a retry affordance.
class _ListErrorView extends StatelessWidget {
  const _ListErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          const DivineIcon(
            icon: DivineIconName.warningCircle,
            size: 64,
            color: VineTheme.likeRed,
          ),
          Text(
            context.l10n.curatedListFailedToLoad,
            style: VineTheme.titleMediumFont(color: VineTheme.likeRed),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error.toString(),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          DivineButton(
            label: context.l10n.commonRetry,
            leadingIcon: DivineIconName.arrowClockwise,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
