import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Apple native auth error contract', () {
    test('maps NSURLError auth-required failures before transport errors', () {
      final source = _appleSourceFile(
        'HTTPPlaybackError.swift',
      ).readAsStringSync();

      final authMapping = RegExp(
        r'code == NSURLErrorUserAuthenticationRequired\s*'
        r'\}\)\s*\{\s*statuses\.append\(401\)\s*\}',
      ).firstMatch(source);
      expect(authMapping, isNotNull);
      expect(
        authMapping!.end,
        lessThan(source.indexOf('case NSURLErrorTimedOut:')),
        reason: 'An auth-required error must outrank a wrapped timeout.',
      );
    });

    test('maps HTTP 401 responses to auth_required', () {
      final source = _appleSourceFile(
        'HTTPPlaybackError.swift',
      ).readAsStringSync();

      expect(source, contains(RegExp(r'case 401:\s*return "auth_required"')));
    });

    test('returns typed auth details from composition-load failures', () {
      final source = _appleSourceFile().readAsStringSync();

      final code = RegExp(
        r'let (\w+)\s*=\s*self\.errorCode\(for:\s*error as NSError\)',
      ).firstMatch(source);
      expect(code, isNotNull, reason: 'Classify the original native error.');
      final compositionError = source.indexOf(
        'code: "COMPOSITION_ERROR"',
        code!.end,
      );
      expect(compositionError, greaterThan(code.end));
      expect(
        source.substring(compositionError),
        contains(
          RegExp(
            r'code: "COMPOSITION_ERROR",\s*'
            r'message: \w+,\s*'
            'details:\\s*\\["errorCode":\\s*${code.group(1)}\\]',
          ),
        ),
        reason: 'FlutterError details must carry the derived native code.',
      );
    });
  });
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the auth contract is asserted
/// once.
File _appleSourceFile([String name = 'DivineVideoPlayerInstance.swift']) {
  final relative =
      'darwin/divine_video_player/Sources/divine_video_player/$name';
  final packageRelative = File(relative);
  return packageRelative.existsSync()
      ? packageRelative
      : File('packages/divine_video_player/$relative');
}
