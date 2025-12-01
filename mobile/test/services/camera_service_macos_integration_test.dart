// ABOUTME: Integration test for macOS camera functionality - runs with actual camera hardware
// ABOUTME: These tests need to run on a real macOS device with camera access

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:camera/camera.dart';
import 'package:openvine/services/camera_service_impl.dart';
import 'dart:io';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CameraService macOS Integration Tests', () {
    late CameraServiceImpl cameraService;

    setUp(() {
      cameraService = CameraServiceImpl();
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    testWidgets('should detect macOS platform correctly', (tester) async {
      if (Platform.isMacOS) {
        expect(Platform.isMacOS, isTrue);
      }
    });

    testWidgets('should list available cameras on macOS', (tester) async {
      if (!Platform.isMacOS) {
        return; // Skip on non-macOS platforms
      }

      final cameras = await availableCameras();

      expect(cameras, isNotEmpty);
      expect(cameras.first.name, isNotEmpty);
    });

    testWidgets('should initialize camera on macOS', (tester) async {
      if (!Platform.isMacOS) {
        return; // Skip on non-macOS platforms
      }

      await cameraService.initialize();

      expect(cameraService.isInitialized, isTrue);
    });

    testWidgets('should record video on macOS', (tester) async {
      if (!Platform.isMacOS) {
        return; // Skip on non-macOS platforms
      }

      await cameraService.initialize();

      // Start recording
      await cameraService.startRecording();
      expect(cameraService.isRecording, isTrue);

      // Record for a short time
      await Future.delayed(const Duration(seconds: 1));

      // Stop recording
      final result = await cameraService.stopRecording();

      expect(cameraService.isRecording, isFalse);
      expect(result.videoFile, isNotNull);
      expect(result.videoFile.existsSync(), isTrue);
      expect(result.duration.inMilliseconds, greaterThan(0));
    });
  });
}
