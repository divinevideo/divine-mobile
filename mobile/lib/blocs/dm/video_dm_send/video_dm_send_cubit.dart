// ABOUTME: Cubit for the encrypted video DM send flow.
// ABOUTME: Owns the picker-free send lifecycle so the composer renders
// ABOUTME: progress without knowing the encrypt/upload/send pipeline.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/services/dm_video_encryption.dart';
import 'package:openvine/services/dm_video_send_service.dart';

/// Size limit for a picked video, in whole megabytes, for display copy.
const int videoDmMaxMegabytes = dmVideoMaxPlaintextBytes ~/ (1024 * 1024);

/// Maps a picked file's extension to the plaintext MIME type recorded in the
/// kind 15 metadata. Defaults to `video/mp4`, the format the gallery picker
/// returns on both platforms.
String videoDmMimeTypeFor(String path) {
  final extension = path.split('.').last.toLowerCase();
  return switch (extension) {
    'mov' => 'video/quicktime',
    'm4v' => 'video/x-m4v',
    'webm' => 'video/webm',
    'avi' => 'video/x-msvideo',
    'mkv' => 'video/x-matroska',
    '3gp' => 'video/3gpp',
    _ => 'video/mp4',
  };
}

/// Lifecycle of a single encrypted video DM send.
enum VideoDmSendStatus {
  /// No send has started.
  idle,

  /// The plaintext file is being encrypted for upload.
  encrypting,

  /// The ciphertext is being uploaded to Blossom.
  uploading,

  /// The kind 15 file message is being published to relays.
  sending,

  /// The recipient gift wrap reached a relay.
  sent,

  /// The picked file exceeds [dmVideoMaxPlaintextBytes]; nothing was
  /// uploaded.
  tooLarge,

  /// The send did not complete. The cause is reported through `addError`.
  failed,
}

/// [VideoDmSendCubit] state: the current pipeline stage.
class VideoDmSendState extends Equatable {
  /// Creates a [VideoDmSendState].
  const VideoDmSendState({this.status = VideoDmSendStatus.idle});

  /// Current pipeline stage.
  final VideoDmSendStatus status;

  /// Whether a send is actively running and the composer should show progress.
  bool get isSending =>
      status == VideoDmSendStatus.encrypting ||
      status == VideoDmSendStatus.uploading ||
      status == VideoDmSendStatus.sending;

  @override
  List<Object?> get props => [status];
}

/// Drives one encrypted video DM send: encrypt, upload, publish.
///
/// A send already in flight drops a second call rather than queueing it, so a
/// double tap cannot publish two events for one picked file.
class VideoDmSendCubit extends Cubit<VideoDmSendState>
    with CloseGuardedEmit<VideoDmSendState> {
  /// Creates a [VideoDmSendCubit] backed by [service].
  VideoDmSendCubit({required DmVideoSendService service})
    : _service = service,
      super(const VideoDmSendState());

  final DmVideoSendService _service;

  /// Sends [videoFile] to [recipientPubkey] as a NIP-17 kind 15 file message.
  ///
  /// The plaintext MIME type is derived from the file extension with
  /// [videoDmMimeTypeFor]. The cubit only maps the service's phase callbacks
  /// and result to state; it holds no display copy.
  Future<void> send({
    required String recipientPubkey,
    required File videoFile,
  }) async {
    if (state.isSending) return;

    emit(const VideoDmSendState(status: VideoDmSendStatus.encrypting));
    try {
      final result = await _service.sendVideo(
        recipientPubkey: recipientPubkey,
        videoFile: videoFile,
        mimeType: videoDmMimeTypeFor(videoFile.path),
        onPhase: _onPhase,
      );
      if (result.success) {
        emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.sent));
        return;
      }
      addError(
        VideoDmSendFailure(result.error ?? 'unknown'),
        StackTrace.current,
      );
      emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.failed));
    } on DmVideoTooLargeException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.tooLarge));
    } catch (error, stackTrace) {
      // DivineBlocObserver logs every addError and forwards only
      // programming-invariant errors to crash reporting.
      addError(error, stackTrace);
      emitIfOpen(const VideoDmSendState(status: VideoDmSendStatus.failed));
    }
  }

  void _onPhase(DmVideoSendPhase phase) {
    if (isClosed) return;
    final status = switch (phase) {
      DmVideoSendPhase.encrypting => VideoDmSendStatus.encrypting,
      DmVideoSendPhase.uploading => VideoDmSendStatus.uploading,
      DmVideoSendPhase.sending => VideoDmSendStatus.sending,
    };
    if (status == state.status) return;
    emitIfOpen(VideoDmSendState(status: status));
  }
}

/// A send the pipeline refused or could not complete, carrying the
/// repository's diagnostic reason for logs. Never shown to the user.
class VideoDmSendFailure implements Exception {
  /// Creates a [VideoDmSendFailure] with a diagnostic [reason].
  const VideoDmSendFailure(this.reason);

  /// Diagnostic text from the send result.
  final String reason;

  @override
  String toString() => 'VideoDmSendFailure: $reason';
}
