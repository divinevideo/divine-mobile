// ABOUTME: Screen for displaying people from a NIP-51 kind 30000 user list with their videos
// ABOUTME: Selects the UserList by id from PeopleListsBloc so it reacts to repository updates.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_list_follow_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_cubit.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/features/people_lists/view/people_list_hero_header.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/semantics_announcement.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/follow_list_button.dart';
import 'package:openvine/widgets/list_video_player_mode.dart';
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
          announceDetached(
            context,
            message,
            description: 'announce people list deletion failure',
            logName: 'UserListPeopleScreen',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: VineTheme.error),
          );
          return;
        }
        announceDetached(
          context,
          context.l10n.curatedListDeletedSnack,
          description: 'announce people list deletion',
          logName: 'UserListPeopleScreen',
        );
        if (context.canPop()) {
          context.pop();
        }
      },
      child:
          BlocSelector<
            PeopleListsBloc,
            PeopleListsState,
            ({bool listsKnown, UserList? list})
          >(
            selector: (state) => (
              listsKnown: state.listsKnown,
              list: _ownListById(state, widget.listId),
            ),
            builder: (context, selected) {
              final userList = selected.list;
              if (userList != null) {
                return _UserListPeopleView(
                  userList: userList,
                  onDeleteConfirmed: _deleteList,
                );
              }
              // "Not found" is only known once the viewer's lists have arrived;
              // before that a cold deep link would flash it over a list that is
              // still on its way.
              if (!selected.listsKnown) return const _ListLoadingView();
              return const _ListNotFoundView();
            },
          ),
    );
  }
}

