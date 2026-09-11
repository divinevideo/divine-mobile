// ABOUTME: Screen for displaying people from a NIP-51 kind 30000 user list with their videos
// ABOUTME: Selects the UserList by id from PeopleListsBloc so it reacts to repository updates.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_cubit.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/people_list_hero_header.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/rounded_grid_viewport.dart';
import 'package:unified_logger/unified_logger.dart';

enum _PeopleListAction { delete }

/// Screen that renders a single NIP-51 kind 30000 people list.
///
/// The screen is addressed by [listId] and selects the matching [UserList]
/// from [PeopleListsBloc] with a [BlocSelector], so edits made elsewhere
/// (add/remove member, rename) are reflected without rebuilding the route.
class UserListPeopleScreen extends StatefulWidget {
  const UserListPeopleScreen({
    required this.listId,
    this.ownerPubkey,
    super.key,
  });

  /// GoRouter name for this route.
  static const routeName = 'people-list-members';

  /// GoRouter path template for this route.
  static const path = '/people-lists/:listId';

  /// Full list id (NIP-51 addressable identifier). Never truncated.
  final String listId;

  /// Author of a discovered list (lowercase hex), from the route's `owner`
  /// query param. When set to someone other than the signed-in owner, the
  /// list resolves from relays read-only instead of the owner-scoped bloc.
  final String? ownerPubkey;

  @override
  State<UserListPeopleScreen> createState() => _UserListPeopleScreenState();
}

class _UserListPeopleScreenState extends State<UserListPeopleScreen> {
  /// The delete this screen is waiting on, with the owner it was issued for.
  ///
  /// The owner is part of the record because the bloc clears its pending
  /// mutations wholesale whenever it tears its state down. On the mutation map
  /// alone, an account switch or a `FeatureFlag.curatedLists` flag-off is
  /// indistinguishable from the delete settling (#6504).
  ///
  /// Only [_pendingDeleteResolved] and the listener read this — [build] does
  /// not — so it is assigned without `setState`.
  ({String listId, String? ownerPubkey})? _pendingDelete;

  void _deleteList(String listId) {
    final bloc = context.read<PeopleListsBloc>();
    _pendingDelete = (listId: listId, ownerPubkey: bloc.state.ownerPubkey);
    bloc.add(PeopleListsDeleteRequested(listId: listId));
  }

  bool _pendingDeleteResolved(
    PeopleListsState previous,
    PeopleListsState current,
  ) {
    final pending = _pendingDelete;
    if (pending == null) return false;
    return _hasPendingDelete(previous, pending.listId) &&
        !_hasPendingDelete(current, pending.listId);
  }

