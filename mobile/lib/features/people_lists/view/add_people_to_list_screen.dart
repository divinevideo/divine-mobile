// ABOUTME: Full-screen picker for adding people to an existing list, on the
// ABOUTME: Following screen's layout: each row's button adds or removes that
// ABOUTME: person through PeopleListsBloc at once, with no confirm step.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Full-screen picker that lets the authenticated user add people to an
/// existing people list, one tap per person.
///
/// The screen resolves the target [UserList] from the ambient
/// [PeopleListsBloc] by [listId], and seeds candidates by scoping a fresh
/// [AddPeopleToListCubit] to it. Candidates are sourced from the
/// authenticated user's following and followers sets, not passed in. Each
/// row carries the Following screen's add/remove button: a tap dispatches
/// [PeopleListsPubkeyToggleRequested] and the row reads the list's
/// membership back from the bloc, so it flips as soon as the optimistic
/// state does and flips back if the write is rolled back.
///
/// Per project rules, full Nostr pubkeys flow through the screen verbatim —
/// they are never truncated in state, events, or navigation.
class AddPeopleToListScreen extends ConsumerWidget {
  /// Creates the add-people picker.
  const AddPeopleToListScreen({required this.listId, super.key});

  /// GoRouter name for this route.
  static const routeName = 'people-list-add-people';

  /// GoRouter path template for this route.
  static const path = '/people-lists/:listId/add-people';

  /// Target list's full addressable id. Never truncated.
  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocSelector<PeopleListsBloc, PeopleListsState, UserList?>(
      selector: (state) {
        for (final list in state.lists) {
          if (list.id == listId) return list;
        }
        return null;
      },
      builder: (context, userList) {
        if (userList == null) {
          return const _ListNotFoundScaffold();
        }
        final followRepository = ref.read(followRepositoryProvider);
        final profileRepository = ref.read(profileRepositoryProvider);
        return BlocProvider<AddPeopleToListCubit>(
          create: (_) {
            final cubit = AddPeopleToListCubit(
              followRepository: followRepository,
              profileRepository: profileRepository,
            );
            runDetached(
              cubit.started(),
              'load people list candidates',
              logName: 'AddPeopleToListScreen',
              category: LogCategory.ui,
            );
            return cubit;
          },
          child: AddPeopleToListView(userList: userList),
        );
      },
    );
  }
}

class _ListNotFoundScaffold extends StatelessWidget {
  const _ListNotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsAddPeopleTitle,
        showBackButton: true,
        onBackPressed: context.safePop,
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.peopleListsListNotFoundSubtitle,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

/// View layer of [AddPeopleToListScreen].
///
/// Reads candidates from the ambient [AddPeopleToListCubit] and membership
/// from the ambient [PeopleListsBloc]. Holds no Riverpod references — the
/// enclosing page owns repository lookups. Marked [visibleForTesting] so
/// widget tests can pump the view directly with a mock cubit rather than
/// seeding real repositories.
@visibleForTesting
class AddPeopleToListView extends StatefulWidget {
  /// Creates the view. [userList] is the target list being edited.
  const AddPeopleToListView({required this.userList, super.key});

  /// Target list named in the app bar and edited by every row action.
  final UserList userList;

  @override
  State<AddPeopleToListView> createState() => _AddPeopleToListViewState();
}

class _AddPeopleToListViewState extends State<AddPeopleToListView> {
  late final String? _openingOwner;

  @override
  void initState() {
    super.initState();
    _openingOwner = context.read<PeopleListsBloc>().state.activeOwnerPubkey;
  }

