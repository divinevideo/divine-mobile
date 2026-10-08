// ABOUTME: State for the sheet that picks which of the viewer's people lists
// ABOUTME: hold a person: which hold them now and which are picked.

import 'package:equatable/equatable.dart';

class PeopleListPicksState extends Equatable {
  const PeopleListPicksState({
    required this.memberListIds,
    required this.selectedListIds,
  });

  /// Ids of the lists that hold the person now.
  final Set<String> memberListIds;

  /// Ids of the lists picked to hold the person; opens as [memberListIds].
  final Set<String> selectedListIds;

  /// Whether the list with [listId] is picked.
  bool isSelected(String listId) => selectedListIds.contains(listId);

  /// Ids of the lists the person is added to when the picks are applied.
  Set<String> get listIdsToAdd => selectedListIds.difference(memberListIds);

  /// Ids of the lists the person is removed from when the picks are applied.
  Set<String> get listIdsToRemove => memberListIds.difference(selectedListIds);

  /// Whether the picks can be applied: a list is picked, or one that holds
  /// the person is unpicked.
  bool get canApply => selectedListIds.isNotEmpty || listIdsToRemove.isNotEmpty;

  PeopleListPicksState copyWith({
    Set<String>? memberListIds,
    Set<String>? selectedListIds,
  }) {
    return PeopleListPicksState(
      memberListIds: memberListIds ?? this.memberListIds,
      selectedListIds: selectedListIds ?? this.selectedListIds,
    );
  }

  @override
  List<Object?> get props => [memberListIds, selectedListIds];
}
