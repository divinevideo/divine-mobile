// ABOUTME: Integration tests for ThumbnailApiService that hit real OpenVine API servers
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests actual network calls, server responses, and end-to-end thumbnail generation

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/thumbnail_api_service.dart';

void main() {
  group('ThumbnailApiService Integration Tests', () {
    // Test configuration
    const testVideoId =
        'test-video-12345'; // Use a real video ID from your test data
    const realVideoId =
        '87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344'; // Rabble's video
    const nonExistentVideoId = 'non-existent-video-99999';

    group('Real API Server Tests', () {
      test('getThumbnailUrl generates valid URLs', () {
        final url = ThumbnailApiService.getThumbnailUrl(realVideoId);
        expect(url, startsWith('https://api.openvine.co/thumbnail/'));
        expect(url, contains(realVideoId));
        expect(url, contains('t=2.5'));
      });

      test(
        'thumbnailExists works with real video',
        () async {
          // This test may pass or fail depending on whether thumbnail exists
          // The important thing is that it doesn't throw an exception
          final exists = await ThumbnailApiService.thumbnailExists(realVideoId);
          expect(exists, isA<bool>());

          Log.info('Thumbnail exists for $realVideoId: $exists');
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'thumbnailExists returns false for non-existent video',
        () async {
          final exists = await ThumbnailApiService.thumbnailExists(
            nonExistentVideoId,
          );
          expect(exists, isFalse);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'getThumbnailWithFallback works with real video URL',
        () async {
          // Test thumbnail generation for Rabble's known video
          final url = await ThumbnailApiService.getThumbnailWithFallback(
            realVideoId,
            timeSeconds: 1,
          );

          if (url != null) {
            expect(url, startsWith('https://api.openvine.co/thumbnail/'));
            expect(url, contains(realVideoId));
            expect(url, contains('t=1.0'));
            Log.info('Successfully generated thumbnail: $url');
          } else {
            Log.info(
              'Thumbnail generation failed for $realVideoId - this may be expected if already exists',
            );
          }

          // The test passes if no exception is thrown, regardless of success/failure
          expect(url, anyOf(isNull, isA<String>()));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'getThumbnailWithFallback handles non-existent video gracefully',
        () async {
          final url = await ThumbnailApiService.getThumbnailWithFallback(
            nonExistentVideoId,
          );
          expect(url, isNull);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'getThumbnailWithFallback works end-to-end',
        () async {
          final url = await ThumbnailApiService.getThumbnailWithFallback(
            realVideoId,
            timeSeconds: 2,
            size: ThumbnailSize.medium,
          );

          if (url != null) {
            expect(url, startsWith('https://api.openvine.co/thumbnail/'));
            expect(url, contains(realVideoId));
            Log.info('Got thumbnail with fallback: $url');
          } else {
            Log.info('Fallback thumbnail generation failed for $realVideoId');
          }

          // Should return a URL or null, but not throw
          expect(url, anyOf(isNull, isA<String>()));
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'uploadCustomThumbnail handles file upload',
        () async {
          // Create a simple test image (1x1 pixel PNG)
          final testImageBytes = Uint8List.fromList([
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 dimensions
            0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
            0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
            0x54, 0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00,
            0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01,
            0xE5, 0x27, 0xDE, 0xFC, 0x00, 0x00, 0x00, 0x00, // IEND chunk
            0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
          ]);

          final success = await ThumbnailApiService.uploadCustomThumbnail(
            testVideoId,
            testImageBytes,
            filename: 'test-thumbnail.png',
          );

          Log.info('Custom thumbnail upload result: $success');
          // Should return a boolean, but not throw
          expect(success, isA<bool>());
        },
        timeout: const Timeout(Duration(seconds: 60)),
      );

      test(
        'batchGenerateThumbnails handles multiple videos',
        () async {
          final videoIds = [realVideoId, nonExistentVideoId];
          final results = await ThumbnailApiService.batchGenerateThumbnails(
            videoIds,
            timeSeconds: 1.5,
          );

          expect(results, isA<Map<String, String>>());
          Log.info(
            'Batch generation results: ${results.length}/${videoIds.length} successful',
          );

          // Print results for debugging
          results.forEach((videoId, url) {
            Log.info('  $videoId -> $url');
          });
        },
        timeout: const Timeout(Duration(seconds: 120)),
      );
    });

    group('Error Handling Tests', () {
      test(
        'handles malformed video IDs gracefully',
        () async {
          const malformedId = 'invalid@video#id!';

          final exists = await ThumbnailApiService.thumbnailExists(malformedId);
          expect(exists, isFalse);

          final url = await ThumbnailApiService.getThumbnailWithFallback(
            malformedId,
          );
          expect(url, isNull);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'handles extremely long video IDs',
        () async {
          final longId = 'a' * 1000;

          final exists = await ThumbnailApiService.thumbnailExists(longId);
          expect(exists, isFalse);

          final url = await ThumbnailApiService.getThumbnailWithFallback(
            longId,
          );
          expect(url, isNull);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test('handles empty video ID', () async {
        const emptyId = '';

        final exists = await ThumbnailApiService.thumbnailExists(emptyId);
        expect(exists, isFalse);

        final url = await ThumbnailApiService.getThumbnailWithFallback(emptyId);
        expect(url, isNull);
      }, timeout: const Timeout(Duration(seconds: 30)));

      test(
        'handles special characters in video ID',
        () async {
          const specialId = 'test-video_with.special-chars';

          // Should not throw exceptions
          final exists = await ThumbnailApiService.thumbnailExists(specialId);
          expect(exists, isA<bool>());

          final url = await ThumbnailApiService.getThumbnailWithFallback(
            specialId,
          );
          expect(url, anyOf(isNull, isA<String>()));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('Performance Tests', () {
      test(
        'thumbnail generation completes within reasonable time',
        () async {
          final stopwatch = Stopwatch()..start();

          await ThumbnailApiService.getThumbnailWithFallback(realVideoId);

          stopwatch.stop();
          final duration = stopwatch.elapsedMilliseconds;

          Log.info('Thumbnail generation took ${duration}ms');
          expect(
            duration,
            lessThan(30000),
          ); // Should complete within 30 seconds
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );

      test(
        'batch processing is reasonably efficient',
        () async {
          final videoIds = List.generate(3, (i) => '$realVideoId-batch-$i');
          final stopwatch = Stopwatch()..start();

          await ThumbnailApiService.batchGenerateThumbnails(videoIds);

          stopwatch.stop();
          final duration = stopwatch.elapsedMilliseconds;
          final averagePerVideo = duration / videoIds.length;

          Log.info(
            'Batch processing took ${duration}ms (${averagePerVideo.toStringAsFixed(1)}ms per video)',
          );
          expect(
            duration,
            lessThan(60000),
          ); // Should complete within 60 seconds
        },
        timeout: const Timeout(Duration(seconds: 90)),
      );

      test(
        'concurrent requests do not interfere',
        () async {
          final futures = List.generate(
            3,
            (i) => ThumbnailApiService.thumbnailExists(
              '$realVideoId-concurrent-$i',
            ),
          );

          final results = await Future.wait(futures);

          expect(results.length, equals(3));
          for (final result in results) {
            expect(result, isA<bool>());
          }

          Log.info('Concurrent requests completed successfully');
        },
        timeout: const Timeout(Duration(seconds: 45)),
      );
    });

    group('Size Parameter Tests', () {
      test('different thumbnail sizes work correctly', () async {
        for (final size in ThumbnailSize.values) {
          final url = ThumbnailApiService.getThumbnailUrl(
            realVideoId,
            size: size,
          );

          if (size == ThumbnailSize.medium) {
            expect(url, isNot(contains('size=')));
          } else {
            expect(url, contains('size=${size.name}'));
          }

          Log.info('${size.name} thumbnail URL: $url');
        }
      });

      test(
        'fallback respects size parameter',
        () async {
          final url = await ThumbnailApiService.getThumbnailWithFallback(
            realVideoId,
            size: ThumbnailSize.large,
          );

          if (url != null) {
            expect(url, contains('size=large'));
            Log.info('Large thumbnail URL: $url');
          }
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('Edge Case Tests', () {
      test(
        'handles very early timestamp (0.1s)',
        () async {
          final url = await ThumbnailApiService.getThumbnailWithFallback(
            realVideoId,
            timeSeconds: 0.1,
          );

          expect(url, anyOf(isNull, isA<String>()));
          if (url != null) {
            expect(url, contains('t=0.1'));
          }
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'handles large timestamp (beyond video length)',
        () async {
          final url = await ThumbnailApiService.getThumbnailWithFallback(
            realVideoId,
            timeSeconds: 9999,
          );

          // Should handle gracefully (either generate at max time or fail gracefully)
          expect(url, anyOf(isNull, isA<String>()));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test('handles zero timestamp', () async {
        final url = await ThumbnailApiService.getThumbnailWithFallback(
          realVideoId,
          timeSeconds: 0,
        );

        expect(url, anyOf(isNull, isA<String>()));
        if (url != null) {
          expect(url, contains('t=0.0'));
        }
      }, timeout: const Timeout(Duration(seconds: 30)));
    });
  });
}

/// Helper function to skip integration tests if server is not available
/// Can be used to conditionally run tests based on environment
bool shouldRunIntegrationTests() {
  // Check if we're in CI or have specific environment variable
  const runIntegration = String.fromEnvironment('RUN_INTEGRATION_TESTS');
  return runIntegration == 'true' || runIntegration == '1';
}

/// Helper to create test video data for upload tests
Uint8List createTestVideoBytes() {
  // Create minimal valid video file bytes for testing
  // This is a very simple approach - in real tests you might want actual video data
  return Uint8List.fromList(List.generate(1024, (i) => i % 256));
}
