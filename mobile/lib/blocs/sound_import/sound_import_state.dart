// ABOUTME: State for the library sound import flow (pick a file, name it, save).
// ABOUTME: Tracks the copied-but-unsaved audio so cleanup can reclaim it.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/services/saved_sounds_service.dart';

enum SoundImportStatus {
  /// Nothing picked yet.
  idle,

  /// The picked file is being copied into library storage and probed.
  copying,

  /// A library-owned copy exists and can be previewed, named, and saved.
  ready,

  /// The copy is being persisted to the library.
  saving,

  /// The sound is durably saved.
  saved,

  /// The last operation failed; [SoundImportState.audio] may still hold a
  /// copied file worth retrying.
  failure,
}

/// Why an import or save failed, mapped to user-facing copy by the view.
enum SoundImportFailureReason {
  unsupportedFormat,
  unreadableFile,
  undecodable,
  saveFailed,
  accountChanged,
}

class SoundImportState extends Equatable {
  const SoundImportState({
    this.status = SoundImportStatus.idle,
    this.audio,
    this.failureReason,
    this.savedResult,
  });

  final SoundImportStatus status;

  /// The library-owned copy for this import, once it exists.
  final AudioEvent? audio;

  final SoundImportFailureReason? failureReason;

  final SavedSoundSaveResult? savedResult;

  bool get isBusy =>
      status == SoundImportStatus.copying || status == SoundImportStatus.saving;

  /// Whether the save found the sound already present in the library.
  bool get alreadyInLibrary => savedResult == SavedSoundSaveResult.alreadySaved;

  /// Whether [save] can run: a copy exists and no operation is in flight.
  bool get canSave =>
      audio != null &&
      !isBusy &&
      (status == SoundImportStatus.ready ||
          status == SoundImportStatus.failure);

  SoundImportState copyWith({
    SoundImportStatus? status,
    AudioEvent? audio,
    SoundImportFailureReason? failureReason,
    SavedSoundSaveResult? savedResult,
    bool clearFailure = false,
  }) {
    return SoundImportState(
      status: status ?? this.status,
      audio: audio ?? this.audio,
      failureReason: clearFailure ? null : failureReason ?? this.failureReason,
      savedResult: savedResult ?? this.savedResult,
    );
  }

  @override
  List<Object?> get props => [status, audio, failureReason, savedResult];
}
