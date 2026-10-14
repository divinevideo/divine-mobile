// ABOUTME: Copies new camera recordings to the device gallery once signed
// ABOUTME: Holds unsigned recordings back and finishes them after late signing

import 'dart:async';
import 'dart:io';

import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/clip_gallery_backup.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/c2pa_signing_service.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/services/recording_gallery_backup_preference_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;
import 'package:unified_logger/unified_logger.dart';

/// Backs up new camera recordings to the device gallery (#10067).
///
/// The gallery gets a copy of the recording file, and the app keeps its own:
/// the clip library never depends on the gallery, so a copy deleted or edited
/// there leaves the clip untouched, and deleting a clip in Divine never
/// deletes its copy.
///
/// The copy is only written once the recording carries its C2PA credential,
/// so it can come back through the gallery import. A recording whose capture
/// signing failed, for example offline, stays
/// [ClipGalleryBackupStatus.pending] until [finishPendingBackups] signs it
/// late. One that can never be signed, because this build cannot sign or no
/// capture proof exists, is copied without a credential and flagged.
class RecordingGalleryBackupService {
  /// Creates the service.
  ///
  /// [clipLibrary] is read per call, so it follows the signed-in account.
  /// [canSignNow] reports whether the account's signer can sign right now; a
  /// late signature without it would lack the creator binding.
  RecordingGalleryBackupService({
    required RecordingGalleryBackupPreferenceService preferences,
    required GallerySaveService gallerySaveService,
    required ClipLibraryService Function() clipLibrary,
    required bool Function() canSignNow,
    bool Function()? buildCanSign,
    Future<bool> Function(String path)? hasCredential,
    Future<bool> Function(C2paEditSource recording)? signRecording,
  }) : _preferences = preferences,
       _gallerySaveService = gallerySaveService,
       _clipLibrary = clipLibrary,
       _canSignNow = canSignNow,
       _buildCanSign = buildCanSign ?? _buildSigns,
       _hasCredential = hasCredential ?? _carriesCredential,
       _signRecording = signRecording ?? _signLate;

  static const _logName = 'RecordingGalleryBackupService';

  final RecordingGalleryBackupPreferenceService _preferences;
  final GallerySaveService _gallerySaveService;
  final ClipLibraryService Function() _clipLibrary;
  final bool Function() _canSignNow;
  final bool Function() _buildCanSign;
  final Future<bool> Function(String path) _hasCredential;

  /// Signs [recording] as a capture when it qualifies, and returns whether it
  /// is still unsigned although it qualifies (see
  /// [NativeProofModeService.signOwnRecordings]).
  final Future<bool> Function(C2paEditSource recording) _signRecording;

  /// Clips whose backup step is running, so a step never runs twice at once
  /// and copies a recording twice.
  final Set<String> _inFlight = {};

  Future<void>? _finishing;
  bool _finishAgain = false;

