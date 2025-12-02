// ABOUTME: Test suite for native macOS camera implementation
// ABOUTME: Verifies recording completion, error handling, and proper cleanup

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:openvine/services/camera/native_macos_camera.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeMacOSCamera', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Set up method channel mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              methodCalls.add(methodCall);

              switch (methodCall.method) {
                case 'initialize':
                  return true;
                case 'startPreview':
                  return true;
                case 'stopPreview':
                  return true;
                case 'startRecording':
                  return true;
                case 'stopRecording':
                  // Simulate successful recording with file path
                  return '/tmp/openvine_test_recording.mov';
                case 'getAvailableCameras':
                  // Return as List<dynamic> which will be cast properly
                  return [
                    {'id': '0', 'name': 'FaceTime HD Camera'},
                  ];
                case 'switchCamera':
                  return true;
                case 'hasPermission':
                  return true;
                case 'requestPermission':
                  return true;
                default:
                  return null;
              }
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            null,
          );
    });

    test('should initialize camera successfully', () async {
      final result = await NativeMacOSCamera.initialize();

      expect(result, isTrue);
      expect(methodCalls.length, 1);
      expect(methodCalls.first.method, 'initialize');
    });

    test('should start preview successfully', () async {
      await NativeMacOSCamera.initialize();
      final result = await NativeMacOSCamera.startPreview();

      expect(result, isTrue);
      expect(methodCalls.any((call) => call.method == 'startPreview'), isTrue);
    });

    test('should start recording successfully', () async {
      await NativeMacOSCamera.initialize();
      await NativeMacOSCamera.startPreview();
      final result = await NativeMacOSCamera.startRecording();

      expect(result, isTrue);
      expect(
        methodCalls.any((call) => call.method == 'startRecording'),
        isTrue,
      );
    });

    test('should stop recording and return file path', () async {
      await NativeMacOSCamera.initialize();
      await NativeMacOSCamera.startPreview();
      await NativeMacOSCamera.startRecording();

      final filePath = await NativeMacOSCamera.stopRecording();

      expect(filePath, isNotNull);
      expect(filePath, '/tmp/openvine_test_recording.mov');
      expect(methodCalls.any((call) => call.method == 'stopRecording'), isTrue);
    });

    test('should handle recording timeout gracefully', () async {
      // Override the mock to simulate timeout
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'stopRecording') {
                // Simulate timeout by delaying beyond the 3-second timeout
                await Future.delayed(const Duration(seconds: 4));
                return null;
              }
              return true;
            },
          );

      await NativeMacOSCamera.initialize();
      await NativeMacOSCamera.startPreview();
      await NativeMacOSCamera.startRecording();

      final filePath = await NativeMacOSCamera.stopRecording();

      // Should return null after timeout
      expect(filePath, isNull);
    });

    test('should get available cameras', () async {
      final cameras = await NativeMacOSCamera.getAvailableCameras();

      expect(cameras, isNotNull);
      expect(cameras, isA<List<Map<String, dynamic>>>());
      expect(cameras.isNotEmpty, isTrue);
      expect(cameras.first['name'], 'FaceTime HD Camera');
    });

    test('should switch camera successfully', () async {
      final result = await NativeMacOSCamera.switchCamera(0);

      expect(result, isTrue);
      expect(
        methodCalls.any(
          (call) =>
              call.method == 'switchCamera' &&
              call.arguments['cameraIndex'] == 0,
        ),
        isTrue,
      );
    });

    test('should check camera permission', () async {
      final hasPermission = await NativeMacOSCamera.hasPermission();

      expect(hasPermission, isTrue);
      expect(methodCalls.any((call) => call.method == 'hasPermission'), isTrue);
    });

    test('should request camera permission', () async {
      final granted = await NativeMacOSCamera.requestPermission();

      expect(granted, isTrue);
      expect(
        methodCalls.any((call) => call.method == 'requestPermission'),
        isTrue,
      );
    });

    test('should stop preview successfully', () async {
      await NativeMacOSCamera.initialize();
      await NativeMacOSCamera.startPreview();
      final result = await NativeMacOSCamera.stopPreview();

      expect(result, isTrue);
      expect(methodCalls.any((call) => call.method == 'stopPreview'), isTrue);
    });

    test('should handle errors gracefully', () async {
      // Override mock to simulate error
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'initialize') {
                throw PlatformException(
                  code: 'PERMISSION_DENIED',
                  message: 'Camera permission denied',
                );
              }
              return null;
            },
          );

      final result = await NativeMacOSCamera.initialize();

      // Should return false on error
      expect(result, isFalse);
    });
  });
}
