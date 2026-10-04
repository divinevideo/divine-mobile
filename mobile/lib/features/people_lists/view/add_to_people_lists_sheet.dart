// ABOUTME: Bottom sheet that picks which of the user's editable people lists
// ABOUTME: hold a person; the check applies the picks through PeopleListsBloc.

import 'package:collection/collection.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_outcome.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/curated_lists_gate.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/widgets/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/list_info_sheet/list_info_sheet.dart';
import 'package:openvine/widgets/list_picker_create_button.dart';
import 'package:openvine/widgets/profile/new_people_list_sheet.dart';

/// Bottom sheet that displays the authenticated user's editable people
/// lists and lets them pick which ones hold the given [pubkey].
///
/// Rows are picked and unpicked freely; the check in the header applies
/// every pick through [PeopleListsBloc] at once, so one visit can put a
/// person in several lists, and the X discards them. The picks live in a
/// [PeopleListPicksCubit] that [AddToPeopleListsSheet.show] owns and the
/// body needs above it.
///
/// Consumers should call [AddToPeopleListsSheet.show] from within a
/// subtree that has a [PeopleListsBloc] provided above it. Callers should
/// also hide their affordance when [FeatureFlag.curatedLists] is off;
/// [AddToPeopleListsSheet.show] enforces the same gate as a backstop.
///
/// The sheet filters out read-only lists (`isEditable == false`). When
/// there are no editable lists, an empty state offers a `Create list`
/// affordance. When lists do exist, the list rows are scrollable and a
/// "Create new list" button is pinned floating at the bottom. Both paths
/// pre-seed the new list with [pubkey], independently of optional metadata.
class AddToPeopleListsSheet extends StatefulWidget {
  /// Creates the sheet widget.
  const AddToPeopleListsSheet({
    required this.pubkey,
    required this.entryPoint,
    this.displayName,
    this.initialCollaborator,
    this.scrollController,
    super.key,
  });

  /// The full hex pubkey whose list membership is being edited. The
  /// pubkey is never truncated in storage, dispatched events, or logs.
  final String pubkey;

  /// Identifies which UI surface triggered this sheet, for analytics and
  /// copy that may branch on the source.
  final PeopleListEntryPoint entryPoint;

  /// Optional display name for the person. Only used for layout copy;
  /// the underlying [pubkey] is always the source of truth.
  final String? displayName;

  /// When set, the "Create new list" sheet opens pre-seeded with this
  /// profile as the first collaborator.
  final UserProfile? initialCollaborator;

  /// Shows the sheet as a modal [VineBottomSheet].
  ///
  /// Does nothing when [FeatureFlag.curatedLists] is off. The global
  /// [PeopleListsBloc] is registered unconditionally and lazily, so opening
  /// this sheet is what would construct it — starting a relay query and cache
  /// subscription for a feature the user turned off.
  ///
  /// Returns a [Future] that completes when the sheet is dismissed.
  static Future<void> show(
    BuildContext context, {
    required String pubkey,
    required PeopleListEntryPoint entryPoint,
    String? displayName,
    UserProfile? initialCollaborator,
  }) async {
    if (!curatedListsEnabled(context)) return;

    final session = _PickerSession(
      context.read<PeopleListsBloc>(),
      ProviderScope.containerOf(context, listen: false),
    );
    if (!session.isAuthCurrent || !session.isCurrent(context)) return;
    final l10n = context.l10n;
    // Resolved before the sheet opens: the screen that opened it may be
    // gone by the time a refusal is known.
    final messenger = ScaffoldMessenger.maybeOf(context);
    // The body seeds the picks from the bloc as it mounts, in the same
    // frame it starts following it, so no membership change can fall
    // between the two.
    Future<PeopleListsOperationResult>? pendingOutcome;
    final bodyKey = GlobalKey();
    await VineBottomSheet.show<void>(
      context: context,
      title: Text(l10n.listAddToLists),
      headerPadding: listInfoSheetHeaderPadding,
      headerLeadingAction: DivineIconButton(
        icon: DivineIconName.x,
        type: DivineIconButtonType.secondary,
        size: DivineIconButtonSize.small,
        semanticLabel: l10n.commonClose,
        // The body's context belongs to the sheet's own route, so the pop
        // is skipped once that route is already on its way out.
        onPressed: () => bodyKey.currentContext?.popModalIfMounted(),
      ),
      trailing: _ApplyButton(
        pubkey: pubkey,
        session: session,
        onApplied: (outcome) => pendingOutcome = outcome,
      ),
      contentWrapper: (_, sheet) => BlocProvider<PeopleListPicksCubit>(
        create: (_) => PeopleListPicksCubit(memberListIds: const {}),
        child: sheet,
      ),
      bottomInput: _CreateNewListButton(
        pubkey: pubkey,
        session: session,
        initialCollaborator: initialCollaborator,
      ),
      buildScrollBody: (scrollController) => AddToPeopleListsSheet(
        key: bodyKey,
        pubkey: pubkey,
        entryPoint: entryPoint,
        displayName: displayName,
        initialCollaborator: initialCollaborator,
        scrollController: scrollController,
      ),
    );
    if (pendingOutcome case final outcome?) {
      // The sheet closed as soon as the picks were sent; the bloc rolls a
      // refused one back on its own, and this is what says so.
      runDetached(
        _reportRefusedPicks(
          refusedPicks: outcome,
          messenger: messenger,
          failedMessage: l10n.peopleListsMembershipUpdateFailed,
          cancelledMessage: l10n.peopleListsSessionChanged,
          isSessionCurrent: () => session.isAuthCurrent,
        ),
        'report refused people list picks',
        logName: 'AddToPeopleListsSheet',
        category: LogCategory.ui,
      );
    }
  }

