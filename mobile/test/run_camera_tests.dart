// ABOUTME: Test runner script for camera tests with real hardware
// ABOUTME: Runs unit and integration tests with proper setup and reporting

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:openvine/utils/unified_logger.dart';

// Import all camera test files
import 'services/camera/enhanced_mobile_camera_interface_test.dart'
    as enhanced_camera_test;
import 'integration/camera_recording_integration_test.dart' as integration_test;

void main() async {
  // Initialize Flutter test environment
  TestWidgetsFlutterBinding.ensureInitialized();

  Log.info(
    '=== OpenVine Camera Test Suite ===',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );
  Log.info(
    'Running camera tests with real hardware...',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );

  // Check camera availability
  List<CameraDescription> cameras;
  try {
    cameras = await availableCameras();
    Log.info(
      'Found ${cameras.length} camera(s):',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    for (var camera in cameras) {
      Log.info(
        '  - ${camera.name} (${camera.lensDirection})',
        name: 'CameraTestRunner',
        category: LogCategory.system,
      );
    }
  } catch (e) {
    Log.warning(
      'Could not detect cameras: $e',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    Log.warning(
      'Some tests will be skipped.',
      name: 'CameraTestRunner',
      category: LogCategory.system,
    );
    cameras = [];
  }

  // Platform information
  Log.info(
    'Platform: ${Platform.operatingSystem}',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );
  Log.info(
    'Dart: ${Platform.version}',
    name: 'CameraTestRunner',
    category: LogCategory.system,
  );

  // Run test suites
  group('Camera Test Suite', () {
    group('Enhanced Mobile Camera Interface Tests', () {
      enhanced_camera_test.main();
    });

    group('VineRecordingController Platform Tests', () {});

    group('Camera Recording Integration Tests', () {
      integration_test.main();
    });
  });
}
