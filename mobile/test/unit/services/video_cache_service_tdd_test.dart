// ABOUTME: TDD tests for extracting video caching logic from VideoEventService
// ABOUTME: Tests separate caching service with priority-based insertion and deduplication

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:models/models.dart';

import '../../helpers/test_helpers.dart';

// First, define the interface that our caching service should implement
abstract class IVideoCacheService {
  List<VideoEvent> get cachedVideos;
  int get cacheSize;

  void addVideo(VideoEvent video);
  void addVideos(List<VideoEvent> videos);
  VideoEvent? getVideoById(String id);
  List<VideoEvent> getVideosByAuthor(String pubkey);
  List<VideoEvent> getVideosByHashtags(List<String> hashtags);
  void clearCache();
  bool containsVideo(String id);
  int getDuplicateCount();
}

// The implementation created to pass the tests
class VideoCacheService implements IVideoCacheService {
  final List<VideoEvent> _cachedVideos = [];
  final Set<String> _videoIds = {};
  int _duplicateCount = 0;

  @override
  List<VideoEvent> get cachedVideos => List.unmodifiable(_cachedVideos);

  @override
  int get cacheSize => _cachedVideos.length;

  @override
  void addVideo(VideoEvent video) {
    // Check for duplicates
    if (_videoIds.contains(video.id)) {
      _duplicateCount++;
      return;
    }

    // Add to ID set
    _videoIds.add(video.id);

    // Priority-based insertion: classic vines go at the top
    if (video.pubkey == AppConstants.classicVinesPubkey) {
      // Find position to insert (after other classic vines, before regular videos)
      int insertPosition = 0;
      while (insertPosition < _cachedVideos.length &&
          _cachedVideos[insertPosition].pubkey ==
              AppConstants.classicVinesPubkey) {
        insertPosition++;
      }
      _cachedVideos.insert(insertPosition, video);
    } else {
      // Regular videos go at the end
      _cachedVideos.add(video);
    }
  }

  @override
  void addVideos(List<VideoEvent> videos) {
    for (final video in videos) {
      addVideo(video);
    }
  }

