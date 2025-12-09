import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('VineRecordingController AspectRatio', () {
    test('defaults to square aspect ratio', () {
      final controller = VineRecordingController();
      expect(controller.aspectRatio, equals(AspectRatio.square));
    });

    test('setAspectRatio updates aspectRatio', () {
      final controller = VineRecordingController();
      controller.setAspectRatio(AspectRatio.vertical);
      expect(controller.aspectRatio, equals(AspectRatio.vertical));
    });

    test('setAspectRatio triggers state change callback', () {
      final controller = VineRecordingController();
      var callbackCalled = false;
      controller.setStateChangeCallback(() {
        callbackCalled = true;
      });

      controller.setAspectRatio(AspectRatio.vertical);
      expect(callbackCalled, isTrue);
    });

    test('setAspectRatio only works when not recording', () {
      final controller = VineRecordingController();

      // Verify we can change aspect ratio when idle
      expect(controller.state, equals(VineRecordingState.idle));
      controller.setAspectRatio(AspectRatio.vertical);
      expect(controller.aspectRatio, equals(AspectRatio.vertical));

      // Note: The implementation correctly checks state == recording
      // Full integration test of blocking during actual recording
      // is covered in vine_recording_controller_macos_test.dart
    });
  });
}
