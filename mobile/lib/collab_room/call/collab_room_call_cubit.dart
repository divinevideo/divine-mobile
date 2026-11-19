// ABOUTME: The room screen's side of a Together call: joining with the
// ABOUTME: microphone on, muting, the camera, and who is connected

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Where this device is in the call.
enum CollabRoomCallStatus {
  /// Not in the call.
  idle,

  /// Opening the microphone and reaching the others.
  joining,

  /// In the call.
  joined,

  /// The microphone could not be opened.
  failed,

  /// The others could not be reached: no relay took the call's messages, or
  /// the relays stopped carrying them.
  unreachable,
}

/// State of [CollabRoomCallCubit].
class CollabRoomCallState extends Equatable {
  /// Creates a state.
  const CollabRoomCallState({
    required this.others,
    this.status = CollabRoomCallStatus.idle,
    this.call = const CollabRoomCallSnapshot(),
    this.cameraFailed = false,
  });

  /// The other people in the room.
  final Set<String> others;

  /// Where this device is in the call.
  final CollabRoomCallStatus status;

  /// The call as this device sees it.
  final CollabRoomCallSnapshot call;

  /// Whether the camera could not be opened the last time it was asked.
  final bool cameraFailed;

  /// Returns a copy with the given fields replaced.
  CollabRoomCallState copyWith({
    Set<String>? others,
    CollabRoomCallStatus? status,
    CollabRoomCallSnapshot? call,
    bool? cameraFailed,
  }) => CollabRoomCallState(
    others: others ?? this.others,
    status: status ?? this.status,
    call: call ?? this.call,
    cameraFailed: cameraFailed ?? this.cameraFailed,
  );

  @override
  List<Object?> get props => [others, status, call, cameraFailed];
}

/// Runs this device's side of a room's call.
class CollabRoomCallCubit extends Cubit<CollabRoomCallState>
    with CloseGuardedEmit<CollabRoomCallState> {
  /// Creates a cubit for [me] in the call of [callKey] with [others].
  CollabRoomCallCubit({
    required String me,
    required String callKey,
    required Set<String> others,
    required CollabRoomCallFactory createCall,
  }) : _me = me,
       _callKey = callKey,
       _createCall = createCall,
       super(CollabRoomCallState(others: others));

  final String _me;
  final String _callKey;
  final CollabRoomCallFactory _createCall;

  /// The running call: a resource handle like a stream subscription, not
  /// state, so it stays out of [CollabRoomCallState].
  CollabRoomCall? _call;
  StreamSubscription<CollabRoomCallSnapshot>? _changes;
  Future<void>? _stopping;
  CollabRoomCall? _changingCamera;
  bool _closing = false;

  /// Joins the call with the microphone on.
  Future<void> join() async {
    if (_closing ||
        _call != null ||
        _stopping != null ||
        state.others.isEmpty) {
      return;
    }
    emitIfOpen(state.copyWith(status: CollabRoomCallStatus.joining));
    CollabRoomCall? call;
    try {
      call = _call = _createCall(
        me: _me,
        others: state.others,
        callKey: _callKey,
      );
      _changes = call.changes.listen(
        (snapshot) {
          if (identical(_call, call)) {
            emitIfOpen(state.copyWith(call: snapshot));
          }
        },
        // The call gave up on its own, say once the relays stopped carrying
        // it: hang up and say so, rather than show a call nobody can hear.
        onError: (Object error, StackTrace stackTrace) {
          if (!identical(_call, call) || _closing) return;
          addError(error, stackTrace);
          runDetached(
            _giveUp(),
            'hang up a collab room call that failed',
            logName: 'CollabRoomCallCubit',
            category: LogCategory.video,
          );
        },
      );
      await call.start();
      if (identical(_call, call)) {
        emitIfOpen(state.copyWith(status: CollabRoomCallStatus.joined));
      }
    } on CollabRoomCallException catch (error, stackTrace) {
      if (!identical(_call, call) || _closing) return;
      addError(error, stackTrace);
      await _giveUp();
    } on Object catch (error, stackTrace) {
      if (!identical(_call, call) || _closing) return;
      addError(error, stackTrace);
      await _hangUp();
      emitIfOpen(state.copyWith(status: CollabRoomCallStatus.failed));
    }
  }

  /// Leaves the call and releases the microphone and camera, for filming a
  /// part or leaving the room.
  Future<void> leave() async {
    await _hangUp();
    emitIfOpen(
      state.copyWith(
        status: CollabRoomCallStatus.idle,
        call: const CollabRoomCallSnapshot(),
      ),
    );
  }

  /// Mutes or unmutes the microphone.
  Future<void> toggleMic() async {
    try {
      await _call?.setMicOn(!state.call.micOn);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// Turns the camera on or off.
  Future<void> toggleCamera() async {
    final call = _call;
    if (call == null || identical(_changingCamera, call)) return;
    _changingCamera = call;
    try {
      await call.setCameraOn(!state.call.cameraOn);
      if (identical(_call, call)) {
        emitIfOpen(state.copyWith(cameraFailed: false));
      }
    } on Object catch (error, stackTrace) {
      if (!identical(_call, call)) return;
      addError(error, stackTrace);
      emitIfOpen(state.copyWith(cameraFailed: true));
    } finally {
      if (identical(_changingCamera, call)) _changingCamera = null;
    }
  }

  /// Tells the others the lobby as it stands, as the author — see
  /// [CollabRoomCall.shareLobby]. Outside the call it goes nowhere: the room's
  /// own snapshot carries it anyway.
  Future<void> shareLobby({
    required String? layout,
    required List<String> seats,
    required int revision,
  }) async {
    final call = _call;
    if (call == null || state.status != CollabRoomCallStatus.joined) return;
    try {
      await call.shareLobby(layout: layout, seats: seats, revision: revision);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// The other people in the room changed.
  void othersChanged(Set<String> others) {
    if (others.length == state.others.length &&
        others.containsAll(state.others)) {
      return;
    }
    emitIfOpen(state.copyWith(others: others));
    _call?.updateOthers(others);
  }

  Future<void> _giveUp() async {
    await _hangUp();
    emitIfOpen(state.copyWith(status: CollabRoomCallStatus.unreachable));
  }

  Future<void> _hangUp() {
    final stopping = _stopping;
    if (stopping != null) return stopping;
    final call = _call;
    _call = null;
    if (call == null) return Future.value();
    return _stopping = _stopCall(call).whenComplete(() {
      _stopping = null;
    });
  }

  Future<void> _stopCall(CollabRoomCall call) async {
    try {
      await _changes?.cancel();
      _changes = null;
      await call.stop();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    await _hangUp();
    return super.close();
  }
}
