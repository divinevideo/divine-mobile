import 'package:divine_video_player/src/desktop/desktop_video_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('desktopVideoConfiguration', () {
    test('preserves Windows 1080 by 1920 portrait output', () {
      final configuration = desktopVideoConfiguration(TargetPlatform.windows);

      // The locked Windows software output independently clamps height to
      // 1080, turning 1080x1920 into a square. Its hardware surface has no cap.
      expect(configuration.enableHardwareAcceleration, isTrue);
    });

    test('retains software output on Linux virtual GPUs', () {
      final configuration = desktopVideoConfiguration(TargetPlatform.linux);

      expect(configuration.enableHardwareAcceleration, isFalse);
    });
  });
}
