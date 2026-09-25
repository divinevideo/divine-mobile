// ABOUTME: Tests for MinorConsentCaptureCubit driving the in-app consent clip
// ABOUTME: Covers start, stop, retake, the 60-second cap, and failure states

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/minor_consent_capture/minor_consent_capture_cubit.dart';
import 'package:openvine/services/minor_consent_recorder.dart';

class _FakeRecorder implements MinorConsentRecorder {
  _FakeRecorder({
    this.startResult = true,
    this.stopResult = '/tmp/consent.mp4',
  });

  final bool startResult;
  final String? stopResult;

  Duration? lastMaxDuration;
  String? lastOutputDirectory;
  bool initialized = false;
  bool disposed = false;
  int startCount = 0;
  int stopCount = 0;

  /// When set, [start] does not return until this completes.
  Completer<bool>? startGate;

  /// When set, [stop] does not return until this completes, and returns its
  /// value instead of [stopResult].
  Completer<String?>? stopGate;

  @override
  void Function(String? path)? onAutoStopped;

  /// Fires the platform's auto-stop callback, as the real camera would at the
  /// 60-second cap or on an interruption.
  void fireAutoStopped(String? path) => onAutoStopped?.call(path);

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<bool> start({
    required Duration maxDuration,
    required String outputDirectory,
  }) async {
    startCount++;
    lastMaxDuration = maxDuration;
    lastOutputDirectory = outputDirectory;
    final gate = startGate;
    if (gate != null) return gate.future;
    return startResult;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    final gate = stopGate;
    if (gate != null) return gate.future;
    return stopResult;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('MinorConsentCaptureCubit', () {
    test('starts idle', () {
      final cubit = MinorConsentCaptureCubit(recorder: _FakeRecorder());

      expect(cubit.state, isA<MinorConsentCaptureIdle>());
    });

    test('start then stop lands in review with the recorded path', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      expect(cubit.state, isA<MinorConsentCaptureRecording>());

      await cubit.stop();
      expect(cubit.state, isA<MinorConsentCaptureReview>());
      expect(
        (cubit.state as MinorConsentCaptureReview).filePath,
        '/tmp/consent.mp4',
      );
    });

    test('start caps recording at 60 seconds', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');

      expect(recorder.lastMaxDuration, const Duration(seconds: 60));
      expect(recorder.lastOutputDirectory, '/tmp');
    });

    test('a second start while the first is in flight is ignored', () async {
      final recorder = _FakeRecorder()..startGate = Completer<bool>();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      final first = cubit.start(outputDirectory: '/tmp');
      final second = cubit.start(outputDirectory: '/tmp');
      recorder.startGate!.complete(true);
      await Future.wait([first, second]);

      expect(recorder.startCount, 1);
      expect(cubit.state, isA<MinorConsentCaptureRecording>());
      await cubit.close();
    });

    test('start while already recording is ignored', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      await cubit.start(outputDirectory: '/tmp');

      expect(recorder.startCount, 1);
      expect(cubit.state, isA<MinorConsentCaptureRecording>());
      await cubit.close();
    });

    test('a denied start surfaces denied state', () async {
      final recorder = _FakeRecorder(startResult: false);
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      expect(cubit.state, isA<MinorConsentCaptureDenied>());
    });

    test('a stop with no recorded file surfaces error state', () async {
      final recorder = _FakeRecorder(stopResult: null);
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      await cubit.stop();

      expect(cubit.state, isA<MinorConsentCaptureError>());
    });

    test('retake returns to idle', () async {
      final cubit = MinorConsentCaptureCubit(recorder: _FakeRecorder());

      await cubit.start(outputDirectory: '/tmp');
      await cubit.stop();
      expect(cubit.state, isA<MinorConsentCaptureReview>());

      cubit.retake();

      expect(cubit.state, isA<MinorConsentCaptureIdle>());
    });