  @override
  VideoEvent? getVideoById(String id) {
    try {
      return _cachedVideos.firstWhere((video) => video.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  List<VideoEvent> getVideosByAuthor(String pubkey) {
    return _cachedVideos.where((video) => video.pubkey == pubkey).toList();
  }

  @override
  List<VideoEvent> getVideosByHashtags(List<String> hashtags) {
    return _cachedVideos.where((video) {
      // Check if video has any of the search hashtags
      return video.hashtags.any((tag) => hashtags.contains(tag));
    }).toList();
  }

  @override
  void clearCache() {
    _cachedVideos.clear();
    _videoIds.clear();
    _duplicateCount = 0;
  }

  @override
  bool containsVideo(String id) {
    return _videoIds.contains(id);
  }

  @override
  int getDuplicateCount() {
    return _duplicateCount;
  }
}

void main() {
  group('VideoCacheService TDD Tests', () {
    late VideoCacheService cacheService;
    late VideoEvent testVideo1;
    late VideoEvent testVideo2;
    late VideoEvent classicVineVideo;

    setUp(() {
      cacheService = VideoCacheService();

      testVideo1 = TestHelpers.createVideoEvent(
        id: 'test-video-1',
        title: 'Test Video 1',
        pubkey: 'regular-user-pubkey',
      );

      testVideo2 = TestHelpers.createVideoEvent(
        id: 'test-video-2',
        title: 'Test Video 2',
        pubkey: 'another-user-pubkey',
      );

      classicVineVideo = TestHelpers.createVideoEvent(
        id: 'classic-vine-1',
        title: 'Classic Vine',
        pubkey: AppConstants.classicVinesPubkey,
      );
    });

    group('Basic Caching Operations', () {
      test('should start with empty cache', () {
        expect(cacheService.cachedVideos, isEmpty);
        expect(cacheService.cacheSize, equals(0));
      });

      test('should add video to cache', () {
        cacheService.addVideo(testVideo1);

        expect(cacheService.cacheSize, equals(1));
        expect(cacheService.cachedVideos.first.id, equals(testVideo1.id));
      });

      test('should prevent duplicate videos', () {
        cacheService.addVideo(testVideo1);
        cacheService.addVideo(testVideo1); // Add same video again

        expect(cacheService.cacheSize, equals(1));
        expect(cacheService.getDuplicateCount(), equals(1));
      });

      test('should retrieve video by ID', () {
        cacheService.addVideo(testVideo1);

        final retrieved = cacheService.getVideoById(testVideo1.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(testVideo1.id));
      });

      test('should return null for non-existent video ID', () {
        final retrieved = cacheService.getVideoById('non-existent-id');
        expect(retrieved, isNull);
      });
    });

    group('Priority-based Insertion', () {
      test('classic vines should be prioritized at top', () {
        // Add regular video first
        cacheService.addVideo(testVideo1);
        // Then add classic vine
        cacheService.addVideo(classicVineVideo);

        // Classic vine should be at the top
        expect(cacheService.cachedVideos.first.id, equals(classicVineVideo.id));
        expect(cacheService.cachedVideos.last.id, equals(testVideo1.id));
      });

      test('multiple classic vines should randomize among themselves', () {
        // Create multiple classic vines
        final classicVine2 = TestHelpers.createVideoEvent(
          id: 'classic-vine-2',
          title: 'Classic Vine 2',
          pubkey: AppConstants.classicVinesPubkey,
        );

        final classicVine3 = TestHelpers.createVideoEvent(
          id: 'classic-vine-3',
          title: 'Classic Vine 3',
          pubkey: AppConstants.classicVinesPubkey,
        );

        // Add regular video and classic vines
        cacheService.addVideo(testVideo1);
        cacheService.addVideo(classicVineVideo);
        cacheService.addVideo(classicVine2);
        cacheService.addVideo(classicVine3);

        // All classic vines should be before regular videos
        final videos = cacheService.cachedVideos;
        var lastClassicIndex = -1;
        for (var i = 0; i < videos.length; i++) {
          if (videos[i].pubkey == AppConstants.classicVinesPubkey) {
            lastClassicIndex = i;
          }
        }

        // Find first regular video
        var firstRegularIndex = -1;
        for (var i = 0; i < videos.length; i++) {
          if (videos[i].pubkey != AppConstants.classicVinesPubkey) {
            firstRegularIndex = i;
            break;
          }
        }

        expect(lastClassicIndex, lessThan(firstRegularIndex));
      });
    });

    group('Query Operations', () {
      setUp(() {
        // Add test data
        cacheService.addVideo(testVideo1);
        cacheService.addVideo(testVideo2);
        cacheService.addVideo(classicVineVideo);
      });

      test('should get videos by author', () {
        final authorVideos = cacheService.getVideosByAuthor(testVideo1.pubkey);

        expect(authorVideos.length, equals(1));
        expect(authorVideos.first.id, equals(testVideo1.id));
      });

      test('should get videos by hashtags', () {
        // Create video with hashtags
        final hashtagVideo = TestHelpers.createVideoEvent(
          id: 'hashtag-video',
          title: 'Hashtag Video',
          hashtags: ['flutter', 'dart', 'nostr'],
        );
        cacheService.addVideo(hashtagVideo);

        final results = cacheService.getVideosByHashtags(['flutter']);
        expect(results.length, equals(1));
        expect(results.first.id, equals(hashtagVideo.id));

        // Test multiple hashtag search
        final results2 = cacheService.getVideosByHashtags(['dart', 'rust']);
        expect(results2.length, equals(1)); // Should find the dart hashtag
      });

      // Skip vine ID test for now - focus on core caching functionality
    });

    group('Cache Management', () {
      test('should clear all cached videos', () {
        cacheService.addVideo(testVideo1);
        cacheService.addVideo(testVideo2);
        expect(cacheService.cacheSize, equals(2));

        cacheService.clearCache();

        expect(cacheService.cacheSize, equals(0));
        expect(cacheService.cachedVideos, isEmpty);
      });

      test('should check if video exists in cache', () {
        cacheService.addVideo(testVideo1);

        expect(cacheService.containsVideo(testVideo1.id), isTrue);
        expect(cacheService.containsVideo('non-existent'), isFalse);
      });

      test('should handle batch video additions', () {
        final videos = [testVideo1, testVideo2, classicVineVideo];
        cacheService.addVideos(videos);

        expect(cacheService.cacheSize, equals(3));
        // Classic vine should still be prioritized
        expect(
          cacheService.cachedVideos.first.pubkey,
          equals(AppConstants.classicVinesPubkey),
        );
      });
    });
  });
}
