// ABOUTME: State for CuratedListInfoCubit backing the list info sheet: the
// ABOUTME: form's values plus where its save stands.

import 'package:equatable/equatable.dart';

/// Where the list info form's save stands.
enum CuratedListInfoStatus {
  /// The form is open for edits.
  editing,

  /// A save is running and the form waits on its answer.
  saving,

  /// The edit is stored on this device and the form can close while relays answer.
  savedAwaitingRelay,

  /// The save landed.
  saved,

  /// The save failed; the form stays open so nothing typed is lost.
  failure,

  /// The edit is stored on this device but no relay accepted it.
  publishFailed,

  /// The list exists, but the video could not be added locally.
  createdWithoutVideo,

  /// The video is saved locally and awaits publication.
  createdWithVideoPendingSync,
}

/// State emitted by `CuratedListInfoCubit`.
class CuratedListInfoState extends Equatable {
  /// Creates an immutable state snapshot.
  const CuratedListInfoState({
    this.status = CuratedListInfoStatus.editing,
    this.name = '',
    this.description = '',
    this.isPublic = true,
    this.collaboratorPubkeys = const [],
    this.wasPublic,
  });

  /// Where the save stands.
  final CuratedListInfoStatus status;

  /// The list name as typed, untrimmed.
  final String name;

  /// The description as typed, untrimmed.
  final String description;

  /// Whether the list is, or is about to be, public.
  final bool isPublic;

  /// Full hex pubkeys of the people allowed to add to the list.
  final List<String> collaboratorPubkeys;

  /// Visibility of the list as it was opened, or null when creating one.
  final bool? wasPublic;

  /// Whether the form edits an existing list rather than creating one.
  bool get isEditing => wasPublic != null;

  /// Whether saving would flip an existing list's visibility.
  bool get visibilityWillChange => wasPublic != null && wasPublic != isPublic;

  /// Whether a save is running.
  bool get isSaving => status == CuratedListInfoStatus.saving;

  /// Whether the form can be submitted as it stands.
  bool get canSubmit => name.trim().isNotEmpty && !isSaving;

  /// Whether the form has nothing left to show and can close.
  bool get canClose =>
      status == CuratedListInfoStatus.saved ||
      status == CuratedListInfoStatus.savedAwaitingRelay ||
      status == CuratedListInfoStatus.createdWithoutVideo ||
      status == CuratedListInfoStatus.createdWithVideoPendingSync;

  /// Whether the list can carry collaborators.
  ///
  /// A private list's items are encrypted to its owner alone, so nobody else
  /// could add to it.
  bool get canHaveCollaborators => isPublic;

  /// The collaborators a save would store.
  List<String> get savedCollaboratorPubkeys =>
      canHaveCollaborators ? collaboratorPubkeys : const [];

  /// Copy with the given fields replaced.
  CuratedListInfoState copyWith({
    CuratedListInfoStatus? status,
    String? name,
    String? description,
    bool? isPublic,
    List<String>? collaboratorPubkeys,
  }) {
    return CuratedListInfoState(
      status: status ?? this.status,
      name: name ?? this.name,
      description: description ?? this.description,
      isPublic: isPublic ?? this.isPublic,
      collaboratorPubkeys: collaboratorPubkeys ?? this.collaboratorPubkeys,
      wasPublic: wasPublic,
    );
  }

  @override
  List<Object?> get props => [
    status,
    name,
    description,
    isPublic,
    collaboratorPubkeys,
    wasPublic,
  ];
}