  @override
  Widget build(BuildContext context) {
    final userList = widget.userList;
    final l10n = context.l10n;
    return BlocListener<PeopleListsBloc, PeopleListsState>(
      // Repository updates can reset submitting to ready before a write fails.
      listenWhen: (previous, current) =>
          previous.status != PeopleListsStatus.failure &&
          current.status == PeopleListsStatus.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.peopleListsMembershipUpdateFailed),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: context.vineColors.surface,
        appBar: DiVineAppBar(
          titleWidget: FollowerCountTitle<PeopleListsBloc, PeopleListsState>(
            title: l10n.peopleListsAddToListName(userList.name),
            selector: (state) => _memberCount(state, userList.id),
            countLabel: (context, count) => context.l10n.listMemberCount(count),
          ),
          showBackButton: true,
          // The add-people link and a web reload open this route as the only
          // entry, so a raw pop would leave no page to show.
          onBackPressed: context.safePop,
          backButtonSemanticLabel: l10n.commonBack,
        ),
        body: Column(
          children: [
            const _SearchField(),
            Expanded(
              child: _Body(
                listId: userList.id,
                openingOwnerPubkey: _openingOwner,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int _memberCount(PeopleListsState state, String listId) {
    for (final list in state.lists) {
      if (list.id == listId) return list.pubkeys.length;
    }
    return 0;
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DivineSearchBar(
        controller: _controller,
        hintText: context.l10n.peopleListsAddPeopleSearchHint,
        onChanged: context.read<AddPeopleToListCubit>().queryChanged,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.listId, required this.openingOwnerPubkey});

  final String listId;
  final String? openingOwnerPubkey;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (AddPeopleToListCubit c) => c.state.status,
    );

    return switch (status) {
      AddPeopleToListStatus.initial ||
      AddPeopleToListStatus.loading => const _LoadingState(),
      AddPeopleToListStatus.failure => const _FailureState(),
      AddPeopleToListStatus.ready => _ReadyBody(
        listId: listId,
        openingOwnerPubkey: openingOwnerPubkey,
      ),
    };
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator());
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.peopleListsAddPeopleError,
              textAlign: TextAlign.center,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            DivineButton(
              label: context.l10n.peopleListsAddPeopleRetry,
              onPressed: context.read<AddPeopleToListCubit>().retryRequested,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyBody extends StatelessWidget {
  const _ReadyBody({required this.listId, required this.openingOwnerPubkey});

  final String listId;
  final String? openingOwnerPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AddPeopleToListCubit, AddPeopleToListState>(
      builder: (context, state) {
        final visible = state.visibleCandidates;
        final Widget child;
        if (state.candidates.isEmpty) {
          child = _ScrollableMessage(context.l10n.peopleListsNoPeopleToAdd);
        } else if (visible.isEmpty) {
          child = _ScrollableMessage(
            context.l10n.searchNoResultsFound(state.query),
          );
        } else {
          child = ListView.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) => _CandidateRow(
              candidate: visible[index],
              listId: listId,
              openingOwnerPubkey: openingOwnerPubkey,
              index: index,
            ),
          );
        }
        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          onRefresh: context.read<AddPeopleToListCubit>().started,
          // Every branch scrolls, so the pull gesture survives an empty
          // candidate set and a query that hides every row.
          child: child,
        );
      },
    );
  }
}

/// A centred message that still scrolls, so the enclosing [RefreshIndicator]
/// has a gesture to attach to when there are no rows to show.
class _ScrollableMessage extends StatelessWidget {
  const _ScrollableMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: VineTheme.bodyMediumFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One candidate, drawn by the Following screen's tile with that screen's
/// add/remove button in place of the follow one.
class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.listId,
    required this.openingOwnerPubkey,
    required this.index,
  });

  final PeopleListCandidate candidate;
  final String listId;
  final String? openingOwnerPubkey;
  final int index;

  void _toggleMembership(BuildContext context) {
    final bloc = context.read<PeopleListsBloc>();
    final current = bloc.state;
    if (openingOwnerPubkey == null ||
        openingOwnerPubkey != current.activeOwnerPubkey ||
        !current.lists.any(
          (list) => list.id == listId && list.isEditable,
        )) {
      return;
    }
    // Main serializes add() mutations through submit() and its owner/session
    // fence, preserving the operation's confirmed result and rollback.
    bloc.add(
      PeopleListsPubkeyToggleRequested(
        listId: listId,
        pubkey: candidate.pubkey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = candidate.pubkey;
    // Membership is the bloc's, not the cubit's: the optimistic add lands
    // here the moment it is emitted, and a rollback takes it away again.
    final isMember = context.select(
      (PeopleListsBloc bloc) =>
          bloc.state.listIdsByPubkey[pubkey]?.contains(listId) ?? false,
    );
    return UserProfileTile(
      pubkey: pubkey,
      index: index,
      onTap: () => context.pushOtherProfile(pubkey),
      showFollowButton: false,
      showAddToListButton: false,
      trailing: _MembershipButton(
        isMember: isMember,
        displayName:
            candidate.displayName ?? UserProfile.defaultDisplayNameFor(pubkey),
        onPressed: () => _toggleMembership(context),
      ),
    );
  }
}

/// The Following screen's follow/unfollow button, repurposed: green chip to
/// add, muted outline to remove, both at the chip's size so a row does not
/// change shape when it flips. Removal needs no confirmation here — a second
/// tap puts the person straight back.
class _MembershipButton extends StatelessWidget {
  const _MembershipButton({
    required this.isMember,
    required this.displayName,
    required this.onPressed,
  });

  final bool isMember;
  final String displayName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (isMember) {
      return DivineIconButton(
        icon: .userMinus,
        type: .secondary,
        size: .small,
        semanticIdentifier: 'remove_person_from_list',
        semanticLabel: l10n.peopleListsRemovePersonSemanticLabel(displayName),
        onPressed: onPressed,
      );
    }
    return DivineIconButton(
      icon: .userPlus,
      size: .small,
      semanticIdentifier: 'add_person_to_list',
      semanticLabel: l10n.peopleListsAddPersonSemanticLabel(displayName),
      onPressed: onPressed,
    );
  }
}