UserList? _ownListById(PeopleListsState state, String listId) {
  for (final list in state.lists) {
    if (list.id == listId) return list;
  }
  return null;
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
      loading: () => const _ListLoadingView(),
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

/// Fullscreen playback of the members' videos, resolved from the provider
/// the grid reads, so the tile tapped there is the video played here.
class _MemberVideoPlayback extends ConsumerWidget {
  const _MemberVideoPlayback({
    required this.userList,
    required this.activeIndex,
    required this.onExit,
  });

  final UserList userList;
  final int activeIndex;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(userListMemberVideosProvider(userList.pubkeys))
        .when(
          data: (videos) => ListVideoPlayerMode(
            videos: videos,
            activeIndex: activeIndex,
            listName: userList.name,
            onExit: onExit,
            unavailableMessage: l10n.peopleListsVideoNotAvailable,
          ),
          loading: () => const Center(
            child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          error: (_, _) => Center(
            child: Text(
              l10n.peopleListsErrorLoadingVideos,
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          ),
        );
  }
}

/// Shown while the list is still on its way: someone else's from relays,
/// or the viewer's own before the bloc has delivered them.
class _ListLoadingView extends StatelessWidget {
  const _ListLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsRouteTitle,
        showBackButton: true,
        // safePop: a cold deep link here is the only route on the stack,
        // and a raw pop would throw GoError (#6112).
        onBackPressed: context.safePop,
      ),
      body: const Center(child: BrandedLoadingIndicator(size: 60)),
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
    runDetached(
      context.push<void>(
        '/people-lists/${Uri.encodeComponent(listId)}/add-people',
      ),
      'open add-people picker',
      logName: 'UserListPeopleScreen',
      category: LogCategory.ui,
    );
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
    // Fullscreen playback draws its own chrome over the whole screen.
    final PreferredSizeWidget? appBar;
    final Widget body;
    if (_activeVideoIndex == null) {
      appBar = DiVineAppBar(
        // The list title lives in the hero header below; the empty widget
        // satisfies the bar's title-or-titleWidget contract without drawing
        // anything.
        titleWidget: const SizedBox.shrink(),
        showBackButton: true,
        onBackPressed: context.pop,
        actions: [
          if (userList.isEditable)
            DiVineAppBarAction(
              icon: SvgIconSource(DivineIconName.userPlus.assetPath),
              tooltip: context.l10n.peopleListsAddPeopleTooltip,
              semanticLabel: context.l10n.peopleListsAddPeopleSemanticLabel,
              onPressed: () => _navigateToAddPeople(userList.id),
            ),
        ],
        customActions: [
          if (widget.ownerPubkey case final owner? when !userList.isEditable)
            _FollowPeopleListAction(ownerPubkey: owner, userList: userList),
          if (userList.isEditable)
            _PeopleListActionsMenu(
              onSelected: (action) {
                switch (action) {
                  case _PeopleListAction.delete:
                    runDetached(
                      _confirmDeleteList(userList),
                      'confirm people list deletion',
                      logName: 'UserListPeopleScreen',
                      category: LogCategory.ui,
                    );
                }
              },
            ),
        ],
      );
      body = _MemberVideos(
        userList: userList,
        ownerPubkey: widget.ownerPubkey,
        onVideoTap: (index) => setState(() => _activeVideoIndex = index),
      );
    } else {
      appBar = null;
      body = _MemberVideoPlayback(
        userList: userList,
        activeIndex: _activeVideoIndex!,
        onExit: () => setState(() => _activeVideoIndex = null),
      );
    }
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
        appBar: appBar,
        body: body,
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

/// The Follow pill on someone else's list. Following it adds the list to the
/// feed selector in Home, as following a video list does.
///
/// Page half of the split: bridges the repository and the signed-in viewer
/// into a [PeopleListFollowCubit], re-keyed on both so an account switch
/// follows on behalf of the right viewer.
class _FollowPeopleListAction extends ConsumerWidget {
  const _FollowPeopleListAction({
    required this.ownerPubkey,
    required this.userList,
  });

  final String ownerPubkey;
  final UserList userList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewerPubkey = context.select(
      (PeopleListsBloc bloc) => bloc.state.ownerPubkey,
    );
    // Follows are kept per viewer, so signed out there is nobody to follow as.
    if (viewerPubkey == null) return const SizedBox.shrink();

    final repository = ref.watch(peopleListsRepositoryProvider);
    return BlocProvider<PeopleListFollowCubit>(
      key: ValueKey((repository, viewerPubkey, ownerPubkey, userList.id)),
      create: (_) {
        final cubit = PeopleListFollowCubit(
          repository: repository,
          viewerPubkey: viewerPubkey,
          ownerPubkey: ownerPubkey,
          listId: userList.id,
        );
        runDetached(
          cubit.started(),
          'watch people list follow',
          logName: 'FollowPeopleListAction',
          category: LogCategory.ui,
        );
        return cubit;
      },
      child: _FollowPeopleListButton(userList: userList),
    );
  }
}

class _FollowPeopleListButton extends StatelessWidget {
  const _FollowPeopleListButton({required this.userList});

  final UserList userList;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PeopleListFollowCubit, PeopleListFollowState>(
      // Only a failed follow or unfollow: a failed read of the stored
      // follows has nothing the viewer did to report on.
      listenWhen: (previous, current) =>
          previous.status == PeopleListFollowStatus.updating &&
          current.status == PeopleListFollowStatus.failure,
      listener: (context, state) {
        final message = context.l10n.discoverListsFailedToUpdateSubscription;
        announceDetached(
          context,
          message,
          description: 'announce people list follow failure',
          logName: 'FollowPeopleListButton',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: VineTheme.error),
        );
      },
      builder: (context, state) {
        // Nothing until the follows are read, rather than a Follow label that
        // flips to Following a frame later.
        if (state.status == PeopleListFollowStatus.loading) {
          return const SizedBox.shrink();
        }
        return FollowListButton(
          isFollowing: state.isFollowing,
          isBusy: state.status == PeopleListFollowStatus.updating,
          onPressed: () => runDetached(
            context.read<PeopleListFollowCubit>().toggled(userList),
            'toggle people list follow',
            logName: 'FollowPeopleListButton',
            category: LogCategory.ui,
          ),
        );
      },
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
        onViewAll: () => runDetached(
          context.push<void>(
            RoutePaths.peopleListMembersForId(
              userList.id,
              ownerPubkey: ownerPubkey,
            ),
          ),
          'open people list roster',
          logName: 'RosterHero',
          category: LogCategory.ui,
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
