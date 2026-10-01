// ABOUTME: Row widget for one people list in the add-to-list sheet: the
// ABOUTME: list's collage, name and member count, and a check when picked.

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/divine_list_thumbnail.dart';
import 'package:openvine/widgets/list_picker_row.dart';

/// A tappable row for a single people list inside the
/// [AddToPeopleListsSheet]; needs a [PeopleListPicksCubit] above it.
///
/// Shows the list's member collage, its name and its member count, with a
/// check at the end while the list is picked. Tapping the row toggles the
/// pick; nothing is written until the sheet's check applies the picks.
class PeopleListRow extends StatelessWidget {
  /// Creates a row widget for [list].
  const PeopleListRow({required this.list, super.key});

  /// The list this row represents.
  final UserList list;

  @override
  Widget build(BuildContext context) {
    // Select only the pick so unrelated picks do not rebuild this row.
    final isSelected = context.select(
      (PeopleListPicksCubit cubit) => cubit.state.isSelected(list.id),
    );
    return ListPickerRow(
      media: DivineListMedia.people(
        memberPubkeys: list.pubkeys,
        showCount: false,
      ),
      title: list.name,
      meta: context.l10n.listMemberCount(list.pubkeys.length),
      isSelected: isSelected,
      onTap: () => context.read<PeopleListPicksCubit>().toggled(list.id),
    );
  }
}
