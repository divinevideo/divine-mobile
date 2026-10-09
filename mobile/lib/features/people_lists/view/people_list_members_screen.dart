// ABOUTME: Full roster of a people list, ranked by who posts the most.
// ABOUTME: Reached from the list's "View all"; the owner can add or remove.

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_member_tile.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/rounded_grid_viewport.dart';
import 'package:profile_repository/profile_repository.dart';

/// Every member of a people list, best-ranked first.
///
/// Addressed like the list screen: [listId] selects the viewer's own list
/// from [PeopleListsBloc], and an [ownerPubkey] other than the signed-in
/// owner resolves a discovered list from relays read-only instead.
class PeopleListMembersScreen extends StatelessWidget {
  const PeopleListMembersScreen({
    required this.listId,
    this.ownerPubkey,
    super.key,
  });

  static const routeName = 'people-list-roster';

  static const path = '/people-lists/:listId/members';

  final String listId;
  final String? ownerPubkey;

  @override
  Widget build(BuildContext context) {
    return _RosterListResolver(
      listId: listId,
      ownerPubkey: ownerPubkey,
      builder: (list) => _RosterPage(list: list),
    );
  }
}

/// Resolves the [UserList] the roster belongs to, mirroring the list screen:
/// the bloc for the viewer's own lists, relays for someone else's.
class _RosterListResolver extends ConsumerWidget {
  const _RosterListResolver({
    required this.listId,
    required this.ownerPubkey,
    required this.builder,
  });

  final String listId;
  final String? ownerPubkey;
  final Widget Function(UserList list) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocOwner = context.select(
      (PeopleListsBloc bloc) => bloc.state.ownerPubkey,
    );
    if (ownerPubkey case final owner? when owner != blocOwner) {
      final provider = publicPeopleListProvider(
        ownerPubkey: owner,
        listId: listId,
      );
      return ref
          .watch(provider)
          .when(
            skipLoadingOnRefresh: false,
            data: (list) {
              if (list == null) return const _RosterNotFoundView();
              return builder(list);
            },
            loading: () => const _RosterLoadingView(),
            error: (_, _) =>
                _RosterFailedView(onRetry: () => ref.invalidate(provider)),
          );
    }

    return BlocSelector<
      PeopleListsBloc,
      PeopleListsState,
      ({bool listsKnown, bool readFailed, UserList? list})
    >(
      selector: (state) => (
        listsKnown: state.listsKnown,
        readFailed:
            state.activeOwnerPubkey != null &&
            state.ownerReadStatus == PeopleListsOwnerReadStatus.failed,
        list: _ownListById(state, listId),
      ),
      builder: (context, selected) {
        final list = selected.list;
        if (list != null) return builder(list);
        // "Not found" is only known once the viewer's lists have arrived;
        // before that a cold deep link would flash it over a list that is
        // still on its way.
        if (selected.readFailed) {
          return _RosterFailedView(
            onRetry: () => context.read<PeopleListsBloc>().add(
              const PeopleListsOwnerSyncRequested(),
            ),
          );
        }
        if (!selected.listsKnown) return const _RosterLoadingView();
        return const _RosterNotFoundView();
      },
    );
  }
}

UserList? _ownListById(PeopleListsState state, String listId) {
  for (final list in state.lists) {
    if (list.id == listId) return list;
  }
  return null;
}

/// Keeps the scroll position while replacing membership-dependent ranking.
class _RosterPage extends ConsumerWidget {
  const _RosterPage({required this.list});
  final UserList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(profileRepositoryProvider);
    final blocklist = ref.watch(contentBlocklistRepositoryProvider);
    return _RosterSession(
      key: ValueKey((repository, blocklist, list.id)),
      list: list,
      profileRepository: repository,
      contentBlocklistRepository: blocklist,
    );
  }
}

class _RosterSession extends StatefulWidget {
  const _RosterSession({
    required this.list,
    required this.profileRepository,
    required this.contentBlocklistRepository,
    super.key,
  });
  final UserList list;
  final ProfileRepository? profileRepository;
  final ContentBlocklistRepository contentBlocklistRepository;

  @override
  State<_RosterSession> createState() => _RosterSessionState();
}

class _RosterSessionState extends State<_RosterSession> {
  final _scrollController = ScrollController();
  late PeopleListMembersCubit _cubit;

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  void _loadRanking() {
    _cubit = PeopleListMembersCubit(
      profileRepository: widget.profileRepository,
      contentBlocklistRepository: widget.contentBlocklistRepository,
      pubkeys: widget.list.pubkeys,
    );
    unawaited(_cubit.load());
  }

