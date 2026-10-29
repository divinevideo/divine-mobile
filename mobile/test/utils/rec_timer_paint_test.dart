// ABOUTME: Tests the text a REC timer shows: seconds and hundredths, since a
// ABOUTME: video runs for a few seconds.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/rec_timer_paint.dart';

void main() {
  group('recTimerText', () {
    test('writes seconds and hundredths', () {
      expect(recTimerText(Duration.zero), equals('00:00'));
      expect(
        recTimerText(const Duration(seconds: 6, milliseconds: 299)),
        equals('06:29'),
      );
    });
  });
}
