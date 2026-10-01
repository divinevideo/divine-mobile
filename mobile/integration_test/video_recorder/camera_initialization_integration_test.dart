// ABOUTME: Integration tests for camera initialization and setup
// ABOUTME: Tests camera service creation, initialization, and basic properties

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_semantics.dart';
import '../helpers/permission_helpers.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Camera Initialization Integration Tests', () {
    late CameraService cameraService;

    setUp(() {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    patrolTest('camera service can be created', ($) async {
      await grantCameraAndMicrophone($);
      expect(cameraService, isNotNull);
      expect(cameraService, isA<CameraService>());
    });

    patrolTest('camera service can be initialized', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      expect(cameraService.isInitialized, isTrue);
    });

    patrolTest('camera provides valid aspect ratio', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      final aspectRatio = cameraService.cameraAspectRatio;
      expect(aspectRatio, greaterThan(0));
      expect(aspectRatio.isFinite, isTrue);
    });

    patrolTest('camera provides valid zoom limits', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      expect(cameraService.minZoomLevel, greaterThan(0.0));
      expect(
        cameraService.maxZoomLevel,
        greaterThanOrEqualTo(cameraService.minZoomLevel),
      );
    });

    patrolTest('camera reports focus support capability', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      expect(cameraService.isFocusPointSupported, isA<bool>());
    });

    patrolTest('camera reports recording capability', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      expect(cameraService.canRecord, isTrue);
    });

    patrolTest('camera reports switch capability', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      expect(cameraService.canSwitchCamera, isA<bool>());
    });

    patrolTest('camera can be disposed after initialization', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);

      await cameraService.dispose();

      // Verify no exceptions occurred during the operations
      expect(tester.takeException(), isNull);
    });

    patrolTest('camera can be initialized multiple times', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);

      // Second initialization should be safe
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);
    });
  });
}
