// ABOUTME: State for the library's Add sound flow: the picked or recorded sound,
// ABOUTME: whether it is shared publicly, its public credit, and the save
// ABOUTME: lifecycle.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/saved_sounds_service.dart';

const _unset = Object();

/// Where the sound on the Add sound screen comes from.
enum AddSoundSource {
  /// An audio file picked from the device.
  file,

  /// A recording made with the microphone on the screen itself.
  recording,
}

enum AddSoundStatus {
  /// Nothing picked yet.
  idle,

  /// The picker is open, or the picked file or recording is being moved into
  /// library storage and probed. A previous sound, if any, stays in
  /// [AddSoundState.audio].
  importing,

  /// A library-owned copy exists and can be previewed, named or credited, and
  /// saved.
  ready,

  /// The sound is being shared and/or written to My Sounds.
  saving,

  /// The sound is durably in My Sounds.
  saved,
}

/// Why the last pick, share, or save did not complete, mapped to copy by the
/// view.
///
/// Transient: cleared when the next attempt starts, so the same failure twice
/// in a row still reads as a change to a listener.
enum AddSoundFailure {
  /// The picked file is not one of the supported audio types.
  unsupportedFormat,

  /// The picker could not hand the file over, or the file could not be
  /// copied or decoded.
  unreadableFile,

  /// The signed-in account changed mid-flow, so the pick was abandoned.
  accountChanged,

  /// Writing to My Sounds failed. When the sound was already shared,
  /// retrying repeats only this write.
  saveFailed,

  /// No signed-in identity can sign the share.
  notSignedIn,

  /// Blossom rejected the upload, signing failed, or no relay acknowledged
  /// the event. Retrying can help.
  publishFailed,

  /// The relay reports the account suspended or banned. Retrying cannot help.
  accountRestricted,
}

class AddSoundState extends Equatable {
  const AddSoundState({
    this.status = AddSoundStatus.idle,
    this.audio,
    this.accountId,
    this.source,
    this.sharePublicly = false,
    this.attribution,
    this.publishedSound,
    this.failure,
    this.savedResult,
  });

  final AddSoundStatus status;

  /// The library-owned copy of the picked file or recording, once it exists.
  final AudioEvent? audio;

  /// The account [audio] was imported under. A save is refused once another
  /// account is signed in, so one account's sound never lands in another's
  /// library.
  final String? accountId;

  /// Where [audio] came from or, while [status] is importing, where the sound
  /// being imported comes from.
  ///
  /// Picks how the sound is replaced: a file through the picker, a recording
  /// by recording again.
  final AddSoundSource? source;

  /// Whether saving also publishes the sound as a reusable Kind 1063.
  final bool sharePublicly;

  /// The public credit the sound ships with when [sharePublicly] is on.
  final AudioShareAttribution? attribution;

  /// The sound as a relay acknowledged it, once shared.
  ///
  /// Set when the My Sounds write that follows the share settles, and kept
  /// when that write fails, so a retry saves this record instead of
  /// publishing a second event. Until then the save in flight is still the
  /// share the user started, not a retry.
  final AudioEvent? publishedSound;

  final AddSoundFailure? failure;

  final SavedSoundSaveResult? savedResult;

  bool get isBusy =>
      status == AddSoundStatus.importing || status == AddSoundStatus.saving;

  /// Whether this sound was shared and its first My Sounds write has settled.
  ///
  /// The share is then settled: the file and the share choice are locked so
  /// a retried My Sounds write stays bound to the published record.
  bool get isPublished => publishedSound != null;

  /// Whether the save found the sound already present in the library.
  bool get alreadyInLibrary => savedResult == SavedSoundSaveResult.alreadySaved;

  /// Whether the file can be swapped and the share choice changed.
  bool get canEdit => audio != null && !isBusy && !isPublished;

  /// Whether the save action is enabled.
  bool get canSave {
    if (audio == null || status != AddSoundStatus.ready) return false;
    if (!sharePublicly || isPublished) return true;
    return attribution?.isValid ?? false;
  }

  AddSoundState copyWith({
    AddSoundStatus? status,
    Object? audio = _unset,
    Object? accountId = _unset,
    Object? source = _unset,
    bool? sharePublicly,
    Object? attribution = _unset,
    Object? publishedSound = _unset,
    Object? failure = _unset,
    Object? savedResult = _unset,
  }) {
    return AddSoundState(
      status: status ?? this.status,
      audio: identical(audio, _unset) ? this.audio : audio as AudioEvent?,
      accountId: identical(accountId, _unset)
          ? this.accountId
          : accountId as String?,
      source: identical(source, _unset)
          ? this.source
          : source as AddSoundSource?,
      sharePublicly: sharePublicly ?? this.sharePublicly,
      attribution: identical(attribution, _unset)
          ? this.attribution
          : attribution as AudioShareAttribution?,
      publishedSound: identical(publishedSound, _unset)
          ? this.publishedSound
          : publishedSound as AudioEvent?,
      failure: identical(failure, _unset)
          ? this.failure
          : failure as AddSoundFailure?,
      savedResult: identical(savedResult, _unset)
          ? this.savedResult
          : savedResult as SavedSoundSaveResult?,
    );
  }

  @override
  List<Object?> get props => [
    status,
    audio,
    accountId,
    source,
    sharePublicly,
    attribution,
    publishedSound,
    failure,
    savedResult,
  ];
}
