// ABOUTME: Cubit for the encrypted video DM send flow.
// ABOUTME: Owns the picker-free send lifecycle so the composer renders
// ABOUTME: progress without knowing the encrypt/upload/send pipeline.

import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/services/dm_video_send_service.dart';
import 'package:unified_logger/unified_logger.dart';

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

  /// The send did not complete; [VideoDmSendState.error] carries the reason.
  failed,
}

/// [VideoDmSendCubit] state: a status plus the last failure reason.
class VideoDmSendState extends Equatable {
  /// Creates a [VideoDmSendState].
  const VideoDmSendState({this.status = VideoDmSendStatus.idle, this.error});

  /// Current pipeline stage.
  final VideoDmSendStatus status;

  /// Failure reason for [VideoDmSendStatus.failed]; `null` otherwise.
  final String? error;

  /// Whether a send is actively running and the composer should show progress.
  bool get isSending =>
      status == VideoDmSendStatus.encrypting ||
      status == VideoDmSendStatus.uploading ||
      status == VideoDmSendStatus.sending;

  @override
  List<Object?> get props => [status, error];
}

/// Drives one encrypted video DM send: encrypt, upload, publish.
///
/// A send already in flight drops a second call rather than queueing it, so a
/// double tap cannot publish two events for one picked file.
class VideoDmSendCubit extends Cubit<VideoDmSendState> {
  /// Creates a [VideoDmSendCubit] backed by [service].
  VideoDmSendCubit({required DmVideoSendService service})
    : _service = service,
      super(const VideoDmSendState());

  final DmVideoSendService _service;

  /// Sends [videoFile] to [recipientPubkey] as a NIP-17 kind 15 file message.
  ///
  /// [mimeType] is the plaintext file's MIME type. The cubit only maps the
  /// service's phase callbacks and result to state; it holds no display copy.
  Future<void> send({
    required String recipientPubkey,
    required File videoFile,
    required String mimeType,
  }) async {
    if (state.isSending) return;

    emit(const VideoDmSendState(status: VideoDmSendStatus.encrypting));
    try {
      final result = await _service.sendVideo(
        recipientPubkey: recipientPubkey,
        videoFile: videoFile,
        mimeType: mimeType,
        onPhase: _onPhase,
      );
      if (isClosed) return;
      emit(
        result.success
            ? const VideoDmSendState(status: VideoDmSendStatus.sent)
            : VideoDmSendState(
                status: VideoDmSendStatus.failed,
                error: result.error,
              ),
      );
    } catch (error, stackTrace) {
      Log.error(
        'Encrypted video DM send failed',
        name: 'VideoDmSendCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      if (!isClosed) {
        emit(
          VideoDmSendState(
            status: VideoDmSendStatus.failed,
            error: error.toString(),
          ),
        );
      }
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
    emit(VideoDmSendState(status: status));
  }
}
