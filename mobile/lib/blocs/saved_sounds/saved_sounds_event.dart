// ABOUTME: Events accepted by the device-local saved sounds BLoC.
// ABOUTME: Keeps mutations ordered and exposes save completion to callers.

import 'dart:async';

import 'package:creator_sync/creator_sync.dart';
import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';

sealed class SavedSoundsEvent extends Equatable {
  const SavedSoundsEvent();
}

final class SavedSoundsLoadRequested extends SavedSoundsEvent {
  const SavedSoundsLoadRequested();

  @override
  List<Object?> get props => const [];
}

final class SavedSoundSaveRequested extends SavedSoundsEvent {
  const SavedSoundSaveRequested({
    required this.sound,
    required this.completer,
    this.sourceContext,
    this.personalLabel,
  });

  final AudioEvent sound;
  final SavedSoundSourceContext? sourceContext;

  /// Optional private name supplied at save time (e.g. the import flow's name
  /// field). Null leaves the record unnamed.
  final String? personalLabel;
  final Completer<SavedSoundSaveResult> completer;

  @override
  List<Object?> get props => [sound, sourceContext, personalLabel, completer];
}

final class SavedSoundDetailsChanged extends SavedSoundsEvent {
  const SavedSoundDetailsChanged({
    required this.soundId,
    required this.label,
    required this.hashtags,
  });

  final String soundId;
  final String? label;
  final List<String> hashtags;

  @override
  List<Object?> get props => [soundId, label, hashtags];
}

final class SavedSoundRemoveRequested extends SavedSoundsEvent {
  const SavedSoundRemoveRequested(this.soundId, {this.completer});

  final String soundId;

  /// Completed once the removal has been persisted, or completed with an error
  /// when it could not be, so the caller can tell the user which happened.
  final Completer<void>? completer;

  @override
  List<Object?> get props => [soundId, completer];
}

/// Retracts the user's own published sound from relays, then removes it.
final class SavedSoundDeleteRequested extends SavedSoundsEvent {
  const SavedSoundDeleteRequested(this.soundId, {required this.completer});

  final String soundId;

  /// Completed with the relay's answer once a relay took the deletion and the
  /// record is gone locally; completed with a [SavedSoundDeleteException]
  /// when no relay did, so the record stays and the caller can say why.
  final Completer<DeleteResult> completer;

  @override
  List<Object?> get props => [soundId, completer];
}

final class SavedSoundsQueryChanged extends SavedSoundsEvent {
  const SavedSoundsQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class SavedSoundsHashtagSelected extends SavedSoundsEvent {
  const SavedSoundsHashtagSelected(this.hashtag);

  final String? hashtag;

  @override
  List<Object?> get props => [hashtag];
}

final class SavedSoundProbeCompleted extends SavedSoundsEvent {
  const SavedSoundProbeCompleted({
    required this.soundId,
    required this.result,
  });

  final String soundId;
  final SavedSoundMediaResult? result;

  @override
  List<Object?> get props => [soundId, result];
}

/// The cross-device sync repository re-pointed to a new instance, or to
/// null while unavailable.
///
/// Fired from the bloc's own `syncRepositoryStream` subscription — never
/// added externally.
final class SavedSoundSyncRepositoryChanged extends SavedSoundsEvent {
  const SavedSoundSyncRepositoryChanged(this.repository);

  final SoundSyncRepository? repository;

  @override
  List<Object?> get props => [repository];
}
