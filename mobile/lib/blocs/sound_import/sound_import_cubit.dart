// ABOUTME: Cubit for importing a picked audio file into the private library.
// ABOUTME: Owns copy, durability, account guard, and cleanup of unsaved copies.

import 'package:bloc/bloc.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/sound_import/sound_import_state.dart';
import 'package:openvine/services/local_audio_import_service.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:unified_logger/unified_logger.dart';

export 'sound_import_state.dart';

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

/// Persists [audio] to the current account's private library.
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

/// Drives one private sound import: pick a file, copy it into library storage,
/// let the user preview and optionally name it, then persist it.
///
/// The cubit is Flutter-free: the picker, the durable save, the file reclaimer,
/// and the account reader are all injected ports, so the whole lifecycle is
/// unit-testable without a plugin.
///
/// Two things it deliberately owns:
///
/// * **Account guard.** The account is captured before the picker opens. If the
///   account changes while the copy or save is in flight, the operation is
///   abandoned and its copied file reclaimed rather than writing one account's
///   import into another account's library.
/// * **Cleanup.** A copied file the library never came to own — cancelled,
///   failed before save, or abandoned on account change — is handed to the
///   reclaimer, which deletes it only when no draft or saved record still
///   references it.
class SoundImportCubit extends Cubit<SoundImportState>
    with CloseGuardedEmit<SoundImportState> {
  SoundImportCubit({
    required LocalAudioImportService importService,
    required AudioImportFilePicker pickFile,
    required SavedSoundSaver saveSound,
    required AudioImportReclaimer reclaimAudio,
    required ViewerAccountIdReader viewerAccountId,
  }) : _importService = importService,
       _pickFile = pickFile,
       _saveSound = saveSound,
       _reclaimAudio = reclaimAudio,
       _viewerAccountId = viewerAccountId,
       super(const SoundImportState());

  static const _logName = 'SoundImportCubit';

  final LocalAudioImportService _importService;
  final AudioImportFilePicker _pickFile;
  final SavedSoundSaver _saveSound;
  final AudioImportReclaimer _reclaimAudio;
  final ViewerAccountIdReader _viewerAccountId;

  /// The account that started this import, captured before the picker opens.
  String? _initiatingAccountId;

  /// Opens the picker and copies the chosen file into library storage.
  Future<void> pickFileAndImport() async {
    if (state.isBusy) return;

    _initiatingAccountId = _viewerAccountId();
    if (!isClosed) {
      emitIfOpen(const SoundImportState(status: SoundImportStatus.copying));
    }

    final AudioImportPickedFile? picked;
    try {
      picked = await _pickFile();
    } catch (error, stackTrace) {
      Log.error(
        'Failed to open the audio picker: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      _emitFailure(SoundImportFailureReason.undecodable);
      return;
    }

    if (picked == null) {
      emitIfOpen(const SoundImportState());
      return;
    }

    final AudioEvent audio;
    try {
      audio = await _importService.importAudioFile(
        sourcePath: picked.path,
        displayName: picked.name,
      );
    } on LocalAudioImportException catch (error) {
      _emitFailure(_reasonFor(error));
      return;
    } catch (error, stackTrace) {
      Log.error(
        'Failed to import audio: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      _emitFailure(SoundImportFailureReason.undecodable);
      return;
    }

    if (isClosed) {
      await _reclaim(audio);
      return;
    }
    if (_accountChanged()) {
      await _reclaim(audio);
      _emitFailure(SoundImportFailureReason.accountChanged);
      return;
    }

    emitIfOpen(SoundImportState(status: SoundImportStatus.ready, audio: audio));
  }

  /// Persists the copied sound to the library, optionally under a private name.
  ///
  /// Safe to call again after a failure: the same copied file is retried, not
  /// re-imported.
  Future<void> save({String? personalLabel}) async {
    final audio = state.audio;
    if (audio == null || !state.canSave) return;

    if (_accountChanged()) {
      await _reclaim(audio);
      _emitFailure(SoundImportFailureReason.accountChanged);
      return;
    }

    // Nothing to persist into a closed cubit; close() already reclaimed the
    // copy it was holding.
    if (isClosed) return;

    emitIfOpen(
      state.copyWith(status: SoundImportStatus.saving, clearFailure: true),
    );
    try {
      final result = await _saveSound(
        audio,
        personalLabel: _normalizeLabel(personalLabel),
      );
      if (isClosed) return;
      emitIfOpen(
        SoundImportState(
          status: SoundImportStatus.saved,
          audio: audio,
          savedResult: result,
        ),
      );
    } catch (error, stackTrace) {
      Log.error(
        'Failed to save an imported sound: $error',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      if (isClosed) {
        // close() left this copy alone because a save owned it. That save just
        // failed, so nothing owns it and no later pass reclaims it by path.
        await _reclaim(audio);
        return;
      }
      // The copy is retained so Retry writes the same file rather than making
      // the user pick it again.
      emitIfOpen(
        SoundImportState(
          status: SoundImportStatus.failure,
          audio: audio,
          failureReason: SoundImportFailureReason.saveFailed,
        ),
      );
    }
  }

  /// Reclaims the copied file for an import that will not be saved.
  ///
  /// Returns the state to idle so the view can offer a fresh pick.
  Future<void> discardUnsavedImport() async {
    final audio = state.audio;
    if (audio != null && state.status != SoundImportStatus.saved) {
      await _reclaim(audio);
    }
    emitIfOpen(const SoundImportState());
  }

  @override
  Future<void> close() async {
    final closing = super.close();
    final audio = state.audio;
    // An in-flight save already owns the file it is about to persist, so it is
    // never reclaimed here; a saved record is the library's, not ours.
    if (audio != null &&
        state.status != SoundImportStatus.saved &&
        state.status != SoundImportStatus.saving) {
      await _reclaim(audio);
    }
    return closing;
  }

  bool _accountChanged() => _viewerAccountId() != _initiatingAccountId;

  void _emitFailure(SoundImportFailureReason reason) {
    emitIfOpen(
      SoundImportState(
        status: SoundImportStatus.failure,
        failureReason: reason,
      ),
    );
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

  static SoundImportFailureReason _reasonFor(LocalAudioImportException error) {
    return switch (error.reason) {
      LocalAudioImportFailureReason.unsupportedType =>
        SoundImportFailureReason.unsupportedFormat,
      LocalAudioImportFailureReason.decodeFailed =>
        SoundImportFailureReason.undecodable,
      LocalAudioImportFailureReason.unreadableSource ||
      LocalAudioImportFailureReason.copyFailed =>
        SoundImportFailureReason.unreadableFile,
    };
  }

  static String? _normalizeLabel(String? label) {
    final trimmed = label?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
