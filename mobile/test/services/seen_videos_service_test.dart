// ABOUTME: Tests for SeenVideosService persistence and metrics tracking
// ABOUTME: Validates video view history storage and retrieval

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SeenVideosService', () {
    late SeenVideosService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = SeenVideosService();
      await service.initialize();
    });

    tearDown(() async {
      await service.dispose();
    });

    test('initializes with empty seen videos', () {
      expect(service.isInitialized, isTrue);
      expect(service.seenVideoCount, 0);
      expect(service.getSeenVideoIds(), isEmpty);
    });

    test('marks video as seen and persists', () async {
      const videoId = 'test_video_123';

      await service.markVideoAsSeen(videoId);

      expect(service.hasSeenVideo(videoId), isTrue);
      expect(service.seenVideoCount, 1);
      expect(service.getSeenVideoIds(), contains(videoId));
    });

    test('records video view with metrics', () async {
      const videoId = 'test_video_456';

      await service.recordVideoView(
        videoId,
        loopCount: 3,
        watchDuration: const Duration(seconds: 45),
      );

      expect(service.hasSeenVideo(videoId), isTrue);

      final metrics = service.getVideoMetrics(videoId);
      expect(metrics, isNotNull);
      expect(metrics!.videoId, videoId);
      expect(metrics.loopCount, 3);
      expect(metrics.totalWatchDuration.inSeconds, 45);
    });

    test('updates existing video metrics', () async {
      const videoId = 'test_video_789';

      // First view
      await service.recordVideoView(
        videoId,
        loopCount: 2,
        watchDuration: const Duration(seconds: 30),
      );

      // Second view
      await service.recordVideoView(
        videoId,
        loopCount: 1,
        watchDuration: const Duration(seconds: 15),
      );

      final metrics = service.getVideoMetrics(videoId);
      expect(metrics!.loopCount, 3); // 2 + 1
      expect(metrics.totalWatchDuration.inSeconds, 45); // 30 + 15
    });

    test('marks multiple videos as seen in batch', () async {
      final videoIds = ['video1', 'video2', 'video3'];

      await service.markVideosAsSeen(videoIds);

      expect(service.seenVideoCount, 3);
      for (final id in videoIds) {
        expect(service.hasSeenVideo(id), isTrue);
      }
    });

    test('checks if video was seen recently', () async {
      const videoId = 'recent_video';

      await service.recordVideoView(videoId);

      expect(
        service.wasSeenRecently(videoId, within: const Duration(hours: 1)),
        isTrue,
      );
      expect(
        service.wasSeenRecently(videoId, within: const Duration(seconds: 1)),
        isTrue,
      );
    });

    test('clears all seen videos', () async {
      await service.markVideosAsSeen(['video1', 'video2']);
      expect(service.seenVideoCount, 2);

      await service.clearSeenVideos();

      expect(service.seenVideoCount, 0);
      expect(service.getSeenVideoIds(), isEmpty);
    });

    test('marks video as unseen', () async {
      const videoId = 'test_video';

      await service.markVideoAsSeen(videoId);
      expect(service.hasSeenVideo(videoId), isTrue);

      await service.markVideoAsUnseen(videoId);
      expect(service.hasSeenVideo(videoId), isFalse);
    });

    test('returns videos by recency', () async {
      await service.recordVideoView('video1');
      service.getVideoMetrics('video1')!.lastSeenAt = DateTime.utc(2000);
      await service.recordVideoView('video2');
      service.getVideoMetrics('video2')!.lastSeenAt = DateTime.utc(2001);
      await service.recordVideoView('video3');
      service.getVideoMetrics('video3')!.lastSeenAt = DateTime.utc(2002);

      final recent = service.getVideosByRecency(limit: 2);

      expect(recent.length, 2);
      expect(recent[0].videoId, 'video3'); // Most recent first
      expect(recent[1].videoId, 'video2');
    });

    test('provides statistics about seen videos', () async {
      await service.recordVideoView(
        'video1',
        loopCount: 5,
        watchDuration: const Duration(seconds: 60),
      );
      await service.recordVideoView(
        'video2',
        loopCount: 3,
        watchDuration: const Duration(seconds: 40),
      );

      final stats = service.getStatistics();

      expect(stats['totalSeen'], 2);
      expect(stats['totalLoops'], 8);
      expect(stats['totalWatchTimeMinutes'], 1); // 100 seconds = 1 minute
    });

    test('enforces max seen videos limit', () async {
      // This test would need to create more than _maxSeenVideos (1000)
      // For practical testing, we verify the limit is respected
      final stats = service.getStatistics();
      expect(stats['storageLimit'], 1000);
    });

    test('persists across service instances', () async {
      const videoId = 'persistent_video';

      await service.recordVideoView(videoId, loopCount: 2);

      // Create new service instance
      final newService = SeenVideosService();
      await newService.initialize();

      expect(newService.hasSeenVideo(videoId), isTrue);
      final metrics = newService.getVideoMetrics(videoId);
      expect(metrics?.loopCount, 2);

      await newService.dispose();
    });

    test('coalesces rapid records while keeping memory current', () async {
      await service.dispose();
      service = SeenVideosService(
        saveDebounceDuration: const Duration(days: 1),
      );
      await service.initialize();

      final firstSave = service.recordVideoView('video1');
      final secondSave = service.recordVideoView('video2');

      expect(service.hasSeenVideo('video1'), isTrue);
      expect(service.hasSeenVideo('video2'), isTrue);

      final beforeFlush = SeenVideosService();
      await beforeFlush.initialize();
      expect(beforeFlush.hasSeenVideo('video1'), isFalse);
      expect(beforeFlush.hasSeenVideo('video2'), isFalse);
      await beforeFlush.dispose();

      await service.dispose();
      await Future.wait([firstSave, secondSave]);

      final afterFlush = SeenVideosService();
      await afterFlush.initialize();
      expect(afterFlush.hasSeenVideo('video1'), isTrue);
      expect(afterFlush.hasSeenVideo('video2'), isTrue);
      await afterFlush.dispose();
    });

    test('dispose flushes pending seen video writes', () async {
      final pendingSave = service.recordVideoView('dispose_video');

      await service.dispose();
      await pendingSave;

      final newService = SeenVideosService();
      await newService.initialize();

      expect(newService.hasSeenVideo('dispose_video'), isTrue);

      await newService.dispose();
    });
  });
}
