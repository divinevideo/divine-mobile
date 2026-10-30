// ABOUTME: Tests for the MinorConsentRecorder port over CameraService
// ABOUTME: Verifies start forwards the cap and stop returns the recorded path

import 'dart:async';

import 'package:divine_camera/divine_camera.dart'
    show DivineCameraLens, DivineVideoQuality, DivineVideoStabilizationMode;
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/minor_consent_recorder.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../mocks/mock_camera_service.dart';

class _FakeCameraService extends MockCameraService {
  _FakeCameraService()
    : super.create(
        onUpdateState: ({bool? forceCameraRebuild}) {},
        onAutoStopped: (EditorVideo? video) {},
      );

  EditorVideo? stopResult = EditorVideo.file('/tmp/consent.mp4');
  Duration? lastMaxDuration;
  String? lastOutputDirectory;
  final lifecycleStates = <AppLifecycleState>[];
  Completer<void>? lifecycleGate;
  Completer<void>? initializationGate;
  Completer<void>? disposalGate;
  Object? initializationFailure;
  int initializationCount = 0;
  int disposalCount = 0;

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
    bool mirrorFrontCameraOutput = false,
  }) async {
    initializationCount++;
    await initializationGate?.future;
    await super.initialize(
      videoQuality: videoQuality,
      initialLens: initialLens,
      enableAutoLensSwitch: enableAutoLensSwitch,
      preferUnprocessedAudio: preferUnprocessedAudio,
      videoStabilizationMode: videoStabilizationMode,
      mirrorFrontCameraOutput: mirrorFrontCameraOutput,
    );
    final error = initializationFailure;
    if (error != null) Error.throwWithStackTrace(error, StackTrace.current);
  }

  @override
  Future<void> dispose() async {
    disposalCount++;
    await disposalGate?.future;
    await super.dispose();
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    lifecycleStates.add(state);
    await lifecycleGate?.future;
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    lastMaxDuration = maxDuration;
    lastOutputDirectory = outputDirectory;
    return true;
  }

  @override
  Future<EditorVideo?> stopRecording() async => stopResult;
}

