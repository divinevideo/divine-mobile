// ABOUTME: Cubit for the sheet that picks which of the viewer's people lists
// ABOUTME: hold a person: holds the picks until the sheet applies them.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/features/people_lists/bloc/people_list_picks_state.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

export 'package:openvine/features/people_lists/bloc/people_list_picks_state.dart';

/// Drives the sheet that picks which of the viewer's people lists hold a
/// person.
///
/// One instance lives for one visit to the sheet. The picks stay here until
/// the sheet's check applies them through [PeopleListsBloc], so one visit
/// can put a person in several lists; the X discards them. Membership is
/// fed in from that bloc's state, so a list created from the sheet with the
/// person in it shows up already picked. What the check sent is recorded
/// too, so the sheet's opener can report a refusal after the sheet closed.
class PeopleListPicksCubit extends Cubit<PeopleListPicksState>
    with CloseGuardedEmit<PeopleListPicksState> {
  /// Creates the cubit for one visit, with the lists holding the person.
  PeopleListPicksCubit({required Set<String> memberListIds})
    : super(
        PeopleListPicksState(
          memberListIds: memberListIds,
          selectedListIds: memberListIds,
        ),
      );

  /// Picks the list with [listId], or unpicks it when it is picked.
  void toggled(String listId) {
    final selected = {...state.selectedListIds};
    if (!selected.add(listId)) selected.remove(listId);
    emitIfOpen(state.copyWith(selectedListIds: selected));
  }

  /// Records that the picks were sent to the bloc, with the outcome the bloc
  /// held at that moment, so the one it records for these picks can be told
  /// apart once the sheet has closed.
  void applied({required PeopleListsPicksOutcome? before}) {
    emitIfOpen(state.copyWith(applied: PeopleListPicksApplied(before: before)));
  }

  /// Follows the lists that hold the person.
  ///
  /// A list that gained the person since the last look is picked and one
  /// that lost them is unpicked; every other pick stands.
  void membershipChanged(Set<String> memberListIds) {
    final gained = memberListIds.difference(state.memberListIds);
    final lost = state.memberListIds.difference(memberListIds);
    emitIfOpen(
      state.copyWith(
        memberListIds: memberListIds,
        selectedListIds: state.selectedListIds.union(gained).difference(lost),
      ),
    );
  }
}
