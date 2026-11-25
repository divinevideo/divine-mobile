import 'package:divine_video_player/src/linux/linux_video_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('linuxVideoConfiguration', () {
    test('retains software output on Linux virtual GPUs', () {
      final configuration = linuxVideoConfiguration();

      expect(configuration.enableHardwareAcceleration, isFalse);
      expect(configuration.hwdec, 'auto-safe');
    });
  });
}
