import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// HTTP 403 and 404 must reach Dart as their own codes rather than being
/// flattened into `http_client_error`.
///
/// Without them, `classifyVideoError` can only recover "forbidden" and
/// "not found" by scanning the raw error message for English status text —
/// and on Android that message is `PlaybackException.localizedMessage`, which
/// carries no guarantee of containing either.
void main() {
  group('Android native HTTP status error contract', () {
    test('classifies 403 and 404 before the generic 4xx mapping', () {
      final source = _androidSourceFile().readAsStringSync();

      final badStatusBranch = source.indexOf(
        'PlaybackException.ERROR_CODE_IO_BAD_HTTP_STATUS',
      );
      final genericClientMapping = source.indexOf(
        'status in 400..499 -> "http_client_error"',
      );

      expect(badStatusBranch, greaterThanOrEqualTo(0));
      expect(genericClientMapping, greaterThan(badStatusBranch));

      for (final entry in const {403: 'forbidden', 404: 'not_found'}.entries) {
        final statusCheck = source.indexOf('status == ${entry.key}');
        expect(
          statusCheck,
          greaterThan(badStatusBranch),
          reason:
              'HTTP ${entry.key} needs its own branch inside the '
              'bad-HTTP-status mapping.',
        );

        final statusMapping = source.indexOf('"${entry.value}"', statusCheck);
        expect(statusMapping, greaterThan(statusCheck));
        expect(
          statusMapping,
          lessThan(genericClientMapping),
          reason:
              'HTTP ${entry.key} must be classified before the generic 4xx '
              'mapping, which would otherwise swallow it as '
              'http_client_error.',
        );
      }
    });
  });

  group('Apple native HTTP response error contract', () {
    test('classifies exposed 403 and 404 responses before generic 4xx', () {
      final source = _appleSourceFile().readAsStringSync();

      final responseBranch = source.indexOf(
        'NSURLErrorFailingURLResponseErrorKey',
      );
      final genericReturn = source.indexOf(
        'return httpResponse.statusCode >= 500',
      );

      expect(responseBranch, greaterThanOrEqualTo(0));
      expect(genericReturn, greaterThan(responseBranch));

      for (final entry in const {403: 'forbidden', 404: 'not_found'}.entries) {
        final statusCheck = source.indexOf(
          'httpResponse.statusCode == ${entry.key}',
        );
        expect(
          statusCheck,
          greaterThan(responseBranch),
          reason:
              'An exposed HTTP ${entry.key} response needs its own branch so '
              'Apple platforms stay normalised with Android.',
        );

        final statusMapping = source.indexOf(
          'return "${entry.value}"',
          statusCheck,
        );
        expect(statusMapping, greaterThan(statusCheck));
        expect(
          statusMapping,
          lessThan(genericReturn),
          reason:
              'HTTP ${entry.key} must return before the generic 4xx/5xx '
              'return, which would otherwise swallow it as '
              'http_client_error.',
        );
      }
    });
  });
}

File _androidSourceFile() => _resolve(
  'android/src/main/kotlin/com/divinevideo/divine_video_player/'
  'DivineVideoPlayerInstance.kt',
);

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the contract is asserted once.
File _appleSourceFile() => _resolve(
  'darwin/divine_video_player/Sources/divine_video_player/'
  'DivineVideoPlayerInstance.swift',
);

/// Resolves [packageRelativePath] whether the suite runs from the package
/// root or from `mobile/`.
File _resolve(String packageRelativePath) {
  final packageRelative = File(packageRelativePath);
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File('packages/divine_video_player/$packageRelativePath');
}
