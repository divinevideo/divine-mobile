// ABOUTME: Pins that startup sizes the image cache the app decodes into by
// ABOUTME: device RAM, before runApp.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('startOpenVineApp image cache budget wiring', () {
    test('sizes the decoding image cache from device RAM before runApp', () {
      final source = File('lib/startup/app_bootstrap.dart').readAsStringSync();
      final code = source
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');

      final call = RegExp(
        r'await\s+configureImageCacheBudget\(([^;]*)\);',
      ).firstMatch(code);
      expect(
        call,
        isNotNull,
        reason:
            'startOpenVineApp must await configureImageCacheBudget. Its own '
            'tests build a fresh ImageCache, so they stay green if this call '
            'is removed and every device keeps the 100 MB framework default.',
      );
      final arguments = call!.group(1)!;
      expect(
        arguments,
        contains(RegExp(r'cache:\s*PaintingBinding\.instance\.imageCache\b')),
        reason: 'the budget must land on the cache the app decodes into',
      );
      expect(
        arguments,
        contains(
          RegExp(
            r'readPhysicalMemoryBytes:\s*'
            r'const DeviceMemoryService\(\)\.physicalMemoryBytes\b',
          ),
        ),
        reason: 'the budget must come from the device-memory channel',
      );
      expect(
        call.start,
        lessThan(code.indexOf('runApp(')),
        reason: 'images decoded before the budget is set use the default',
      );
    });
  });
}
