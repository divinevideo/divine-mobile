// ABOUTME: Full-screen picker for adding multiple people to an existing list.
// ABOUTME: Reads candidates from AddPeopleToListCubit and dispatches one add
// ABOUTME: request per selected pubkey through PeopleListsBloc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_cubit.dart';
import 'package:openvine/features/people_lists/bloc/add_people_to_list_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_candidate.dart';
import 'package:openvine/features/people_lists/view/widgets/person_pickable_row.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';

/// Full-screen picker that lets the authenticated user batch-add candidate
/// pubkeys to an existing people list.
///
/// The screen resolves the target [UserList] from the ambient
/// [PeopleListsBloc] by [listId], and seeds candidates by scoping a fresh
/// [AddPeopleToListCubit] to that list. Candidates are sourced from the
/// authenticated user's following and followers sets, not passed in.
/// Candidates already in the target list are rendered selected + disabled.
/// Tapping the pinned "Add N" button dispatches one
/// [PeopleListsPubkeyAddRequested] per selected pubkey, then pops.
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
          create: (_) => AddPeopleToListCubit(
            followRepository: followRepository,
            profileRepository: profileRepository,
            existingMemberPubkeys: userList.pubkeys,
          )..started(),
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
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsAddPeopleTitle,
        showBackButton: true,
        onBackPressed: context.pop,
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
/// Reads all data from the ambient [AddPeopleToListCubit] and
/// [PeopleListsBloc]. Holds no Riverpod references — the enclosing page
/// owns repository lookups. Marked [visibleForTesting] so widget tests can
/// pump the view directly with a mock cubit rather than seeding real
/// repositories.
@visibleForTesting
class AddPeopleToListView extends StatelessWidget {
  /// Creates the view. [userList] is the target list being edited.
  const AddPeopleToListView({required this.userList, super.key});

  /// Target list shown in the app bar and used to gate already-member rows.
  final UserList userList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.vineColors.background,
      appBar: DiVineAppBar(
        title: context.l10n.peopleListsAddToListName(userList.name),
        showBackButton: true,
        onBackPressed: context.pop,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _SearchField(),
            Expanded(child: _Body(userList: userList)),
            _AddButtonBar(listId: userList.id),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    context.read<AddPeopleToListCubit>().queryChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _controller,
        style: VineTheme.bodyMediumFont(color: context.vineColors.onSurface),
        decoration: InputDecoration(
          hintText: context.l10n.peopleListsAddPeopleSearchHint,
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12),
            child: DivineIcon(
              icon: DivineIconName.search,
              color: context.vineColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.userList});

  final UserList userList;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (AddPeopleToListCubit c) => c.state.status,
    );

    return switch (status) {
      AddPeopleToListStatus.initial ||
      AddPeopleToListStatus.loading => const _LoadingState(),
      AddPeopleToListStatus.failure => const _FailureState(),
      AddPeopleToListStatus.ready => _ReadyBody(userList: userList),
    };
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: DivineCircularProgressIndicator());
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
  const _ReadyBody({required this.userList});

  final UserList userList;

  @override
  Widget build(BuildContext context) {
    final visible = context.select(
      (AddPeopleToListCubit c) => c.state.visibleCandidates,
    );

    if (visible.isEmpty) {
      return const _EmptyCandidatesState();
    }

    return _CandidateList(userList: userList, candidates: visible);
  }
}

class _EmptyCandidatesState extends StatelessWidget {
  const _EmptyCandidatesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.l10n.peopleListsNoPeopleToAdd,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _CandidateList extends StatelessWidget {
  const _CandidateList({required this.userList, required this.candidates});

  final UserList userList;
  final List<PeopleListCandidate> candidates;

  @override
  Widget build(BuildContext context) {
    final selected = context.select(
      (AddPeopleToListCubit c) => c.state.selectedPubkeys,
    );

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: candidates.length,
      itemBuilder: (context, index) {
        final candidate = candidates[index];
        final isMember = candidate.isAlreadyInList;
        final isSelected = isMember || selected.contains(candidate.pubkey);

        return PersonPickableRow(
          candidate: candidate,
          isSelected: isSelected,
          enabled: !isMember,
          onTap: () => context.read<AddPeopleToListCubit>().candidateToggled(
            candidate.pubkey,
          ),
        );
      },
    );
  }
}

class _AddButtonBar extends StatelessWidget {
  const _AddButtonBar({required this.listId});

  final String listId;

  @override
  Widget build(BuildContext context) {
    final selected = context.select(
      (AddPeopleToListCubit c) => c.state.selectedPubkeys,
    );

    final l10n = context.l10n;
    final count = selected.length;
    final label = count == 0
        ? l10n.peopleListsAddButton
        : l10n.peopleListsAddButtonWithCount(count);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: DivineButton(
        label: label,
        expanded: true,
        onPressed: count == 0 ? null : () => _submit(context, selected),
      ),
    );
  }

  void _submit(BuildContext context, Set<String> selected) {
    final bloc = context.read<PeopleListsBloc>();
    for (final pubkey in selected) {
      bloc.add(
        PeopleListsPubkeyAddRequested(listId: listId, pubkey: pubkey),
      );
    }
    // Use Navigator.maybePop so the screen works even when no GoRouter is
    // present (e.g., simple widget-test harnesses without MaterialApp.router).
    Navigator.of(context).maybePop();
  }
}
