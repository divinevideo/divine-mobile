// ABOUTME: State for RecordingGalleryBackupCubit — the gallery backup setting.

import 'package:equatable/equatable.dart';

/// State for `RecordingGalleryBackupCubit`.
class RecordingGalleryBackupState extends Equatable {
  const RecordingGalleryBackupState({
    this.isEnabled = false,
    this.permissionDenied = false,
  });

  /// Whether new recordings are backed up to the gallery.
  final bool isEnabled;

  /// Whether the last attempt to turn the setting on failed because the
  /// gallery permission was not granted. Cleared on the next attempt.
  final bool permissionDenied;

  RecordingGalleryBackupState copyWith({
    bool? isEnabled,
    bool? permissionDenied,
  }) {
    return RecordingGalleryBackupState(
      isEnabled: isEnabled ?? this.isEnabled,
      permissionDenied: permissionDenied ?? this.permissionDenied,
    );
  }

  @override
  List<Object?> get props => [isEnabled, permissionDenied];
}
