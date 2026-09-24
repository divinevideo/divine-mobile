// ABOUTME: Cubit that decrypts an encrypted video DM and saves it to the
// ABOUTME: gallery from the conversation's message actions.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/dm/video_playback/dm_video_playback_cubit.dart'
    show DmVideoSaveStatus;
import 'package:openvine/services/dm_video_decryptor.dart';
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

/// Decrypts a received encrypted video DM straight to the device gallery.
///
/// The plaintext temp file is always removed before the save settles.
class EncryptedVideoSaveCubit extends Cubit<EncryptedVideoSaveState>
    with CloseGuardedEmit<EncryptedVideoSaveState> {
  /// Creates an [EncryptedVideoSaveCubit].
  EncryptedVideoSaveCubit({
    required DmVideoDecryptor decryptor,
    required GallerySaveService gallerySaveService,
  }) : _decryptor = decryptor,
       _gallerySaveService = gallerySaveService,
       super(const EncryptedVideoSaveState());

  final DmVideoDecryptor _decryptor;
  final GallerySaveService _gallerySaveService;

  /// Decrypts [message]'s video and saves it to the gallery. A second call
  /// while a save is running is dropped.
  Future<void> save(DmMessage message) async {
    if (state.status == DmVideoSaveStatus.saving) return;
    emit(const EncryptedVideoSaveState(status: DmVideoSaveStatus.saving));

    String? path;
    try {
      path = await _decryptor.decryptToFile(message);
      final result = await _gallerySaveService.saveVideoToGallery(
        EditorVideo.file(path),
      );
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
    } finally {
      if (path != null) _decryptor.deleteClip(path);
    }
  }
}
