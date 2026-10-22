// ABOUTME: Unit tests for the Add sound screen's microphone recorder: permission
// ABOUTME: gating, handing over the finished file, the length cap, and cleanup.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_recorder/sound_recorder_cubit.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:openvine/services/video_editor/voice_over_recorder_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:sound_service/sound_service.dart';

class _MockPermissionsService extends Mock implements PermissionsService {}

class _FakeAudioSessionService extends AudioSessionService {
  int resetCount = 0;

  /// Thrown by every reset when set. The real service swallows exceptions,
  /// so only an `Error` from the `audio_session` plugin can reach the cubit.
  Error? resetError;

  @override
  Future<void> resetAudioSession() async {
    resetCount++;
    if (resetError case final error?) throw error;
  }
}

/// Like `record`'s `AudioRecorder`, runs start, stop and dispose one at a
/// time (`record.dart` `_safeCall` behind one semaphore), so a dispose waits
/// for a start or stop that is still in flight.
class _FakeRecorder implements VoiceOverRecorderService {
  final _levels = StreamController<double>.broadcast();
  bool throwOnStart = false;
  bool throwOnStop = false;
  int startCount = 0;
  int stopCount = 0;
  String? path;
  DateTime now = DateTime(2026);
  Future<void>? _inFlight;

  /// When set, [start] waits for it before the native file appears, as the
  /// real recorder does while it opens the microphone.
  Completer<void>? startGate;

  /// When set, [stop] waits for it before the native recorder finishes.
  Completer<void>? stopGate;

  /// When set, [dispose] waits for it, standing in for the platform round
  /// trip that keeps close() from finishing straight away.
  Completer<void>? disposeGate;

  final _pauses = StreamController<void>.broadcast();

  @override
  Stream<double> get amplitudeStream => _levels.stream;

  @override
  Stream<void> get systemPauses => _pauses.stream;

  Future<T> _oneAtATime<T>(Future<T> Function() call) async {
    for (var pending = _inFlight; pending != null; pending = _inFlight) {
      await pending;
    }
    final done = Completer<void>();
    _inFlight = done.future;
    try {
      return await call();
    } finally {
      _inFlight = null;
      done.complete();
    }
  }

  @override
  Future<void> start(String path) => _oneAtATime(() async {
    startCount++;
    this.path = path;
    await startGate?.future;
    // The native recorder creates its output file as it starts.
    File(path).writeAsBytesSync([1, 2, 3]);
    if (throwOnStart) throw VoiceOverRecorderException('mic unavailable');
  });

  @override
  Future<String?> stop() => _oneAtATime(() async {
    stopCount++;
    await stopGate?.future;
    if (throwOnStop) throw VoiceOverRecorderException('stop failed');
    return path;
  });

  @override
  Future<void> dispose() => _oneAtATime(() async {
    await disposeGate?.future;
    await _levels.close();
    await _pauses.close();
  });

  /// Whether the cubit is still subscribed to [systemPauses].
  bool get isWatchingPauses => _pauses.hasListener;

  /// A call, Siri or another app taking audio focus.
  Future<void> pauseBySystem() async {
    _pauses.add(null);
    await pumpEventQueue();
  }

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

