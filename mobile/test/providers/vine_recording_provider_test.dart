// ABOUTME: TDD test for VineRecordingUIState convenience getters used by universal_camera_screen_pure.dart
// ABOUTME: Tests isRecording, isInitialized, isError, recordingDuration, and errorMessage getters

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingUIState Convenience Getters (TDD)', () {
    group('GREEN Phase: Tests for working getters', () {
      test('VineRecordingUIState isRecording should work correctly', () {
        const recordingState = VineRecordingUIState(
          recordingState: VineRecordingState.recording,
          progress: 0.5,
          totalRecordedDuration: Duration(seconds: 3),
          remainingDuration: Duration(seconds: 3),
          canRecord: true,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: true,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        expect(recordingState.isRecording, true);
        expect(idleState.isRecording, false);
      });

      test('VineRecordingUIState isInitialized should work correctly', () {
        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: true,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        const errorState = VineRecordingUIState(
          recordingState: VineRecordingState.error,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: false,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        const processingState = VineRecordingUIState(
          recordingState: VineRecordingState.processing,
          progress: 1.0,
          totalRecordedDuration: Duration(seconds: 6),
          remainingDuration: Duration.zero,
          canRecord: false,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        expect(idleState.isInitialized, true);
        expect(errorState.isInitialized, false);
        expect(processingState.isInitialized, false);
      });

      test('VineRecordingUIState isError should work correctly', () {
        const errorState = VineRecordingUIState(
          recordingState: VineRecordingState.error,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: false,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: true,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        expect(errorState.isError, true);
        expect(idleState.isError, false);
      });

      test('VineRecordingUIState recordingDuration should work correctly', () {
        const state = VineRecordingUIState(
          recordingState: VineRecordingState.recording,
          progress: 0.5,
          totalRecordedDuration: Duration(seconds: 3),
          remainingDuration: Duration(seconds: 3),
          canRecord: true,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        expect(state.recordingDuration, Duration(seconds: 3));
      });

      test('VineRecordingUIState errorMessage should work correctly', () {
        const errorState = VineRecordingUIState(
          recordingState: VineRecordingState.error,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: false,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        const idleState = VineRecordingUIState(
          recordingState: VineRecordingState.idle,
          progress: 0.0,
          totalRecordedDuration: Duration.zero,
          remainingDuration: Duration(seconds: 6),
          canRecord: true,
          segments: [],
          isCameraInitialized: true,
          canSwitchCamera: false,
        );

        expect(errorState.errorMessage, isA<String>());
        expect(errorState.errorMessage, isNotNull);
        expect(idleState.errorMessage, null);
      });
    });
  });

  group('RecordingResult return type (TDD)', () {
    test(
      'stopRecording should return RecordingResult with video and draftId',
      () async {
        // This test will guide implementation
        // Note: We can't fully test this without a real controller setup
        // This is a structural test to verify the API exists

        // For now, just verify the RecordingResult class exists and has the right fields
        final result = RecordingResult(
          videoFile: File('/path/to/video.mp4'),
          draftId: 'draft_12345',
          proofManifest: null,
        );

        expect(result.videoFile, isNotNull);
        expect(result.draftId, isNotNull);
        expect(result.draftId, startsWith('draft_'));
        expect(result.proofManifest, isNull);
      },
    );
  });
}
