// ABOUTME: Lists the account's open collaborative rooms and starts new ones,
// ABOUTME: for the camera's Together tab

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/collab_room/collab_room_service.dart';

/// How creating a room is going.
enum CollabRoomsCreateStatus {
  /// Nothing being created.
  idle,

  /// Sending the invites.
  creating,

  /// The room is in [CollabRoomsState.createdRoomId].
  created,

  /// No invite could be sent.
  failed,
}

/// State of [CollabRoomsCubit].
class CollabRoomsState extends Equatable {
  /// Creates a state.
  const CollabRoomsState({
    this.rooms = const [],
    this.createStatus = CollabRoomsCreateStatus.idle,
    this.createdRoomId,
  });

  /// The open rooms the account is still in, newest first.
  final List<CollabRoom> rooms;

  /// How creating a room is going.
  final CollabRoomsCreateStatus createStatus;

  /// The room just created, once [createStatus] is created.
  final String? createdRoomId;

  /// Returns a copy with the given fields replaced.
  CollabRoomsState copyWith({
    List<CollabRoom>? rooms,
    CollabRoomsCreateStatus? createStatus,
    String? createdRoomId,
  }) => CollabRoomsState(
    rooms: rooms ?? this.rooms,
    createStatus: createStatus ?? this.createStatus,
    createdRoomId: createdRoomId ?? this.createdRoomId,
  );

  @override
  List<Object?> get props => [rooms, createStatus, createdRoomId];
}

/// Lists the account's open rooms and creates new ones.
class CollabRoomsCubit extends Cubit<CollabRoomsState>
    with CloseGuardedEmit<CollabRoomsState> {
  /// Creates a cubit and starts watching the account's rooms.
  CollabRoomsCubit({required CollabRoomService service})
    : _service = service,
      super(const CollabRoomsState()) {
    _subscription = _service.watchRooms().listen(
      (rooms) => emitIfOpen(
        state.copyWith(rooms: rooms.where(_isOpenForMe).toList()),
      ),
      onError: addError,
    );
  }

  final CollabRoomService _service;
  late final StreamSubscription<List<CollabRoom>> _subscription;

  static bool _isOpenForMe(CollabRoom room) =>
      room.phase.isOpen &&
      (room.isAuthor || (room.me?.status.isActive ?? false));

  /// Creates a room with [invitees].
  Future<void> create(List<String> invitees) async {
    if (invitees.isEmpty || state.createStatus == .creating) return;
    emitIfOpen(state.copyWith(createStatus: .creating));
    try {
      final roomId = await _service.createRoom(invitees);
      emitIfOpen(
        state.copyWith(createStatus: .created, createdRoomId: roomId),
      );
    } on CollabRoomException catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(createStatus: .failed));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
