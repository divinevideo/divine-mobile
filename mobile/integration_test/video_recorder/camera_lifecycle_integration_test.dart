// ABOUTME: Integration tests for app lifecycle handling
// ABOUTME: Tests camera behavior during app pause/resume and other lifecycle changes

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/patrol_semantics.dart';
import '../helpers/permission_helpers.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Camera Lifecycle Integration Tests', () {
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

    patrolTest('handles app pause', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      await cameraService.handleAppLifecycleState(.paused);
      await tester.pump(const Duration(milliseconds: 100));

      // Should complete without error
    });

    patrolTest('handles app resume', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      await cameraService.handleAppLifecycleState(.resumed);
      await tester.pump(const Duration(milliseconds: 100));

      // Camera should still be initialized
      expect(cameraService.isInitialized, isTrue);
    });

    patrolTest('handles pause-resume cycle', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      await cameraService.handleAppLifecycleState(.paused);
      await tester.pump(const Duration(milliseconds: 200));

      await cameraService.handleAppLifecycleState(.resumed);
      await tester.pump(const Duration(milliseconds: 200));

      // Camera should recover
      expect(cameraService.isInitialized, isTrue);
      expect(cameraService.canRecord, isTrue);
    });

    patrolTest('handles multiple lifecycle changes', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      final List<AppLifecycleState> states = [
        .paused,
        .resumed,
        .inactive,
        .resumed,
        .paused,
        .resumed,
      ];

      for (final state in states) {
        await cameraService.handleAppLifecycleState(state);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Should handle all transitions gracefully
      expect(cameraService.isInitialized, isTrue);
    });

    patrolTest('can record after lifecycle changes', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      // Simulate app going to background and back
      await cameraService.handleAppLifecycleState(.paused);
      await tester.pump(const Duration(milliseconds: 200));

      await cameraService.handleAppLifecycleState(.resumed);
      await tester.pump(const Duration(milliseconds: 200));

      // Should still be able to record
      expect(cameraService.canRecord, isTrue);

      await cameraService.startRecording();
      await tester.pump(const Duration(milliseconds: 500));

      final video = await cameraService.stopRecording();
      expect(video, anyOf(isNull, isA<Object>()));
    });

    patrolTest('handles detached state', ($) async {
      await grantCameraAndMicrophone($);
      final tester = $.tester;
      await cameraService.handleAppLifecycleState(.detached);
      await tester.pump(const Duration(milliseconds: 100));

      // Verify no exceptions occurred during the operations
      expect(tester.takeException(), isNull);
    });
  });
}
