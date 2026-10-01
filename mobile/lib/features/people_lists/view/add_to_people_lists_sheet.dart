// ABOUTME: Bottom sheet that picks which of the user's editable people lists
// ABOUTME: hold a person; the check applies the picks through PeopleListsBloc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/modal_pop_extension.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_cubit.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/curated_lists_gate.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/widgets/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
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
/// pre-seed the new list with [initialCollaborator] when provided.
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

    final l10n = context.l10n;
    // The body seeds the picks from the bloc as it mounts, in the same
    // frame it starts following it, so no membership change can fall
    // between the two.
    final cubit = PeopleListPicksCubit(memberListIds: const {});
    final bodyKey = GlobalKey();
    try {
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
        trailing: _ApplyButton(pubkey: pubkey),
        contentWrapper: (_, sheet) => BlocProvider<PeopleListPicksCubit>.value(
          value: cubit,
          child: sheet,
        ),
        bottomInput: _CreateNewListButton(
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
    } finally {
      await cubit.close();
    }
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
      listenWhen: (previous, current) =>
          previous.listIdsByPubkey[pubkey] != current.listIdsByPubkey[pubkey],
      listener: (context, state) => _syncPicks(state),
      child: editableLists.isEmpty
          ? const _EmptyListRows()
          // The sheet's own surface sits above the modal's Material, so the
          // rows need a transparent one of their own for their ink to show.
          : Material(
              type: MaterialType.transparency,
              child: ListView.builder(
                controller: widget.scrollController,
                padding: EdgeInsets.zero,
                itemCount: editableLists.length,
                itemBuilder: (context, index) =>
                    PeopleListRow(list: editableLists[index]),
              ),
            ),
    );
  }
}

/// The header's check button: applies the picks and closes the sheet.
///
/// Each add and remove goes to [PeopleListsBloc] as its own event, which
/// applies it optimistically and rolls it back if the relay refuses, the
/// same way a tap used to.
class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.pubkey});

  final String pubkey;

  void _apply(BuildContext context) {
    final picks = context.read<PeopleListPicksCubit>().state;
    final bloc = context.read<PeopleListsBloc>();
    final offered = {
      for (final list in bloc.state.lists)
        if (list.isEditable) list.id,
    };
    for (final listId in picks.listIdsToAdd.intersection(offered)) {
      bloc.add(PeopleListsPubkeyAddRequested(listId: listId, pubkey: pubkey));
    }
    for (final listId in picks.listIdsToRemove.intersection(offered)) {
      bloc.add(
        PeopleListsPubkeyRemoveRequested(listId: listId, pubkey: pubkey),
      );
    }
    context.popModalIfMounted();
  }

  @override
  Widget build(BuildContext context) {
    // Disabled until at least one list is picked.
    final canApply = context.select(
      (PeopleListPicksCubit cubit) => cubit.state.selectedListIds.isNotEmpty,
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
  const _CreateNewListButton({this.initialCollaborator});

  final UserProfile? initialCollaborator;

  @override
  Widget build(BuildContext context) {
    return ListPickerCreateButton(
      onPressed: () => showNewPeopleListSheet(
        context,
        initialCollaborator: initialCollaborator,
      ),
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
