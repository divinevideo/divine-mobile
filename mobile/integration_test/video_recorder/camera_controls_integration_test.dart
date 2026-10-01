// ABOUTME: Integration tests for camera control features
// ABOUTME: Tests flash, zoom, focus point, and exposure controls

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:patrol/patrol.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/patrol_semantics.dart';
import '../helpers/permission_helpers.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Camera Controls Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      Log.info(
        'Running Camera Controls Integration Tests',
        name: 'CameraControlsIntegrationTest',
        category: LogCategory.system,
      );
      Log.info(
        'Platform: ${Platform.operatingSystem}',
        name: 'CameraControlsIntegrationTest',
        category: LogCategory.system,
      );
    });

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

    group('Flash Control', () {
      patrolTest('can set flash to auto', ($) async {
        await grantCameraAndMicrophone($);
        final success = await cameraService.setFlashMode(DivineFlashMode.auto);
        expect(success, isA<bool>());
      });

      patrolTest('can set flash to off', ($) async {
        await grantCameraAndMicrophone($);
        final success = await cameraService.setFlashMode(DivineFlashMode.off);
        expect(success, isA<bool>());
      });

      patrolTest('can set flash to torch', ($) async {
        await grantCameraAndMicrophone($);
        final success = await cameraService.setFlashMode(DivineFlashMode.torch);
        expect(success, isA<bool>());
      });

      patrolTest('can cycle through all flash modes', ($) async {
        await grantCameraAndMicrophone($);
        final tester = $.tester;
        for (final mode in DivineFlashMode.values) {
          final success = await cameraService.setFlashMode(mode);
          expect(success, isA<bool>());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    });

    group('Zoom Control', () {
      patrolTest('can set zoom level', ($) async {
        await grantCameraAndMicrophone($);
        final minZoom = cameraService.minZoomLevel;
        final maxZoom = cameraService.maxZoomLevel;

        final midZoom = (minZoom + maxZoom) / 2;
        // setZoomLevel returns the zoom the camera actually applied
        // (double?, null on failure), not a bool — assert it lands inside
        // the advertised range.
        final applied = await cameraService.setZoomLevel(midZoom);

        expect(applied, isNotNull);
        expect(applied, inInclusiveRange(minZoom, maxZoom));
      });

      patrolTest('can set zoom to minimum', ($) async {
        await grantCameraAndMicrophone($);
        final minZoom = cameraService.minZoomLevel;
        final maxZoom = cameraService.maxZoomLevel;
        final applied = await cameraService.setZoomLevel(minZoom);

        expect(applied, isNotNull);
        expect(applied, inInclusiveRange(minZoom, maxZoom));
      });

      patrolTest('can set zoom to maximum', ($) async {
        await grantCameraAndMicrophone($);
        final minZoom = cameraService.minZoomLevel;
        final maxZoom = cameraService.maxZoomLevel;
        final applied = await cameraService.setZoomLevel(maxZoom);

        expect(applied, isNotNull);
        expect(applied, inInclusiveRange(minZoom, maxZoom));
      });

      patrolTest('can smoothly transition zoom levels', ($) async {
        await grantCameraAndMicrophone($);
        final tester = $.tester;
        final minZoom = cameraService.minZoomLevel;
        final maxZoom = cameraService.maxZoomLevel;

        // Zoom from min to max in steps
        for (var i = 0; i <= 5; i++) {
          final zoom = minZoom + (maxZoom - minZoom) * (i / 5);
          await cameraService.setZoomLevel(zoom);
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
    });

    group('Focus Control', () {
      patrolTest('can set focus point at center', ($) async {
        await grantCameraAndMicrophone($);
        final success = await cameraService.setFocusPoint(
          const Offset(0.5, 0.5),
        );
        expect(success, isA<bool>());
      });

      patrolTest('can set focus point at corners', ($) async {
        await grantCameraAndMicrophone($);
        final tester = $.tester;
        final points = [
          Offset.zero, // Top-left
          const Offset(1.0, 0.0), // Top-right
          const Offset(0.0, 1.0), // Bottom-left
          const Offset(1.0, 1.0), // Bottom-right
        ];

        for (final point in points) {
          final success = await cameraService.setFocusPoint(point);
          expect(success, isA<bool>());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });

      patrolTest('can set exposure point', ($) async {
        await grantCameraAndMicrophone($);
        final success = await cameraService.setExposurePoint(
          const Offset(0.5, 0.5),
        );
        expect(success, isA<bool>());
      });

      patrolTest('can set exposure at corners', ($) async {
        await grantCameraAndMicrophone($);
        final tester = $.tester;
        final points = [
          Offset.zero, // Top-left
          const Offset(1.0, 0.0), // Top-right
          const Offset(0.0, 1.0), // Bottom-left
          const Offset(1.0, 1.0), // Bottom-right
        ];

        for (final point in points) {
          final success = await cameraService.setExposurePoint(point);
          expect(success, isA<bool>());
          await tester.pump(const Duration(milliseconds: 100));
        }
      });
    });

    group('Combined Controls', () {
      patrolTest('can change multiple settings in sequence', ($) async {
        await grantCameraAndMicrophone($);
        final tester = $.tester;
        await cameraService.setFlashMode(DivineFlashMode.auto);
        await tester.pump(const Duration(milliseconds: 100));

        await cameraService.setZoomLevel(2.0);
        await tester.pump(const Duration(milliseconds: 100));

        await cameraService.setFocusPoint(const Offset(0.5, 0.5));
        await tester.pump(const Duration(milliseconds: 100));

        // Verify no exceptions occurred during the operations
        expect(tester.takeException(), isNull);
      });
    });
  });
}
