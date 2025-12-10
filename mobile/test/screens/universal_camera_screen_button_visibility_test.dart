// ABOUTME: Tests for VineRecordingUIState canSwitchCamera field
// ABOUTME: Validates camera switch button visibility state management

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart'
    show VineRecordingState;

void main() {
  group('VineRecordingUIState', () {
    test('includes canSwitchCamera field', () {
      // Test that VineRecordingUIState has canSwitchCamera property
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: Duration(seconds: 30),
        canRecord: true,
        segments: [],
        hasSegments: false,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
      );

      expect(state.canSwitchCamera, isTrue);
    });

    test('canSwitchCamera can be false', () {
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: Duration(seconds: 30),
        canRecord: true,
        segments: [],
        hasSegments: false,
        isCameraInitialized: true,
        canSwitchCamera: false,
        aspectRatio: model.AspectRatio.square,
      );

      expect(state.canSwitchCamera, isFalse);
    });

    test('copyWith preserves canSwitchCamera', () {
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: Duration(seconds: 30),
        canRecord: true,
        segments: [],
        hasSegments: false,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
      );

      final copied = state.copyWith(progress: 0.5);

      expect(copied.canSwitchCamera, isTrue);
      expect(copied.progress, 0.5);
    });

    test('copyWith can update canSwitchCamera', () {
      final state = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: Duration(seconds: 30),
        canRecord: true,
        segments: [],
        hasSegments: false,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
      );

      final copied = state.copyWith(canSwitchCamera: false);

      expect(copied.canSwitchCamera, isFalse);
      expect(state.canSwitchCamera, isTrue); // Original unchanged
    });
  });
}
