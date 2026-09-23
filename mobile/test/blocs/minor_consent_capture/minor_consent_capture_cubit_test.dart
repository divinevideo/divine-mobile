// ABOUTME: Tests for MinorConsentCaptureCubit driving the in-app consent clip
// ABOUTME: Covers start, stop, retake, the 60-second cap, and failure states

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
  int stopCount = 0;

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
    lastMaxDuration = maxDuration;
    lastOutputDirectory = outputDirectory;
    return startResult;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
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
  });
}
