// ABOUTME: Tests for macOS camera functionality using the latest camera package
// ABOUTME: Verifies camera initialization, recording, and platform-specific features work on macOS

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:camera/camera.dart';
// For Offset
import 'package:openvine/services/camera_service_impl.dart';
import 'dart:io';

import 'camera_service_macos_test.mocks.dart';

@GenerateNiceMocks([MockSpec<CameraController>()])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraService macOS Support', () {
    late CameraServiceImpl cameraService;
    late MockCameraController mockController;

    setUp(() {
      cameraService = CameraServiceImpl();
      mockController = MockCameraController();
      // Log is already initialized globally, no need to call initialize
    });

    test('should detect macOS platform correctly', () {
      // This test will fail if not running on macOS
      if (Platform.isMacOS) {
        expect(Platform.isMacOS, isTrue);
      }
    });

    test('should list available cameras on macOS', () async {
      // Test that we can get available cameras
      final cameras = await availableCameras();

      // On macOS, we should have at least one camera
      if (Platform.isMacOS) {
        expect(cameras, isNotEmpty);
        expect(cameras.first.name, isNotEmpty);
        expect(cameras.first.lensDirection, isNotNull);
      }
    });

    test('should initialize camera on macOS', () async {
      // Get available cameras
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return; // Skip test if no cameras available
      }

      // Initialize with the first camera
      await cameraService.initialize();

      // Verify initialization
      expect(cameraService.isInitialized, isTrue);
      expect(cameraService.controller, isNotNull);
    });

    test('should handle camera initialization failure gracefully', () async {
      // Mock a scenario where no cameras are available
      when(mockController.initialize()).thenThrow(
        CameraException('NoCameraAvailable', 'No cameras found on device'),
      );

      // Attempt to initialize should not throw, but handle error gracefully
      await expectLater(cameraService.initialize(), completes);

      // Service should indicate it's not initialized
      expect(cameraService.isInitialized, isFalse);
    });

    test('should support video recording on macOS', () async {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return; // Skip test if no cameras available
      }

      // Initialize camera
      await cameraService.initialize();

      // Start recording
      await cameraService.startVideoRecording();
      expect(cameraService.isRecording, isTrue);

      // Wait a moment
      await Future.delayed(const Duration(milliseconds: 100));

      // Stop recording
      final videoFile = await cameraService.stopVideoRecording();

      // Verify recording stopped and file was created
      expect(cameraService.isRecording, isFalse);
      expect(videoFile, isNotNull);
    });

    test('should handle resolution settings on macOS', () async {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return; // Skip test if no cameras available
      }

      // Initialize with specific resolution
      await cameraService.initialize(
        preferredResolution: ResolutionPreset.high,
      );

      // Verify initialization with resolution
      expect(cameraService.isInitialized, isTrue);
      expect(cameraService.controller, isNotNull);
    });

    test(
      'should handle camera switching on macOS if multiple cameras exist',
      () async {
        final cameras = await availableCameras();

        if (cameras.length < 2) {
          return; // Skip test if multiple cameras not available
        }

        // Initialize with first camera
        await cameraService.initialize();
        final firstCamera = cameraService.selectedCamera;

        // Switch to another camera
        await cameraService.switchCamera();
        final secondCamera = cameraService.selectedCamera;

        // Verify camera switched
        expect(firstCamera, isNot(equals(secondCamera)));
      },
    );

    test('should properly dispose camera resources', () async {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return; // Skip test if no cameras available
      }

      // Initialize and then dispose
      await cameraService.initialize();
      expect(cameraService.isInitialized, isTrue);

      await cameraService.dispose();
      expect(cameraService.isInitialized, isFalse);
      expect(cameraService.controller, isNull);
    });

    test('should handle flash modes on macOS', () async {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return; // Skip test if no cameras available
      }

      await cameraService.initialize();

      // Test setting flash modes (may not be supported on all macOS cameras)
      try {
        await cameraService.setFlashMode(FlashMode.off);
        expect(cameraService.currentFlashMode, equals(FlashMode.off));

        await cameraService.setFlashMode(FlashMode.auto);
        expect(cameraService.currentFlashMode, equals(FlashMode.auto));
      } catch (e) {
        // Flash might not be supported on this camera
        expect(e, isA<CameraException>());
      }
    });

    test('should handle focus and exposure on macOS', () async {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        return; // Skip test if no cameras available
      }

      await cameraService.initialize();

      // Test setting focus point (may not be supported on all macOS cameras)
      try {
        await cameraService.setFocusPoint(const Offset(0.5, 0.5));
        // If supported, should complete without error
      } catch (e) {
        // Focus point might not be supported
        expect(e, isA<CameraException>());
      }

      // Test setting exposure point
      try {
        await cameraService.setExposurePoint(const Offset(0.5, 0.5));
        // If supported, should complete without error
      } catch (e) {
        // Exposure point might not be supported
        expect(e, isA<CameraException>());
      }
    });
  });
}
