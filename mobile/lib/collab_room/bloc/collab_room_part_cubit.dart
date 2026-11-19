// ABOUTME: Hands in the account's finished part of a collaborative room
// ABOUTME: once the editor rendered it

import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
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

/// Hands in the account's part of one room.
class CollabRoomPartCubit extends Cubit<CollabRoomPartStatus>
    with CloseGuardedEmit<CollabRoomPartStatus> {
  /// Creates a cubit for [roomId].
  CollabRoomPartCubit({
    required CollabRoomService service,
    required String roomId,
  }) : _service = service,
       _roomId = roomId,
       super(CollabRoomPartStatus.idle);

  final CollabRoomService _service;
  final String _roomId;

  /// Hands in [video] as the account's part.
  Future<void> send(File video) async {
    if (state == .sending || state == .sent) return;
    emitIfOpen(CollabRoomPartStatus.sending);
    try {
      final room = await _service.watchRoom(_roomId).first;
      if (room == null || room.phase != CollabRoomPhase.recording) {
        throw const CollabRoomException('The room no longer takes parts');
      }
      await _service.sendPart(room, video);
      emitIfOpen(CollabRoomPartStatus.sent);
    } on CollabRoomException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(CollabRoomPartStatus.failed);
    }
  }
}