    SoundRecorderCubit build({
      Duration? maxDuration,
      Future<Directory> Function()? scratchDirectoryProvider,
      bool closeOnTearDown = true,
    }) {
      final cubit = SoundRecorderCubit(
        permissionsService: permissions,
        audioSessionService: audioSession,
        recorder: recorder,
        scratchDirectoryProvider:
            scratchDirectoryProvider ?? () async => scratch,
        now: () => recorder.now,
        maxDuration: maxDuration ?? SoundRecorderCubit.defaultMaxDuration,
      );
      if (closeOnTearDown) addTearDown(cubit.close);
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

      test('a second tap while the first is starting is ignored', () async {
        final permission = Completer<PermissionStatus>();
        when(
          permissions.checkMicrophoneStatus,
        ).thenAnswer((_) => permission.future);
        final cubit = build();

        final first = cubit.start();
        final second = cubit.start();
        permission.complete(PermissionStatus.granted);
        await Future.wait([first, second]);

        verify(permissions.checkMicrophoneStatus).called(1);
        expect(recorder.startCount, 1);
        expect(cubit.state.status, SoundRecorderStatus.recording);
      });

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

      test('records after a start that visibility stopped', () async {
        recorder.startGate = Completer<void>();
        final cubit = build();
        final interrupted = cubit.start();
        await pumpEventQueue();
        await cubit.stop();
        recorder.startGate!.complete();
        await interrupted;
        expect(cubit.state.status, SoundRecorderStatus.idle);
        recorder.startGate = null;

        await cubit.start();

        expect(cubit.state.status, SoundRecorderStatus.recording);
        expect(recorder.startCount, 2);
      });
    });

    group('stop', () {
      test(
        'cancel during a stop discards the take instead of publishing it',
        () async {
          final cubit = build();
          await cubit.start();
          await recorder.emitLevel(0.5);
          recorder.stopGate = Completer<void>();
          final stopping = cubit.stop();
          await pumpEventQueue();
          expect(cubit.state.status, SoundRecorderStatus.stopping);

          final cancelling = cubit.cancel();
          recorder.stopGate!.complete();
          await Future.wait([stopping, cancelling]);

          expect(cubit.state.recordingPath, isNull);
          expect(File(recorder.path!).existsSync(), isFalse);
        },
      );

      test(
        'cancellation enters stopping while the native recorder flushes',
        () async {
          final cubit = build();
          await cubit.start();
          await recorder.emitLevel(0.5);
          recorder.stopGate = Completer<void>();
          final cancelling = cubit.cancel();
          await pumpEventQueue();
          try {
            expect(cubit.state.status, SoundRecorderStatus.stopping);
          } finally {
            recorder.stopGate!.complete();
            await cancelling;
          }
        },
      );
      test('does not miss a system pause during native startup', () async {
        recorder.startGate = Completer<void>();
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();

        await recorder.pauseBySystem();
        recorder.startGate!.complete();
        await starting;

        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(recorder.stopCount, 1);
        expect(File(recorder.path!).existsSync(), isFalse);
      });

      test(
        'aborts an in-flight native start when visibility requests stop',
        () async {
          recorder.startGate = Completer<void>();
          final cubit = build();
          final starting = cubit.start();
          await pumpEventQueue();
          expect(cubit.state.isStarting, isTrue);

          await cubit.stop();
          recorder.startGate!.complete();
          await starting;

          expect(cubit.state.status, SoundRecorderStatus.idle);
          expect(recorder.stopCount, 1);
          expect(File(recorder.path!).existsSync(), isFalse);
        },
      );

      test('shows no permission prompt when visibility requests stop during '
          'the permission check', () async {
        final check = Completer<PermissionStatus>();
        when(permissions.checkMicrophoneStatus).thenAnswer((_) => check.future);
        when(
          permissions.requestMicrophonePermission,
        ).thenAnswer((_) async => PermissionStatus.granted);
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();

        await cubit.stop();
        check.complete(PermissionStatus.canRequest);
        await starting;

        verifyNever(permissions.requestMicrophonePermission);
        expect(cubit.state.status, SoundRecorderStatus.idle);
      });

      test('never starts the recorder when visibility requests stop while '
          'the scratch folder resolves', () async {
        final folder = Completer<Directory>();
        final cubit = build(scratchDirectoryProvider: () => folder.future);
        final starting = cubit.start();
        await pumpEventQueue();

        await cubit.stop();
        folder.complete(scratch);
        await starting;

        expect(recorder.startCount, 0);
        expect(cubit.state.status, SoundRecorderStatus.idle);
      });

      test('reports no failure for a start visibility stopped that then '
          'fails natively', () async {
        recorder
          ..startGate = Completer<void>()
          ..throwOnStart = true;
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();

        await cubit.stop();
        recorder.startGate!.complete();
        await starting;

        expect(cubit.state.status, SoundRecorderStatus.idle);
      });

      testWidgets('never announces or vibrates for a native start that '
          'visibility stopped', (tester) async {
        var vibrations = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') vibrations++;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        recorder.startGate = Completer<void>();
        final cubit = build();
        final statuses = <SoundRecorderStatus>[];
        final subscription = cubit.stream.listen((s) => statuses.add(s.status));
        addTearDown(subscription.cancel);
        final starting = cubit.start();
        await tester.runAsync(pumpEventQueue);

        await cubit.stop();
        recorder.startGate!.complete();
        await tester.runAsync(pumpEventQueue);
        await starting;
        await tester.runAsync(pumpEventQueue);

        expect(statuses, isNot(contains(SoundRecorderStatus.recording)));
        expect(statuses.last, SoundRecorderStatus.idle);
        expect(vibrations, 0);
      });

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

      test('a recorder that fails to stop deletes the take', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        recorder.throwOnStop = true;

        await cubit.stop();

        expect(cubit.state.status, SoundRecorderStatus.failed);
        expect(cubit.state.recordingPath, isNull);
        expect(File(recorder.path!).existsSync(), isFalse);
        expect(audioSession.resetCount, 1);
      });

      test('discards a recording stopped before its first level', () async {
        final cubit = build();
        await cubit.start();

        await cubit.stop();

        expect(cubit.state.recordingPath, isNull);
        expect(File(recorder.path!).existsSync(), isFalse);
      });

      test('stops on its own when the system pauses capture', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);

        await recorder.pauseBySystem();

        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(cubit.state.recordingPath, recorder.path);
        expect(File(recorder.path!).existsSync(), isTrue);
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
        expect(audioSession.resetCount, 1);
      });

      test('does not discard the next take a stop ends', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        await cubit.cancel();

        await cubit.start();
        await recorder.emitLevel(0.5);
        await cubit.stop();

        expect(cubit.state.recordingPath, recorder.path);
        expect(File(recorder.path!).existsSync(), isTrue);
      });
    });

    group('close', () {
      for (final discard in [false, true]) {
        test(
          'shares an in-flight ${discard ? 'cancel' : 'stop'} operation',
          () async {
            final cubit = build();
            await cubit.start();
            await recorder.emitLevel(0.5);
            recorder.stopGate = Completer<void>();
            final ending = discard ? cubit.cancel() : cubit.stop();
            await pumpEventQueue();

            final closing = cubit.close();
            await pumpEventQueue();
            recorder.stopGate!.complete();
            await Future.wait([ending, closing]);

            expect(recorder.stopCount, 1);
            expect(audioSession.resetCount, 1);
            expect(File(recorder.path!).existsSync(), isFalse);
            expect(cubit.isClosed, isTrue);
          },
        );
      }

      test('deletes a finished recording nobody took over', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        await cubit.stop();
        final unclaimed = File(cubit.state.recordingPath!);

        await cubit.close();

        expect(unclaimed.existsSync(), isFalse);
      });

      // An account switch rebuilds the screen's providers mid-recording, and
      // a route redirect disposes it; close() is the only stop either gets.
      test(
        'while recording stops the microphone and deletes the take',
        () async {
          final cubit = build();
          await cubit.start();
          await recorder.emitLevel(0.5);

          await cubit.close();

          expect(recorder.stopCount, 1);
          expect(audioSession.resetCount, 1);
          expect(File(recorder.path!).existsSync(), isFalse);
        },
      );

      test('while a stop is in flight publishes and keeps no take', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        recorder.stopGate = Completer<void>();
        final stopping = cubit.stop();
        await pumpEventQueue();
        expect(cubit.state.status, SoundRecorderStatus.stopping);
        final published = <String>[];
        final subscription = cubit.stream.listen((state) {
          if (state.recordingPath case final path?) published.add(path);
        });

        final closing = cubit.close();
        recorder.stopGate!.complete();
        await Future.wait([stopping, closing]);
        await subscription.cancel();

        expect(published, isEmpty);
        expect(File(recorder.path!).existsSync(), isFalse);
      });
    });

    // `record` runs dispose() behind the same semaphore as start(), so
    // close() cannot finish, and isClosed cannot flip, until a native start
    // in flight has returned.
    group('close while starting', () {
      test(
        'leaves no take behind when the native start is in flight',
        () async {
          recorder.startGate = Completer<void>();
          final cubit = build();
          final statuses = <SoundRecorderStatus>[];
          final subscription = cubit.stream.listen(
            (s) => statuses.add(s.status),
          );
          final starting = cubit.start();
          await pumpEventQueue();
          expect(recorder.startCount, 1);

          final closing = cubit.close();
          recorder.startGate!.complete();
          await Future.wait([starting, closing]);
          await subscription.cancel();

          expect(statuses, isNot(contains(SoundRecorderStatus.recording)));
          expect(recorder.stopCount, 1);
          expect(audioSession.resetCount, 1);
          expect(File(recorder.path!).existsSync(), isFalse);
        },
      );

      testWidgets('arms no length timer that would stop, vibrate or reset '
          'later', (tester) async {
        var vibrations = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') vibrations++;
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        recorder.startGate = Completer<void>();
        // Closed in the body: a second close() in tearDown would await done
        // futures completed inside this test's fake-async zone, which never
        // fire again.
        final cubit = build(
          maxDuration: const Duration(seconds: 1),
          closeOnTearDown: false,
        );
        final starting = cubit.start();
        await tester.runAsync(pumpEventQueue);
        final closing = cubit.close();
        recorder.startGate!.complete();
        await tester.runAsync(pumpEventQueue);
        await starting;
        await closing;
        final stops = recorder.stopCount;
        final resets = audioSession.resetCount;
        final vibrationsAtClose = vibrations;

        await tester.pump(const Duration(seconds: 2));
        await tester.runAsync(pumpEventQueue);
        await tester.pump();

        expect(recorder.stopCount, stops);
        expect(audioSession.resetCount, resets);
        expect(vibrations, vibrationsAtClose);
        // The take itself was stopped once, by the start that close() raced.
        expect(stops, 1);
      });

      test('never starts the recorder when it lands during the permission '
          'check', () async {
        final check = Completer<PermissionStatus>();
        when(permissions.checkMicrophoneStatus).thenAnswer((_) => check.future);
        recorder.disposeGate = Completer<void>();
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();

        final closing = cubit.close();
        check.complete(PermissionStatus.granted);
        await pumpEventQueue();
        recorder.disposeGate!.complete();
        await Future.wait([starting, closing]);

        expect(recorder.startCount, 0);
      });

      test('never starts the recorder when it lands during the permission '
          'prompt', () async {
        final prompt = Completer<PermissionStatus>();
        when(
          permissions.checkMicrophoneStatus,
        ).thenAnswer((_) async => PermissionStatus.canRequest);
        when(
          permissions.requestMicrophonePermission,
        ).thenAnswer((_) => prompt.future);
        recorder.disposeGate = Completer<void>();
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();

        final closing = cubit.close();
        prompt.complete(PermissionStatus.granted);
        await pumpEventQueue();
        recorder.disposeGate!.complete();
        await Future.wait([starting, closing]);

        expect(recorder.startCount, 0);
      });

      test('never starts the recorder when it lands while the scratch folder '
          'resolves', () async {
        final folder = Completer<Directory>();
        recorder.disposeGate = Completer<void>();
        final cubit = build(scratchDirectoryProvider: () => folder.future);
        final starting = cubit.start();
        await pumpEventQueue();

        final closing = cubit.close();
        folder.complete(scratch);
        await pumpEventQueue();
        recorder.disposeGate!.complete();
        await Future.wait([starting, closing]);

        expect(recorder.startCount, 0);
      });
    });

    // The pause stream is the recorder's shared state stream, so a take that
    // leaves its listener behind leaks one per recording.
    group('system pause listener', () {
      test('is released when a take stops', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        expect(recorder.isWatchingPauses, isTrue);

        await cubit.stop();

        expect(recorder.isWatchingPauses, isFalse);
      });

      test('is released when a take is cancelled', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        expect(recorder.isWatchingPauses, isTrue);

        await cubit.cancel();

        expect(recorder.isWatchingPauses, isFalse);
      });

      test('is released when the native start fails', () async {
        recorder
          ..startGate = Completer<void>()
          ..throwOnStart = true;
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();
        expect(recorder.isWatchingPauses, isTrue);

        recorder.startGate!.complete();
        await starting;

        expect(cubit.state.status, SoundRecorderStatus.failed);
        expect(recorder.isWatchingPauses, isFalse);
      });

      test('is released when visibility stops an in-flight native '
          'start', () async {
        recorder.startGate = Completer<void>();
        final cubit = build();
        final starting = cubit.start();
        await pumpEventQueue();
        expect(recorder.isWatchingPauses, isTrue);

        await cubit.stop();
        recorder.startGate!.complete();
        await starting;

        expect(recorder.isWatchingPauses, isFalse);
      });

      // dispose() closes the fake's pause stream, which would drop the
      // listener anyway, so this checks while dispose is still pending.
      test('is released before close disposes the recorder', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        expect(recorder.isWatchingPauses, isTrue);
        final dispose = recorder.disposeGate = Completer<void>();
        // Opened before a failing expect, or the tearDown close would wait
        // on the gate forever.
        addTearDown(() {
          if (!dispose.isCompleted) dispose.complete();
        });

        final closing = cubit.close();
        await pumpEventQueue();

        expect(recorder.isWatchingPauses, isFalse);
        dispose.complete();
        await closing;
      });
    });

    group('length timer', () {
      // Started in the fake-async zone, so the limit timer is a fake one
      // that tester.pump can fire.
      testWidgets("a stopped take's limit cannot stop the next take", (
        tester,
      ) async {
        final cubit = build(maxDuration: const Duration(seconds: 1));
        await cubit.start();
        await tester.runAsync(() => recorder.emitLevel(0.5));
        final stopping = cubit.stop();
        await tester.runAsync(pumpEventQueue);
        await stopping;
        await tester.pump(const Duration(milliseconds: 500));

        await cubit.start();
        // The first take's deadline passes while the second is recording.
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(pumpEventQueue);
        await tester.pump();

        expect(cubit.state.isRecording, isTrue);
        expect(recorder.stopCount, 1);
        // Stop the second take so no limit timer is left pending.
        final second = cubit.stop();
        await tester.runAsync(pumpEventQueue);
        await second;
      });
    });

    group('scratch folder', () {
      // A recording cut off by the app being killed is never deleted by the
      // recorder, so its folder must be one the Storage screen clears.
      test('is one the Storage screen counts and clears', () async {
        final cubit = SoundRecorderCubit(
          permissionsService: permissions,
          audioSessionService: audioSession,
          recorder: recorder,
          now: () => recorder.now,
        );
        // Runs after close(), which deletes the in-progress file, so the
        // shared temp folder is left as it was found.
        addTearDown(() {
          final folder = File(recorder.path!).parent;
          if (folder.listSync().isEmpty) folder.deleteSync();
        });
        addTearDown(cubit.close);

        await cubit.start();

        final folder = File(recorder.path!).parent;
        final temporary = await getTemporaryDirectory();
        expect(folder.parent.path, temporary.path);
        expect(TempRenderDirectories.all, contains(p.basename(folder.path)));
      });
    });

    group('when the audio session will not reset', () {
      setUp(() => audioSession.resetError = StateError('session'));

      test('stop still hands the finished file over', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);

        await cubit.stop();

        expect(audioSession.resetCount, 1);
        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(cubit.state.recordingPath, recorder.path);
        expect(File(recorder.path!).existsSync(), isTrue);
      });

      test('a failed stop still deletes the in-progress file', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);
        recorder.throwOnStop = true;

        await cubit.stop();

        expect(audioSession.resetCount, 1);
        expect(cubit.state.status, SoundRecorderStatus.failed);
        expect(File(recorder.path!).existsSync(), isFalse);
      });

      test('cancel still deletes the recording in progress', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);

        await cubit.cancel();

        expect(audioSession.resetCount, 1);
        expect(cubit.state.status, SoundRecorderStatus.idle);
        expect(File(recorder.path!).existsSync(), isFalse);
      });

      test('a failed start still leaves no file behind', () async {
        recorder.throwOnStart = true;
        final cubit = build();

        await cubit.start();

        expect(audioSession.resetCount, 1);
        expect(cubit.state.status, SoundRecorderStatus.failed);
        expect(File(recorder.path!).existsSync(), isFalse);
      });

      test('close while recording still deletes the file and closes', () async {
        final cubit = build();
        await cubit.start();
        await recorder.emitLevel(0.5);

        await cubit.close();

        expect(audioSession.resetCount, 1);
        expect(cubit.isClosed, isTrue);
        expect(File(recorder.path!).existsSync(), isFalse);
      });
    });
  });
}
