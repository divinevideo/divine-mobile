import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/services/video_recorder/camera/camera_mobile_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _FakeCameraPlatform extends DivineCameraPlatform {
  bool shouldFail = true;

  /// When set, the audio-capture calls throw instead of recording.
  bool failAudioCapture = false;

  final List<String> audioCaptureCalls = [];

  /// The stabilization mode the last [initializeCamera] asked for.
  DivineVideoStabilizationMode? lastStabilizationMode;

  @override
  void Function(VideoRecordingResult? result)? onRecordingAutoStopped;

  @override
  void Function(RemoteRecordTrigger trigger)? onRemoteRecordTrigger;

  @override
  ValueChanged<bool>? onScreenFlashChanged;

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
    DivineVideoStabilizationMode videoStabilizationMode =
        DivineVideoStabilizationMode.off,
  }) async {
    lastStabilizationMode = videoStabilizationMode;
    if (shouldFail) throw StateError('camera unavailable');
    return const CameraState(isInitialized: true, textureId: 1);
  }

  @override
  Future<void> disposeCamera() async {}

  @override
  Future<void> suspendAudioCapture() async {
    if (failAudioCapture) throw StateError('no audio session');
    audioCaptureCalls.add('suspend');
  }

  @override
  Future<void> resumeAudioCapture() async {
    if (failAudioCapture) throw StateError('no audio session');
    audioCaptureCalls.add('resume');
  }
}

void main() {
  group(CameraMobileService, () {
    final initialPlatform = DivineCameraPlatform.instance;
    late _FakeCameraPlatform platform;
    late List<bool?> rebuildRequests;
    late CameraMobileService service;

    setUp(() async {
      platform = _FakeCameraPlatform();
      DivineCameraPlatform.instance = platform;
      await DivineCamera.instance.dispose();
      rebuildRequests = [];
      service = CameraMobileService(
        onUpdateState: ({forceCameraRebuild}) {
          rebuildRequests.add(forceCameraRebuild);
        },
        onAutoStopped: (_) {},
      );
    });

    tearDown(() async {
      await DivineCamera.instance.dispose();
      DivineCameraPlatform.instance = initialPlatform;
    });

    test('rethrows initialization failures after updating state', () async {
      await expectLater(service.initialize(), throwsStateError);

      expect(service.isInitialized, isFalse);
      expect(
        service.initializationError,
        CameraInitializationError.failed,
      );
      expect(rebuildRequests, [isTrue]);
    });

    test('clears a previous failure when initialization is retried', () async {
      await expectLater(service.initialize(), throwsStateError);
      platform.shouldFail = false;

      await service.initialize();

      expect(service.isInitialized, isTrue);
      expect(service.initializationError, isNull);
      expect(rebuildRequests, [isTrue, isTrue]);
    });

    test('opens the camera with the requested stabilization mode', () async {
      platform.shouldFail = false;

      await service.initialize(
        videoStabilizationMode: DivineVideoStabilizationMode.standard,
      );

      expect(
        platform.lastStabilizationMode,
        DivineVideoStabilizationMode.standard,
      );
    });

    group('audio capture suspension', () {
      test('forwards suspend and resume once initialized', () async {
        platform.shouldFail = false;
        await service.initialize();

        await service.suspendAudioCapture();
        await service.resumeAudioCapture();

        expect(platform.audioCaptureCalls, ['suspend', 'resume']);
      });

      test('does not reach the platform before initialize', () async {
        await service.suspendAudioCapture();
        await service.resumeAudioCapture();

        expect(platform.audioCaptureCalls, isEmpty);
      });

      test('swallows a platform failure so the countdown still runs', () async {
        // A failed suspend only keeps today's audio path; a failed resume
        // leaves the reopen to the record tap. Neither may abort the start.
        platform.shouldFail = false;
        await service.initialize();
        platform.failAudioCapture = true;

        await expectLater(service.suspendAudioCapture(), completes);
        await expectLater(service.resumeAudioCapture(), completes);
      });
    });

    group('onAutoStopped', () {
      late List<EditorVideo?> autoStopped;

      setUp(() async {
        autoStopped = [];
        platform.shouldFail = false;
        service = CameraMobileService(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: autoStopped.add,
        );
        await service.initialize();
      });

      test('forwards a native stop that captured nothing as null', () {
        platform.onRecordingAutoStopped!(null);

        expect(autoStopped, [isNull]);
      });

      test('forwards a native stop with a video as that file', () {
        platform.onRecordingAutoStopped!(
          const VideoRecordingResult(filePath: '/clips/auto.mp4'),
        );

        expect(autoStopped, hasLength(1));
        expect(autoStopped.single?.file?.path, '/clips/auto.mp4');
      });
    });

    group('onScreenFlashChanged', () {
      test('forwards native screen flash changes', () async {
        final changes = <bool>[];
        platform.shouldFail = false;
        service = CameraMobileService(
          onUpdateState: ({forceCameraRebuild}) {},
          onAutoStopped: (_) {},
          onScreenFlashChanged: changes.add,
        );
        await service.initialize();

        platform.onScreenFlashChanged!(true);
        platform.onScreenFlashChanged!(false);

        expect(changes, [isTrue, isFalse]);
      });
    });
  });
}
