// ABOUTME: Row widget that toggles a pubkey's membership in a people list.
// ABOUTME: Uses BlocSelector so a tap rebuilds only the affected row.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';

/// A tappable row representing a single people list inside the
/// [AddToPeopleListsSheet]. Shows a checkbox on the left that reflects
/// whether [pubkey] is currently a member of the list identified by
/// [listId], and the list's display name on the right.
///
/// Tapping the row dispatches [PeopleListsPubkeyToggleRequested] to the
/// ambient [PeopleListsBloc].
class PeopleListRow extends StatelessWidget {
  /// Creates a row widget for a single people list.
  const PeopleListRow({
    required this.listId,
    required this.listName,
    required this.pubkey,
    required this.entryPoint,
    super.key,
  });

  /// The full addressable id of the list this row represents.
  final String listId;

  /// The list's display name.
  final String listName;

  /// The full hex pubkey being added/removed. Never truncated.
  final String pubkey;

  /// Identifies which UI surface triggered the host sheet. Exposed so
  /// future analytics wiring can attribute toggle events to the source
  /// screen without the row needing to know about that surface directly.
  final PeopleListEntryPoint entryPoint;

  @override
  Widget build(BuildContext context) {
    // Select only the membership bit so unrelated state changes do not
    // rebuild this row.
    final isMember = context.select<PeopleListsBloc, bool>(
      (bloc) => bloc.state.listIdsByPubkey[pubkey]?.contains(listId) ?? false,
    );

    return Semantics(
      button: true,
      selected: isMember,
      label: listName,
      child: InkWell(
        onTap: () => context.read<PeopleListsBloc>().add(
          PeopleListsPubkeyToggleRequested(
            listId: listId,
            pubkey: pubkey,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                DivineSpriteCheckbox(
                  state: isMember
                      ? DivineCheckboxState.selected
                      : DivineCheckboxState.unselected,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    listName,
                    style: VineTheme.titleMediumFont(
                      color: context.vineColors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