  void _closeRanking() {
    runDetached(
      _cubit.close(),
      'close roster ranking',
      logName: 'PeopleListMembersScreen',
      category: LogCategory.ui,
    );
  }

  @override
  void didUpdateWidget(_RosterSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!const ListEquality<String>().equals(
      oldWidget.list.pubkeys,
      widget.list.pubkeys,
    )) {
      _closeRanking();
      _loadRanking();
    }
  }

  @override
  void dispose() {
    _closeRanking();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PeopleListMembersCubit>.value(
      value: _cubit,
      child: _RosterView(
        list: widget.list,
        scrollController: _scrollController,
      ),
    );
  }
}

class _RosterView extends StatelessWidget {
  const _RosterView({required this.list, required this.scrollController});

  final ScrollController scrollController;

  final UserList list;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RosterScaffold(
      title: list.name,
      subtitle: l10n.peopleListsPeopleCount(list.pubkeys.length),
      actions: [
        if (list.isEditable)
          DiVineAppBarAction(
            icon: SvgIconSource(DivineIconName.userPlus.assetPath),
            tooltip: l10n.peopleListsAddPeopleTooltip,
            semanticLabel: l10n.peopleListsAddPeopleSemanticLabel,
            onPressed: () => runDetached(
              context.push<void>(
                RoutePaths.peopleListAddPeopleForId(list.id),
              ),
              'open add-people picker',
              logName: 'PeopleListMembersScreen',
              category: LogCategory.ui,
            ),
          ),
      ],
      body: _RosterBody(list: list, scrollController: scrollController),
    );
  }
}

/// The roster's page frame, shared by every state of the screen.
///
/// The bar and the page behind it are the nav color, and the content sits on
/// a surface whose top corners are rounded: the seam Explore and the inbox
/// draw. Sharing it keeps the frame still while the roster loads.
class _RosterScaffold extends StatelessWidget {
  const _RosterScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<DiVineAppBarAction> actions;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.nav,
      appBar: DiVineAppBar(
        title: title,
        subtitle: subtitle,
        showBackButton: true,
        onBackPressed: context.safePop,
        actions: actions,
      ),
      body: RoundedGridViewport(
        child: ColoredBox(
          color: context.vineColors.surfaceContainerHigh,
          child: SizedBox.expand(child: body),
        ),
      ),
    );
  }
}

/// The ranked roster, or an empty view: for a list with no members yet, or
/// for one whose members are all hidden from the viewer.
class _RosterBody extends StatelessWidget {
  const _RosterBody({required this.list, required this.scrollController});

  final ScrollController scrollController;

  final UserList list;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (list.pubkeys.isEmpty) {
      return _EmptyRosterView(
        title: l10n.peopleListsNoPeopleTitle,
        subtitle: l10n.peopleListsNoPeopleSubtitle,
      );
    }
    return BlocBuilder<PeopleListMembersCubit, PeopleListMembersState>(
      builder: (context, state) => state.members.isEmpty
          ? _EmptyRosterView(
              title: l10n.peopleListsAllMembersHiddenTitle,
              subtitle: l10n.peopleListsAllMembersHiddenSubtitle,
            )
          : ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.members.length,
              findChildIndexCallback: (key) {
                if (key is! ValueKey<String>) return null;
                final index = state.members.indexWhere(
                  (member) => member.pubkey == key.value,
                );
                return index < 0 ? null : index;
              },
              itemBuilder: (context, index) => PeopleListMemberTile(
                key: ValueKey(state.members[index].pubkey),
                pubkey: state.members[index].pubkey,
                listId: list.id,
                canRemove: list.isEditable,
              ),
            ),
    );
  }
}

class _EmptyRosterView extends StatelessWidget {
  const _EmptyRosterView({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
              title,
              style: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              subtitle,
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

class _RosterLoadingView extends StatelessWidget {
  const _RosterLoadingView();

  @override
  Widget build(BuildContext context) {
    return _RosterScaffold(
      title: context.l10n.peopleListsRouteTitle,
      body: const Center(
        child: DivineCircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}

class _RosterNotFoundView extends StatelessWidget {
  const _RosterNotFoundView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RosterScaffold(
      title: l10n.peopleListsRouteTitle,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.peopleListsListNotFoundTitle,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.primaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _RosterFailedView extends StatelessWidget {
  const _RosterFailedView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _RosterScaffold(
      title: l10n.peopleListsRouteTitle,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 16,
            children: [
              Text(
                l10n.peopleListsLoadFailed,
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
      ),
    );
  }
}
