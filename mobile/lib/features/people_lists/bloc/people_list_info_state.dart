// ABOUTME: State for the sheet that edits a people list's info: the name and
// ABOUTME: description as typed, and where the save stands.

import 'package:equatable/equatable.dart';

/// Where the people list info form's save stands.
enum PeopleListInfoStatus {
  /// The form is open for edits.
  editing,

  /// A save is running and the form waits on its answer.
  saving,

  /// The save was submitted, so the form can close.
  saved,

  /// The save failed; the form stays open so nothing typed is lost.
  failure,
}

class PeopleListInfoState extends Equatable {
  const PeopleListInfoState({
    required this.name,
    required this.description,
    this.status = PeopleListInfoStatus.editing,
  });

  /// The list name as typed, untrimmed.
  final String name;

  /// The description as typed, untrimmed.
  final String description;

  final PeopleListInfoStatus status;

  /// Whether a save is running.
  bool get isSaving => status == PeopleListInfoStatus.saving;

  /// Whether the form can be submitted as it stands.
  bool get canSubmit => name.trim().isNotEmpty && !isSaving;

  /// Whether the form has nothing left to show and can close.
  bool get canClose => status == PeopleListInfoStatus.saved;

  PeopleListInfoState copyWith({
    String? name,
    String? description,
    PeopleListInfoStatus? status,
  }) {
    return PeopleListInfoState(
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [name, description, status];
}
