// ABOUTME: Unit tests for VineRecordingUIState behavior
// ABOUTME: Tests state getters and properties without requiring camera

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingUIState Tests', () {
    test('hasSegments should be false when no segments', () {
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: const Duration(seconds: 6),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [],
      );

      expect(state.hasSegments, isFalse, reason: 'Should have no segments');
    });

    test('hasSegments should be true when segments exist', () {
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.paused,
        progress: 0.5,
        totalRecordedDuration: const Duration(seconds: 2),
        remainingDuration: const Duration(seconds: 4),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [
          RecordingSegment(
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(seconds: 1)),
            duration: const Duration(seconds: 1),
            filePath: '/test/segment.mp4',
          ),
        ],
      );

      expect(state.hasSegments, isTrue, reason: 'Should have segments');
      expect(state.segments.length, equals(1));
    });

    test('isRecording getter should match recording state', () {
      final recordingState = VineRecordingUIState(
        recordingState: VineRecordingState.recording,
        progress: 0.3,
        totalRecordedDuration: const Duration(seconds: 1),
        remainingDuration: const Duration(seconds: 5),
        canRecord: false,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [],
      );

      final idleState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: const Duration(seconds: 6),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [],
      );

      expect(recordingState.isRecording, isTrue);
      expect(idleState.isRecording, isFalse);
    });

    test('recordingDuration should match totalRecordedDuration', () {
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.paused,
        progress: 0.5,
        totalRecordedDuration: const Duration(seconds: 3),
        remainingDuration: const Duration(seconds: 3),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [],
      );

      expect(state.recordingDuration, equals(const Duration(seconds: 3)));
      expect(state.recordingDuration.inSeconds, equals(3));
    });

    test('multiple segments should be countable', () {
      final segments = [
        RecordingSegment(
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1)),
          duration: const Duration(seconds: 1),
          filePath: '/test/segment1.mp4',
        ),
        RecordingSegment(
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1)),
          duration: const Duration(seconds: 1),
          filePath: '/test/segment2.mp4',
        ),
        RecordingSegment(
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(seconds: 1)),
          duration: const Duration(seconds: 1),
          filePath: '/test/segment3.mp4',
        ),
      ];

      final state = VineRecordingUIState(
        recordingState: VineRecordingState.paused,
        progress: 0.5,
        totalRecordedDuration: const Duration(seconds: 3),
        remainingDuration: const Duration(seconds: 3),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: segments,
      );

      expect(state.segments.length, equals(3));
      expect(state.hasSegments, isTrue);
    });

    test('canRecord should reflect ability to start recording', () {
      final canRecordState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: const Duration(seconds: 6),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [],
      );

      final cannotRecordState = VineRecordingUIState(
        recordingState: VineRecordingState.recording,
        progress: 1.0,
        totalRecordedDuration: const Duration(seconds: 6),
        remainingDuration: Duration.zero,
        canRecord: false,
        isCameraInitialized: true,
        canSwitchCamera: false,
        segments: [],
      );

      expect(canRecordState.canRecord, isTrue);
      expect(cannotRecordState.canRecord, isFalse);
    });

    test('progress should be between 0 and 1', () {
      final states = [
        VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: const Duration(seconds: 6),
          canRecord: true,
          isCameraInitialized: true,
          canSwitchCamera: false,
          segments: [],
        ),
        VineRecordingUIState(
          recordingState: VineRecordingState.recording,
          progress: 0.5,
          totalRecordedDuration: const Duration(seconds: 3),
          remainingDuration: const Duration(seconds: 3),
          canRecord: false,
          isCameraInitialized: true,
          canSwitchCamera: false,
          segments: [],
        ),
        VineRecordingUIState(
          recordingState: VineRecordingState.completed,
          progress: 1.0,
          totalRecordedDuration: const Duration(seconds: 6),
          remainingDuration: Duration.zero,
          canRecord: false,
          isCameraInitialized: true,
          canSwitchCamera: false,
          segments: [],
        ),
      ];

      for (final state in states) {
        expect(state.progress, greaterThanOrEqualTo(0.0));
        expect(state.progress, lessThanOrEqualTo(1.0));
      }
    });
  });
}
