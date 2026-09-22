// ABOUTME: State for SoundUploadCubit — the picked audio file, its public
// ABOUTME: credit, and the lifecycle of publishing it as a standalone Kind 1063.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/audio_share_attribution.dart';

const _unset = Object();

/// Lifecycle of the standalone sound upload.
enum SoundUploadStatus {
  /// No file picked yet.
  idle,

  /// The picked file is being copied into library storage.
  importing,

  /// A file is picked; the credit can be edited and the sound published.
  ready,

  /// The sound is uploading and its Kind 1063 is being published.
  publishing,

  /// The Kind 1063 was acknowledged; [SoundUploadState.publishedSound] is
  /// set and the view saves it to My Sounds.
  published,
}

/// Why the last import or publish attempt did not complete.
///
/// Transient: cleared when the next attempt starts, so the same failure twice
/// in a row still reads as a change to a listener.
enum SoundUploadFailure {
  /// The picked file could not be read, is not a supported type, or could
  /// not be copied into library storage.
  importFailed,

  /// No signed-in identity can sign the event.
  notSignedIn,

  /// Blossom rejected the upload, signing failed, or no relay acknowledged
  /// the event. Retrying can help.
  publishFailed,

  /// The relay reports the account suspended or banned. Retrying cannot help.
  accountRestricted,
}

/// State for `SoundUploadCubit`.
class SoundUploadState extends Equatable {
  const SoundUploadState({
    this.status = SoundUploadStatus.idle,
    this.sound,
    this.attribution,
    this.failure,
    this.publishedSound,
  });

  final SoundUploadStatus status;

  /// The device-local audio picked for upload, or null before a pick.
  final AudioEvent? sound;

  /// The public credit that will ship with the sound.
  final AudioShareAttribution? attribution;

  final SoundUploadFailure? failure;

  /// The sound as published, parsed back from the signed event.
  final AudioEvent? publishedSound;

  /// Whether the share action is enabled.
  bool get canPublish =>
      status == SoundUploadStatus.ready &&
      sound != null &&
      (attribution?.isValid ?? false);

  /// Whether leaving the page would abandon in-flight work.
  bool get isBusy =>
      status == SoundUploadStatus.importing ||
      status == SoundUploadStatus.publishing;

  SoundUploadState copyWith({
    SoundUploadStatus? status,
    Object? sound = _unset,
    Object? attribution = _unset,
    Object? failure = _unset,
    Object? publishedSound = _unset,
  }) {
    return SoundUploadState(
      status: status ?? this.status,
      sound: identical(sound, _unset) ? this.sound : sound as AudioEvent?,
      attribution: identical(attribution, _unset)
          ? this.attribution
          : attribution as AudioShareAttribution?,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as SoundUploadFailure?,
      publishedSound: identical(publishedSound, _unset)
          ? this.publishedSound
          : publishedSound as AudioEvent?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sound,
    attribution,
    failure,
    publishedSound,
  ];
}
