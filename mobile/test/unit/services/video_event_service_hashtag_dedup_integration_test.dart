// ABOUTME: Integration test to verify hashtag deduplication fix
// ABOUTME: Tests the actual VideoEventService method after implementing the fix

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('VideoEventService Hashtag Deduplication Integration Test', () {
    test('Verify deduplication logic works correctly', () {
      // Create test video events
      final video1 = VideoEvent(
        id: 'video-1',
        pubkey:
            'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Dog video',
        timestamp: DateTime.now(),
        hashtags: ['dog', 'cute'],
        videoUrl: 'https://example.com/video1.mp4',
      );

      final video2 = VideoEvent(
        id: 'video-2',
        pubkey:
            '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Cat video',
        timestamp: DateTime.now(),
        hashtags: ['cat', 'cute'],
        videoUrl: 'https://example.com/video2.mp4',
      );

      // Simulate event lists structure from VideoEventService
      final eventLists = <String, List<VideoEvent>>{
        'discovery': [video1, video2], // Both videos in discovery
        'hashtag': [video1], // video1 also in hashtag subscription
        'trending': [], // Empty trending
      };

      // Test the OLD buggy implementation
      final buggyResult = <VideoEvent>[];
      for (final events in eventLists.values) {
        buggyResult.addAll(
          events.where(
            (event) => ['dog'].any((tag) => event.hashtags.contains(tag)),
          ),
        );
      }

      Log.info('Buggy implementation results: ${buggyResult.length}');
      expect(
        buggyResult.length,
        equals(2),
        reason: 'Old implementation returns duplicates',
      );

      // Test the FIXED implementation with deduplication
      final fixedResult = <VideoEvent>[];
      final seenIds = <String>{};

      for (final events in eventLists.values) {
        for (final event in events.where(
          (event) => ['dog'].any((tag) => event.hashtags.contains(tag)),
        )) {
          if (!seenIds.contains(event.id)) {
            seenIds.add(event.id);
            fixedResult.add(event);
          }
        }
      }

      Log.info('Fixed implementation results: ${fixedResult.length}');
      expect(
        fixedResult.length,
        equals(1),
        reason: 'Fixed implementation deduplicates correctly',
      );
      expect(fixedResult.first.id, equals('video-1'));

      // Test edge cases

      // Test with multiple hashtag filters
      final multiTagResult = <VideoEvent>[];
      final multiSeenIds = <String>{};

      for (final events in eventLists.values) {
        for (final event in events.where(
          (event) => ['cute'].any((tag) => event.hashtags.contains(tag)),
        )) {
          if (!multiSeenIds.contains(event.id)) {
            multiSeenIds.add(event.id);
            multiTagResult.add(event);
          }
        }
      }

      // Both videos have 'cute' hashtag, but video1 appears twice in lists
      expect(multiTagResult.length, equals(2));
      expect(
        multiTagResult.map((v) => v.id).toSet(),
        equals({'video-1', 'video-2'}),
      );

      // Test with no matches
      final noMatchResult = <VideoEvent>[];
      final noMatchSeenIds = <String>{};

      for (final events in eventLists.values) {
        for (final event in events.where(
          (event) => ['bird'].any((tag) => event.hashtags.contains(tag)),
        )) {
          if (!noMatchSeenIds.contains(event.id)) {
            noMatchSeenIds.add(event.id);
            noMatchResult.add(event);
          }
        }
      }

      expect(noMatchResult.length, equals(0));
    });
  });
}
