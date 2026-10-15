// ABOUTME: Cubit for the library's Add sound flow: imports a picked file and
// ABOUTME: saves it to My Sounds, optionally sharing it publicly first.

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/add_sound/add_sound_state.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/models/audio_share_attribution.dart';
import 'package:openvine/services/local_audio_event_publisher.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:unified_logger/unified_logger.dart';

export 'add_sound_state.dart';

/// A file the user picked to import.
@immutable
class AudioImportPickedFile {
  const AudioImportPickedFile({required this.path, required this.name});

  /// Absolute path of the picked file, as handed back by the platform picker.
  final String path;

  /// Display name the picker reported, including its extension.
  final String name;
}

/// Opens the platform audio picker and returns the chosen file, or null when
/// the user cancelled.
typedef AudioImportFilePicker = Future<AudioImportPickedFile?> Function();

/// Persists [audio] to the current account's library.
///
/// The production wiring is `SavedSoundsBloc.saveSound`, so the save also
/// updates library state and mirrors to the creator's other devices.
typedef SavedSoundSaver = Future<SavedSoundSaveResult> Function(
  AudioEvent audio, {
  String? personalLabel,
});

/// Reclaims a library audio file once nothing references it.
typedef AudioImportReclaimer = Future<void> Function(String audioFilePath);

/// Reads the *current* signed-in account's pubkey hex, or null when signed out.
typedef ViewerAccountIdReader = String? Function();

/// Reads the publisher for the *current* session at the moment of sharing, so
/// a relay client or signer that arrived after the page opened is used.
typedef LocalAudioPublisherReader = LocalAudioEventPublisher Function();

