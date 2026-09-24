// ABOUTME: Cubit for playing and saving a received encrypted video DM.
// ABOUTME: Owns the decrypted temp file and deletes it on failure and close.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// Decrypt-to-play progress of a received encrypted video DM.
enum DmVideoPlaybackStatus {
  /// Downloading and decrypting the ciphertext.
  loading,

  /// [DmVideoPlaybackState.clipPath] holds the decrypted clip.
  ready,

  /// The video could not be downloaded, verified, decrypted, or played. The
  /// cause is reported through `addError`.
  failed,
}

/// Outcome of saving a decrypted encrypted video DM to the device gallery.
enum DmVideoSaveStatus {
  /// No save has been requested.
  idle,

  /// A save is in flight.
  saving,

  /// The video reached the gallery.
  saved,

  /// The user denied gallery access.
  permissionDenied,

  /// The save failed for another reason.
  failed,
}

/// [DmVideoPlaybackCubit] state.
class DmVideoPlaybackState extends Equatable {
  /// Creates a [DmVideoPlaybackState].
  const DmVideoPlaybackState({
    this.status = DmVideoPlaybackStatus.loading,
    this.clipPath,
    this.saveStatus = DmVideoSaveStatus.idle,
  });

  /// Decrypt-to-play progress.
  final DmVideoPlaybackStatus status;

  /// Path of the decrypted clip while [status] is
  /// [DmVideoPlaybackStatus.ready]; `null` otherwise.
  final String? clipPath;

  /// Outcome of the most recent gallery save.
  final DmVideoSaveStatus saveStatus;

  @override
  List<Object?> get props => [status, clipPath, saveStatus];
}

/// Decrypts one received encrypted video DM for the full-screen play page
/// and saves it to the gallery on request.
///
/// The decrypted plaintext only ever lives in the temp file the
/// [DmVideoDecryptor] wrote; this cubit deletes it when playback fails and
/// when it closes, including when a decrypt finishes after close.
class DmVideoPlaybackCubit extends Cubit<DmVideoPlaybackState>
    with CloseGuardedEmit<DmVideoPlaybackState> {
  /// Creates a [DmVideoPlaybackCubit] for [message].
  DmVideoPlaybackCubit({
    required DmMessage message,
    required DmVideoDecryptor decryptor,
    required GallerySaveService gallerySaveService,
  }) : _message = message,
       _decryptor = decryptor,
       _gallerySaveService = gallerySaveService,
       super(const DmVideoPlaybackState());

  final DmMessage _message;
  final DmVideoDecryptor _decryptor;
  final GallerySaveService _gallerySaveService;

  /// Platform-aware name of the gallery destination, for user-facing save
  /// copy. Exposed here so the view reaches no service directly.
  String get galleryDestinationName => GallerySaveService.destinationName;

  /// Downloads and decrypts the video into a temp clip.
  Future<void> load() async {
    try {
      final path = await _decryptor.decryptToFile(_message);
      if (isClosed) {
        _decryptor.deleteClip(path);
        return;
      }
      emit(
        DmVideoPlaybackState(
          status: DmVideoPlaybackStatus.ready,
          clipPath: path,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        const DmVideoPlaybackState(status: DmVideoPlaybackStatus.failed),
      );
    }
  }

  /// Reports that the player could not open the decrypted clip, and deletes
  /// it.
  void playbackFailed(Object error, StackTrace stackTrace) {
    addError(error, stackTrace);
    _deleteClip();
    emitIfOpen(
      const DmVideoPlaybackState(status: DmVideoPlaybackStatus.failed),
    );
  }

  /// Saves the decrypted clip to the device gallery.
  ///
  /// A no-op unless a clip is ready and no save is already running.
  Future<void> saveToGallery() async {
    final path = state.clipPath;
    if (path == null || state.saveStatus == DmVideoSaveStatus.saving) return;

    emit(_withSaveStatus(DmVideoSaveStatus.saving));
    final result = await _gallerySaveService.saveVideoToGallery(
      EditorVideo.file(path),
    );
    emitIfOpen(
      _withSaveStatus(switch (result) {
        GallerySaveSuccess() => DmVideoSaveStatus.saved,
        GallerySavePermissionDenied() => DmVideoSaveStatus.permissionDenied,
        GallerySaveFailure() => DmVideoSaveStatus.failed,
      }),
    );
  }

  DmVideoPlaybackState _withSaveStatus(DmVideoSaveStatus saveStatus) =>
      DmVideoPlaybackState(
        status: state.status,
        clipPath: state.clipPath,
        saveStatus: saveStatus,
      );

  void _deleteClip() {
    final path = state.clipPath;
    if (path != null) _decryptor.deleteClip(path);
  }

  @override
  Future<void> close() {
    _deleteClip();
    return super.close();
  }
}
