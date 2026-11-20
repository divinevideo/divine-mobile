import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/collab_room/call/collab_room_call.dart';
import 'package:openvine/collab_room/call/collab_room_call_cubit.dart';

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _kai = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

class _FakeCall implements CollabRoomCall {
  _FakeCall({
    this.failStart = false,
    this.unreachable = false,
    this.refusedMicrophone = false,
    this.failCamera = false,
  });

  final bool failStart;
  final bool unreachable;
  final bool refusedMicrophone;
  final bool failCamera;
  final controller = StreamController<CollabRoomCallSnapshot>.broadcast();
  final log = <String>[];
  bool mic = true;
  bool camera = false;

  @override
  Stream<CollabRoomCallSnapshot> get changes => controller.stream;

  void _emit() =>
      controller.add(CollabRoomCallSnapshot(micOn: mic, cameraOn: camera));

  @override
  Future<void> start() async {
    log.add('start');
    if (failStart) throw Exception('no microphone');
    if (refusedMicrophone) {
      throw const CollabRoomMicrophoneException('Permission denied');
    }
    if (unreachable) {
      throw const CollabRoomCallException('No relay accepted the call signal');
    }
    _emit();
  }

  @override
  Future<void> setMicOn(bool on) async {
    mic = on;
    _emit();
  }

  @override
  Future<void> setCameraOn(bool on) async {
    if (failCamera) throw Exception('no camera');
    camera = on;
    _emit();
  }

  @override
  void updateOthers(Set<String> others) => log.add('others ${others.length}');

  @override
  Future<void> shareLobby({
    required String? layout,
    required List<String> seats,
    required int revision,
  }) async => log.add('lobby $layout ${seats.length} $revision');

  @override
  Future<void> stop() async => log.add('stop');
}