    test('initialize prepares the camera behind the recorder', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.initialize();

      expect(recorder.initialized, isTrue);
    });

    test(
      'close stops a recording in progress and disposes the recorder',
      () async {
        final recorder = _FakeRecorder();
        final cubit = MinorConsentCaptureCubit(recorder: recorder);

        await cubit.start(outputDirectory: '/tmp');
        expect(cubit.state, isA<MinorConsentCaptureRecording>());

        await cubit.close();

        expect(recorder.stopCount, 1);
        expect(recorder.disposed, isTrue);
      },
    );

    test('close is idempotent and disposes an idle recorder', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.close();
      await cubit.close();

      expect(recorder.stopCount, 0);
      expect(recorder.disposed, isTrue);
    });

    test(
      'releaseRecorder disposes the recorder and makes close a no-op',
      () async {
        final recorder = _FakeRecorder();
        final cubit = MinorConsentCaptureCubit(recorder: recorder);

        await cubit.start(outputDirectory: '/tmp');
        await cubit.stop();

        await cubit.releaseRecorder();
        expect(recorder.disposed, isTrue);

        await cubit.close();
        expect(recorder.stopCount, 1);
        expect(recorder.disposed, isTrue);
      },
    );

    test('releaseRecorder is idempotent', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.releaseRecorder();
      await cubit.releaseRecorder();

      expect(recorder.disposed, isTrue);
    });

    test(
      'auto-stop while recording lands in review with the recorded path',
      () async {
        final recorder = _FakeRecorder();
        final cubit = MinorConsentCaptureCubit(recorder: recorder);

        await cubit.start(outputDirectory: '/tmp');
        expect(cubit.state, isA<MinorConsentCaptureRecording>());

        recorder.fireAutoStopped('/tmp/auto-stopped.mp4');

        expect(cubit.state, isA<MinorConsentCaptureReview>());
        expect(
          (cubit.state as MinorConsentCaptureReview).filePath,
          '/tmp/auto-stopped.mp4',
        );
        await cubit.close();
      },
    );

    test('auto-stop with no captured clip surfaces error', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      recorder.fireAutoStopped(null);

      expect(cubit.state, isA<MinorConsentCaptureError>());
      await cubit.close();
    });

    test('a stop after auto-stop keeps the auto-stopped clip', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      recorder.fireAutoStopped('/tmp/auto-stopped.mp4');
      await cubit.stop();

      expect(cubit.state, isA<MinorConsentCaptureReview>());
      expect(
        (cubit.state as MinorConsentCaptureReview).filePath,
        '/tmp/auto-stopped.mp4',
      );
      expect(recorder.stopCount, 0);
      await cubit.close();
    });

    group('stop racing the 60-second auto-stop', () {
      test('an auto-stop landing while stop awaits keeps its clip', () async {
        final deleted = <String>[];
        final recorder = _FakeRecorder()..stopGate = Completer<String?>();
        final cubit = MinorConsentCaptureCubit(
          recorder: recorder,
          deleteClip: (path) async => deleted.add(path),
        );

        await cubit.start(outputDirectory: '/tmp');
        final stopping = cubit.stop();
        recorder.fireAutoStopped('/tmp/auto-stopped.mp4');
        recorder.stopGate!.complete(null);
        await stopping;
        await pumpEventQueue();

        expect(cubit.state, isA<MinorConsentCaptureReview>());
        expect(
          (cubit.state as MinorConsentCaptureReview).filePath,
          '/tmp/auto-stopped.mp4',
        );
        expect(deleted, isEmpty);
        await cubit.close();
      });

      test(
        'an auto-stop arriving after an empty stop keeps its clip',
        () async {
          final deleted = <String>[];
          final recorder = _FakeRecorder(stopResult: null);
          final cubit = MinorConsentCaptureCubit(
            recorder: recorder,
            deleteClip: (path) async => deleted.add(path),
          );

          await cubit.start(outputDirectory: '/tmp');
          await cubit.stop();
          recorder.fireAutoStopped('/tmp/auto-stopped.mp4');
          await pumpEventQueue();

          expect(cubit.state, isA<MinorConsentCaptureReview>());
          expect(
            (cubit.state as MinorConsentCaptureReview).filePath,
            '/tmp/auto-stopped.mp4',
          );
          expect(deleted, isEmpty);
          await cubit.close();
        },
      );
    });

    test('auto-stop after close is ignored and does not throw', () async {
      final recorder = _FakeRecorder();
      final cubit = MinorConsentCaptureCubit(recorder: recorder);

      await cubit.start(outputDirectory: '/tmp');
      await cubit.close();

      expect(
        () => recorder.fireAutoStopped('/tmp/auto-stopped.mp4'),
        returnsNormally,
      );
    });

    test('retake deletes the discarded clip', () async {
      final deleted = <String>[];
      final cubit = MinorConsentCaptureCubit(
        recorder: _FakeRecorder(),
        deleteClip: (path) async => deleted.add(path),
      );

      await cubit.start(outputDirectory: '/tmp');
      await cubit.stop();
      expect(cubit.state, isA<MinorConsentCaptureReview>());

      cubit.retake();
      await pumpEventQueue();

      expect(cubit.state, isA<MinorConsentCaptureIdle>());
      expect(deleted, ['/tmp/consent.mp4']);
    });

    test('retake from idle does not delete anything', () async {
      final deleted = <String>[];
      final cubit = MinorConsentCaptureCubit(
        recorder: _FakeRecorder(),
        deleteClip: (path) async => deleted.add(path),
      );

      cubit.retake();
      await pumpEventQueue();

      expect(deleted, isEmpty);
    });

    group('shutdown clip cleanup', () {
      test('close deletes the clip it stops mid-recording', () async {
        final deleted = <String>[];
        final cubit = MinorConsentCaptureCubit(
          recorder: _FakeRecorder(stopResult: '/tmp/mid-recording.mp4'),
          deleteClip: (path) async => deleted.add(path),
        );

        await cubit.start(outputDirectory: '/tmp');
        expect(cubit.state, isA<MinorConsentCaptureRecording>());

        await cubit.close();

        expect(deleted, ['/tmp/mid-recording.mp4']);
      });

      test('releaseRecorder deletes a clip it stops mid-recording', () async {
        final deleted = <String>[];
        final cubit = MinorConsentCaptureCubit(
          recorder: _FakeRecorder(stopResult: '/tmp/mid-recording.mp4'),
          deleteClip: (path) async => deleted.add(path),
        );

        await cubit.start(outputDirectory: '/tmp');
        await cubit.releaseRecorder();

        expect(deleted, ['/tmp/mid-recording.mp4']);
        await cubit.close();
      });

      test('an accepted clip survives releaseRecorder and close', () async {
        final deleted = <String>[];
        final cubit = MinorConsentCaptureCubit(
          recorder: _FakeRecorder(stopResult: '/tmp/accepted.mp4'),
          deleteClip: (path) async => deleted.add(path),
        );

        await cubit.start(outputDirectory: '/tmp');
        await cubit.stop();
        expect(cubit.state, isA<MinorConsentCaptureReview>());

        await cubit.releaseRecorder();
        await cubit.close();

        expect(deleted, isEmpty);
      });

      test('a late auto-stop after close deletes the orphaned clip', () async {
        final deleted = <String>[];
        final recorder = _FakeRecorder(stopResult: '/tmp/stopped-on-close.mp4');
        final cubit = MinorConsentCaptureCubit(
          recorder: recorder,
          deleteClip: (path) async => deleted.add(path),
        );

        await cubit.start(outputDirectory: '/tmp');
        await cubit.close();

        // The provider looks the listener up when the platform calls back, so
        // fire through the recorder rather than a callback held from before.
        recorder.fireAutoStopped('/tmp/late-auto-stop.mp4');
        await pumpEventQueue();

        expect(deleted, [
          '/tmp/stopped-on-close.mp4',
          '/tmp/late-auto-stop.mp4',
        ]);
      });

      test('a late auto-stop carrying the accepted clip keeps it', () async {
        final deleted = <String>[];
        final recorder = _FakeRecorder(stopResult: '/tmp/accepted.mp4');
        final cubit = MinorConsentCaptureCubit(
          recorder: recorder,
          deleteClip: (path) async => deleted.add(path),
        );

        await cubit.start(outputDirectory: '/tmp');
        await cubit.stop();
        await cubit.releaseRecorder();

        recorder.fireAutoStopped('/tmp/accepted.mp4');
        await pumpEventQueue();

        expect(deleted, isEmpty);
        await cubit.close();
      });

      test(
        'a late auto-stop after releaseRecorder deletes the orphaned clip',
        () async {
          final deleted = <String>[];
          final recorder = _FakeRecorder(stopResult: '/tmp/accepted.mp4');
          final cubit = MinorConsentCaptureCubit(
            recorder: recorder,
            deleteClip: (path) async => deleted.add(path),
          );

          await cubit.start(outputDirectory: '/tmp');
          await cubit.stop();
          await cubit.releaseRecorder();

          recorder.fireAutoStopped('/tmp/late-auto-stop.mp4');
          await pumpEventQueue();

          expect(deleted, ['/tmp/late-auto-stop.mp4']);
          await cubit.close();
        },
      );

      test('leaving while the camera starts deletes what it wrote', () async {
        final deleted = <String>[];
        final recorder = _FakeRecorder(stopResult: '/tmp/aborted.mp4');
        final cubit = MinorConsentCaptureCubit(
          recorder: recorder,
          deleteClip: (path) async => deleted.add(path),
        );

        final starting = cubit.start(outputDirectory: '/tmp');
        await cubit.close();
        await starting;

        expect(deleted, ['/tmp/aborted.mp4']);
      });
    });
  });
}
