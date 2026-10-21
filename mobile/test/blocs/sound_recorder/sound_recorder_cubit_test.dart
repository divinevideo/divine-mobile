// ABOUTME: Unit tests for the Add sound screen's microphone recorder: permission
// ABOUTME: gating, handing over the finished file, the length cap, and cleanup.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_recorder/sound_recorder_cubit.dart';
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:sound_service/sound_service.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

class _FakeAudioSessionService extends AudioSessionService {
  int resetCount = 0;

  @override
  Future<void> resetAudioSession() async => resetCount++;
}

class _FakeRecorder implements VoiceOverRecorderService {
  final _levels = StreamController<double>.broadcast();
  bool throwOnStart = false;
  String? path;
  DateTime now = DateTime(2026);

  @override
  Stream<double> get amplitudeStream => _levels.stream;

  @override
  Future<void> start(String path) async {
    this.path = path;
    // The native recorder creates its output file as it starts.
    File(path).writeAsBytesSync([1, 2, 3]);
    if (throwOnStart) throw VoiceOverRecorderException('mic unavailable');
  }

  @override
  Future<String?> stop() async => path;

  @override
  Future<void> dispose() => _levels.close();

  Future<void> emitLevel(double level) async {
    now = now.add(SoundRecorderCubit.amplitudeInterval);
    _levels.add(level);
    await pumpEventQueue();
  }
}

void main() {
  group(SoundRecorderCubit, () {
    late Directory scratch;
    late _MockPermissionsService permissions;
    late _FakeAudioSessionService audioSession;
    late _FakeRecorder recorder;

    setUp(() async {
      scratch = await Directory.systemTemp.createTemp('sound_recorder_test_');
      permissions = _MockPermissionsService();
      audioSession = _FakeAudioSessionService();
      recorder = _FakeRecorder();
      when(
        permissions.checkMicrophoneStatus,
      ).thenAnswer((_) async => PermissionStatus.granted);
    });

    tearDown(() async {
      if (scratch.existsSync()) scratch.deleteSync(recursive: true);
    });

    SoundRecorderCubit build({Duration? maxDuration}) {
      final cubit = SoundRecorderCubit(
        permissionsService: permissions,
        audioSessionService: audioSession,
        recorder: recorder,
        scratchDirectoryProvider: () async => scratch,
        now: () => recorder.now,
        maxDuration: maxDuration ?? SoundRecorderCubit.defaultMaxDuration,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    group('start', () {
      test('asks for microphone access and records once granted', () async {
        when(
          permissions.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.canRequest);
        when(
          permissions.requestMicrophonePermission,
        ).thenAnswer((_) async => PermissionStatus.granted);
        final cubit = build();

        await cubit.start();

        expect(cubit.state.status, SoundRecorderStatus.recording);
        expect(File(recorder.path!).parent.path, scratch.path);
      });

      test('reports a refusal without starting the recorder', () async {
        when(
          permissions.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        final cubit = build();

        await cubit.start();

        expect(cubit.state.status, SoundRecorderStatus.permissionDenied);
        expect(recorder.path, isNull);
      });

      test('a recorder that fails to start leaves no file behind', () async {
        recorder.throwOnStart = true;
        final cubit = build();

        await cubit.start();

        expect(cubit.state.status, SoundRecorderStatus.failed);
        expect(File(recorder.path!).existsSync(), isFalse);
        expect(audioSession.resetCount, 1);
      });

      test(
        'reports each consecutive failed start to status listeners',
        () async {
          recorder.throwOnStart = true;
          final cubit = build();
          final statuses = <SoundRecorderStatus>[];
          final subscription = cubit.stream.listen(
            (state) => statuses.add(state.status),
          );
          addTearDown(subscription.cancel);

          await cubit.start();
          await cubit.start();
          await pumpEventQueue();

          expect(
            statuses.where((status) => status == SoundRecorderStatus.failed),
            hasLength(2),
          );
        },
      );

      test('the next recording deletes an unclaimed one', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        await cubit.stop();
        final unclaimed = File(cubit.state.recordingPath!);

        await cubit.start();

        expect(unclaimed.existsSync(), isFalse);
        expect(cubit.state.recordingPath, isNull);
      });
    });

    group('stop', () {
      test(
        'uses elapsed clock time instead of counting meter samples',
        () async {
          final cubit = build();
          await cubit.start();
          recorder.now = recorder.now.add(const Duration(seconds: 20));

          await recorder.emitLevel(0.5);

          expect(
            cubit.state.elapsed,
            const Duration(seconds: 20) + SoundRecorderCubit.amplitudeInterval,
          );
        },
      );

      testWidgets(
        'enforces the length limit even when no meter samples arrive',
        (tester) async {
          final cubit = build(maxDuration: const Duration(seconds: 1));
          await cubit.start();
          expect(cubit.state.isRecording, isTrue);

          await tester.pump(const Duration(seconds: 1));
          await tester.runAsync(pumpEventQueue);
          await tester.pump();

          expect(cubit.state.isActive, isFalse);
          expect(audioSession.resetCount, 1);
          expect(cubit.state.recordingPath, isNotNull);
          expect(File(cubit.state.recordingPath!).existsSync(), isTrue);
        },
      );

      test(
        'keeps a manually stopped recording when meter samples stall',
        () async {
          final cubit = build();
          await cubit.start();
          recorder.now = recorder.now.add(const Duration(minutes: 1));

          await cubit.stop();

          expect(cubit.state.status, SoundRecorderStatus.idle);
          expect(cubit.state.recordingPath, recorder.path);
          expect(File(recorder.path!).existsSync(), isTrue);
        },
      );

      test('hands the finished file over and resets the session', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        expect(cubit.state.elapsed, SoundRecorderCubit.amplitudeInterval);

        await cubit.stop();

        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(cubit.state.recordingPath, recorder.path);
        expect(File(recorder.path!).existsSync(), isTrue);
        expect(audioSession.resetCount, 1);
      });

      test('discards a recording stopped before its first level', () async {
        final cubit = build();
        await cubit.start();

        await cubit.stop();

        expect(cubit.state.recordingPath, isNull);
        expect(File(recorder.path!).existsSync(), isFalse);
      });

      test('stops on its own at the length limit', () async {
        final cubit = build(maxDuration: SoundRecorderCubit.amplitudeInterval);
        await cubit.start();

        await recorder.emitLevel(0.5);

        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(cubit.state.recordingPath, recorder.path);
      });
    });

    group('cancel', () {
      test('deletes the recording in progress', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);

        await cubit.cancel();

        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(cubit.state.recordingPath, isNull);
        expect(File(recorder.path!).existsSync(), isFalse);
      });
    });

    group('close', () {
      test('deletes a finished recording nobody took over', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        await cubit.stop();
        final unclaimed = File(cubit.state.recordingPath!);

        await cubit.close();

        expect(unclaimed.existsSync(), isFalse);
      });
    });
  });
}