  static Future<void> _reportRefusedPicks({
    required Future<PeopleListsOperationResult> refusedPicks,
    required ScaffoldMessengerState? messenger,
    required String failedMessage,
    required String cancelledMessage,
    required bool Function() isSessionCurrent,
  }) async {
    final result = await refusedPicks;
    if (result == PeopleListsOperationResult.succeeded ||
        !isSessionCurrent() ||
        !(messenger?.mounted ?? false)) {
      return;
    }
    final message = result == PeopleListsOperationResult.cancelled
        ? cancelledMessage
        : failedMessage;
    messenger!.showSnackBar(
      DivineSnackbarContainer.snackBar(message, error: true),
    );
  }

  /// The sheet's scroll controller, so dragging the rows moves the sheet.
  final ScrollController? scrollController;

  @override
  State<AddToPeopleListsSheet> createState() => _AddToPeopleListsSheetState();
}

class _AddToPeopleListsSheetState extends State<AddToPeopleListsSheet> {
  @override
  void initState() {
    super.initState();
    // Membership belongs to the global bloc; the picks open on it here and
    // follow it below, so a list created from the sheet with the person in
    // it shows up picked.
    _syncPicks(context.read<PeopleListsBloc>().state);
  }

  void _syncPicks(PeopleListsState state) {
    context.read<PeopleListPicksCubit>().membershipChanged(
      state.listIdsByPubkey[widget.pubkey] ?? const {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final pubkey = widget.pubkey;
    final editableLists = context.select<PeopleListsBloc, List<UserList>>(
      (bloc) => bloc.state.lists
          .where((list) => list.isEditable)
          .toList(growable: false),
    );

    return BlocListener<PeopleListsBloc, PeopleListsState>(
      // The bloc rebuilds its index on every lists emission, so the sets are
      // new objects each time; only their contents say whether this
      // person's membership moved.
      listenWhen: (previous, current) => !const SetEquality<String>().equals(
        previous.listIdsByPubkey[pubkey] ?? const {},
        current.listIdsByPubkey[pubkey] ?? const {},
      ),
      listener: (context, state) => _syncPicks(state),
      child: _PeopleListRows(
        editableLists: editableLists,
        pubkey: pubkey,
        scrollController: widget.scrollController,
      ),
    );
  }
}

class _PeopleListRows extends StatelessWidget {
  const _PeopleListRows({
    required this.editableLists,
    required this.pubkey,
    required this.scrollController,
  });

  final List<UserList> editableLists;
  final String pubkey;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PeopleListsBloc>().state;
    if (editableLists.isEmpty && !state.listsKnown) {
      if (state.ownerReadStatus == PeopleListsOwnerReadStatus.failed) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.peopleListsLoadFailed),
            DivineButton(
              label: context.l10n.peopleListsAddPeopleRetry,
              onPressed: () => context.read<PeopleListsBloc>().add(
                const PeopleListsOwnerSyncRequested(),
              ),
            ),
          ],
        );
      }
      return const Center(child: DivineCircularProgressIndicator());
    }
    if (editableLists.isEmpty) return const _EmptyListRows();
    return Material(
      type: MaterialType.transparency,
      child: ListView.builder(
        key: ValueKey((state.activeOwnerPubkey, pubkey)),
        controller: scrollController,
        findChildIndexCallback: (key) {
          final index = editableLists.indexWhere(
            (list) => ValueKey(list.id) == key,
          );
          return index < 0 ? null : index;
        },
        padding: EdgeInsets.zero,
        itemCount: editableLists.length,
        itemBuilder: (context, index) {
          final list = editableLists[index];
          return PeopleListRow(key: ValueKey(list.id), list: list);
        },
      ),
    );
  }
}

