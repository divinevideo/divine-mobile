// ABOUTME: Cubit that saves a received encrypted video DM to the gallery from
// ABOUTME: the conversation's message actions, using the video kept on device.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/dm/video_playback/dm_video_playback_cubit.dart'
    show DmVideoSaveStatus;
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show EditorVideo;

export 'package:openvine/blocs/dm/video_playback/dm_video_playback_cubit.dart'
    show DmVideoSaveStatus;

/// [EncryptedVideoSaveCubit] state.
class EncryptedVideoSaveState extends Equatable {
  /// Creates an [EncryptedVideoSaveState].
  const EncryptedVideoSaveState({this.status = DmVideoSaveStatus.idle});

  /// Outcome of the most recent save.
  final DmVideoSaveStatus status;

  @override
  List<Object?> get props => [status];
}

/// Saves a received encrypted video DM to the device gallery.
///
/// The video comes from the [DmVideoStore] of the account signed in when the
/// save starts, which downloads and decrypts it the first time and keeps it.
/// The save holds it until the gallery has its copy.
class EncryptedVideoSaveCubit extends Cubit<EncryptedVideoSaveState>
    with CloseGuardedEmit<EncryptedVideoSaveState> {
  /// Creates an [EncryptedVideoSaveCubit].
  EncryptedVideoSaveCubit({
    required DmVideoStoreResolver resolveStore,
    required GallerySaveService gallerySaveService,
  }) : _resolveStore = resolveStore,
       _gallerySaveService = gallerySaveService,
       super(const EncryptedVideoSaveState());

  final DmVideoStoreResolver _resolveStore;
  final GallerySaveService _gallerySaveService;

  /// Saves [message]'s video to the gallery, downloading and decrypting it
  /// the first time. A second call while a save is running is dropped.
  Future<void> save(DmMessage message) async {
    if (state.status == DmVideoSaveStatus.saving) return;
    emit(const EncryptedVideoSaveState(status: DmVideoSaveStatus.saving));

    try {
      final store = _resolveStore();
      if (store == null) {
        throw const DmVideoUnavailableException('no account is signed in');
      }
      final video = await store.videoFor(message);
      final GallerySaveResult result;
      try {
        result = await _gallerySaveService.saveVideoToGallery(
          EditorVideo.file(video.path),
          // The kept file is named after its message.
          copyUnderNeutralName: true,
        );
      } finally {
        store.releaseVideo(video);
      }
      emitIfOpen(
        EncryptedVideoSaveState(
          status: switch (result) {
            GallerySaveSuccess() => DmVideoSaveStatus.saved,
            GallerySavePermissionDenied() => DmVideoSaveStatus.permissionDenied,
            GallerySaveFailure() => DmVideoSaveStatus.failed,
          },
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        const EncryptedVideoSaveState(status: DmVideoSaveStatus.failed),
      );
    }
  }
}
