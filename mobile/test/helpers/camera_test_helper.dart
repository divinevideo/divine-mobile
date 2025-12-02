// ABOUTME: Helper utilities for camera tests that use real hardware
// ABOUTME: Provides test setup, cleanup, and device capability detection

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Helper class for camera integration tests
class CameraTestHelper {
  static late Directory _testDirectory;
  static List<CameraDescription>? _availableCameras;

  /// Initialize test environment
  static Future<void> setUp() async {
    // Create test directory
    final tempDir = await getTemporaryDirectory();
    _testDirectory = Directory(
      path.join(
        tempDir.path,
        'camera_tests',
        DateTime.now().millisecondsSinceEpoch.toString(),
      ),
    );
    _testDirectory.createSync(recursive: true);

    // Cache available cameras
    try {
      _availableCameras = await availableCameras();
    } catch (e) {
      _availableCameras = [];
    }
  }

  /// Clean up test environment
  static Future<void> tearDown() async {
    if (_testDirectory.existsSync()) {
      _testDirectory.deleteSync(recursive: true);
    }
  }

  /// Get test directory for output files
  static Directory get testDirectory => _testDirectory;

  /// Check if cameras are available
  static bool get hasCameras =>
      _availableCameras != null && _availableCameras!.isNotEmpty;

  /// Check if multiple cameras are available
  static bool get hasMultipleCameras =>
      _availableCameras != null && _availableCameras!.length > 1;

  /// Check if running on mobile platform
  static bool get isMobilePlatform =>
      !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Check if running on desktop platform
  static bool get isDesktopPlatform =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// Get platform name for test descriptions
  static String get platformName {
    if (kIsWeb) return 'Web';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  /// Create a unique test file path
  static String createTestFilePath(String prefix, String extension) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(_testDirectory.path, '${prefix}_$timestamp.$extension');
  }

  /// Verify a video file is valid
  static bool isValidVideoFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    final size = file.lengthSync();
    if (size < 1000) return false; // At least 1KB

    // Basic check for video file signature
    // MP4 files typically start with 'ftyp' box after 4 bytes
    try {
      final bytes = file.readAsBytesSync();
      if (bytes.length > 8) {
        final signature = String.fromCharCodes(bytes.sublist(4, 8));
        return signature == 'ftyp';
      }
    } catch (e) {
      // If we can't read the file, it's not valid
    }

    return false;
  }

  /// Get camera description string for logging
  static String getCameraDescription(CameraDescription camera) {
    return '${camera.name} (${camera.lensDirection.name})';
  }

  /// Wait for camera initialization with timeout
  static Future<bool> waitForCameraInit(
    Future<void> Function() initFunction, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      await initFunction().timeout(timeout);
      return true;
    } catch (e) {
      return false;
    }
  }
}
