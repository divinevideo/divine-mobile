import 'package:divine_camera/divine_camera.dart' show DivineCameraLens;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_recorder/camera_initialization_error.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_linux_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(CameraLinuxService, () {
    late CameraLinuxService service;
    late int updateStateCallCount;
    late List<EditorVideo?> autoStoppedVideos;

    setUp(() {
      updateStateCallCount = 0;
      autoStoppedVideos = [];
      service = CameraLinuxService(
        onUpdateState: ({bool? forceCameraRebuild}) {
          updateStateCallCount++;
        },
        onAutoStopped: autoStoppedVideos.add,
      );
    });

    group('initializationError', () {
      // The reason has to be `unsupportedPlatform` rather than `failed`: the
      // two map to different copy, and only `failed` implies retrying could
      // help. Linux has no camera support to retry into.
      test('reports unsupportedPlatform, not a message', () {
        expect(
          service.initializationError,
          CameraInitializationError.unsupportedPlatform,
        );
      });
    });

    group('state properties', () {
      test('isInitialized is always false', () {
        expect(service.isInitialized, isFalse);
      });

      test('canRecord is always false', () {
        expect(service.canRecord, isFalse);
      });

      test('canSwitchCamera is always false', () {
        expect(service.canSwitchCamera, isFalse);
      });

      test('hasFlash is always false', () {
        expect(service.hasFlash, isFalse);
      });

      test('isFocusPointSupported is always false', () {
        expect(service.isFocusPointSupported, isFalse);
      });

      test('availableLenses is empty', () {
        expect(service.availableLenses, isEmpty);
      });

      test('currentLensMetadata is null', () {
        expect(service.currentLensMetadata, isNull);
      });
    });

    group('initialize', () {
      test('triggers onUpdateState', () async {
        await service.initialize();

        expect(updateStateCallCount, equals(1));
      });

      test('still reports isInitialized as false after initialize', () async {
        await service.initialize();

        expect(service.isInitialized, isFalse);
      });
    });

    group('recording methods', () {
      test('startRecording returns false', () async {
        final result = await service.startRecording();

        expect(result, isFalse);
      });

      test('stopRecording returns null', () async {
        final result = await service.stopRecording();

        expect(result, isNull);
      });

      test('capturePhoto returns null', () async {
        final result = await service.capturePhoto();

        expect(result, isNull);
      });
    });

    group('camera control methods', () {
      test('setFlashMode returns false', () async {
        final result = await service.setFlashMode(DivineFlashMode.torch);

        expect(result, isFalse);
      });

      test('setFocusPoint returns false', () async {
        final result = await service.setFocusPoint(const Offset(0.5, 0.5));

        expect(result, isFalse);
      });

      test('setExposurePoint returns false', () async {
        final result = await service.setExposurePoint(const Offset(0.5, 0.5));

        expect(result, isFalse);
      });

      test('setZoomLevel returns null (zoom unsupported)', () async {
        final result = await service.setZoomLevel(2);

        expect(result, isNull);
      });

      test('switchCamera returns false', () async {
        final result = await service.switchCamera();

        expect(result, isFalse);
      });

      test('setLens returns false', () async {
        final result = await service.setLens(DivineCameraLens.back);

        expect(result, isFalse);
      });

      test('setRemoteRecordControlEnabled returns false', () async {
        final result = await service.setRemoteRecordControlEnabled(
          enabled: true,
        );

        expect(result, isFalse);
      });

      test('setVolumeKeysEnabled returns false', () async {
        final result = await service.setVolumeKeysEnabled(enabled: true);

        expect(result, isFalse);
      });
    });

    group('dispose', () {
      test('completes without error', () async {
        await expectLater(service.dispose(), completes);
      });

      test('can be called multiple times', () async {
        await service.dispose();
        await expectLater(service.dispose(), completes);
      });
    });

    group('handleAppLifecycleState', () {
      test('completes without error for all states', () async {
        for (final state in AppLifecycleState.values) {
          await expectLater(service.handleAppLifecycleState(state), completes);
        }
      });
    });
  });
}
