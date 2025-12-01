// ABOUTME: Tests for VideoEventCacheService extracted from VideoEventService
// ABOUTME: Validates caching logic, priority-based insertion, and memory management

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_cache_service.dart';

void main() {
  group('VideoEventCacheService', () {
    late VideoEventCacheService cacheService;

    setUp(() {
      cacheService = VideoEventCacheService();
    });

    group('Basic Operations', () {
      test('should start with empty cache', () {
        expect(cacheService.videoEvents, isEmpty);
        expect(cacheService.hasEvents, false);
        expect(cacheService.eventCount, 0);
      });

      test('should add video event to cache', () {
        final videoEvent = _createTestVideoEvent('test1');

        cacheService.addVideo(videoEvent);

        expect(cacheService.videoEvents, hasLength(1));
        expect(cacheService.videoEvents.first.id, 'test1');
        expect(cacheService.hasEvents, true);
        expect(cacheService.eventCount, 1);
      });

      test('should prevent duplicate video events', () {
        final videoEvent = _createTestVideoEvent('test1');

        cacheService.addVideo(videoEvent);
        cacheService.addVideo(videoEvent); // Try to add same video again

        expect(cacheService.videoEvents, hasLength(1));
        expect(cacheService.getDuplicateCount(), 1);
      });

      test('should get videos by author', () {
        final video1 = _createTestVideoEvent('test1', pubkey: 'author1');
        final video2 = _createTestVideoEvent('test2', pubkey: 'author2');
        final video3 = _createTestVideoEvent('test3', pubkey: 'author1');

        cacheService.addVideo(video1);
        cacheService.addVideo(video2);
        cacheService.addVideo(video3);

        final authorVideos = cacheService.getVideosByAuthor('author1');
        expect(authorVideos, hasLength(2));
        expect(authorVideos.map((v) => v.id), containsAll(['test1', 'test3']));
      });

      test('should clear cache', () {
        cacheService.addVideo(_createTestVideoEvent('test1'));
        cacheService.addVideo(_createTestVideoEvent('test2'));

        cacheService.clear();

        expect(cacheService.videoEvents, isEmpty);
        expect(cacheService.hasEvents, false);
      });
    });

    group('Priority-Based Insertion', () {
      test('should prioritize classic vines at top', () {
        final regularVideo = _createTestVideoEvent('regular1');
        final classicVine = _createTestVideoEvent(
          'classic1',
          pubkey: AppConstants.classicVinesPubkey,
        );

        cacheService.addVideo(regularVideo);
        cacheService.addVideo(classicVine);

        expect(cacheService.videoEvents.first.id, 'classic1');
        expect(cacheService.videoEvents.last.id, 'regular1');
      });

      test('should randomize classic vines order', () {
        // Add multiple classic vines and verify they're at top but in varied positions
        final classicVines = List.generate(
          5,
          (i) => _createTestVideoEvent(
            'classic$i',
            pubkey: AppConstants.classicVinesPubkey,
          ),
        );

        for (final vine in classicVines) {
          cacheService.addVideo(vine);
        }

        // All classic vines should be present
        expect(cacheService.videoEvents, hasLength(5));

        // All should have classic vine pubkey
        for (var i = 0; i < 5; i++) {
          expect(
            cacheService.videoEvents[i].pubkey,
            AppConstants.classicVinesPubkey,
          );
        }
      });

      test(
        'should place default videos after classic vines but before regular',
        () {
          final regularVideo = _createTestVideoEvent('regular1');
          final classicVine = _createTestVideoEvent(
            'classic1',
            pubkey: AppConstants.classicVinesPubkey,
          );
          final defaultVideo = _createTestVideoEvent(
            'default1',
            isDefaultContent: true,
          );

          // Add in mixed order
          cacheService.addVideo(regularVideo);
          cacheService.addVideo(defaultVideo);
          cacheService.addVideo(classicVine);

          // Should be ordered: classic, default, regular
          expect(cacheService.videoEvents[0].id, 'classic1');
          expect(cacheService.videoEvents[1].id, 'default1');
          expect(cacheService.videoEvents[2].id, 'regular1');
        },
      );

      test('should maintain timestamp order within same priority', () {
        final now = DateTime.now();
        final older = _createTestVideoEvent(
          'older',
          timestamp: now.subtract(const Duration(hours: 2)),
        );
        final newer = _createTestVideoEvent(
          'newer',
          timestamp: now.subtract(const Duration(hours: 1)),
        );

        cacheService.addVideo(older);
        cacheService.addVideo(newer);

        // Newer should come first
        expect(cacheService.videoEvents[0].id, 'newer');
        expect(cacheService.videoEvents[1].id, 'older');
      });
    });

    group('Memory Management', () {
      test('should limit cache size to prevent memory issues', () {
        // Add more than the limit
        for (var i = 0; i < 600; i++) {
          cacheService.addVideo(_createTestVideoEvent('video$i'));
        }

        // Should only keep 500 most recent
        expect(cacheService.videoEvents, hasLength(500));

        // Verify oldest videos were removed (0-99 should be gone)
        final ids = cacheService.videoEvents.map((v) => v.id).toSet();
        expect(ids.contains('video0'), false);
        expect(ids.contains('video99'), false);
        expect(ids.contains('video100'), true);
        expect(ids.contains('video599'), true);
      });

      test('should maintain priority videos when trimming', () {
        // Add a classic vine
        final classicVine = _createTestVideoEvent(
          'classic1',
          pubkey: AppConstants.classicVinesPubkey,
        );
        cacheService.addVideo(classicVine);

        // Add 500 regular videos
        for (var i = 0; i < 500; i++) {
          cacheService.addVideo(_createTestVideoEvent('video$i'));
        }

        // Classic vine should still be first
        expect(cacheService.videoEvents.first.id, 'classic1');
        expect(cacheService.videoEvents, hasLength(500));
      });
    });

    group('Default Content Handling', () {
      test('should check if video exists in cache', () {
        final video = _createTestVideoEvent('test1');

        expect(cacheService.hasVideo('test1'), false);

        cacheService.addVideo(video);

        expect(cacheService.hasVideo('test1'), true);
      });

      test('should add default videos when cache is empty', () {
        final defaultVideos = [
          _createTestVideoEvent('default1', isDefaultContent: true),
          _createTestVideoEvent('default2', isDefaultContent: true),
        ];

        cacheService.addDefaultVideosIfNeeded(defaultVideos);

        expect(cacheService.videoEvents, hasLength(2));
        expect(
          cacheService.videoEvents.map((v) => v.id),
          containsAll(['default1', 'default2']),
        );
      });

      test('should ensure default video is first in non-empty cache', () {
        // Add regular videos first
        cacheService.addVideo(_createTestVideoEvent('regular1'));
        cacheService.addVideo(_createTestVideoEvent('regular2'));

        final defaultVideos = [
          _createTestVideoEvent('default1', isDefaultContent: true),
        ];

        cacheService.addDefaultVideosIfNeeded(defaultVideos);

        // Default should be inserted at beginning after any classic vines
        expect(cacheService.videoEvents, hasLength(3));
        expect(cacheService.videoEvents.first.id, 'default1');
      });
    });
  });
}

// Helper function to create test video events
VideoEvent _createTestVideoEvent(
  String id, {
  String pubkey = 'testpubkey',
  DateTime? timestamp,
  bool isDefaultContent = false,
}) {
  timestamp ??= DateTime.now();

  // Create rawTags map
  final rawTags = <String, String>{
    'title': 'Test Video $id',
    'url': 'https://example.com/video/$id.mp4',
  };

  if (isDefaultContent) {
    rawTags['default'] = 'true';
  }

  // Create VideoEvent directly with constructor
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Test video content',
    timestamp: timestamp,
    title: 'Test Video $id',
    videoUrl: 'https://example.com/video/$id.mp4',
    rawTags: rawTags,
  );
}