  /// Backs up the recording at [recordingPath] of the library clip [clipId]
  /// once its capture proof settled, with [proof] as the result.
  ///
  /// Does nothing while the setting is off, for a clip that is not in the
  /// library, or for one whose backup already started. A take in the trash
  /// waits until it is restored. Never throws.
  Future<void> backUpRecording({
    required String clipId,
    required String recordingPath,
    required NativeProofData? proof,
  }) async {
    if (!_preferences.isEnabled || !_inFlight.add(clipId)) return;
    var signed = false;
    try {
      final library = _clipLibrary();
      final clip = await library.getClipById(clipId);
      if (clip == null || clip.galleryBackup != null) return;
      final pending = ClipGalleryBackup(
        status: ClipGalleryBackupStatus.pending,
        recordingPath: recordingPath,
      );
      signed = proof?.c2paManifestId != null;
      // Without a proof there is no camera hash to sign the file against
      // later, so it can only be copied as it is.
      final signableLater = !signed && proof != null && _buildCanSign();
      if (clip.deletedAt != null || signableLater) {
        await library.setGalleryBackup(clipId: clipId, backup: pending);
        return;
      }
      await _copy(library, clipId, pending, signed: signed);
    } on Exception catch (error, stackTrace) {
      Log.error(
        'Could not back up recording of clip $clipId to the gallery',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _inFlight.remove(clipId);
    }
    // This one was signed, so earlier ones can likely be signed now too.
    if (signed) unawaited(finishPendingBackups());
  }

  /// Finishes every backup of this account's library that is still
  /// [ClipGalleryBackupStatus.pending]: signs the recording late where it
  /// can, then copies it.
  ///
  /// Stops at the first recording whose signing fails, since the next would
  /// fail the same way, and leaves the rest for the next call. A call while
  /// one runs makes it go over the library once more. Never throws.
  Future<void> finishPendingBackups() {
    if (_finishing case final running?) {
      _finishAgain = true;
      return running;
    }
    return _finishing = _finishWhileAsked().whenComplete(
      () => _finishing = null,
    );
  }

  Future<void> _finishWhileAsked() async {
    do {
      _finishAgain = false;
      await _finishPending();
    } while (_finishAgain);
  }

  Future<void> _finishPending() async {
    if (!_preferences.isEnabled) return;
    try {
      final library = _clipLibrary();
      for (final clip in await library.getAllClips()) {
        final backup = clip.galleryBackup;
        if (backup?.status != ClipGalleryBackupStatus.pending) continue;
        if (!_inFlight.add(clip.id)) continue;
        try {
          if (!await _finishOne(library, clip, backup!)) break;
        } finally {
          _inFlight.remove(clip.id);
        }
      }
    } on Exception catch (error, stackTrace) {
      Log.error(
        'Could not finish pending gallery backups',
        name: _logName,
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Finishes the backup of [clip] and returns whether the next one is worth
  /// trying now.
  Future<bool> _finishOne(
    ClipLibraryService library,
    DivineVideoClip clip,
    ClipGalleryBackup backup,
  ) async {
    final path = backup.recordingPath;
    if (!File(path).existsSync()) {
      // The recording is gone, so there is nothing left to back up.
      await library.setGalleryBackup(clipId: clip.id, backup: null);
      return true;
    }
    var signed = await _hasCredential(path);
    if (!signed && _buildCanSign()) {
      // Waits for a signer that can name the account; another recording may
      // already be signed, by a DM send or an edit.
      if (!_canSignNow()) return true;
      final leftUnsigned = await _signRecording(
        C2paEditSource(path: path, recordingSha256: clip.recordingSha256),
      );
      signed = await _hasCredential(path);
      // Signing could not run, for example offline. Otherwise the file no
      // longer qualifies as a capture and is copied as it is.
      if (!signed && leftUnsigned) return false;
    }
    await _copy(library, clip.id, backup, signed: signed);
    return true;
  }

  /// Copies [backup]'s recording to the gallery and notes the outcome on the
  /// library clip [clipId]. A copy that fails stays pending for a retry.
  Future<void> _copy(
    ClipLibraryService library,
    String clipId,
    ClipGalleryBackup backup, {
    required bool signed,
  }) async {
    final result = await _gallerySaveService.saveVideoToGallery(
      EditorVideo.file(backup.recordingPath),
      // Runs after a take or on resume, where a permission prompt would come
      // out of nowhere. The setting asks for it when it is turned on.
      requestPermission: false,
    );
    final status = switch (result) {
      GallerySaveSuccess() when signed => ClipGalleryBackupStatus.saved,
      GallerySaveSuccess() => ClipGalleryBackupStatus.savedUnsigned,
      GallerySaveFailure() ||
      GallerySavePermissionDenied() => ClipGalleryBackupStatus.pending,
    };
    if (status == ClipGalleryBackupStatus.pending) {
      Log.warning(
        'Gallery backup of clip $clipId failed and is tried again later',
        name: _logName,
        category: LogCategory.video,
      );
    }
    await library.setGalleryBackup(
      clipId: clipId,
      backup: backup.withStatus(status),
    );
  }

  static bool _buildSigns() =>
      C2paSigningService.isSigningConfigured &&
      C2paSigningService.hasSigningToken;

  static Future<bool> _carriesCredential(String path) async {
    final manifest = await C2paSigningService().readManifest(path);
    return manifest?.activeManifest != null;
  }

  static Future<bool> _signLate(C2paEditSource recording) =>
      NativeProofModeService.signOwnRecordings(
        const [],
        otherSources: [recording],
      );
}
