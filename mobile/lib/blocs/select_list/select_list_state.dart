// ABOUTME: State for the sheet that picks which of the viewer's lists hold a
// ABOUTME: video: the lists on offer, the picks made, and where the save stands.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

/// Where the list picker's save stands.
enum SelectListStatus {
  /// The picks are open for changes.
  editing,

  /// The picks are being written to the lists.
  saving,

  /// Every pick reached its list, so the sheet can close.
  saved,

  /// At least one list refused the change; the picks stay so they can be
  /// retried.
  failure,

  /// Every failed change was an add to a private list that has no room left,
  /// which retrying cannot fix.
  failureListFull,

  /// A new list exists without the video.
  createdWithoutVideo,

  /// A sync attempt could not confirm publication of local membership.
  syncFailed,

  /// The video is saved locally and awaits relay publication.
  videoPendingSync,

  /// A confirmed permission change or deletion request needs local recovery.
  recoveryPendingSync,
}

class SelectListState extends Equatable {
  const SelectListState({
    required this.lists,
    required this.memberListIds,
    required this.selectedListIds,
    this.status = SelectListStatus.editing,
    this.syncingListIds = const {},
    this.failedSyncListIds = const {},
    this.recoveryReadOnly = false,
    this.serviceAvailable = true,
  });

  /// The lists the viewer can put the video in.
  final List<CuratedList> lists;

  /// Ids of the lists that hold the video now.
  final Set<String> memberListIds;

  /// Ids of the lists picked to hold the video; opens as [memberListIds].
  final Set<String> selectedListIds;

  final SelectListStatus status;

  /// Lists whose retry is currently awaiting a relay outcome.
  final Set<String> syncingListIds;

  /// Outstanding memberships whose latest retry did not confirm publication.
  final Set<String> failedSyncListIds;

  /// Saved recovery records must be verified before any changes are made.
  final bool recoveryReadOnly;

  /// Whether this picker is bound to the current initialized service.
  final bool serviceAvailable;

  bool get canEdit => serviceAvailable && !recoveryReadOnly && !isSaving;

  /// Whether the picks are being written.
  bool get isSaving => status == SelectListStatus.saving;

  /// Whether the picks can be written: no save is running, and a list is
  /// picked or one that holds the video is unpicked.
  bool get canSubmit =>
      canEdit && (selectedListIds.isNotEmpty || listIdsToRemove.isNotEmpty);

  /// Any pending list recovery; retry does not toggle the pick.
  Set<String> get pendingSyncListIds => {
    for (final list in lists)
      if (list.needsSync) list.id,
  };

  /// Whether the sheet has nothing left to show and can close.
  bool get canClose => status == SelectListStatus.saved;

  /// Whether the list with [listId] is picked.
  bool isSelected(String listId) => selectedListIds.contains(listId);

  /// Ids of the lists a save adds the video to.
  Set<String> get listIdsToAdd => selectedListIds.difference(memberListIds);

  /// Ids of the lists a save removes the video from.
  Set<String> get listIdsToRemove => memberListIds.difference(selectedListIds);

  SelectListState copyWith({
    List<CuratedList>? lists,
    Set<String>? memberListIds,
    Set<String>? selectedListIds,
    SelectListStatus? status,
    Set<String>? syncingListIds,
    Set<String>? failedSyncListIds,
    bool? recoveryReadOnly,
    bool? serviceAvailable,
  }) {
    return SelectListState(
      lists: lists ?? this.lists,
      memberListIds: memberListIds ?? this.memberListIds,
      selectedListIds: selectedListIds ?? this.selectedListIds,
      status: status ?? this.status,
      syncingListIds: syncingListIds ?? this.syncingListIds,
      failedSyncListIds: failedSyncListIds ?? this.failedSyncListIds,
      recoveryReadOnly: recoveryReadOnly ?? this.recoveryReadOnly,
      serviceAvailable: serviceAvailable ?? this.serviceAvailable,
    );
  }

  @override
  List<Object?> get props => [
    lists,
    memberListIds,
    selectedListIds,
    status,
    syncingListIds,
    failedSyncListIds,
    recoveryReadOnly,
    serviceAvailable,
  ];
}
