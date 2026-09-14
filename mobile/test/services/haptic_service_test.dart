// ABOUTME: Unit tests for HapticService.
// ABOUTME: Verifies that centralized haptic methods dispatch correct platform
// calls.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/haptic_service.dart';

void main() {
  group(HapticService, () {
    late List<String> hapticCalls;
    late TestWidgetsFlutterBinding binding;

    setUp(() {
      binding = TestWidgetsFlutterBinding.ensureInitialized();
      hapticCalls = [];
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call.arguments as String);
          }
          return null;
        },
      );
    });

    tearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    test('lightImpact dispatches HapticFeedbackType.lightImpact', () async {
      await HapticService.lightImpact();

      expect(hapticCalls, equals(['HapticFeedbackType.lightImpact']));
    });

    test('heavyImpact dispatches HapticFeedbackType.heavyImpact', () async {
      await HapticService.heavyImpact();

      expect(hapticCalls, equals(['HapticFeedbackType.heavyImpact']));
    });

    test('recordingFeedback delegates to lightImpact', () async {
      await HapticService.recordingFeedback();

      expect(hapticCalls, equals(['HapticFeedbackType.lightImpact']));
    });

    test('snapFeedback delegates to lightImpact', () async {
      await HapticService.snapFeedback();

      expect(hapticCalls, equals(['HapticFeedbackType.lightImpact']));
    });

    test('destructiveZoneFeedback delegates to heavyImpact', () async {
      await HapticService.destructiveZoneFeedback();

      expect(hapticCalls, equals(['HapticFeedbackType.heavyImpact']));
    });

    test('immersiveModeFeedback delegates to lightImpact', () async {
      await HapticService.immersiveModeFeedback();

      expect(hapticCalls, equals(['HapticFeedbackType.lightImpact']));
    });
  });
}
