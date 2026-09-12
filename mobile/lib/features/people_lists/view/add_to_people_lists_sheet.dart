// ABOUTME: Bottom sheet to add/remove a pubkey across the user's editable
// ABOUTME: people lists. Routes taps through PeopleListsBloc.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/curated_lists_gate.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/widgets/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/new_people_list_sheet.dart';

/// Bottom sheet that displays the authenticated user's editable people
/// lists and lets them toggle membership for the given [pubkey].
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
class AddToPeopleListsSheet extends StatelessWidget {
  /// Creates the sheet widget.
  const AddToPeopleListsSheet({
    required this.pubkey,
    required this.entryPoint,
    this.displayName,
    this.initialCollaborator,
    super.key,
  });

  /// The full hex pubkey whose list membership is being edited. The
  /// pubkey is never truncated in storage, dispatched events, or logs.
  final String pubkey;

  /// Identifies which UI surface triggered this sheet. Threaded through
  /// to child rows so analytics and future copy can branch on source.
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
  }) {
    if (!curatedListsEnabled(context)) return Future<void>.value();

    return VineBottomSheet.show<void>(
      context: context,
      title: Text(context.l10n.peopleListsSheetTitle),
      bottomInput: _CreateNewListButton(
        initialCollaborator: initialCollaborator,
      ),
      buildScrollBody: (scrollController) => AddToPeopleListsSheet(
        pubkey: pubkey,
        entryPoint: entryPoint,
        displayName: displayName,
        initialCollaborator: initialCollaborator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editableLists = context.select<PeopleListsBloc, List<UserList>>(
      (bloc) => bloc.state.lists
          .where((list) => list.isEditable)
          .toList(growable: false),
    );

    if (editableLists.isEmpty) {
      return const _EmptyListRows();
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: editableLists.length,
      itemBuilder: (context, index) {
        final list = editableLists[index];
        return PeopleListRow(
          listId: list.id,
          listName: list.name,
          pubkey: pubkey,
          entryPoint: entryPoint,
        );
      },
    );
  }
}

/// Floating "Create new list" button pinned to the bottom of the sheet.
class _CreateNewListButton extends StatelessWidget {
  const _CreateNewListButton({this.initialCollaborator});

  final UserProfile? initialCollaborator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: DivineButton(
        label: context.l10n.peopleListsCreateList,
        expanded: true,
        leadingIcon: DivineIconName.listPlus,
        type: DivineButtonType.secondary,
        onPressed: () => showNewPeopleListSheet(
          context,
          initialCollaborator: initialCollaborator,
        ),
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
