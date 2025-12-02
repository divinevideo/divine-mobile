// ABOUTME: TDD tests for VideoPrefetchMixin
// ABOUTME: Verifies video prefetching behavior in PageView-based feeds

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_cache_manager.dart';

import 'video_prefetch_mixin_test.mocks.dart';

// Generate mocks
@GenerateMocks([VideoCacheManager])
void main() {
  late MockVideoCacheManager mockCache;

  setUp(() {
    mockCache = MockVideoCacheManager();
    when(mockCache.preCache(any, any)).thenAnswer((_) async {});
  });

  group('VideoPrefetchMixin', () {
    test('SPEC: should prefetch videos around current index', () {
      // Given a list of videos and current index
      final videos = _createMockVideos(10);
      const currentIndex = 5;

      // When checkForPrefetch is called
      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: currentIndex, videos: videos);

      // Then it should call preCache with correct videos
      final captured = verify(
        mockCache.preCache(captureAny, captureAny),
      ).captured;
      final cachedIds = captured[1] as List<String>;

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
        mockCache.preCache(captureAny, captureAny),
      ).captured;
      final cachedIds = captured[1] as List<String>;

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
        mockCache.preCache(captureAny, captureAny),
      ).captured;
      final cachedIds = captured[1] as List<String>;

      // Should only prefetch before (2, 3), no videos after
      expect(cachedIds, containsAll(['video-2', 'video-3']));
      expect(cachedIds.length, equals(2));
    });

    test('SPEC: should skip prefetch for empty video list', () {
      final mixin = TestVideoPrefetchMixin(mockCache);
      mixin.checkForPrefetch(currentIndex: 0, videos: []);

      verifyNever(mockCache.preCache(any, any));
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
        mockCache.preCache(captureAny, captureAny),
      ).captured;
      final cachedIds = captured[1] as List<String>;

      // Should skip video-2 (no URL)
      expect(cachedIds, isNot(contains('video-2')));
    });

    test('SPEC: should throttle rapid prefetch calls', () {
      final videos = _createMockVideos(10);

      final mixin = TestVideoPrefetchMixin(mockCache);

      // First call should work
      mixin.checkForPrefetch(currentIndex: 3, videos: videos);
      verify(mockCache.preCache(any, any)).called(1);

      reset(mockCache);
      when(mockCache.preCache(any, any)).thenAnswer((_) async {});

      // Second call immediately after should be throttled
      mixin.checkForPrefetch(currentIndex: 4, videos: videos);
      verifyNever(mockCache.preCache(any, any));
    });

    test('SPEC: should allow prefetch after throttle period', () async {
      final videos = _createMockVideos(10);

      final mixin = TestVideoPrefetchMixin(mockCache);

      // First call
      mixin.checkForPrefetch(currentIndex: 3, videos: videos);
      verify(mockCache.preCache(any, any)).called(1);

      reset(mockCache);
      when(mockCache.preCache(any, any)).thenAnswer((_) async {});

      // Wait for throttle period (default 1 second in test)
      await Future.delayed(const Duration(milliseconds: 1100));

      // Second call should work now
      mixin.checkForPrefetch(currentIndex: 4, videos: videos);
      verify(mockCache.preCache(any, any)).called(1);
    });

    test('SPEC: should handle prefetch errors gracefully', () {
      final videos = _createMockVideos(5);

      when(mockCache.preCache(any, any)).thenThrow(Exception('Network error'));

      final mixin = TestVideoPrefetchMixin(mockCache);

      // Should not throw
      expect(
        () => mixin.checkForPrefetch(currentIndex: 2, videos: videos),
        returnsNormally,
      );
    });

    test('SPEC: resetPrefetch should clear throttle', () {
      final videos = _createMockVideos(10);

      final mixin = TestVideoPrefetchMixin(mockCache);

      // First call
      mixin.checkForPrefetch(currentIndex: 3, videos: videos);
      verify(mockCache.preCache(any, any)).called(1);

      reset(mockCache);
      when(mockCache.preCache(any, any)).thenAnswer((_) async {});

      // Reset throttle
      mixin.resetPrefetch();

      // Next call should work immediately (not throttled)
      mixin.checkForPrefetch(currentIndex: 4, videos: videos);
      verify(mockCache.preCache(any, any)).called(1);
    });
  });
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
VideoEvent _createVideo(String id, {required bool hasUrl}) {
  final timestamp = DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'pubkey',
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Video content',
    timestamp: timestamp,
    videoUrl: hasUrl ? 'https://example.com/$id.mp4' : null,
    title: 'Test Video',
  );
}

/// Test implementation of VideoPrefetchMixin
class TestVideoPrefetchMixin with VideoPrefetchMixin {
  TestVideoPrefetchMixin(this._cache);

  final VideoCacheManager _cache;

  @override
  VideoCacheManager get videoCacheManager => _cache;

  @override
  int get prefetchThrottleSeconds => 1; // Shorter for testing
}
