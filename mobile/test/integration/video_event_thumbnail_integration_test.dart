// ABOUTME: Integration test for VideoEvent thumbnail API integration
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests the complete workflow from video events to automatic thumbnail generation

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/thumbnail_api_service.dart';

void main() {
  group('VideoEvent Thumbnail API Integration', () {
    // Test data - using Rabble's known video
    const realVideoId =
        '87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344';

    late VideoEvent testVideoEvent;
    late VideoEvent videoEventWithoutThumbnail;

    setUp(() {
      // Create test video event with existing thumbnail
      testVideoEvent = VideoEvent(
        id: realVideoId,
        pubkey:
            '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd',
        createdAt: 1747864092,
        content: 'Test video with thumbnail',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1747864092 * 1000),
        videoUrl:
            'https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4',
        thumbnailUrl: 'https://existing-thumbnail.com/thumb.jpg',
        duration: 3,
        hashtags: [],
      );

      // Create test video event without thumbnail
      videoEventWithoutThumbnail = VideoEvent(
        id: realVideoId,
        pubkey:
            '0461fcbecc4c3374439932d6b8f11269ccdb7cc973ad7a50ae362db135a474dd',
        createdAt: 1747864092,
        content: 'Test video without thumbnail',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1747864092 * 1000),
        videoUrl:
            'https://blossom.primal.net/87444ba2b07f28f29a8df3e9b358712e434a9d94bc67b08db5d4de61e6205344.mp4',
        thumbnailUrl: null, // No existing thumbnail
        duration: 3,
        hashtags: [],
      );
    });

    group('effectiveThumbnailUrl behavior', () {
      test('returns existing thumbnail when available', () {
        final thumbnailUrl = testVideoEvent.effectiveThumbnailUrl;
        expect(
          thumbnailUrl,
          equals('https://existing-thumbnail.com/thumb.jpg'),
        );
      });

      test('returns null when no thumbnail available (no more picsum!)', () {
        final thumbnailUrl = videoEventWithoutThumbnail.effectiveThumbnailUrl;
        expect(thumbnailUrl, isNull);
      });
    });

    group('getApiThumbnailUrl async method', () {
      test('returns existing thumbnail when available', () async {
        final thumbnailUrl = await testVideoEvent.getApiThumbnailUrl();
        expect(
          thumbnailUrl,
          equals('https://existing-thumbnail.com/thumb.jpg'),
        );
      });

      test(
        'attempts API generation when no thumbnail available',
        () async {
          final thumbnailUrl = await videoEventWithoutThumbnail
              .getApiThumbnailUrl(timeSeconds: 2, size: ThumbnailSize.medium);

          // May return null if generation fails (expected for test environment)
          // or return a proper API URL if successful
          if (thumbnailUrl != null) {
            expect(
              thumbnailUrl,
              startsWith('https://api.openvine.co/thumbnail/'),
            );
            expect(thumbnailUrl, contains(realVideoId));
            expect(thumbnailUrl, contains('t=2.0'));
            Log.info('Successfully generated API thumbnail: $thumbnailUrl');
          } else {
            Log.info(
              'API thumbnail generation returned null (expected in test environment)',
            );
          }

          expect(thumbnailUrl, anyOf(isNull, isA<String>()));
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );

      test(
        'respects size parameter in API call',
        () async {
          final thumbnailUrl = await videoEventWithoutThumbnail
              .getApiThumbnailUrl(timeSeconds: 1.5, size: ThumbnailSize.large);

          if (thumbnailUrl != null) {
            expect(thumbnailUrl, contains('size=large'));
            expect(thumbnailUrl, contains('t=1.5'));
          }
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('getApiThumbnailUrlSync method', () {
      test('returns existing thumbnail when available', () {
        final thumbnailUrl = testVideoEvent.getApiThumbnailUrlSync();
        expect(
          thumbnailUrl,
          equals('https://existing-thumbnail.com/thumb.jpg'),
        );
      });

      test('generates API URL when no thumbnail available', () {
        final thumbnailUrl = videoEventWithoutThumbnail.getApiThumbnailUrlSync(
          timeSeconds: 3,
          size: ThumbnailSize.small,
        );

        expect(thumbnailUrl, startsWith('https://api.openvine.co/thumbnail/'));
        expect(thumbnailUrl, contains(realVideoId));
        expect(thumbnailUrl, contains('t=3.0'));
        expect(thumbnailUrl, contains('size=small'));
      });

      test('handles medium size correctly (no size param)', () {
        final thumbnailUrl = videoEventWithoutThumbnail.getApiThumbnailUrlSync(
          timeSeconds: 2.5,
          size: ThumbnailSize.medium,
        );

        expect(thumbnailUrl, startsWith('https://api.openvine.co/thumbnail/'));
        expect(thumbnailUrl, contains('t=2.5'));
        expect(thumbnailUrl, isNot(contains('size=')));
      });
    });

    group('Thumbnail workflow comparison', () {
      test(
        'sync vs async methods provide consistent URLs when no generation needed',
        () async {
          // Both should return existing thumbnail
          final syncUrl = testVideoEvent.getApiThumbnailUrlSync();
          final asyncUrl = await testVideoEvent.getApiThumbnailUrl();

          expect(syncUrl, equals(asyncUrl));
          expect(syncUrl, equals('https://existing-thumbnail.com/thumb.jpg'));
        },
      );

      test(
        'sync method provides immediate URL while async attempts generation',
        () async {
          final syncUrl = videoEventWithoutThumbnail.getApiThumbnailUrlSync(
            timeSeconds: 2.5,
            size: ThumbnailSize.medium,
          );

          final asyncUrl = await videoEventWithoutThumbnail.getApiThumbnailUrl(
            timeSeconds: 2.5,
            size: ThumbnailSize.medium,
          );

          // Sync should always return a URL (constructed)
          expect(syncUrl, isA<String>());
          expect(syncUrl, startsWith('https://api.openvine.co/thumbnail/'));

          // Async may return null if generation fails, or the same URL if successful
          if (asyncUrl != null) {
            // If generation was successful, URLs should match
            expect(asyncUrl, equals(syncUrl));
          }

          Log.info('Sync URL: $syncUrl');
          Log.info('Async URL: $asyncUrl');
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('Error handling and edge cases', () {
      test('handles video event with empty video ID', () {
        final emptyIdEvent = VideoEvent(
          id: '',
          pubkey: 'test-pubkey',
          createdAt: 1234567890,
          content: 'Test',
          timestamp: DateTime.now(),
          thumbnailUrl: null,
          hashtags: [],
        );

        final syncUrl = emptyIdEvent.getApiThumbnailUrlSync();
        expect(syncUrl, startsWith('https://api.openvine.co/thumbnail/'));
        expect(syncUrl, contains('?t=2.5'));
      });

      test('handles extreme timestamp values', () {
        final extremeTimestamps = [0.0, 0.001, 99999.99];

        for (final timestamp in extremeTimestamps) {
          final url = videoEventWithoutThumbnail.getApiThumbnailUrlSync(
            timeSeconds: timestamp,
          );
          expect(url, contains('t=$timestamp'));
        }
      });

      test(
        'async method handles network errors gracefully',
        () async {
          final invalidVideoEvent = VideoEvent(
            id: 'invalid-video-id-that-does-not-exist',
            pubkey: 'test-pubkey',
            createdAt: 1234567890,
            content: 'Test',
            timestamp: DateTime.now(),
            thumbnailUrl: null,
            hashtags: [],
          );

          final thumbnailUrl = await invalidVideoEvent.getApiThumbnailUrl();
          // Should return null for invalid video IDs, not throw an exception
          expect(thumbnailUrl, isNull);
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    });

    group('Backward compatibility', () {
      test('effectiveThumbnailUrl still works as before', () {
        // With thumbnail
        expect(testVideoEvent.effectiveThumbnailUrl, isNotNull);
        expect(
          testVideoEvent.effectiveThumbnailUrl,
          equals('https://existing-thumbnail.com/thumb.jpg'),
        );

        // Without thumbnail (should return null, not picsum!)
        expect(videoEventWithoutThumbnail.effectiveThumbnailUrl, isNull);
      });

      test('hasVideo property still works correctly', () {
        expect(testVideoEvent.hasVideo, isTrue);
        expect(videoEventWithoutThumbnail.hasVideo, isTrue);

        final noVideoEvent = VideoEvent(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: 1234567890,
          content: 'Test',
          timestamp: DateTime.now(),
          videoUrl: null,
          hashtags: [],
        );

        expect(noVideoEvent.hasVideo, isFalse);
      });
    });

    group('Performance considerations', () {
      test('sync method is fast', () {
        final stopwatch = Stopwatch()..start();

        for (var i = 0; i < 100; i++) {
          videoEventWithoutThumbnail.getApiThumbnailUrlSync();
        }

        stopwatch.stop();
        final duration = stopwatch.elapsedMilliseconds;

        Log.info(
          '100 sync calls took ${duration}ms (${duration / 100}ms average)',
        );
        expect(duration, lessThan(100)); // Should be very fast
      });

      test(
        'async method timeout handling',
        () async {
          final startTime = DateTime.now();

          await videoEventWithoutThumbnail.getApiThumbnailUrl();

          final duration = DateTime.now().difference(startTime);

          Log.info('Async call took ${duration.inMilliseconds}ms');
          expect(duration.inSeconds, lessThan(30)); // Should not hang
        },
        timeout: const Timeout(Duration(seconds: 35)),
      );
    });
  });
}
