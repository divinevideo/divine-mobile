import 'package:divine_camera/divine_camera.dart';
import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// A test implementation of DivineCameraPlatform that implements all methods.
class TestDivineCameraPlatform extends DivineCameraPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getPlatformVersion() async => 'test';

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
    bool enableAutoLensSwitch = false,
    bool preferUnprocessedAudio = false,
  }) async => const CameraState(isInitialized: true);

  @override
  Future<void> disposeCamera() async {}

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async => true;

  @override
  Future<bool> setFocusPoint(Offset offset) async => true;

  @override
  Future<bool> cancelFocusAndMetering() async => true;

  @override
  Future<bool> setExposurePoint(Offset offset) async => true;

  @override
  Future<CameraZoomState?> setZoomLevel(double level) async =>
      CameraZoomState(zoomLevel: level, minZoomLevel: 1, maxZoomLevel: 10);

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async =>
      CameraState(isInitialized: true, lens: lens);

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    return true;
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async => null;

  @override
  Future<void> pausePreview({bool releaseAudio = true}) async {}

  @override
  Future<void> resumePreview() async {}

  @override
  Future<void> suspendAudioCapture() async {}

  @override
  Future<void> resumeAudioCapture() async {}

  @override
  Future<CameraState> getCameraState() async =>
      const CameraState(isInitialized: true);

  @override
  Widget buildPreview(int textureId) => Container();

  void Function(VideoRecordingResult? result)? _callback;

  @override
  void Function(VideoRecordingResult? result)? get onRecordingAutoStopped =>
      _callback;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult? result)? callback,
  ) {
    _callback = callback;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DivineCameraPlatform', () {
    test('instance getter returns MethodChannelDivineCamera by default', () {
      expect(DivineCameraPlatform.instance, isNotNull);
    });

    test('instance setter accepts valid implementation', () {
      final initialPlatform = DivineCameraPlatform.instance;
      addTearDown(() => DivineCameraPlatform.instance = initialPlatform);
      final testPlatform = TestDivineCameraPlatform();
      DivineCameraPlatform.instance = testPlatform;
      expect(DivineCameraPlatform.instance, testPlatform);
    });

    group('default implementation throws UnimplementedError', () {
      late DivineCameraPlatform basePlatform;

      setUp(() {
        basePlatform = _UnimplementedDivineCameraPlatform();
      });

      test('getPlatformVersion throws', () {
        expect(
          () => basePlatform.getPlatformVersion(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('initializeCamera throws', () {
        expect(
          () => basePlatform.initializeCamera(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('disposeCamera throws', () {
        expect(
          () => basePlatform.disposeCamera(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('setFlashMode throws', () {
        expect(
          () => basePlatform.setFlashMode(DivineCameraFlashMode.on),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('setFocusPoint throws', () {
        expect(
          () => basePlatform.setFocusPoint(const Offset(0.5, 0.5)),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('cancelFocusAndMetering throws', () {
        expect(
          () => basePlatform.cancelFocusAndMetering(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('setExposurePoint throws', () {
        expect(
          () => basePlatform.setExposurePoint(const Offset(0.5, 0.5)),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('setZoomLevel throws', () {
        expect(
          () => basePlatform.setZoomLevel(2),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('switchCamera throws', () {
        expect(
          () => basePlatform.switchCamera(DivineCameraLens.front),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('setVideoStabilizationMode throws', () {
        expect(
          () => basePlatform.setVideoStabilizationMode(
            DivineVideoStabilizationMode.standard,
          ),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('startRecording throws', () {
        expect(
          () => basePlatform.startRecording(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('stopRecording throws', () {
        expect(
          () => basePlatform.stopRecording(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('capturePhoto throws', () {
        expect(
          () => basePlatform.capturePhoto(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('pausePreview throws', () {
        expect(
          () => basePlatform.pausePreview(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('resumePreview throws', () {
        expect(
          () => basePlatform.resumePreview(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('suspendAudioCapture throws', () {
        expect(
          () => basePlatform.suspendAudioCapture(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('resumeAudioCapture throws', () {
        expect(
          () => basePlatform.resumeAudioCapture(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('getCameraState throws', () {
        expect(
          () => basePlatform.getCameraState(),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('buildPreview throws', () {
        expect(
          () => basePlatform.buildPreview(1),
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('onRecordingAutoStopped getter throws', () {
        expect(
          () => basePlatform.onRecordingAutoStopped,
          throwsA(isA<UnimplementedError>()),
        );
      });

      test('onRecordingAutoStopped setter throws', () {
        expect(
          () => basePlatform.onRecordingAutoStopped = (_) {},
          throwsA(isA<UnimplementedError>()),
        );
      });
    });
  });
}

/// A minimal implementation that exposes the default (unimplemented) behavior.
class _UnimplementedDivineCameraPlatform extends DivineCameraPlatform
    with MockPlatformInterfaceMixin {}