  static bool _hasPendingDelete(PeopleListsState state, String listId) {
    return state.pendingMutations.values.any(
      (mutation) =>
          mutation.kind == PeopleListsMutationKind.deleteList &&
          mutation.listId == listId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocOwner = context.select(
      (PeopleListsBloc bloc) => bloc.state.ownerPubkey,
    );
    if (widget.ownerPubkey case final owner? when owner != blocOwner) {
      return _DiscoveredPeopleListLoader(
        ownerPubkey: owner,
        listId: widget.listId,
      );
    }

    return BlocListener<PeopleListsBloc, PeopleListsState>(
      listenWhen: _pendingDeleteResolved,
      listener: (context, state) {
        final pending = _pendingDelete;
        final failed = state.status == PeopleListsStatus.failure;
        _pendingDelete = null;
        // The bloc dropped the mutation rather than resolving it: the feature
        // was turned off, or another account took over. Nothing settled, so
        // announce nothing and stay on the route.
        if (pending == null ||
            !state.enabled ||
            state.ownerPubkey != pending.ownerPubkey) {
          return;
        }
        if (failed) {
          final message = context.l10n.peopleListsDeleteFailed;
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
        SemanticsService.sendAnnouncement(
          View.of(context),
          context.l10n.curatedListDeletedSnack,
          Directionality.of(context),
        );
        if (context.canPop()) {
          context.pop();
        }
      },
      child: BlocSelector<PeopleListsBloc, PeopleListsState, UserList?>(
        selector: (state) {
          for (final list in state.lists) {
            if (list.id == widget.listId) return list;
          }
          return null;
        },
        builder: (context, userList) {
          if (userList == null) {
            return const _ListNotFoundView();
          }
          return _UserListPeopleView(
            userList: userList,
            onDeleteConfirmed: _deleteList,
          );
        },
      ),
    );
  }
}

/// Resolves a discovered (someone else's) list from relays and renders the
/// members view read-only — the repository returns it with
/// `isEditable: false`, which hides every owner affordance.
class _DiscoveredPeopleListLoader extends ConsumerWidget {
  const _DiscoveredPeopleListLoader({
    required this.ownerPubkey,
    required this.listId,
  });

  final String ownerPubkey;
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(
      publicPeopleListProvider(ownerPubkey: ownerPubkey, listId: listId),
    );
    return listAsync.when(
      data: (userList) {
        if (userList == null) {
          return const _ListNotFoundView();
        }
        return _UserListPeopleView(
          userList: userList,
          // Unreachable: the delete menu only renders for editable lists.
          onDeleteConfirmed: (_) {},
          ownerPubkey: ownerPubkey,
        );
      },
      loading: () => Scaffold(
        backgroundColor: context.vineColors.background,
        appBar: DiVineAppBar(
          title: context.l10n.peopleListsRouteTitle,
          showBackButton: true,
          // safePop: a cold deep link here is the only route on the stack,
          // and a raw pop would throw GoError (#6112).
          onBackPressed: context.safePop,
        ),
        body: const Center(child: BrandedLoadingIndicator(size: 60)),
      ),
      // A relay failure is not "this list does not exist": keep the two
      // apart and let the viewer try again without leaving the screen.
      error: (error, stackTrace) => _ListLoadFailedView(
        onRetry: () => ref.invalidate(
          publicPeopleListProvider(ownerPubkey: ownerPubkey, listId: listId),
        ),
      ),
    );
  }
}

/// Shown when a discovered list could not be read from the relays.
class _ListLoadFailedView extends StatelessWidget {
  const _ListLoadFailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsRouteTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: [
              DivineIcon(
                icon: DivineIconName.warningCircle,
                size: 48,
                color: context.vineColors.secondaryText,
              ),
              Text(
                context.l10n.peopleListsLoadFailed,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              DivineButton(
                label: context.l10n.commonRetry,
                type: DivineButtonType.secondary,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the selected [UserList] is not present in bloc state.
class _ListNotFoundView extends StatelessWidget {
  const _ListNotFoundView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsRouteTitle,
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.group_off,
              size: 64,
              color: context.vineColors.secondaryText,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.peopleListsListNotFoundTitle,
              style: TextStyle(
                color: context.vineColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.peopleListsListDeletedSubtitle,
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Body view for a resolved [UserList].
class _UserListPeopleView extends ConsumerStatefulWidget {
  const _UserListPeopleView({
    required this.userList,
    required this.onDeleteConfirmed,
    this.ownerPubkey,
  });

  final UserList userList;
  final ValueChanged<String> onDeleteConfirmed;

  /// Author of a discovered list, carried into the roster route; `null` for
  /// the viewer's own list.
  final String? ownerPubkey;

  @override
  ConsumerState<_UserListPeopleView> createState() =>
      _UserListPeopleViewState();
}

class _UserListPeopleViewState extends ConsumerState<_UserListPeopleView> {
  int? _activeVideoIndex;

  void _navigateToAddPeople(String listId) {
    context.push('/people-lists/${Uri.encodeComponent(listId)}/add-people');
  }

  Future<void> _confirmDeleteList(UserList userList) async {
    final l10n = context.l10n;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.surfaceContainer,
        title: Text(
          l10n.peopleListsDeleteConfirmTitle,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          l10n.peopleListsDeleteConfirmBody,
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

    if (shouldDelete != true || !mounted) return;

    widget.onDeleteConfirmed(userList.id);
  }

  @override
  Widget build(BuildContext context) {
    final userList = widget.userList;
    final profileRepository = ref.watch(profileRepositoryProvider);
    return BlocProvider<PeopleListMembersCubit>(
      key: ValueKey((profileRepository, Object.hashAll(userList.pubkeys))),
      create: (_) {
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: userList.pubkeys,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: Scaffold(
        // One surface for app bar, hero and grid, like the video list screen.
        backgroundColor: context.vineColors.nav,
        appBar: _activeVideoIndex == null
            ? DiVineAppBar(
                // The list title lives in the hero header below; the empty
                // widget satisfies the bar's title-or-titleWidget contract
                // without drawing anything.
                titleWidget: const SizedBox.shrink(),
                showBackButton: true,
                onBackPressed: context.pop,
                actions: [
                  if (userList.isEditable)
                    DiVineAppBarAction(
                      icon: SvgIconSource(DivineIconName.userPlus.assetPath),
                      tooltip: context.l10n.peopleListsAddPeopleTooltip,
                      semanticLabel:
                          context.l10n.peopleListsAddPeopleSemanticLabel,
                      onPressed: () => _navigateToAddPeople(userList.id),
                    ),
                ],
                customActions: [
                  if (userList.isEditable)
                    _PeopleListActionsMenu(
                      onSelected: (action) {
                        switch (action) {
                          case _PeopleListAction.delete:
                            _confirmDeleteList(userList);
                        }
                      },
                    ),
                ],
              )
            : null,
        body: _activeVideoIndex != null
            ? _buildVideoPlayer(userList)
            : _MemberVideos(
                userList: userList,
                ownerPubkey: widget.ownerPubkey,
                onVideoTap: (index) =>
                    setState(() => _activeVideoIndex = index),
              ),
      ),
    );
  }

  Widget _buildVideoPlayer(UserList userList) {
    final videosAsync = ref.watch(
      userListMemberVideosProvider(userList.pubkeys),
    );
    final l10n = context.l10n;

    return videosAsync.when(
      data: (videos) {
        if (videos.isEmpty || _activeVideoIndex! >= videos.length) {
          return Center(
            child: Text(
              l10n.peopleListsVideoNotAvailable,
              style: TextStyle(color: context.vineColors.secondaryText),
            ),
          );
        }

        return Stack(
          children: [
            PooledFullscreenVideoFeedScreen(
              source: VideoListViewSource(videos),
              feedRepository: StaticFeedRepository(),
              initialIndex: _activeVideoIndex!,
              contextTitle: userList.name,
            ),
            // Header bar showing list name and back button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [VineTheme.scrim70, VineTheme.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      // Back to grid button
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: VineTheme.scrim50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.grid_view,
                            color: VineTheme.whiteText,
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _activeVideoIndex = null;
                          });
                        },
                        tooltip: l10n.peopleListsBackToGridTooltip,
                      ),
                      const SizedBox(width: 8),
                      // List name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userList.name,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userList.description != null)
                              Text(
                                userList.description!,
                                style: const TextStyle(
                                  color: VineTheme.secondaryText,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      // Video count indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: VineTheme.scrim50,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_activeVideoIndex! + 1}/${videos.length}',
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => Center(
        child: Text(
          l10n.peopleListsErrorLoadingVideos,
          style: const TextStyle(color: VineTheme.likeRed),
        ),
      ),
    );
  }
}

class _PeopleListActionsMenu extends StatelessWidget {
  const _PeopleListActionsMenu({required this.onSelected});

  final ValueChanged<_PeopleListAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_PeopleListAction>(
      tooltip: context.l10n.peopleListsActionsTooltip,
      color: context.vineColors.surfaceContainer,
      icon: DivineIcon(
        icon: DivineIconName.dotsThreeVertical,
        color: context.vineColors.primaryText,
      ),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _PeopleListAction.delete,
          child: Text(
            context.l10n.listDeleteAction,
            style: TextStyle(color: context.vineColors.primaryText),
          ),
        ),
      ],
    );
  }
}

/// Horizontal carousel of people avatars for a user list.
/// The list's video grid with the hero header scrolled above it.
///
/// The header, and with it the members preview and "View all", renders in
/// every state of the videos fetch, so a list whose members have posted
/// nothing still leads to its people instead of a dead end.
class _MemberVideos extends ConsumerWidget {
  const _MemberVideos({
    required this.userList,
    required this.ownerPubkey,
    required this.onVideoTap,
  });

  final UserList userList;
  final String? ownerPubkey;
  final ValueChanged<int> onVideoTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = userListMemberVideosProvider(userList.pubkeys);
    final videosAsync = ref.watch(provider);
    final videos = videosAsync.value ?? const <VideoEvent>[];

    return RoundedGridViewport(
      child: ComposableVideoGrid(
        videos: videos,
        useMasonryLayout: true,
        // Edge-to-edge like the video list screen: the 4px column gap comes
        // from the grid's spacing, and the first row sits flush on the
        // panel's rounded top edge.
        padding: const EdgeInsets.only(bottom: 4),
        topOuterRadius: VineTheme.shellInnerCornerRadius,
        backgroundColor: context.vineColors.surfaceContainerHigh,
        showSubscribedListBadge: false,
        headerSlivers: [
          SliverToBoxAdapter(
            child: _RosterHero(userList: userList, ownerPubkey: ownerPubkey),
          ),
        ],
        onVideoTap: (videoList, index) {
          Log.info(
            'Tapped video in user list: ${videoList[index].id}',
            category: LogCategory.ui,
          );
          onVideoTap(index);
        },
        onRefresh: () async {
          ref.invalidate(provider);
          await context.read<PeopleListMembersCubit>().load();
        },
        emptyBuilder: () {
          if (userList.pubkeys.isEmpty) return const _NoPeopleView();
          return switch (videosAsync) {
            AsyncError() => _MemberVideosFailedView(
              onRetry: () => ref.invalidate(provider),
            ),
            AsyncData() => const _NoMemberVideosView(),
            _ => const _MemberVideosLoadingView(),
          };
        },
      ),
    );
  }
}

/// The hero header fed by the roster cubit: ranked members in the preview,
/// totals in the stats line, "View all" into the roster route.
class _RosterHero extends StatelessWidget {
  const _RosterHero({required this.userList, required this.ownerPubkey});

  final UserList userList;
  final String? ownerPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PeopleListMembersCubit, PeopleListMembersState>(
      builder: (context, state) => PeopleListHeroHeader(
        name: userList.name,
        description: userList.description,
        memberCount: userList.pubkeys.length,
        previewPubkeys: [for (final member in state.members) member.pubkey],
        totalVideos: state.totalVideos,
        totalLoops: state.totalLoops,
        onViewAll: () => context.push(
          RoutePaths.peopleListMembersForId(
            userList.id,
            ownerPubkey: ownerPubkey,
          ),
        ),
      ),
    );
  }
}

class _MemberVideosLoadingView extends StatelessWidget {
  const _MemberVideosLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}

class _NoMemberVideosView extends StatelessWidget {
  const _NoMemberVideosView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            DivineIcon(
              icon: DivineIconName.play,
              size: 64,
              color: context.vineColors.secondaryText,
            ),
            Text(
              l10n.peopleListsNoVideosTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              l10n.peopleListsNoVideosSubtitle,
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

class _MemberVideosFailedView extends StatelessWidget {
  const _MemberVideosFailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 16,
          children: [
            Text(
              l10n.peopleListsFailedToLoadVideos,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            DivineButton(
              label: l10n.commonRetry,
              type: DivineButtonType.secondary,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state of a list with no members yet; the owner adds people from
/// the app bar.
class _NoPeopleView extends StatelessWidget {
  const _NoPeopleView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 8,
          children: [
            DivineIcon(
              icon: DivineIconName.users,
              size: 64,
              color: context.vineColors.secondaryText,
            ),
            Text(
              l10n.peopleListsNoPeopleTitle,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              l10n.peopleListsNoPeopleSubtitle,
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
