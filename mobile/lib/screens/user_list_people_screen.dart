// ABOUTME: Screen for displaying people from a NIP-51 kind 30000 user list with their videos
// ABOUTME: Selects the UserList by id from PeopleListsBloc so it reacts to repository updates.

import 'package:divine_ui/divine_ui.dart';
import 'package:feed_repository/feed_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/features/people_lists/people_lists.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:openvine/widgets/scroll_to_hide_mixin.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:unified_logger/unified_logger.dart';

enum _PeopleListAction { delete }

/// Screen that renders a single NIP-51 kind 30000 people list.
///
/// The screen is addressed by [listId] and selects the matching [UserList]
/// from [PeopleListsBloc] with a [BlocSelector], so edits made elsewhere
/// (add/remove member, rename) are reflected without rebuilding the route.
class UserListPeopleScreen extends StatefulWidget {
  const UserListPeopleScreen({required this.listId, super.key});

  /// GoRouter name for this route.
  static const routeName = 'people-list-members';

  /// GoRouter path template for this route.
  static const path = '/people-lists/:listId';

  /// Full list id (NIP-51 addressable identifier). Never truncated.
  final String listId;

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

class _PeopleListAppBarTitle extends StatelessWidget {
  const _PeopleListAppBarTitle({required this.userList});

  final UserList userList;

  @override
  Widget build(BuildContext context) {
    final description = userList.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          userList.name,
          style: VineTheme.titleLargeFont(
            color: context.vineColors.primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (description != null && description.isNotEmpty) ...[
          const SizedBox(height: 2),
          LinkifiedText(
            text: description,
            style: VineTheme.bodySmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Body view for a resolved [UserList].
class _UserListPeopleView extends ConsumerStatefulWidget {
  const _UserListPeopleView({
    required this.userList,
    required this.onDeleteConfirmed,
  });

  final UserList userList;
  final ValueChanged<String> onDeleteConfirmed;

  @override
  ConsumerState<_UserListPeopleView> createState() =>
      _UserListPeopleViewState();
}

class _UserListPeopleViewState extends ConsumerState<_UserListPeopleView>
    with ScrollToHideMixin {
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
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: _activeVideoIndex == null
          ? DiVineAppBar(
              titleWidget: _PeopleListAppBarTitle(userList: userList),
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
      body: userList.pubkeys.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DivineIcon(
                    icon: DivineIconName.users,
                    size: 64,
                    color: context.vineColors.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.peopleListsNoPeopleTitle,
                    style: TextStyle(
                      color: context.vineColors.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.peopleListsNoPeopleSubtitle,
                    style: TextStyle(
                      color: context.vineColors.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _activeVideoIndex != null
          ? _buildVideoPlayer(userList)
          : _buildListContent(userList),
    );
  }

  Widget _buildListContent(UserList userList) {
    final videosAsync = ref.watch(
      userListMemberVideosProvider(userList.pubkeys),
    );
    final l10n = context.l10n;

    measureHeaderHeight();

    return videosAsync.when(
      data: (videos) {
        if (videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library,
                  size: 64,
                  color: context.vineColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.peopleListsNoVideosTitle,
                  style: TextStyle(
                    color: context.vineColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.peopleListsNoVideosSubtitle,
                  style: TextStyle(
                    color: context.vineColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: handleScrollNotification,
                child: ComposableVideoGrid(
                  videos: videos,
                  useMasonryLayout: true,
                  padding: EdgeInsets.only(
                    left: 4,
                    right: 4,
                    bottom: 4,
                    top: headerHeight > 0 ? headerHeight + 4 : 4,
                  ),
                  onVideoTap: (videos, index) {
                    Log.info(
                      'Tapped video in user list: ${videos[index].id}',
                      category: LogCategory.ui,
                    );
                    setState(() {
                      _activeVideoIndex = index;
                    });
                  },
                  onRefresh: () async {
                    ref.invalidate(
                      userListMemberVideosProvider(userList.pubkeys),
                    );
                  },
                  emptyBuilder: () => Center(
                    child: Text(
                      l10n.peopleListsNoVideosAvailable,
                      style: TextStyle(color: context.vineColors.secondaryText),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: headerFullyHidden
                  ? const Duration(milliseconds: 250)
                  : Duration.zero,
              curve: Curves.easeOut,
              top: headerOffset,
              left: 0,
              right: 0,
              child: PeopleCarousel(
                key: headerKey,
                pubkeys: userList.pubkeys,
                listId: userList.id,
                canRemove: userList.isEditable,
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              size: 64,
              color: VineTheme.likeRed,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.peopleListsFailedToLoadVideos,
              style: const TextStyle(color: VineTheme.likeRed, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
@visibleForTesting
class PeopleCarousel extends StatelessWidget {
  const PeopleCarousel({
    required this.pubkeys,
    required this.listId,
    required this.canRemove,
    super.key,
  });

  final List<String> pubkeys;
  final String listId;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.background,
      child: SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.only(
            start: 16,
            end: 16,
            top: 12,
          ),
          itemCount: pubkeys.length,
          itemBuilder: (context, index) => _PeopleAvatarItem(
            pubkey: pubkeys[index],
            listId: listId,
            canRemove: canRemove,
          ),
        ),
      ),
    );
  }
}

class _PeopleAvatarItem extends ConsumerWidget {
  const _PeopleAvatarItem({
    required this.pubkey,
    required this.listId,
    required this.canRemove,
  });

  final String pubkey;
  final String listId;
  final bool canRemove;

  Future<void> _confirmRemove(BuildContext context, String displayName) async {
    final l10n = context.l10n;
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.vineColors.surfaceContainer,
        title: Text(
          l10n.peopleListsRemoveConfirmTitle(displayName),
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
        ),
        content: Text(
          l10n.peopleListsRemoveConfirmBody,
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
              l10n.peopleListsRemove,
              style: VineTheme.labelMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (shouldRemove != true || !context.mounted) return;

    final bloc = context.read<PeopleListsBloc>()
      ..add(PeopleListsPubkeyRemoveRequested(listId: listId, pubkey: pubkey));

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.peopleListsRemovedFromList(displayName)),
        action: SnackBarAction(
          label: l10n.peopleListsUndo,
          onPressed: () {
            bloc.add(
              PeopleListsPubkeyAddRequested(listId: listId, pubkey: pubkey),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);

    return Semantics(
      label: canRemove
          ? context.l10n.peopleListsProfileLongPressHint(displayName)
          : context.l10n.peopleListsViewProfileHint(displayName),
      button: true,
      child: GestureDetector(
        onTap: () {
          final npub = NostrKeyUtils.encodePubKey(pubkey);
          context.push(OtherProfileScreen.pathForNpub(npub));
        },
        onLongPress: canRemove
            ? () => _confirmRemove(context, displayName)
            : null,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              UserAvatar(
                imageUrl: profile?.picture,
                placeholderSeed: pubkey,
                size: 56,
              ),
              SizedBox(
                width: 70,
                child: Text(
                  displayName,
                  style: VineTheme.titleTinyFont(
                    color: context.vineColors.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
