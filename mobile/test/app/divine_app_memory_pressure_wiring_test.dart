// ABOUTME: Pins that the app's memory-pressure handler clears the image cache
// ABOUTME: through the helper that also schedules a frame.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineApp memory-pressure wiring', () {
    test('clears the image cache through clearDecodedImageCache', () {
      final source = File('lib/app/divine_app.dart').readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      expect(
        code,
        contains(
          RegExp(
            r'clearImageCache:\s*\(\)\s*=>\s*'
            r'clearDecodedImageCache\(\s*includeLiveImages:\s*true,?\s*\)',
          ),
        ),
        reason:
            'A bare imageCache.clear() frees nothing until a frame is drawn, '
            'so the backgrounded app kept its graphics memory (#10308). '
            'MemoryPressureHandler tests inject their own callback, so they '
            'stay green if this wiring changes.',
      );
    });
  });
}