/// Drives one Add sound: pick a file, copy it into library storage, let the
/// user preview it, then save it to My Sounds — privately under an optional
/// name, or shared publicly as a reusable Kind 1063 with a credit.
///
/// The cubit is Flutter-free: the picker, the durable save, the publisher, the
/// file reclaimer, and the account reader are all injected, so the whole
/// lifecycle is unit-testable without a plugin.
///
/// What it deliberately owns:
///
/// * **One share, one library row.** A public save publishes first and then
///   writes the published record to My Sounds. If that write fails the
///   record is kept, and a retry repeats only the write: a published sound
///   with no library row could not be deleted, since deletion resolves the
///   record from the library and nothing else lists a standalone sound.
/// * **Account guard.** Each copy is bound to the account that imported it
///   ([AddSoundState.accountId]). If the account changes while a copy or save
///   is in flight, the work is abandoned rather than writing one account's
///   sound into another account's library.
/// * **Cleanup.** A copy no private library record came to own — cancelled,
///   replaced by another pick, abandoned, or superseded by its published
///   upload — is handed to the reclaimer, which deletes it only when no draft
///   or saved record still references it.
class AddSoundCubit extends Cubit<AddSoundState>
    with CloseGuardedEmit<AddSoundState> {
  AddSoundCubit({
    required LocalAudioImportService importService,
    required AudioImportFilePicker pickFile,
    required SavedSoundSaver saveSound,
    required AudioImportReclaimer reclaimAudio,
    required ViewerAccountIdReader viewerAccountId,
    required LocalAudioPublisherReader publisher,
    required String publisherName,
    String? publisherPubkey,
  }) : _importService = importService,
       _pickFile = pickFile,
       _saveSound = saveSound,
       _reclaimAudio = reclaimAudio,
       _viewerAccountId = viewerAccountId,
       _publisher = publisher,
       _publisherName = publisherName,
       _publisherPubkey = publisherPubkey,
       super(const AddSoundState());

  static const _logName = 'AddSoundCubit';

  final LocalAudioImportService _importService;
  final AudioImportFilePicker _pickFile;
  final SavedSoundSaver _saveSound;
  final AudioImportReclaimer _reclaimAudio;
  final ViewerAccountIdReader _viewerAccountId;
  final LocalAudioPublisherReader _publisher;

  /// The signed-in user's display name, prefilled as the credited creator.
  final String _publisherName;

  /// The signed-in user's pubkey, credited on the `p` tag while the sound is
  /// confirmed as their own work.
  final String? _publisherPubkey;

  /// Opens the picker and copies the chosen file into library storage.
  ///
  /// A cancelled or failed pick keeps the file picked before it, still bound
  /// to the account that imported it; a successful one replaces it and
  /// reclaims the replaced copy.
  Future<void> pickFileAndImport() async {
    if (state.isBusy || state.isPublished) return;
    final previous = state.audio;

    final accountId = _viewerAccountId();
    emitIfOpen(state.copyWith(status: AddSoundStatus.importing, failure: null));

    final AudioImportPickedFile? picked;
    try {
      picked = await _pickFile();
    } catch (error, stackTrace) {
      // The Android picker throws when it cannot copy the chosen file (#10065).
      Log.error(
        'Failed to open the audio picker: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      _failImport(AddSoundFailure.unreadableFile);
      return;
    }

    if (picked == null) {
      emitIfOpen(state.copyWith(status: _restingStatus));
      return;
    }

    final AudioEvent audio;
    try {
      audio = await _importService.importAudioFile(
        sourcePath: picked.path,
        displayName: picked.name,
      );
    } on LocalAudioImportException catch (error) {
      _failImport(_reasonFor(error));
      return;
    } catch (error, stackTrace) {
      Log.error(
        'Failed to import audio: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      _failImport(AddSoundFailure.unreadableFile);
      return;
    }

    // close() already reclaimed the previous copy.
    if (isClosed) {
      await _reclaim(audio);
      return;
    }
    if (_viewerAccountId() != accountId) {
      emitIfOpen(const AddSoundState(failure: AddSoundFailure.accountChanged));
      await _reclaim(audio);
      if (previous != null) await _reclaim(previous);
      return;
    }

    emitIfOpen(
      AddSoundState(
        status: AddSoundStatus.ready,
        audio: audio,
        accountId: accountId,
        sharePublicly: state.sharePublicly,
        // The credit opens as the publisher's own work: that is the case
        // sharing exists for, and turning it off is one tap.
        attribution: AudioShareAttribution(
          title: audio.title ?? '',
          creatorName: _publisherName,
          creatorPubkey: _publisherPubkey,
          publicTags: const [],
          confirmedOwnWork: true,
        ),
      ),
    );
    if (previous != null) await _reclaim(previous);
  }

  /// Chooses whether saving also shares the sound publicly.
  void setSharePublicly(bool value) {
    if (!state.canEdit) return;
    emitIfOpen(state.copyWith(sharePublicly: value));
  }

  /// Applies an edit from the credit editor.
  ///
  /// The `p` tag follows ownership: confirmed own work credits the publisher's
  /// pubkey, anything else carries none, so the feed row can say "Shared by"
  /// when the credited creator is somebody else.
  void updateAttribution(AudioShareAttribution attribution) {
    if (!state.canEdit) return;
    emitIfOpen(
      state.copyWith(
        attribution: attribution.copyWith(
          creatorPubkey: attribution.confirmedOwnWork ? _publisherPubkey : null,
        ),
      ),
    );
  }

  /// Saves the copied sound to My Sounds.
  ///
  /// Privately, under [personalLabel] when one is given. When
  /// [AddSoundState.sharePublicly] is on, the sound is first published as a
  /// reusable Kind 1063 and the published record is what lands in the
  /// library; the private label does not apply.
  ///
  /// Safe to call again after a failure: the same copy is retried, and a
  /// sound that was already published is not published again.
  Future<void> save({String? personalLabel}) async {
    final audio = state.audio;
    if (audio == null || !state.canSave) return;

    if (_accountChanged()) {
      emitIfOpen(const AddSoundState(failure: AddSoundFailure.accountChanged));
      await _reclaim(audio);
      return;
    }

    // Nothing to persist into a closed cubit; close() already reclaimed the
    // copy it was holding.
    if (isClosed) return;

    final sharePublicly = state.sharePublicly;
    emitIfOpen(state.copyWith(status: AddSoundStatus.saving, failure: null));

    final AudioEvent record;
    if (sharePublicly) {
      final published = state.publishedSound ?? await _publish(audio);
      if (published == null) {
        if (isClosed) await _reclaim(audio);
        return;
      }
      if (_accountChanged()) {
        // The share went out as the account that started it; its library
        // row belongs to that account, not the one now signed in.
        emitIfOpen(
          const AddSoundState(failure: AddSoundFailure.accountChanged),
        );
        await _reclaim(audio);
        return;
      }
      record = published;
    } else {
      record = audio;
    }

    var savedToLibrary = false;
    try {
      final result = await _saveSound(
        record,
        personalLabel: sharePublicly ? null : _normalizeLabel(personalLabel),
      );
      savedToLibrary = true;
      emitIfOpen(
        state.copyWith(status: AddSoundStatus.saved, savedResult: result),
      );
    } catch (error, stackTrace) {
      Log.error(
        'Failed to save a sound to the library: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      // The copy (or the published record) is retained so Retry writes the
      // same sound rather than making the user pick or share it again.
      emitIfOpen(
        state.copyWith(
          status: AddSoundStatus.ready,
          failure: AddSoundFailure.saveFailed,
        ),
      );
    }

    // close() leaves the copy to a save in flight. Now that the save has
    // settled, only a private library record keeps the copy alive.
    if (isClosed && !(savedToLibrary && !sharePublicly)) await _reclaim(audio);
  }

  @override
  Future<void> close() async {
    final closing = super.close();
    // A save in flight owns the copy until it settles; see [save].
    if (state.status != AddSoundStatus.saving) {
      final audio = state.audio;
      final ownedByLibrary =
          state.status == AddSoundStatus.saved && !state.isPublished;
      if (audio != null && !ownedByLibrary) await _reclaim(audio);
    }
    return closing;
  }

  /// Uploads [audio] and publishes it as a reusable Kind 1063.
  ///
  /// A standalone sound always carries `allow_audio_reuse=true`: it exists
  /// to be reused, so there is no remix toggle. Returns the published record,
  /// or null after emitting the failure.
  Future<AudioEvent?> _publish(AudioEvent audio) async {
    final attribution = state.attribution;
    if (attribution == null) return null;
    try {
      final result = await _publisher().publish(
        audio: audio,
        attribution: attribution,
        allowAudioReuse: true,
      );
      switch (result) {
        case LocalAudioPublished(audio: final published):
          emitIfOpen(state.copyWith(publishedSound: published));
          return published;
        case LocalAudioPublishFailed(:final failure):
          _failSave(switch (failure) {
            LocalAudioPublishFailure.notAuthenticated =>
              AddSoundFailure.notSignedIn,
            LocalAudioPublishFailure.invalidAttribution ||
            LocalAudioPublishFailure.fileUnavailable ||
            LocalAudioPublishFailure.uploadFailed ||
            LocalAudioPublishFailure.signingFailed ||
            LocalAudioPublishFailure.relayRejected =>
              AddSoundFailure.publishFailed,
          });
      }
    } on AccountRestrictedPublishException catch (error, stackTrace) {
      addError(error, stackTrace);
      _failSave(AddSoundFailure.accountRestricted);
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      _failSave(AddSoundFailure.publishFailed);
    }
    return null;
  }

  AddSoundStatus get _restingStatus =>
      state.audio == null ? AddSoundStatus.idle : AddSoundStatus.ready;

  bool _accountChanged() => _viewerAccountId() != state.accountId;

  void _failImport(AddSoundFailure failure) {
    emitIfOpen(state.copyWith(status: _restingStatus, failure: failure));
  }

  void _failSave(AddSoundFailure failure) {
    emitIfOpen(state.copyWith(status: AddSoundStatus.ready, failure: failure));
  }

  Future<void> _reclaim(AudioEvent audio) async {
    final path = audio.localFilePath;
    if (path == null || path.isEmpty) return;
    try {
      await _reclaimAudio(path);
    } catch (error) {
      // Cleanup is best-effort. A leaked copy costs disk; surfacing the failure
      // here would only mask the operation outcome the user is waiting on.
      Log.warning(
        '⚠️ Failed to reclaim an unsaved import: $path - $error',
        name: _logName,
        category: LogCategory.video,
      );
    }
  }

  static AddSoundFailure _reasonFor(LocalAudioImportException error) {
    return switch (error.reason) {
      LocalAudioImportFailureReason.unsupportedType =>
        AddSoundFailure.unsupportedFormat,
      LocalAudioImportFailureReason.decodeFailed ||
      LocalAudioImportFailureReason.unreadableSource ||
      LocalAudioImportFailureReason.copyFailed =>
        AddSoundFailure.unreadableFile,
    };
  }

  static String? _normalizeLabel(String? label) {
    final trimmed = label?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