void main() {
  group(CollabRoomCallCubit, () {
    late _FakeCall call;
    late List<Set<String>> created;

    setUp(() {
      call = _FakeCall();
      created = [];
    });

    CollabRoomCallCubit build({_FakeCall? fake, Set<String>? others}) =>
        CollabRoomCallCubit(
          me: _author,
          callKey: 'f' * 64,
          others: others ?? {_sam},
          createCall: ({required me, required others, required callKey}) {
            created.add(others);
            return fake ?? call;
          },
        );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'joins with the microphone on',
      build: build,
      act: (cubit) => cubit.join(),
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomCallStatus.joined);
        expect(cubit.state.call.micOn, isTrue);
        expect(created.single, {_sam});
        // blocTest verifies after close(), which hangs up.
        expect(call.log, ['start', 'stop']);
      },
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'joins nobody when the room has no one else',
      build: () => build(others: {}),
      act: (cubit) => cubit.join(),
      expect: () => const <CollabRoomCallState>[],
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'reports a microphone it cannot open and hangs up',
      build: () => build(fake: _FakeCall(failStart: true)),
      act: (cubit) => cubit.join(),
      verify: (cubit) =>
          expect(cubit.state.status, CollabRoomCallStatus.failed),
      errors: () => [isA<Exception>()],
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'reports others it cannot reach, not the microphone',
      build: () => build(fake: _FakeCall(unreachable: true)),
      act: (cubit) => cubit.join(),
      verify: (cubit) =>
          expect(cubit.state.status, CollabRoomCallStatus.unreachable),
      errors: () => [isA<CollabRoomCallException>()],
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'hangs up and says so when the call gives up on its own',
      build: build,
      act: (cubit) async {
        await cubit.join();
        call.controller.addError(
          const CollabRoomCallException('The relays stopped carrying the call'),
        );
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomCallStatus.unreachable);
        expect(call.log, ['start', 'stop']);
      },
      errors: () => [isA<CollabRoomCallException>()],
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'reports a refused microphone as such, not as others out of reach',
      build: () => build(fake: _FakeCall(refusedMicrophone: true)),
      act: (cubit) => cubit.join(),
      verify: (cubit) =>
          expect(cubit.state.status, CollabRoomCallStatus.failed),
      errors: () => [isA<CollabRoomMicrophoneException>()],
    );

    test('keeps the microphone muted when the call comes back', () async {
      final calls = <_FakeCall>[];
      final cubit = CollabRoomCallCubit(
        me: _author,
        callKey: 'f' * 64,
        others: {_sam},
        createCall: ({required me, required others, required callKey}) {
          final fresh = _FakeCall();
          calls.add(fresh);
          return fresh;
        },
      );
      addTearDown(cubit.close);

      await cubit.join();
      await pumpEventQueue();
      await cubit.toggleMic();
      await cubit.stepAside();
      await cubit.comeBack();
      await pumpEventQueue();

      expect(calls, hasLength(2));
      // The new call opened the microphone on, then muted it at once.
      expect(calls.last.mic, isFalse);
      expect(cubit.state.call.micOn, isFalse);
      expect(cubit.state.muted, isTrue);
    });

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'mutes and turns the camera on',
      build: build,
      act: (cubit) async {
        await cubit.join();
        await cubit.toggleMic();
        await cubit.toggleCamera();
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.call.micOn, isFalse);
        expect(cubit.state.call.cameraOn, isTrue);
        expect(cubit.state.cameraFailed, isFalse);
      },
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'reports a camera it cannot open',
      build: () => build(fake: _FakeCall(failCamera: true)),
      act: (cubit) async {
        await cubit.join();
        await cubit.toggleCamera();
      },
      verify: (cubit) => expect(cubit.state.cameraFailed, isTrue),
      errors: () => [isA<Exception>()],
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'joins on its own once someone else is in the room',
      build: () => build(others: {}),
      act: (cubit) async {
        cubit.othersChanged({_sam});
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomCallStatus.joined);
        expect(created.single, {_sam});
      },
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'stays out while stepped aside for the camera, then comes back',
      build: build,
      act: (cubit) async {
        await cubit.join();
        await cubit.stepAside();
        // Someone joining meanwhile does not take the microphone back.
        cubit.othersChanged({_sam, _kai});
        await pumpEventQueue();
        expect(cubit.state.status, CollabRoomCallStatus.idle);
        await cubit.comeBack();
      },
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomCallStatus.joined);
        expect(cubit.state.steppedAside, isFalse);
        expect(created, [
          {_sam},
          {_sam, _kai},
        ]);
        expect(call.log, ['start', 'stop', 'start', 'stop']);
      },
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'comes back after a hang-up that is still under way',
      build: build,
      act: (cubit) async {
        await cubit.join();
        unawaited(cubit.stepAside());
        await cubit.comeBack();
      },
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomCallStatus.joined);
        expect(call.log, ['start', 'stop', 'start', 'stop']);
      },
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'does not try again on its own after the call failed',
      build: () => build(fake: _FakeCall(unreachable: true)),
      act: (cubit) async {
        await cubit.join();
        cubit.othersChanged({_sam, _kai});
        await pumpEventQueue();
      },
      verify: (cubit) {
        expect(cubit.state.status, CollabRoomCallStatus.unreachable);
        expect(created, hasLength(1));
      },
      errors: () => [isA<CollabRoomCallException>()],
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'tells the call when the room changes',
      build: build,
      act: (cubit) async {
        await cubit.join();
        cubit
          ..othersChanged({_sam})
          ..othersChanged({_sam, _kai});
      },
      verify: (cubit) {
        expect(cubit.state.others, {_sam, _kai});
        expect(call.log, ['start', 'others 2', 'stop']);
      },
    );

    blocTest<CollabRoomCallCubit, CollabRoomCallState>(
      'shares the lobby once in the call, and not before',
      build: build,
      act: (cubit) async {
        await cubit.shareLobby(
          layout: 'stacked',
          seats: [_author],
          revision: 1,
        );
        await cubit.join();
        await cubit.shareLobby(
          layout: 'stacked',
          seats: [_author, _sam],
          revision: 2,
        );
      },
      verify: (_) => expect(call.log, ['start', 'lobby stacked 2 2', 'stop']),
    );

    test('hangs up when closed', () async {
      final cubit = build();
      await cubit.join();
      await cubit.close();
      expect(call.log, ['start', 'stop']);
    });
  });
}
