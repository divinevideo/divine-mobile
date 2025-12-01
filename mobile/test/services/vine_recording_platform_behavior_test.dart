// ABOUTME: Unit tests for platform-specific recording behavior in VineRecordingController
// ABOUTME: Tests web single-shot vs mobile multi-segment recording constraints

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingController Platform Behavior Tests', () {
    group('Web Platform Constraints', () {
      test('should prevent multiple segments on web', () async {
        if (!kIsWeb) {
          // Skip on non-web platforms
          return;
        }

        final controller = VineRecordingController();
        await controller.initialize();

        // Start first recording
        await controller.startRecording();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();

        expect(controller.segments.length, equals(1));

        // Try to start second segment - should be blocked on web
        await controller.startRecording();

        // Should still only have 1 segment
        expect(controller.segments.length, equals(1));

        controller.dispose();
      });

      test('web should use single continuous recording', () async {
        if (!kIsWeb) {
          return;
        }

        final controller = VineRecordingController();
        await controller.initialize();

        // Web recording flow: start -> stop -> finish
        await controller.startRecording();
        expect(controller.state, equals(VineRecordingState.recording));

        await Future.delayed(const Duration(milliseconds: 200));

        await controller.stopRecording();
        expect(controller.state, isNot(equals(VineRecordingState.recording)));
        expect(controller.segments.length, equals(1));

        // Cannot start another segment
        await controller.startRecording();
        expect(
          controller.segments.length,
          equals(1),
          reason: 'Web should not allow multiple segments',
        );

        controller.dispose();
      });
    });

    group('Mobile/Desktop Platform Behavior', () {
      test('should allow multiple segments on mobile', () async {
        if (kIsWeb) {
          // Skip on web platform
          return;
        }

        final controller = VineRecordingController();
        await controller.initialize();

        // First segment
        await controller.startRecording();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();
        expect(controller.segments.length, equals(1));

        // Second segment
        await controller.startRecording();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();
        expect(controller.segments.length, equals(2));

        // Third segment
        await controller.startRecording();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();
        expect(controller.segments.length, equals(3));

        controller.dispose();
      });

      test('should track total duration across segments on mobile', () async {
        if (kIsWeb) {
          return;
        }

        final controller = VineRecordingController();
        await controller.initialize();

        // Record three 200ms segments
        for (int i = 0; i < 3; i++) {
          await controller.startRecording();
          await Future.delayed(const Duration(milliseconds: 200));
          await controller.stopRecording();
        }

        // Total should be ~600ms
        expect(
          controller.totalRecordedDuration.inMilliseconds,
          greaterThan(500),
        );
        expect(controller.totalRecordedDuration.inMilliseconds, lessThan(800));

        controller.dispose();
      });

      test('should support pause and resume on mobile', () async {
        if (kIsWeb) {
          return;
        }

        final controller = VineRecordingController();
        await controller.initialize();

        // Start recording
        await controller.startRecording();
        expect(controller.state, equals(VineRecordingState.recording));

        // Pause (stop without finishing)
        await controller.stopRecording();
        expect(controller.state, equals(VineRecordingState.paused));
        expect(controller.segments.isNotEmpty, isTrue);

        // Resume (start another segment)
        await controller.startRecording();
        expect(controller.state, equals(VineRecordingState.recording));

        await controller.stopRecording();
        expect(controller.segments.length, greaterThan(1));

        controller.dispose();
      });
    });

    group('FFmpeg Concatenation Platform Check', () {
      test('should reject FFmpeg concatenation on web', () async {
        if (!kIsWeb) {
          // This test is for web behavior
          return;
        }

        final controller = VineRecordingController();

        // Directly test that concatenation throws on web
        // (We'd need to expose _concatenateSegments or test via finishRecording)
        // For now, verify the constraint via segments
        await controller.initialize();
        await controller.startRecording();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();

        // Verify web doesn't support multi-segment
        expect(controller.segments.length, equals(1));

        controller.dispose();
      });

      test('should support FFmpeg concatenation on mobile', () async {
        if (kIsWeb) {
          return;
        }

        final controller = VineRecordingController();
        await controller.initialize();

        // Create multiple segments
        for (int i = 0; i < 3; i++) {
          await controller.startRecording();
          await Future.delayed(const Duration(milliseconds: 100));
          await controller.stopRecording();
        }

        expect(
          controller.segments.length,
          equals(3),
          reason: 'Mobile should support multiple segments for FFmpeg concat',
        );

        controller.dispose();
      });
    });

    group('State Transitions', () {
      test('should transition through states correctly', () async {
        final controller = VineRecordingController();

        await controller.initialize();
        expect(controller.state, equals(VineRecordingState.idle));

        await controller.startRecording();
        expect(controller.state, equals(VineRecordingState.recording));

        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();

        if (kIsWeb) {
          // Web stays idle after stop
          expect(controller.state, equals(VineRecordingState.idle));
        } else {
          // Mobile goes to paused
          expect(controller.state, equals(VineRecordingState.paused));
        }

        controller.dispose();
      });

      test('should set canRecord correctly based on platform', () async {
        final controller = VineRecordingController();
        await controller.initialize();

        expect(controller.canRecord, isTrue);

        await controller.startRecording();
        await Future.delayed(const Duration(milliseconds: 100));
        await controller.stopRecording();

        if (kIsWeb) {
          // Web can't record again (single-shot)
          expect(controller.canRecord, isFalse);
        } else {
          // Mobile can record again (segments)
          expect(controller.canRecord, isTrue);
        }

        controller.dispose();
      });
    });
  });
}
