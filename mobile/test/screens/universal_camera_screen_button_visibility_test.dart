import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/aspect_ratio.dart' show AspectRatio;
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
        aspectRatio: AspectRatio.vertical,
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
        aspectRatio: AspectRatio.vertical,
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
        aspectRatio: AspectRatio.vertical,
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
        aspectRatio: AspectRatio.vertical,
      );

      final copied = state.copyWith(canSwitchCamera: false);

      expect(copied.canSwitchCamera, isFalse);
      expect(state.canSwitchCamera, isTrue); // Original unchanged
    });
  });
}