/// The header's check button: applies the picks and closes the sheet.
///
/// The picks go to [PeopleListsBloc] as one [PeopleListsPicksApplied]; the
/// bloc applies each optimistically, rolls back any a relay refuses, and
/// records the outcome, which the sheet's opener reports on the screen
/// underneath, since the sheet is gone by then.
class _ApplyButton extends StatelessWidget {
  const _ApplyButton({
    required this.pubkey,
    required this.session,
    required this.onApplied,
  });

  final String pubkey;
  final _PickerSession session;
  final ValueChanged<Future<PeopleListsOperationResult>> onApplied;

  void _apply(BuildContext context) {
    if (!session.isAuthCurrent) return;
    final cubit = context.read<PeopleListPicksCubit>();
    final bloc = context.read<PeopleListsBloc>();
    if (!session.isCurrent(context)) {
      onApplied(Future.value(PeopleListsOperationResult.cancelled));
      context.popModalIfMounted();
      return;
    }
    final offered = {
      for (final list in bloc.state.lists)
        if (list.isEditable) list.id,
    };
    final addListIds = cubit.state.listIdsToAdd.intersection(offered);
    final removeListIds = cubit.state.listIdsToRemove.intersection(offered);
    final ownerPubkey = bloc.state.activeOwnerPubkey;
    if (ownerPubkey != null &&
        (addListIds.isNotEmpty || removeListIds.isNotEmpty)) {
      final request = PeopleListsPicksApplied(
        requestId: Object(),
        ownerPubkey: ownerPubkey,
        pubkey: pubkey,
        addListIds: addListIds,
        removeListIds: removeListIds,
      );
      final before = bloc.state.lastPicksOutcome;
      final refusedPicks = awaitRefusedPicks(
        states: bloc.stream,
        requestId: request.requestId,
        ownerPubkey: ownerPubkey,
        before: before,
        pubkey: pubkey,
      );
      onApplied(_awaitResult(bloc.submit(request), refusedPicks));
    }
    context.popModalIfMounted();
  }

  Future<PeopleListsOperationResult> _awaitResult(
    Future<PeopleListsOperationResult> completion,
    Future<int> refusedPicks,
  ) async {
    final result = await completion;
    if (result != PeopleListsOperationResult.succeeded) return result;
    return await refusedPicks == 0
        ? PeopleListsOperationResult.succeeded
        : PeopleListsOperationResult.failed;
  }

  @override
  Widget build(BuildContext context) {
    // Disabled while no list is picked and none that holds the person is
    // unpicked.
    final canApply = context.select(
      (PeopleListPicksCubit cubit) => cubit.state.canApply,
    );
    return ListInfoCheckButton(
      semanticLabel: context.l10n.listDone,
      isSaving: false,
      onPressed: canApply ? () => _apply(context) : null,
    );
  }
}

/// The "Create New List" button pinned to the bottom of the sheet.
class _CreateNewListButton extends StatelessWidget {
  const _CreateNewListButton({
    required this.pubkey,
    required this.session,
    this.initialCollaborator,
  });

  final String pubkey;
  final _PickerSession session;

  final UserProfile? initialCollaborator;

  @override
  Widget build(BuildContext context) {
    return ListPickerCreateButton(
      onPressed: () {
        if (!session.isAuthCurrent) return;
        if (!session.isCurrent(context)) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.peopleListsSessionChanged,
              error: true,
            ),
          );
          return;
        }
        runDetached(
          showNewPeopleListSheet(
            context,
            initialCollaborator: initialCollaborator,
            initialPubkey: pubkey,
          ),
          'open people list creation sheet',
          logName: 'AddToPeopleListsSheet',
          category: LogCategory.ui,
        );
      },
    );
  }
}

/// Shown when there are no editable lists yet — empty hint text only.
/// The create button is always visible in the pinned bottom slot.
class _EmptyListRows extends StatelessWidget {
  const _EmptyListRows();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.peopleListsEmptyTitle,
            textAlign: TextAlign.center,
            style: VineTheme.titleMediumFont(
              color: context.vineColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.peopleListsEmptySubtitle,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

/// The opening account and mutation epoch belong to one picker visit.
class _PickerSession {
  _PickerSession(this.bloc, this.container)
    : ownerPubkey = bloc.state.activeOwnerPubkey,
      epoch = bloc.mutationSessionEpoch;

  final PeopleListsBloc bloc;
  final ProviderContainer container;
  final String? ownerPubkey;
  final int epoch;

  bool get isAuthCurrent =>
      ownerPubkey != null &&
      ownerPubkey!.isNotEmpty &&
      container.read(authServiceProvider).currentPublicKeyHex == ownerPubkey;

  bool isCurrent(BuildContext context) =>
      curatedListsEnabled(context) &&
      identical(context.read<PeopleListsBloc>(), bloc) &&
      bloc.mutationSessionEpoch == epoch &&
      bloc.state.activeOwnerPubkey == ownerPubkey;
}
