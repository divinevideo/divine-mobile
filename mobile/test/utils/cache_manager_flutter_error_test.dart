import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/cache_manager_flutter_error.dart';

void main() {
  group('shouldReportCacheManagerError', () {
    final writeContext = ErrorDescription(
      'Thrown when writing the file containing cache info. '
      'The cache info could not be persisted and may be lost when the '
      'app is closed.',
    );

    // Crashlytics ba4e2ce245c67dca3ba9c061b4c342df (iOS 1.0.29 (912)): the
    // index write failed on a full disk and was reported as JSON corruption.
    test('does not report an index write that failed on a full disk', () {
      final details = FlutterErrorDetails(
        exception: const FileSystemException(
          'writeFrom failed',
          '/Library/Application Support/openvine_video_cache.json.tmp',
          OSError('No space left on device', 28),
        ),
        library: 'flutter cache manager',
        context: writeContext,
      );

      expect(shouldReportCacheManagerError(details), isFalse);
    });

    test('reports an index write that failed for another reason', () {
      final details = FlutterErrorDetails(
        exception: const FileSystemException(
          'writeFrom failed',
          '/Library/Application Support/openvine_video_cache.json.tmp',
          OSError('Input/output error', 5),
        ),
        library: 'flutter cache manager',
        context: writeContext,
      );

      expect(shouldReportCacheManagerError(details), isTrue);
    });

    test('reports an index that cannot be parsed', () {
      final details = FlutterErrorDetails(
        exception: const FormatException('Unexpected end of input'),
        library: 'flutter cache manager',
        context: ErrorDescription(
          'Thrown when reading the file containing cache info. '
          'The cached files cannot be used by the cache manager anymore.',
        ),
      );

      expect(shouldReportCacheManagerError(details), isTrue);
    });
  });
}
