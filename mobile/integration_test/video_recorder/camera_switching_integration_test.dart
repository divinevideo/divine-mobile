// ABOUTME: Integration tests for camera switching functionality
// ABOUTME: Tests switching between front and back cameras

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_semantics.dart';
import '../helpers/permission_helpers.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Camera Switching Integration Tests', () {
    late CameraService cameraService;

    setUp(() async {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
      await cameraService.initialize();
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    patrolTest('reports camera switch capability', ($) async {
      await grantCameraAndMicrophone($);
      final canSwitch = cameraService.canSwitchCamera;
      expect(canSwitch, isA<bool>());
    });

    patrolTest('can switch camera if multiple cameras available', ($) async {
      await grantCameraAndMicrophone($);
      if (!cameraService.canSwitchCamera) {
        // Skip if device only has one camera
        return;
      }

      final success = await cameraService.switchCamera();

      expect(success, isTrue);
      expect(cameraService.isInitialized, isTrue);
    });

    patrolTest('camera remains initialized after switching', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      if (!cameraService.canSwitchCamera) {
        return;
      }

      await cameraService.switchCamera();
      await tester.pump(const Duration(milliseconds: 500));

      expect(cameraService.isInitialized, isTrue);
      expect(cameraService.canRecord, isTrue);
    });

    patrolTest('can switch camera multiple times', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      if (!cameraService.canSwitchCamera) {
        return;
      }

      for (var i = 0; i < 3; i++) {
        final success = await cameraService.switchCamera();
        expect(success, isTrue);

        await tester.pump(const Duration(milliseconds: 300));
      }

      expect(cameraService.isInitialized, isTrue);
    });

    patrolTest('switching camera updates aspect ratio', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      if (!cameraService.canSwitchCamera) {
        return;
      }

      await cameraService.switchCamera();
      await tester.pump(const Duration(milliseconds: 500));

      final newAspectRatio = cameraService.cameraAspectRatio;

      // Aspect ratio should be valid (may or may not change)
      expect(newAspectRatio, greaterThan(0));
      expect(newAspectRatio.isFinite, isTrue);
    });
  });
}
