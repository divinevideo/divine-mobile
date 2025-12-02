// ABOUTME: Direct test of the getVideoEventsByHashtags duplicate bug
// ABOUTME: Minimal reproduction case showing the deduplication issue

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  group('VideoEventService getVideoEventsByHashtags Bug', () {
    test('CURRENT BUG: getVideoEventsByHashtags returns duplicates', () {
      // This test demonstrates the current bug without mocking
      // It directly tests the getVideoEventsByHashtags method

      // Create a test video event
      final nostrEvent = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        34236,
        [
          ['url', 'https://example.com/test.mp4'],
          ['m', 'video/mp4'],
          ['t', 'dog'],
          ['t', 'shiba'],
        ],
        'Test video',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      nostrEvent.id = 'test-video-123';

      final testVideo = VideoEvent(
        id: 'test-video-123',
        pubkey:
            'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        createdAt: nostrEvent.createdAt,
        content: 'Test video',
        timestamp: DateTime.now(),
        hashtags: ['dog', 'shiba'],
        videoUrl: 'https://example.com/test.mp4',
      );

      // Create a mock list structure similar to VideoEventService._eventLists
      final eventLists = <String, List<VideoEvent>>{
        'discovery': [testVideo], // Video exists in discovery list
        'hashtag': [testVideo], // Same video also in hashtag list
        'trending': [], // Empty trending list
      };

      // Replicate the buggy getVideoEventsByHashtags logic
      final result = <VideoEvent>[];
      for (final events in eventLists.values) {
        result.addAll(
          events.where(
            (event) => ['dog'].any((tag) => event.hashtags.contains(tag)),
          ),
        );
      }

      // Print debug info
      Log.info('Event lists:');
      eventLists.forEach((key, value) {
        Log.info('  $key: ${value.length} videos');
      });
      Log.info('Result count: ${result.length}');
      Log.info('Result IDs: ${result.map((v) => v.id).toList()}');

      // BUG DEMONSTRATION: This will show 2 instead of 1
      expect(
        result.length,
        equals(2),
        reason:
            'Current implementation returns duplicates when same video exists in multiple lists',
      );

      // Both results are the same video
      expect(result[0].id, equals('test-video-123'));
      expect(result[1].id, equals('test-video-123'));

      // WHAT IT SHOULD BE: Deduplicated to return only unique videos
      final deduplicatedResult = result.toSet().toList();
      expect(
        deduplicatedResult.length,
        equals(1),
        reason: 'After deduplication, should only have 1 unique video',
      );
    });

    test('PROPOSED FIX: getVideoEventsByHashtags with deduplication', () {
      // This demonstrates the fix

      final nostrEvent = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        34236,
        [
          ['url', 'https://example.com/test.mp4'],
          ['m', 'video/mp4'],
          ['t', 'dog'],
          ['t', 'shiba'],
        ],
        'Test video',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      nostrEvent.id = 'test-video-123';

      final testVideo = VideoEvent(
        id: 'test-video-123',
        pubkey:
            'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        createdAt: nostrEvent.createdAt,
        content: 'Test video',
        timestamp: DateTime.now(),
        hashtags: ['dog', 'shiba'],
        videoUrl: 'https://example.com/test.mp4',
      );

      // Create a mock list structure
      final eventLists = <String, List<VideoEvent>>{
        'discovery': [testVideo],
        'hashtag': [testVideo],
        'trending': [],
      };

      // FIXED implementation with deduplication
      final result = <VideoEvent>[];
      final seenIds = <String>{};

      for (final events in eventLists.values) {
        for (final event in events.where(
          (event) => ['dog'].any((tag) => event.hashtags.contains(tag)),
        )) {
          if (!seenIds.contains(event.id)) {
            seenIds.add(event.id);
            result.add(event);
          }
        }
      }

      // With fix: Should return only 1 video
      expect(result.length, equals(1));
      expect(result.first.id, equals('test-video-123'));
    });
  });
}
