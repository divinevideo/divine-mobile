// ABOUTME: TDD tests for VideoPrefetchMixin
// ABOUTME: Verifies video prefetching behavior in PageView-based feeds

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:unified_logger/unified_logger.dart';

class MockMediaCacheManager extends Mock implements MediaCacheManager {}

void main() {
  late MockMediaCacheManager mockCache;

  setUp(() {
    mockCache = MockMediaCacheManager();
    when(
      () => mockCache.preCacheFiles(
        any(),
        batchSize: any(named: 'batchSize'),
        authHeadersProvider: any(named: 'authHeadersProvider'),
      ),
    ).thenAnswer((_) async {});
  });

  group('VideoPrefetchMixin', () {
    test('SPEC: should prefetch videos around current index', () {
      // Given a list of videos and current index
      final videos = _createMockVideos(10);
      const currentIndex = 5;

      // When checkForPrefetch is called
      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: currentIndex, videos: videos);

      // Then it should call preCacheFiles with correct videos
      final captured = verify(
        () => mockCache.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final cachedIds = items.map((item) => item.key).toList();

      // Should prefetch videos 3, 4, 6, 7, 8 (before=2, after=3)
      expect(
        cachedIds,
        containsAll(['video-3', 'video-4', 'video-6', 'video-7', 'video-8']),
      );
      expect(cachedIds, isNot(contains('video-5'))); // Skip current
    });

    test('SPEC: should handle index at start (no videos before)', () {
      final videos = _createMockVideos(10);
      const currentIndex = 0;

      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: currentIndex, videos: videos);

      final captured = verify(
        () => mockCache.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final cachedIds = items.map((item) => item.key).toList();

      // Should only prefetch after (1, 2, 3), no videos before
      expect(cachedIds, containsAll(['video-1', 'video-2', 'video-3']));
      expect(cachedIds.length, equals(3));
    });

    test('SPEC: should handle index at end (no videos after)', () {
      final videos = _createMockVideos(5);
      const currentIndex = 4;

      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: currentIndex, videos: videos);

      final captured = verify(
        () => mockCache.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final cachedIds = items.map((item) => item.key).toList();

      // Should only prefetch before (2, 3), no videos after
      expect(cachedIds, containsAll(['video-2', 'video-3']));
      expect(cachedIds.length, equals(2));
    });

    test('SPEC: should skip prefetch for empty video list', () {
      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: 0, videos: []);

      verifyNever(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      );
    });

    test('SPEC: should skip videos without URLs', () {
      final videos = [
        _createVideo('video-1', hasUrl: true),
        _createVideo('video-2', hasUrl: false), // No URL
        _createVideo('video-3', hasUrl: true),
      ];

      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: 1, videos: videos);

      final captured = verify(
        () => mockCache.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final cachedIds = items.map((item) => item.key).toList();

      // Should skip video-2 (no URL)
      expect(cachedIds, isNot(contains('video-2')));
    });

    test('SPEC: should include Divine videos in prefetch (MP4 cacheable)', () {
      final videos = [
        _createVideo('video-1', hasUrl: true),
        _createVideo(
          'video-2',
          hasUrl: true,
          videoUrl:
              'https://media.divine.video/'
              'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d',
        ),
        _createVideo('video-3', hasUrl: true),
      ];

      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: 0, videos: videos);

      final captured = verify(
        () => mockCache.preCacheFiles(
          captureAny(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).captured;
      final items = captured[0] as List<({String url, String key})>;
      final cachedIds = items.map((item) => item.key).toList();

      // Divine videos now use progressive MP4 which is single-file cacheable
      expect(cachedIds, contains('video-2'));
      expect(cachedIds, contains('video-3'));
    });

    test('SPEC: should throttle rapid prefetch calls', () {
      final videos = _createMockVideos(10);

      final mixin = TestVideoPrefetchMixin(mockCache);

      // First call should work
      mixin.checkForPrefetch(currentIndex: 3, videos: videos);
      verify(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).called(1);

      reset(mockCache);
      when(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async {});

      // Second call immediately after should be throttled
      mixin.checkForPrefetch(currentIndex: 4, videos: videos);
      verifyNever(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      );
    });

    test('SPEC: should allow prefetch after throttle period', () {
      fakeAsync((async) {
        final videos = _createMockVideos(10);

        final mixin = TestVideoPrefetchMixin(mockCache);

        // First call
        mixin.checkForPrefetch(currentIndex: 3, videos: videos);
        verify(
          () => mockCache.preCacheFiles(
            any(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).called(1);

        reset(mockCache);
        when(
          () => mockCache.preCacheFiles(
            any(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).thenAnswer((_) async {});

        // Wait for throttle period (default 1 second in test)
        async.elapse(const Duration(milliseconds: 1100));

        // Second call should work now
        mixin.checkForPrefetch(currentIndex: 4, videos: videos);
        verify(
          () => mockCache.preCacheFiles(
            any(),
            batchSize: any(named: 'batchSize'),
            authHeadersProvider: any(named: 'authHeadersProvider'),
          ),
        ).called(1);
      });
    });

    group('prefetch failures', () {
      late LogCaptureService logCapture;

      setUp(() async {
        logCapture = LogCaptureService();
        await logCapture.clearAllLogs();
      });

      tearDown(() async {
        await logCapture.clearAllLogs();
      });

      test(
        'SPEC: should log and contain asynchronous prefetch errors',
        () async {
          final videos = _createMockVideos(5);

          when(
            () => mockCache.preCacheFiles(
              any(),
              batchSize: any(named: 'batchSize'),
              authHeadersProvider: any(named: 'authHeadersProvider'),
            ),
          ).thenAnswer((_) async => throw Exception('Network error'));

          final mixin = TestVideoPrefetchMixin(mockCache);

          final unhandledErrors = await _unhandledErrorsWhile(() async {
            mixin.checkForPrefetch(currentIndex: 2, videos: videos);
          });

          expect(unhandledErrors, isEmpty);
          verify(
            () => mockCache.preCacheFiles(
              any(),
              batchSize: any(named: 'batchSize'),
              authHeadersProvider: any(named: 'authHeadersProvider'),
            ),
          ).called(1);
          _expectPrefetchFailureLogged(
            logCapture,
            'Failed to prefetch videos: Exception: Network error',
          );
        },
      );

      test(
        'SPEC: should log and contain synchronous prefetch errors',
        () async {
          final videos = _createMockVideos(10);

          when(
            () => mockCache.preCacheFiles(
              any(),
              batchSize: any(named: 'batchSize'),
              authHeadersProvider: any(named: 'authHeadersProvider'),
            ),
          ).thenThrow(Exception('Synchronous cache error'));

          final mixin = TestVideoPrefetchMixin(mockCache);

          final unhandledErrors = await _unhandledErrorsWhile(() async {
            mixin.checkForPrefetch(currentIndex: 2, videos: videos);
          });

          expect(unhandledErrors, isEmpty);
          verify(
            () => mockCache.preCacheFiles(
              any(),
              batchSize: any(named: 'batchSize'),
              authHeadersProvider: any(named: 'authHeadersProvider'),
            ),
          ).called(1);
          _expectPrefetchFailureLogged(
            logCapture,
            'Failed to prefetch videos: Exception: Synchronous cache error',
          );
        },
      );
    });

    test('SPEC: resetPrefetch should clear throttle', () {
      final videos = _createMockVideos(10);

      final mixin = TestVideoPrefetchMixin(mockCache);

      // First call
      mixin.checkForPrefetch(currentIndex: 3, videos: videos);
      verify(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).called(1);

      reset(mockCache);
      when(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).thenAnswer((_) async {});

      // Reset throttle
      mixin.resetPrefetch();

      // Next call should work immediately (not throttled)
      mixin.checkForPrefetch(currentIndex: 4, videos: videos);
      verify(
        () => mockCache.preCacheFiles(
          any(),
          batchSize: any(named: 'batchSize'),
          authHeadersProvider: any(named: 'authHeadersProvider'),
        ),
      ).called(1);
    });
  });
}

/// Runs [body] in a guarded zone and returns every error that escaped it,
/// including one thrown by [body] itself.
///
/// Errors escaping `runDetached` are reported to the zone current when the
/// future was created, so the call under test has to run inside [body]. A
/// throw from [body] is recorded rather than rethrown because the guarded
/// zone would swallow it and leave this future pending until the test times
/// out.
Future<List<Object>> _unhandledErrorsWhile(
  Future<void> Function() body,
) async {
  final errors = <Object>[];
  await runZonedGuarded(() async {
    try {
      await body();
      await pumpEventQueue();
    } on Object catch (error) {
      errors.add(error);
    }
  }, (error, _) => errors.add(error));
  return errors;
}

/// Asserts exactly one prefetch failure was logged with [message].
void _expectPrefetchFailureLogged(
  LogCaptureService logCapture,
  String message,
) {
  final failures = logCapture.getRecentLogs().where(
    (entry) =>
        entry.name == 'VideoPrefetchMixin' && entry.level == LogLevel.error,
  );
  expect(failures, hasLength(1));
  expect(failures.single.category, LogCategory.video);
  expect(failures.single.message, message);
}

/// Helper: Create mock video events
List<VideoEvent> _createMockVideos(int count) {
  final now = DateTime.now();
  return List.generate(count, (i) {
    final timestamp = now.subtract(Duration(days: i));
    return VideoEvent(
      id: 'video-$i',
      pubkey: 'pubkey-$i',
      createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
      content: 'Video $i',
      timestamp: timestamp,
      videoUrl: 'https://example.com/video-$i.mp4',
      title: 'Test Video $i',
    );
  });
}

/// Helper: Create single video with optional URL
VideoEvent _createVideo(String id, {required bool hasUrl, String? videoUrl}) {
  final timestamp = DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'pubkey',
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Video content',
    timestamp: timestamp,
    videoUrl: hasUrl ? (videoUrl ?? 'https://example.com/$id.mp4') : null,
    title: 'Test Video',
  );
}

/// Test implementation of VideoPrefetchMixin
class TestVideoPrefetchMixin with VideoPrefetchMixin {
  TestVideoPrefetchMixin(this._cache);

  final MediaCacheManager _cache;

  @override
  MediaCacheManager get videoCacheManager => _cache;

  @override
  int get prefetchThrottleSeconds => 1; // Shorter for testing
}
