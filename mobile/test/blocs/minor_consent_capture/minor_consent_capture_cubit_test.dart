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
  Future<String?> stop() async => stopResult;

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
  });
}
