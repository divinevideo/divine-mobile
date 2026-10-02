// ABOUTME: Integration tests for single-photo (stop-motion) capture
// ABOUTME: Tests that capturePhoto writes real JPEG frames to disk on device

import 'dart:io';

import 'package:divine_camera/divine_camera.dart' show PhotoCaptureResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:patrol/patrol.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/patrol_semantics.dart';
import '../helpers/permission_helpers.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Camera Photo Capture Integration Tests', () {
    late CameraService cameraService;

    setUpAll(() async {
      Log.info(
        'Running Camera Photo Capture Integration Tests',
        name: 'CameraPhotoCaptureIntegrationTest',
        category: LogCategory.system,
      );
      Log.info(
        'Platform: ${Platform.operatingSystem}',
        name: 'CameraPhotoCaptureIntegrationTest',
        category: LogCategory.system,
      );
    });

    setUp(() async {
      cameraService = CameraService.create(
        onUpdateState: ({forceCameraRebuild}) {},
        onAutoStopped: (_) {},
      );
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    patrolTest('captures a single photo and writes a JPEG to disk', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      final result = await cameraService.capturePhoto();

      expect(result, isNotNull);
      expect(result!.filePath, endsWith('.jpg'));

      final file = File(result.filePath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    patrolTest('captures multiple frames in sequence (stop-motion)', ($) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();
      final tester = $.tester;

      final results = <PhotoCaptureResult>[];
      for (var i = 0; i < 3; i++) {
        final result = await cameraService.capturePhoto();
        expect(result, isNotNull);
        results.add(result!);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Every frame produced a distinct, non-empty file on disk.
      final paths = results.map((r) => r.filePath).toSet();
      expect(paths, hasLength(3));
      for (final result in results) {
        final file = File(result.filePath);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
      }
    });

    patrolTest('writes the photo into the provided output directory', (
      $,
    ) async {
      await grantCameraAndMicrophone($);
      await cameraService.initialize();

      final dir = await Directory.systemTemp.createTemp('stop_motion_frames');
      try {
        final result = await cameraService.capturePhoto(
          outputDirectory: dir.path,
        );

        expect(result, isNotNull);
        expect(result!.filePath, startsWith(dir.path));
        expect(File(result.filePath).existsSync(), isTrue);
      } finally {
        if (dir.existsSync()) {
          await dir.delete(recursive: true);
        }
      }
    });
  });
}