void main() {
  group('CameraMinorConsentRecorder', () {
    test('start forwards the cap and stop returns the recorded path', () async {
      final camera = _FakeCameraService();
      final recorder = CameraMinorConsentRecorder(camera: camera);

      final started = await recorder.start(
        maxDuration: const Duration(seconds: 60),
        outputDirectory: '/tmp',
      );
      final path = await recorder.stop();

      expect(started, isTrue);
      expect(camera.lastMaxDuration, const Duration(seconds: 60));
      expect(camera.lastOutputDirectory, '/tmp');
      expect(path, '/tmp/consent.mp4');
    });

    test('stop returns null when the camera captured nothing', () async {
      final camera = _FakeCameraService()..stopResult = null;
      final recorder = CameraMinorConsentRecorder(camera: camera);

      final path = await recorder.stop();

      expect(path, isNull);
    });

    test('forwards lifecycle until the camera is disposed', () async {
      final camera = _FakeCameraService();
      final recorder = CameraMinorConsentRecorder(camera: camera);
      await recorder.handleAppLifecycleState(AppLifecycleState.paused);
      await recorder.handleAppLifecycleState(AppLifecycleState.resumed);
      await recorder.dispose();
      await recorder.handleAppLifecycleState(AppLifecycleState.resumed);
      expect(camera.lifecycleStates, [
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
      ]);
    });

    test('provider disposal waits for a native lifecycle operation', () async {
      final camera = _FakeCameraService()..lifecycleGate = Completer<void>();
      await camera.initialize();
      final recorder = CameraMinorConsentRecorder(camera: camera);
      final resuming = recorder.handleAppLifecycleState(
        AppLifecycleState.resumed,
      );
      final disposing = recorder.dispose();
      final initializedWhileResuming = camera.isInitialized;
      camera.lifecycleGate!.complete();
      await Future.wait([resuming, disposing]);
      expect(initializedWhileResuming, isTrue);
      expect(camera.isInitialized, isFalse);
    });

    test('dispose releases the wrapped camera', () async {
      final camera = _FakeCameraService();
      await camera.initialize();
      expect(camera.isInitialized, isTrue);
      final recorder = CameraMinorConsentRecorder(camera: camera);

      await recorder.dispose();

      expect(camera.isInitialized, isFalse);
    });

    test(
      'dispose releases a camera whose initialization was pending',
      () async {
        final camera = _FakeCameraService()
          ..initializationGate = Completer<void>();
        final recorder = CameraMinorConsentRecorder(camera: camera);
        final initializing = recorder.initialize();
        final disposing = recorder.dispose();
        await pumpEventQueue();

        final releasesBeforeInitialization = camera.disposalCount;
        camera.initializationGate!.complete();
        await Future.wait([initializing, disposing]);
        await recorder.dispose();

        expect(camera.initializationCount, 1);
        expect(camera.disposalCount, 1);
        expect(camera.isInitialized, isFalse);
        expect(releasesBeforeInitialization, 0);
      },
    );

    test(
      'an initialization failure still releases the eventual camera',
      () async {
        final failure = StateError('initialization failed after allocation');
        final camera = _FakeCameraService()
          ..initializationGate = Completer<void>()
          ..initializationFailure = failure;
        final recorder = CameraMinorConsentRecorder(camera: camera);
        final initializing = expectLater(
          recorder.initialize(),
          throwsA(failure),
        );
        final disposing = recorder.dispose();
        // Disposal may also report the preparation failure, but must release.
        final disposalResult = expectLater(disposing, throwsA(failure));
        camera.initializationGate!.complete();
        await Future.wait([initializing, disposalResult]);

        expect(camera.disposalCount, 1);
        expect(camera.isInitialized, isFalse);
      },
    );

    test('repeated disposal waits for the same native release', () async {
      final camera = _FakeCameraService()..disposalGate = Completer<void>();
      await camera.initialize();
      final recorder = CameraMinorConsentRecorder(camera: camera);
      var firstCompleted = false;
      var secondCompleted = false;
      final first = recorder.dispose().then((_) => firstCompleted = true);
      final second = recorder.dispose().then((_) => secondCompleted = true);
      await pumpEventQueue();

      expect(camera.disposalCount, 1);
      expect(firstCompleted, isFalse);
      expect(secondCompleted, isFalse);
      camera.disposalGate!.complete();
      await Future.wait([first, second]);

      expect(firstCompleted, isTrue);
      expect(secondCompleted, isTrue);
      expect(camera.isInitialized, isFalse);
    });

    test('does not initialize or start after disposal begins', () async {
      final camera = _FakeCameraService()
        ..initializationGate = Completer<void>();
      final recorder = CameraMinorConsentRecorder(camera: camera);
      final initializing = recorder.initialize();
      final disposing = recorder.dispose();

      final lateInitialization = recorder.initialize();
      final lateStart = await recorder.start(
        maxDuration: const Duration(seconds: 60),
        outputDirectory: '/tmp',
      );
      camera.initializationGate!.complete();
      await Future.wait([initializing, disposing, lateInitialization]);

      expect(camera.initializationCount, 1);
      expect(camera.lastOutputDirectory, isNull);
      expect(lateStart, isFalse);
      expect(camera.isInitialized, isFalse);
    });
  });

  group('minorConsentAutoStoppedPath', () {
    test('returns the recorded path from an EditorVideo', () {
      expect(
        minorConsentAutoStoppedPath(EditorVideo.file('/tmp/consent.mp4')),
        '/tmp/consent.mp4',
      );
    });

    test('returns null when the camera captured nothing', () {
      expect(minorConsentAutoStoppedPath(null), isNull);
    });
  });
}
