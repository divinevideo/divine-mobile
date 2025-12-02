// ABOUTME: Test to reproduce and verify revine display issue in profile screen
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests that revined videos appear correctly in the user's profile revine tab

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('Revine Profile Display Tests', () {
    const testUserPubkey = 'test_user_pubkey_12345';
    const originalVideoPubkey = 'original_video_author_pubkey';
    const originalVideoEventId = 'original_video_event_id_12345';
    const repostEventId = 'repost_event_id_12345';

    test('should detect revined videos correctly', () async {
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

      // Create repost event (what happens when user revines)
      final repostVideoEvent = VideoEvent.createRepostEvent(
        originalEvent: originalVideoEvent,
        repostEventId: repostEventId,
        reposterPubkey: testUserPubkey,
        repostedAt: DateTime.now(),
      );

      // Verify repost event properties
      expect(repostVideoEvent.isRepost, isTrue);
      expect(repostVideoEvent.reposterPubkey, equals(testUserPubkey));
      expect(repostVideoEvent.reposterId, equals(repostEventId));
      expect(repostVideoEvent.repostedAt, isNotNull);

      // Verify original content is preserved
      expect(repostVideoEvent.videoUrl, equals(originalVideoEvent.videoUrl));
      expect(repostVideoEvent.title, equals(originalVideoEvent.title));
      expect(
        repostVideoEvent.pubkey,
        equals(originalVideoPubkey),
      ); // Original author
    });

    test('should filter user reposts correctly for profile display', () {
      // Create multiple video events
      final originalVideo1 = VideoEvent(
        id: 'original1',
        pubkey: originalVideoPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video 1',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video1.mp4',
        isRepost: false,
      );

      final originalVideo2 = VideoEvent(
        id: 'original2',
        pubkey: 'another_author',
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

      // Someone else reposts video2 (should not show in user's profile)
      final otherUserRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo2,
        repostEventId: 'repost2',
        reposterPubkey: 'other_user_pubkey',
        repostedAt: DateTime.now(),
      );

      // Simulate video events in service
      final allVideos = [
        originalVideo1,
        originalVideo2,
        userRepost1,
        otherUserRepost,
      ];

      // Filter logic from ProfileScreen._buildRepostsGrid()
      final userReposts = allVideos
          .where(
            (video) => video.isRepost && video.reposterPubkey == testUserPubkey,
          )
          .toList();

      // Verify filtering
      expect(userReposts.length, equals(1));
      expect(userReposts.first.reposterId, equals('repost1'));
      expect(userReposts.first.reposterPubkey, equals(testUserPubkey));
      expect(
        userReposts.first.videoUrl,
        equals('https://example.com/video1.mp4'),
      );
    });

    test('should identify why revines might not appear in profile', () {
      // Test scenario: User thinks they revined something but it's not showing

      // Case 1: Event was created but not marked as repost
      final missingRepostFlag = VideoEvent(
        id: originalVideoEventId,
        pubkey: originalVideoPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        isRepost: false, // ❌ Should be true for revines
        reposterPubkey: testUserPubkey, // Set but isRepost is false
      );

      // Case 2: Wrong reposter pubkey
      final wrongReposter = VideoEvent(
        id: originalVideoEventId,
        pubkey: originalVideoPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        isRepost: true,
        reposterPubkey: 'wrong_user_pubkey', // ❌ Should be testUserPubkey
      );

      // Case 3: Missing reposter pubkey
      final missingReposter = VideoEvent(
        id: originalVideoEventId,
        pubkey: originalVideoPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video content',
        timestamp: DateTime.now(),
        videoUrl: 'https://example.com/video.mp4',
        isRepost: true,
        reposterPubkey: null, // ❌ Should be set
      );

      final problematicVideos = [
        missingRepostFlag,
        wrongReposter,
        missingReposter,
      ];

      // Apply profile filter logic
      final userReposts = problematicVideos
          .where(
            (video) => video.isRepost && video.reposterPubkey == testUserPubkey,
          )
          .toList();

      // All these cases should result in no revines showing
      expect(userReposts.length, equals(0));

      // Log what went wrong for each case
      Log.info('=== DEBUGGING WHY REVINES DONT SHOW ===');
      for (var i = 0; i < problematicVideos.length; i++) {
        final video = problematicVideos[i];
        Log.info('Video ${i + 1}:');
        Log.info('  isRepost: ${video.isRepost}');
        Log.info('  reposterPubkey: ${video.reposterPubkey}');
        Log.info('  expectedPubkey: $testUserPubkey');
        Log.info(
          '  wouldShow: ${video.isRepost && video.reposterPubkey == testUserPubkey}',
        );
        Log.info('');
      }
    });
  });
}
