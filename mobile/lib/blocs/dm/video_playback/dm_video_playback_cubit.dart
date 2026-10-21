// ABOUTME: Cubit for playing and saving a received encrypted video DM.
// ABOUTME: Plays the video kept on the device, downloading it the first time.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

/// Decrypt-to-play progress of a received encrypted video DM.
enum DmVideoPlaybackStatus {
  /// Getting the kept video, downloading and decrypting it the first time.
  loading,

  /// [DmVideoPlaybackState.clipPath] holds the decrypted video.
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

  /// Path of the kept, decrypted video while [status] is
  /// [DmVideoPlaybackStatus.ready]; `null` otherwise.
  final String? clipPath;

  /// Outcome of the most recent gallery save.
  final DmVideoSaveStatus saveStatus;

  @override
  List<Object?> get props => [status, clipPath, saveStatus];
}

/// Plays one received encrypted video DM on the full-screen play page and
/// saves it to the gallery on request.
///
/// The video comes from the account's [DmVideoStore], which downloads and
/// decrypts it the first time and keeps it after that, so closing the page
/// leaves it for the next open and for the conversation card's frame. The
/// cubit holds it while open and lets go when closed, so the store can then
/// delete it for its age.
class DmVideoPlaybackCubit extends Cubit<DmVideoPlaybackState>
    with CloseGuardedEmit<DmVideoPlaybackState> {
  /// Creates a [DmVideoPlaybackCubit] for [message].
  DmVideoPlaybackCubit({
    required DmMessage message,
    required DmVideoStore? store,
    required GallerySaveService gallerySaveService,
  }) : _message = message,
       _store = store,
       _gallerySaveService = gallerySaveService,
       super(const DmVideoPlaybackState());

  final DmMessage _message;

  /// The kind 15 message this cubit plays.
  DmMessage get message => _message;

  /// Null when no account is signed in: videos are kept per account.
  final DmVideoStore? _store;
  final GallerySaveService _gallerySaveService;

  /// The kept video this page plays: a store hold to let go of, not UI state.
  File? _heldVideo;

  /// Platform-aware name of the gallery destination, for user-facing save
  /// copy. Exposed here so the view reaches no service directly.
  String get galleryDestinationName => GallerySaveService.destinationName;

  /// Gets the kept video, downloading and decrypting it the first time.
  Future<void> load() async {
    try {
      final store = _store;
      if (store == null) {
        throw const DmVideoUnavailableException('no account is signed in');
      }
      final video = await store.videoFor(_message);
      // Closed while it downloaded: nothing will play it.
      if (isClosed) {
        store.releaseVideo(video);
        return;
      }
      _letGoOfVideo();
      _heldVideo = video;
      emitIfOpen(
        DmVideoPlaybackState(
          status: DmVideoPlaybackStatus.ready,
          clipPath: video.path,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        const DmVideoPlaybackState(status: DmVideoPlaybackStatus.failed),
      );
    }
  }

  /// Reports that the player could not open the video. [error] is what is
  /// reported, already rid of anything private; [cause], what raised it,
  /// decides whether it is a bug worth a crash report.
  void playbackFailed(Object error, StackTrace stackTrace, {Object? cause}) {
    final asBug = cause == null
        ? null
        : asReportableError(cause, context: 'playbackFailed');
    addError(
      asBug == null ? error : Reportable(error, context: 'playbackFailed'),
      stackTrace,
    );
    emitIfOpen(
      const DmVideoPlaybackState(status: DmVideoPlaybackStatus.failed),
    );
  }

  /// Saves the decrypted video to the device gallery.
  ///
  /// A no-op unless a clip is ready and no save is already running. Fails
  /// when the message was retracted or removed since the page opened.
  Future<void> saveToGallery() async {
    final store = _store;
    if (store == null ||
        state.clipPath == null ||
        state.saveStatus == DmVideoSaveStatus.saving) {
      return;
    }

    emit(_withSaveStatus(DmVideoSaveStatus.saving));
    final GallerySaveResult result;
    try {
      // Asked of the store again, which refuses a message gone since.
      final video = await store.videoFor(_message);
      try {
        result = await _gallerySaveService.saveVideoToGallery(
          EditorVideo.file(video.path),
          // The kept file is named after its message.
          copyUnderNeutralName: true,
        );
      } finally {
        store.releaseVideo(video);
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(_withSaveStatus(DmVideoSaveStatus.failed));
      return;
    }
    emitIfOpen(
      _withSaveStatus(switch (result) {
        GallerySaveSuccess() => DmVideoSaveStatus.saved,
        GallerySavePermissionDenied() => DmVideoSaveStatus.permissionDenied,
        GallerySaveFailure() => DmVideoSaveStatus.failed,
      }),
    );
  }

  @override
  Future<void> close() {
    _letGoOfVideo();
    return super.close();
  }

  void _letGoOfVideo() {
    final video = _heldVideo;
    _heldVideo = null;
    if (video != null) _store?.releaseVideo(video);
  }

  DmVideoPlaybackState _withSaveStatus(DmVideoSaveStatus saveStatus) =>
      DmVideoPlaybackState(
        status: state.status,
        clipPath: state.clipPath,
        saveStatus: saveStatus,
      );
}
