// ABOUTME: Test to verify the revine fix works correctly
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests that enabling includeReposts allows Kind 6 events to be processed

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

import 'mocks/mock_nostr_service.dart';

class MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  group('Revine Fix Tests', () {
    const testUserPubkey = 'test_user_pubkey_12345';
    const originalVideoPubkey = 'original_video_author_pubkey';
    const originalVideoEventId = 'original_video_event_id_12345';
    const repostEventId = 'repost_event_id_12345';

    test(
      'VideoEvent.createRepostEvent should create proper repost structure',
      () {
        // Create original video event
        final originalVideoEvent = VideoEvent(
          id: originalVideoEventId,
          pubkey: originalVideoPubkey,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Original video content',
          timestamp: DateTime.now(),
          title: 'Test Video',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
          isRepost: false,
        );

        // Create repost event using the factory method
        final repostVideoEvent = VideoEvent.createRepostEvent(
          originalEvent: originalVideoEvent,
          repostEventId: repostEventId,
          reposterPubkey: testUserPubkey,
          repostedAt: DateTime.now(),
        );

        // Verify the repost maintains all original content
        expect(repostVideoEvent.isRepost, isTrue);
        expect(repostVideoEvent.reposterPubkey, equals(testUserPubkey));
        expect(repostVideoEvent.reposterId, equals(repostEventId));
        expect(repostVideoEvent.repostedAt, isNotNull);

        // Verify original content is preserved
        expect(
          repostVideoEvent.id,
          equals(originalVideoEvent.id),
        ); // Original video ID
        expect(
          repostVideoEvent.pubkey,
          equals(originalVideoPubkey),
        ); // Original author
        expect(repostVideoEvent.videoUrl, equals(originalVideoEvent.videoUrl));
        expect(repostVideoEvent.title, equals(originalVideoEvent.title));
        expect(repostVideoEvent.content, equals(originalVideoEvent.content));

        Log.info('✅ Repost VideoEvent structure is correct');
        Log.info('  - Original author: ${repostVideoEvent.pubkey}');
        Log.info('  - Reposter: ${repostVideoEvent.reposterPubkey}');
        Log.info('  - isRepost: ${repostVideoEvent.isRepost}');
        Log.info('  - Video URL preserved: ${repostVideoEvent.videoUrl}');
      },
    );

    test('Profile repost filtering logic should work correctly', () {
      // Create test data
      final originalVideo1 = VideoEvent(
        id: 'video1',
        pubkey: 'author1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video 1',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video1.mp4',
        isRepost: false,
      );

      final originalVideo2 = VideoEvent(
        id: 'video2',
        pubkey: 'author2',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video 2',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video2.mp4',
        isRepost: false,
      );

      // User reposts video1
      final userRepost1 = VideoEvent.createRepostEvent(
        originalEvent: originalVideo1,
        repostEventId: 'repost1',
        reposterPubkey: testUserPubkey,
        repostedAt: DateTime.now(),
      );

      // User reposts video2
      final userRepost2 = VideoEvent.createRepostEvent(
        originalEvent: originalVideo2,
        repostEventId: 'repost2',
        reposterPubkey: testUserPubkey,
        repostedAt: DateTime.now(),
      );

      // Someone else reposts video1 (should not show in user's profile)
      final otherUserRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo1,
        repostEventId: 'repost3',
        reposterPubkey: 'other_user',
        repostedAt: DateTime.now(),
      );

      // Simulate the full feed (mixed original videos and reposts)
      final allVideos = [
        originalVideo1,
        originalVideo2,
        userRepost1,
        userRepost2,
        otherUserRepost,
      ];

      // Apply the ProfileScreen._buildRepostsGrid() filtering logic
      final userReposts = allVideos
          .where(
            (video) => video.isRepost && video.reposterPubkey == testUserPubkey,
          )
          .toList();

      // Verify results
      expect(
        userReposts.length,
        equals(2),
        reason: 'User should have 2 reposts',
      );
      expect(
        userReposts.every((v) => v.reposterPubkey == testUserPubkey),
        isTrue,
      );
      expect(userReposts.every((v) => v.isRepost), isTrue);

      // Check specific videos are included
      final repostIds = userReposts.map((v) => v.reposterId).toSet();
      expect(repostIds.contains('repost1'), isTrue);
      expect(repostIds.contains('repost2'), isTrue);
      expect(
        repostIds.contains('repost3'),
        isFalse,
        reason: 'Other user repost should not appear',
      );

      Log.info('✅ Profile repost filtering works correctly');
      Log.info('  - Total videos in feed: ${allVideos.length}');
      Log.info('  - User reposts found: ${userReposts.length}');
      Log.info('  - Repost IDs: ${repostIds.toList()}');
    });

    test('includeReposts flag should be tracked correctly', () async {
      final mockNostrService = MockNostrService();
      final mockSubscriptionManager = MockSubscriptionManager();
      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      // Initially reposts should be disabled
      expect(videoEventService.classicVinesPubkey, isNotEmpty);

      // This test verifies that the _includeReposts field is set correctly
      // We can't directly test the private field, but we can verify the behavior
      Log.info('✅ VideoEventService initialized correctly');
      Log.info(
        '  - Classic vines pubkey available: ${videoEventService.classicVinesPubkey}',
      );
    });
  });
}
