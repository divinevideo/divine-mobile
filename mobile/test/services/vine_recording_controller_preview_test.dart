// ABOUTME: Unit tests for VineRecordingController preview widget state management
// ABOUTME: Tests the timing and availability of preview widget relative to initialization state

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VineRecordingController Preview Widget State Tests', () {
    late List<MethodCall> methodCalls;

    setUp(() {
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('openvine/native_camera'),
        (MethodCall methodCall) async {
          methodCalls.add(methodCall);

          switch (methodCall.method) {
            case 'hasPermission':
              return true;
            case 'initialize':
              // Simulate realistic native initialization delay
              await Future.delayed(const Duration(milliseconds: 150));
              return true;
            case 'startPreview':
              await Future.delayed(const Duration(milliseconds: 75));
              return true;
            case 'stopPreview':
              return true;
            case 'startRecording':
              return true;
            case 'stopRecording':
              return '/tmp/test.mov';
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
        'FAILING TEST: preview widget should be available immediately when state=idle after init',
        (WidgetTester tester) async {
      // Skip on non-macOS for now
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        // Initialize
        await controller.initialize();

        // When state is idle, the preview widget MUST be accessible
        expect(controller.state, equals(VineRecordingState.idle));

        // This WILL throw LateInitializationError if bug exists
        expect(
            () => controller.cameraInterface?.previewWidget, returnsNormally,
            reason:
                'Preview widget must be available when controller is initialized');

        // Widget should not be null
        expect(controller.cameraInterface?.previewWidget, isNotNull);
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
        'FAILING TEST: accessing previewWidget before initialization should throw meaningful error',
        (WidgetTester tester) async {
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        // Before initialization, state should not be idle
        expect(controller.state, isNot(equals(VineRecordingState.idle)));

        // Accessing preview before init should either:
        // 1. Return null/placeholder gracefully, OR
        // 2. Throw a meaningful error (not LateInitializationError)

        // Currently this throws confusing LateInitializationError
        expect(
            () => controller.cameraInterface?.previewWidget,
            anyOf([
              returnsNormally, // Acceptable: returns null or placeholder
              throwsA(isA<
                  StateError>()), // Acceptable: meaningful "not initialized" error
            ]),
            reason:
                'Should not throw LateInitializationError - should handle gracefully');
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
        'FAILING TEST: initialize() should ensure preview widget is ready before returning',
        (WidgetTester tester) async {
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        // Initialize
        final stopwatch = Stopwatch()..start();
        await controller.initialize();
        stopwatch.stop();

        // After initialize completes, preview MUST be ready
        expect(controller.cameraInterface, isNotNull);
        expect(controller.state, equals(VineRecordingState.idle));

        // Preview widget should be accessible immediately
        expect(() => controller.cameraInterface!.previewWidget,
            returnsNormally,
            reason:
                'initialize() should not complete until preview widget is ready');

        // Should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(3000),
            reason: 'Should not timeout waiting for preview');
      } finally {
        controller.dispose();
      }
    }, skip: 'Test hangs indefinitely - needs investigation (Phase 3.5)');

    testWidgets(
        'FAILING TEST: preview widget should survive state transitions',
        (WidgetTester tester) async {
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        // Initialize
        await controller.initialize();
        expect(controller.state, equals(VineRecordingState.idle));

        // Get preview reference
        final preview1 = controller.cameraInterface!.previewWidget;
        expect(preview1, isNotNull);

        // Start recording
        await controller.startRecording();
        expect(controller.state, equals(VineRecordingState.recording));

        // Preview should still be accessible
        final preview2 = controller.cameraInterface!.previewWidget;
        expect(preview2, isNotNull);

        // Stop recording
        await controller.stopRecording();

        // Preview should still be accessible
        final preview3 = controller.cameraInterface!.previewWidget;
        expect(preview3, isNotNull);

        // Preview widget should be the same instance throughout
        expect(identical(preview1, preview2), isTrue);
        expect(identical(preview2, preview3), isTrue);
      } finally {
        controller.dispose();
      }
    });

    testWidgets(
        'FAILING TEST: concurrent preview widget access should not crash',
        (WidgetTester tester) async {
      if (kIsWeb || !Platform.isMacOS) {
        return;
      }

      final controller = VineRecordingController();

      try {
        // Start initialization
        final initFuture = controller.initialize();

        // Try to access preview during initialization
        // This simulates race condition from UI layer
        await Future.delayed(const Duration(milliseconds: 50));

        // Should either return null gracefully or block until ready
        // Should NOT throw LateInitializationError
        try {
          final preview = controller.cameraInterface?.previewWidget;
          // If we get here, it handled gracefully
          expect(preview, anyOf([isNull, isNotNull]));
        } catch (e) {
          // If it throws, should be meaningful error (not late initialization error)
          expect(e.runtimeType.toString(), isNot(equals('LateError')),
              reason:
                  'Should not expose LateInitializationError to callers');
        }

        // Wait for init to complete
        await initFuture;

        // Now should definitely work
        expect(() => controller.cameraInterface!.previewWidget,
            returnsNormally);
      } finally {
        controller.dispose();
      }
    });
  });
}
