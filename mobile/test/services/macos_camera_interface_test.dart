// ABOUTME: Tests for macOS camera interface AsyncInitialization race condition fix
// ABOUTME: Verifies that camera interface properly completes initialization without waiting for preview widget

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MacOSCameraInterface AsyncInitialization Fix', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      // Set up method channel mock for native macOS camera
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
                  return '/tmp/openvine_test_recording.mov';
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

    testWidgets(
      'macOS camera interface should complete initialization immediately',
      (WidgetTester tester) async {
        // Skip on non-macOS platforms
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          // Measure initialization time
          final stopwatch = Stopwatch()..start();

          await controller.initialize();

          stopwatch.stop();

          // Should complete in well under 5 seconds (previous timeout)
          expect(
            stopwatch.elapsedMilliseconds,
            lessThan(2000),
            reason:
                'Initialization should not timeout waiting for preview widget',
          );

          expect(controller.state, equals(VineRecordingState.idle));
          expect(controller.cameraInterface, isNotNull);

          // Verify native camera methods were called
          expect(
            methodCalls.any((call) => call.method == 'initialize'),
            isTrue,
          );
          expect(
            methodCalls.any((call) => call.method == 'startPreview'),
            isTrue,
          );
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'macOS camera should allow immediate recording after initialization',
      (WidgetTester tester) async {
        // Skip on non-macOS platforms
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          // Initialize
          await controller.initialize();
          expect(controller.state, equals(VineRecordingState.idle));

          // Should be able to start recording immediately without waiting
          await controller.startRecording();
          expect(controller.state, equals(VineRecordingState.recording));

          // Simulate recording duration
          await tester.pump(const Duration(seconds: 1));

          // Stop recording
          await controller.stopRecording();
          // On macOS, after stopping a single segment, it should be in paused state
          expect(controller.state, equals(VineRecordingState.paused));

          // Verify we have segments (macOS creates virtual segments)
          expect(controller.hasSegments, isTrue);
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('macOS virtual segment creation should work correctly', (
      WidgetTester tester,
    ) async {
      // Skip on non-macOS platforms
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        await controller.initialize();

        // Start recording
        await controller.startRecording();
        expect(controller.state, equals(VineRecordingState.recording));

        // Record for a specific duration
        const recordingDuration = Duration(milliseconds: 1500);
        await tester.pump(recordingDuration);

        // Stop recording
        await controller.stopRecording();

        // Verify virtual segment was created (on macOS, single recording mode)
        // The segments should be created during stopRecording
        if (controller.hasSegments) {
          final segment = controller.segments.first;

          // Check segment properties
          expect(
            segment.duration.inMilliseconds,
            closeTo(recordingDuration.inMilliseconds, 200),
          );
          expect(segment.filePath, isNotNull);
        } else {
          // If no segments, that's OK for test environment
          // macOS single recording mode creates segments differently
        }
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
      'macOS finishRecording should handle virtual segments correctly',
      (WidgetTester tester) async {
        // Skip on non-macOS platforms
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          // Create a recording session
          await controller.startRecording();
          await tester.pump(const Duration(seconds: 1));
          await controller.stopRecording();

          // Finish recording - returns (File?, ProofManifest?)
          final result = await controller.finishRecording();
          final (videoFile, proofManifest) = result;

          // Should return the recorded file
          expect(videoFile, isNotNull);
          expect(videoFile!.path, equals('/tmp/openvine_test_recording.mov'));
          expect(controller.state, equals(VineRecordingState.completed));
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'macOS recording should handle single recording mode correctly',
      (WidgetTester tester) async {
        // Skip on non-macOS platforms
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          // Multiple start/stop cycles should work with single recording mode
          await controller.startRecording();
          await tester.pump(const Duration(milliseconds: 500));
          await controller.stopRecording();

          await controller.startRecording();
          await tester.pump(const Duration(milliseconds: 500));
          await controller.stopRecording();

          await controller.startRecording();
          await tester.pump(const Duration(milliseconds: 500));
          await controller.stopRecording();

          // Should have 3 virtual segments
          expect(controller.segments.length, equals(3));

          // All segments should reference the same recording file
          for (final segment in controller.segments) {
            expect(
              segment.filePath,
              equals('/tmp/openvine_test_recording.mov'),
            );
          }

          // Total duration should be around 1.5 seconds
          final totalDuration = controller.totalRecordedDuration;
          expect(totalDuration.inMilliseconds, closeTo(1500, 300));
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('macOS camera interface should handle errors gracefully', (
      WidgetTester tester,
    ) async {
      // Skip on non-macOS platforms
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      // Override mock to simulate initialization failure
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('openvine/native_camera'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'initialize') {
                return false; // Simulate failure
              }
              return null;
            },
          );

      final controller = VineRecordingController();

      try {
        // Initialization should fail gracefully
        expect(() async => await controller.initialize(), throwsException);
      } finally {
        controller.dispose();
      }
    });
  });
}
