// ABOUTME: Full roster of a people list, ranked by who posts the most.
// ABOUTME: Reached from the list's "View all"; the owner can add or remove.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/people_list_members_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/view/people_list_member_tile.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/repository_providers.dart';

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
            data: (list) =>
                list == null ? const _RosterNotFoundView() : builder(list),
            loading: () => const _RosterLoadingView(),
            error: (_, _) =>
                _RosterFailedView(onRetry: () => ref.invalidate(provider)),
          );
    }

    return BlocSelector<PeopleListsBloc, PeopleListsState, UserList?>(
      selector: (state) {
        for (final list in state.lists) {
          if (list.id == listId) return list;
        }
        return null;
      },
      builder: (context, list) =>
          list == null ? const _RosterNotFoundView() : builder(list),
    );
  }
}

/// Owns the roster cubit for [list]; re-keyed when the profile repository
/// or the membership changes so the ranking never outlives its inputs.
class _RosterPage extends ConsumerWidget {
  const _RosterPage({required this.list});

  final UserList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileRepository = ref.watch(profileRepositoryProvider);
    return BlocProvider<PeopleListMembersCubit>(
      key: ValueKey((profileRepository, Object.hashAll(list.pubkeys))),
      create: (_) {
        final cubit = PeopleListMembersCubit(
          profileRepository: profileRepository,
          pubkeys: list.pubkeys,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _RosterView(list: list),
    );
  }
}

class _RosterView extends StatelessWidget {
  const _RosterView({required this.list});

  final UserList list;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: DiVineAppBar(
        title: list.name,
        subtitle: l10n.peopleListsPeopleCount(list.pubkeys.length),
        showBackButton: true,
        onBackPressed: context.safePop,
        actions: [
          if (list.isEditable)
            DiVineAppBarAction(
              icon: SvgIconSource(DivineIconName.userPlus.assetPath),
              tooltip: l10n.peopleListsAddPeopleTooltip,
              semanticLabel: l10n.peopleListsAddPeopleSemanticLabel,
              onPressed: () => unawaited(
                context.push(
                  '/people-lists/${Uri.encodeComponent(list.id)}/add-people',
                ),
              ),
            ),
        ],
      ),
      body: list.pubkeys.isEmpty
          ? const _EmptyRosterView()
          : BlocBuilder<PeopleListMembersCubit, PeopleListMembersState>(
              builder: (context, state) => ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.members.length,
                itemBuilder: (context, index) => PeopleListMemberTile(
                  key: ValueKey(state.members[index].pubkey),
                  pubkey: state.members[index].pubkey,
                  listId: list.id,
                  canRemove: list.isEditable,
                ),
              ),
            ),
    );
  }
}

class _EmptyRosterView extends StatelessWidget {
  const _EmptyRosterView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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

class _RosterLoadingView extends StatelessWidget {
  const _RosterLoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsRouteTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
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
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: DiVineAppBar(
        title: l10n.peopleListsRouteTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
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
    return Scaffold(
      backgroundColor: context.vineColors.surfaceContainerHigh,
      appBar: DiVineAppBar(
        title: l10n.peopleListsRouteTitle,
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
