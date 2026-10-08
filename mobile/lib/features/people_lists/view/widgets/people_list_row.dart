// ABOUTME: Row widget that toggles a pubkey's membership in a people list.
// ABOUTME: Uses BlocSelector so a tap rebuilds only the affected row.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/widgets/people_list_result_notice.dart';
import 'package:openvine/l10n/l10n.dart';

/// A tappable row representing a single people list inside the
/// [AddToPeopleListsSheet]. Shows a checkbox on the left that reflects
/// whether [pubkey] is currently a member of the list identified by
/// [listId], and the list's display name on the right.
///
/// Tapping the row dispatches [PeopleListsPubkeyToggleRequested] to the
/// ambient [PeopleListsBloc].
class PeopleListRow extends StatefulWidget {
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
  State<PeopleListRow> createState() => _PeopleListRowState();
}

class _PeopleListRowState extends State<PeopleListRow> {
  bool _pending = false;
  PeopleListsOperationResult? _result;
  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = context.read<PeopleListsBloc>().state.activeOwnerPubkey;
  }

  Future<void> _toggle() async {
    final bloc = context.read<PeopleListsBloc>();
    if (_pending) return;
    if (_owner == null || _owner != bloc.state.activeOwnerPubkey) {
      setState(() => _result = PeopleListsOperationResult.cancelled);
      return;
    }
    setState(() {
      _pending = true;
      _result = null;
    });
    final result = await bloc.submit(
      PeopleListsPubkeyToggleRequested(
        listId: widget.listId,
        pubkey: widget.pubkey,
      ),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Select only the membership bit so unrelated state changes do not
    // rebuild this row.
    final isMember = context.select<PeopleListsBloc, bool>(
      (bloc) =>
          bloc.state.listIdsByPubkey[widget.pubkey]?.contains(widget.listId) ??
          false,
    );

    return Semantics(
      button: true,
      selected: isMember,
      label: widget.listName,
      child: InkWell(
        onTap: _pending ? null : _toggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                if (_pending)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: DivineCircularProgressIndicator(),
                  )
                else
                  DivineSpriteCheckbox(
                    state: isMember
                        ? DivineCheckboxState.selected
                        : DivineCheckboxState.unselected,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.listName,
                        style: VineTheme.titleMediumFont(
                          color: context.vineColors.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      PeopleListResultNotice(
                        result: _result,
                        failedMessage: context.l10n.listUpdateFailed,
                      ),
                    ],
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
