// ABOUTME: Hands in the account's finished part of a collaborative room once
// ABOUTME: the editor rendered it, uploading it ahead and reporting progress

import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/collab_room/collab_room_service.dart';

/// How handing in the part is going.
enum CollabRoomPartStatus {
  /// Not sent yet.
  idle,

  /// Uploading and sending.
  sending,

  /// The part is in.
  sent,

  /// The room is closed, or the upload or message failed.
  failed,
}

/// State of [CollabRoomPartCubit].
class CollabRoomPartState extends Equatable {
  /// Creates a state.
  const CollabRoomPartState({
    this.status = CollabRoomPartStatus.idle,
    this.uploadProgress,
  });

  /// How handing in the part is going.
  final CollabRoomPartStatus status;

  /// How much of the part's upload is done, from 0 to 1, or `null` while
  /// nothing uploads.
  final double? uploadProgress;

  /// Returns a copy with the given fields replaced.
  CollabRoomPartState copyWith({
    CollabRoomPartStatus? status,
    double? uploadProgress,
    bool clearUploadProgress = false,
  }) => CollabRoomPartState(
    status: status ?? this.status,
    uploadProgress: clearUploadProgress
        ? null
        : uploadProgress ?? this.uploadProgress,
  );

  @override
  List<Object?> get props => [status, uploadProgress];
}

/// Hands in the account's part of one room.
///
/// The upload starts as soon as the part is rendered ([prepare]), so tapping
/// Send only has to hand the uploaded part in; [CollabRoomPartState] tells
/// how far the upload got meanwhile.
class CollabRoomPartCubit extends Cubit<CollabRoomPartState>
    with CloseGuardedEmit<CollabRoomPartState> {
  /// Creates a cubit for [roomId].
  CollabRoomPartCubit({
    required CollabRoomService service,
    required String roomId,
  }) : _service = service,
       _roomId = roomId,
       super(const CollabRoomPartState());

  /// The smallest step of progress worth showing: Blossom reports every
  /// chunk, and the screen needs whole percents.
  static const double _progressStep = 0.01;

  final CollabRoomService _service;
  final String _roomId;

  /// The upload of the part on screen, by its path: a resource handle like a
  /// stream subscription, not state. A new render uploads afresh; a failed
  /// one is dropped so the next Send tries again.
  ({String path, Future<CollabRoomUpload> upload})? _upload;

  /// Starts uploading [video] ahead of [send].
  void prepare(File video) => _uploadOf(video);

  Future<CollabRoomUpload> _uploadOf(File video) {
    final current = _upload;
    if (current != null && current.path == video.path) return current.upload;
    final path = video.path;
    // Registered before the upload starts, so its first progress already
    // counts as this upload's.
    final uploaded = Completer<CollabRoomUpload>();
    _upload = (path: path, upload: uploaded.future);
    // A failure surfaces when Send awaits it, never as an unhandled error.
    unawaited(
      uploaded.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    bool isCurrent() => _upload?.path == path;
    emitIfOpen(state.copyWith(uploadProgress: 0));
    unawaited(
      _service
          .uploadPart(
            video,
            onProgress: (fraction) {
              if (!isCurrent()) return;
              final shown = state.uploadProgress ?? 0;
              if (fraction - shown < _progressStep && fraction < 1) return;
              emitIfOpen(
                state.copyWith(uploadProgress: fraction.clamp(0.0, 1.0)),
              );
            },
          )
          .then((upload) {
            if (isCurrent()) emitIfOpen(state.copyWith(uploadProgress: 1));
            uploaded.complete(upload);
          }, onError: uploaded.completeError),
    );
    return uploaded.future;
  }

  /// Hands in [video] as the account's part, uploading it first unless
  /// [prepare] already did.
  Future<void> send(File video) async {
    if (state.status == .sending || state.status == .sent) return;
    emitIfOpen(state.copyWith(status: CollabRoomPartStatus.sending));
    try {
      final room = await _service.watchRoom(_roomId).first;
      if (room == null || room.phase != CollabRoomPhase.recording) {
        throw const CollabRoomException('The room no longer takes parts');
      }
      final upload = await _uploadOf(video);
      await _service.handInPart(room, upload);
      emitIfOpen(state.copyWith(status: CollabRoomPartStatus.sent));
    } on CollabRoomException catch (error, stackTrace) {
      _upload = null;
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(
          status: CollabRoomPartStatus.failed,
          clearUploadProgress: true,
        ),
      );
    }
  }
}
