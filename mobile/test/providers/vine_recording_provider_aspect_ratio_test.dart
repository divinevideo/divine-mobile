import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingUIState AspectRatio', () {
    test('includes aspectRatio in state', () {
      final controller = VineRecordingController();
      final state = VineRecordingUIState(
        recordingState: controller.state,
        progress: controller.progress,
        totalRecordedDuration: controller.totalRecordedDuration,
        remainingDuration: controller.remainingDuration,
        canRecord: controller.canRecord,
        segments: controller.segments,
        hasSegments: controller.hasSegments,
        isCameraInitialized: controller.isCameraInitialized,
        canSwitchCamera: controller.canSwitchCamera,
        aspectRatio: controller.aspectRatio,
      );

      expect(state.aspectRatio, equals(AspectRatio.square));
    });

    test('copyWith updates aspectRatio', () {
      final controller = VineRecordingController();
      final state = VineRecordingUIState(
        recordingState: controller.state,
        progress: controller.progress,
        totalRecordedDuration: controller.totalRecordedDuration,
        remainingDuration: controller.remainingDuration,
        canRecord: controller.canRecord,
        segments: controller.segments,
        hasSegments: controller.hasSegments,
        isCameraInitialized: controller.isCameraInitialized,
        canSwitchCamera: controller.canSwitchCamera,
        aspectRatio: AspectRatio.square,
      );

      final updated = state.copyWith(aspectRatio: AspectRatio.vertical);
      expect(updated.aspectRatio, equals(AspectRatio.vertical));
    });
  });
}
