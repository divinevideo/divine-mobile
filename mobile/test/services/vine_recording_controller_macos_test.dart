// ABOUTME: TDD tests for VineRecordingController macOS-specific logic
// ABOUTME: Tests virtual segment creation, single recording mode, and finish recording workflow

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/vine_recording_controller.dart';

// Generate mocks
@GenerateMocks([File])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VineRecordingController macOS Logic (TDD)', () {
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
                  return '/Users/test/recording_${DateTime.now().millisecondsSinceEpoch}.mov';
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
      'RED: VineRecordingController should create virtual segments on macOS',
      (WidgetTester tester) async {
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

          // Simulate recording time
          await tester.pump(const Duration(milliseconds: 1200));

          // Stop recording (should create virtual segment)
          await controller.stopRecording();

          // RED: Should have 1 virtual segment
          expect(
            controller.segments.length,
            equals(1),
            reason: 'macOS should create virtual segments during recording',
          );

          // Verify segment properties
          final segment = controller.segments.first;
          expect(
            segment.duration.inMilliseconds,
            closeTo(1200, 100),
            reason: 'Virtual segment should match recording duration',
          );
          expect(
            segment.filePath,
            isNotNull,
            reason: 'Virtual segment should have file path',
          );
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'GREEN: Multiple recording segments should accumulate total duration',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          // Record three segments
          const segmentDurations = [800, 1200, 600]; // milliseconds

          for (int i = 0; i < segmentDurations.length; i++) {
            await controller.startRecording();
            await tester.pump(Duration(milliseconds: segmentDurations[i]));
            await controller.stopRecording();
          }

          // Should have 3 segments
          expect(controller.segments.length, equals(3));

          // Total duration should be sum of all segments
          final expectedTotal = segmentDurations.reduce((a, b) => a + b);
          expect(
            controller.totalRecordedDuration.inMilliseconds,
            closeTo(expectedTotal, 300),
          );
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'GREEN: finishRecording should handle macOS single recording mode',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          // Create recording session
          await controller.startRecording();
          await tester.pump(const Duration(seconds: 2));
          await controller.stopRecording();

          // Finish recording (returns tuple: (File?, ProofManifest?))
          final (videoFile, _) = await controller.finishRecording();

          // Should return valid file
          expect(videoFile, isNotNull);
          expect(videoFile!.path, startsWith('/Users/test/recording_'));
          expect(videoFile.path, endsWith('.mov'));

          // State should be completed
          expect(controller.state, equals(VineRecordingState.completed));
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'EDGE CASE: finishRecording should handle empty segments gracefully',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          // Try to finish recording without any segments
          expect(
            () async => await controller.finishRecording(),
            throwsA(
              predicate(
                (e) => e.toString().contains(
                  'No valid video segments found for compilation',
                ),
              ),
            ),
            reason: 'Should fail when no segments exist',
          );
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('EDGE CASE: very short recording segments should be ignored', (
      WidgetTester tester,
    ) async {
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        await controller.initialize();

        // Record very short segment (below minimum)
        await controller.startRecording();
        await tester.pump(
          const Duration(milliseconds: 50),
        ); // Below 100ms minimum
        await controller.stopRecording();

        // Should not create segment
        expect(
          controller.segments.length,
          equals(0),
          reason: 'Segments below minimum duration should be ignored',
        );

        // Record valid segment
        await controller.startRecording();
        await tester.pump(const Duration(milliseconds: 200)); // Above minimum
        await controller.stopRecording();

        // Should create segment
        expect(
          controller.segments.length,
          equals(1),
          reason: 'Segments above minimum duration should be created',
        );
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
      'REFACTOR: segment file paths should be consistent in single recording mode',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          // Create multiple virtual segments (same underlying recording)
          for (int i = 0; i < 3; i++) {
            await controller.startRecording();
            await tester.pump(const Duration(milliseconds: 500));
            await controller.stopRecording();
          }

          expect(controller.segments.length, equals(3));

          // All segments should reference the same file (single recording mode)
          final firstFilePath = controller.segments.first.filePath;
          for (final segment in controller.segments) {
            expect(
              segment.filePath,
              equals(firstFilePath),
              reason:
                  'All virtual segments should reference same recording file',
            );
          }
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets(
      'ERROR HANDLING: stopRecording should handle recording errors gracefully',
      (WidgetTester tester) async {
        if (kIsWeb || !Platform.isMacOS) {
          return;
        }

        // Override mock to simulate recording error
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('openvine/native_camera'),
              (MethodCall methodCall) async {
                if (methodCall.method == 'stopRecording') {
                  throw PlatformException(
                    code: 'RECORDING_ERROR',
                    message: 'Failed to stop recording',
                  );
                }
                return methodCall.method == 'initialize' ||
                        methodCall.method == 'startPreview' ||
                        methodCall.method == 'startRecording'
                    ? true
                    : null;
              },
            );

        final controller = VineRecordingController();

        try {
          await controller.initialize();

          await controller.startRecording();
          await tester.pump(const Duration(milliseconds: 500));

          // stopRecording should handle error gracefully
          await controller.stopRecording();

          // Should still transition to paused/idle state
          expect(
            controller.state,
            anyOf([
              VineRecordingState.idle,
              VineRecordingState.paused,
              VineRecordingState.error,
            ]),
          );
        } finally {
          controller.dispose();
        }
      },
    );

    testWidgets('PERFORMANCE: initialization should complete quickly on macOS', (
      WidgetTester tester,
    ) async {
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();
      final stopwatch = Stopwatch()..start();

      try {
        await controller.initialize();
        stopwatch.stop();

        // Should complete in under 1 second (was timing out at 5 seconds before fix)
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason: 'AsyncInitialization race condition should be fixed',
        );

        expect(controller.state, equals(VineRecordingState.idle));
      } finally {
        controller.dispose();
      }
    });
  });
}
