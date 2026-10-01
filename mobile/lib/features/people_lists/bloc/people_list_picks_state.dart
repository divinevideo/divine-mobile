// ABOUTME: State for the sheet that picks which of the viewer's people lists
// ABOUTME: hold a person: which hold them now and which are picked.

import 'package:equatable/equatable.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

class PeopleListPicksState extends Equatable {
  const PeopleListPicksState({
    required this.memberListIds,
    required this.selectedListIds,
    this.applied,
  });

  /// Ids of the lists that hold the person now.
  final Set<String> memberListIds;

  /// Ids of the lists picked to hold the person; opens as [memberListIds].
  final Set<String> selectedListIds;

  /// Set once the picks were sent to the bloc: the outcome the bloc held at
  /// that moment, or [PeopleListPicksApplied.none] when it held none. Null
  /// while nothing was sent, so there is no outcome to wait for.
  final PeopleListPicksApplied? applied;

  /// Whether the list with [listId] is picked.
  bool isSelected(String listId) => selectedListIds.contains(listId);

  /// Ids of the lists the person is added to when the picks are applied.
  Set<String> get listIdsToAdd => selectedListIds.difference(memberListIds);

  /// Ids of the lists the person is removed from when the picks are applied.
  Set<String> get listIdsToRemove => memberListIds.difference(selectedListIds);

  PeopleListPicksState copyWith({
    Set<String>? memberListIds,
    Set<String>? selectedListIds,
    PeopleListPicksApplied? applied,
  }) {
    return PeopleListPicksState(
      memberListIds: memberListIds ?? this.memberListIds,
      selectedListIds: selectedListIds ?? this.selectedListIds,
      applied: applied ?? this.applied,
    );
  }

  @override
  List<Object?> get props => [memberListIds, selectedListIds, applied];
}

/// The picks were sent; the bloc's outcome for them is the first one newer
/// than [before].
class PeopleListPicksApplied extends Equatable {
  /// Records the outcome the bloc held when the picks were sent.
  const PeopleListPicksApplied({required this.before});

  /// The bloc's last outcome at the moment of sending, if any.
  final PeopleListsPicksOutcome? before;

  @override
  List<Object?> get props => [before];
}
