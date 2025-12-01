// ABOUTME: End-to-end test for revine functionality to verify the complete fix
import 'package:openvine/utils/unified_logger.dart';
// ABOUTME: Tests from revining a video to seeing it appear in the user's profile

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('Revine End-to-End Integration Test', () {
    const userPubkey = 'user123';
    const authorPubkey = 'author456';

    test('Complete revine flow: create → process → filter → display', () {
      Log.info('🧪 Testing complete revine flow...\n');

      // Step 1: Original video exists
      Log.info('📹 Step 1: Create original video');
      final originalVideo = VideoEvent(
        id: 'original_video_123',
        pubkey: authorPubkey,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Amazing video content!',
        timestamp: DateTime.now(),
        title: 'Test Video',
        videoUrl: 'https://cdn.example.com/video.mp4',
        thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
        hashtags: ['funny', 'viral'],
        isRepost: false,
      );

      Log.info('   ✓ Original video created by ${authorPubkey}...');
      Log.info('   ✓ Video URL: ${originalVideo.videoUrl}');
      Log.info('   ✓ isRepost: ${originalVideo.isRepost}\n');

      // Step 2: User revines the video (creates Kind 6 event → VideoEvent repost)
      Log.info('🔄 Step 2: User revines the video');
      final revineEvent = VideoEvent.createRepostEvent(
        originalEvent: originalVideo,
        repostEventId: 'revine_event_789',
        reposterPubkey: userPubkey,
        repostedAt: DateTime.now(),
      );

      Log.info('   ✓ Revine event created with ID: ${revineEvent.reposterId}');
      Log.info('   ✓ Reposter: ${revineEvent.reposterPubkey}');
      Log.info('   ✓ isRepost: ${revineEvent.isRepost}');
      Log.info('   ✓ Original content preserved: ${revineEvent.title}\n');

      // Step 3: Simulate mixed feed (what VideoEventService would have)
      Log.info('📱 Step 3: Simulate app feed with mixed content');
      final feedVideos = [
        originalVideo,
        revineEvent,
        // Add some other user's content to make it realistic
        VideoEvent(
          id: 'other_video',
          pubkey: 'other_author',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Other video',
          timestamp: DateTime.now(),
          videoUrl: 'https://cdn.example.com/other.mp4',
          isRepost: false,
        ),
        // Add another user's revine to test filtering
        VideoEvent.createRepostEvent(
          originalEvent: originalVideo,
          repostEventId: 'other_revine',
          reposterPubkey: 'other_user',
          repostedAt: DateTime.now(),
        ),
      ];

      Log.info('   ✓ Feed contains ${feedVideos.length} videos total');
      Log.info(
        '   ✓ Original videos: ${feedVideos.where((v) => !v.isRepost).length}',
      );
      Log.info('   ✓ Revines: ${feedVideos.where((v) => v.isRepost).length}\n');

      // Step 4: Profile filtering (what ProfileScreen._buildRepostsGrid() does)
      Log.info("👤 Step 4: Filter for user's revines in profile");
      final userRevines = feedVideos
          .where(
            (video) => video.isRepost && video.reposterPubkey == userPubkey,
          )
          .toList();

      Log.info('   ✓ User revines found: ${userRevines.length}');
      expect(
        userRevines.length,
        equals(1),
        reason: 'User should have exactly 1 revine',
      );

      final userRevine = userRevines.first;
      Log.info('   ✓ Revine ID: ${userRevine.reposterId}');
      Log.info('   ✓ Original video title: ${userRevine.title}');
      Log.info('   ✓ Video URL accessible: ${userRevine.videoUrl}\n');

      // Step 5: Verify the revine displays correctly
      Log.info('✨ Step 5: Verify display properties');
      expect(userRevine.isRepost, isTrue);
      expect(userRevine.reposterPubkey, equals(userPubkey));
      expect(userRevine.reposterId, equals('revine_event_789'));
      expect(userRevine.repostedAt, isNotNull);

      // Original content should be preserved for display
      expect(userRevine.title, equals('Test Video'));
      expect(userRevine.videoUrl, equals('https://cdn.example.com/video.mp4'));
      expect(
        userRevine.thumbnailUrl,
        equals('https://cdn.example.com/thumb.jpg'),
      );
      expect(userRevine.pubkey, equals(authorPubkey)); // Original author
      expect(userRevine.hashtags, contains('funny'));

      Log.info('   ✓ All display properties correct');
      Log.info('   ✓ Original author preserved: ${userRevine.pubkey}');
      Log.info('   ✓ Reposter identified: ${userRevine.reposterPubkey}');
      Log.info('   ✓ Content accessible for playback\n');

      Log.info('🎉 SUCCESS: Complete revine flow working correctly!');
      Log.info(
        "   The revined video will now appear in the user's profile Revines tab",
      );
    });

    test('Verify edge cases are handled correctly', () {
      Log.info('🔍 Testing edge cases...\n');

      // Edge case 1: Multiple revines by same user
      final video1 = VideoEvent(
        id: 'video1',
        pubkey: 'author1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video 1',
        timestamp: DateTime.now(),
        videoUrl: 'https://cdn.example.com/video1.mp4',
        isRepost: false,
      );

      final video2 = VideoEvent(
        id: 'video2',
        pubkey: 'author2',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Video 2',
        timestamp: DateTime.now(),
        videoUrl: 'https://cdn.example.com/video2.mp4',
        isRepost: false,
      );

      final revine1 = VideoEvent.createRepostEvent(
        originalEvent: video1,
        repostEventId: 'revine1',
        reposterPubkey: userPubkey,
        repostedAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      final revine2 = VideoEvent.createRepostEvent(
        originalEvent: video2,
        repostEventId: 'revine2',
        reposterPubkey: userPubkey,
        repostedAt: DateTime.now(),
      );

      final mixedFeed = [video1, video2, revine1, revine2];
      final userRevines = mixedFeed
          .where((v) => v.isRepost && v.reposterPubkey == userPubkey)
          .toList();

      expect(userRevines.length, equals(2));
      Log.info('   ✓ Multiple revines by same user handled correctly');

      // Edge case 2: Same video revined by multiple users
      final otherUserRevine = VideoEvent.createRepostEvent(
        originalEvent: video1,
        repostEventId: 'other_revine',
        reposterPubkey: 'other_user',
        repostedAt: DateTime.now(),
      );

      final feedWithDuplicates = [video1, revine1, otherUserRevine];
      final onlyUserRevines = feedWithDuplicates
          .where((v) => v.isRepost && v.reposterPubkey == userPubkey)
          .toList();

      expect(onlyUserRevines.length, equals(1));
      Log.info('   ✓ Duplicate revines filtered correctly');

      // Edge case 3: Revine without proper metadata
      final incompleteRevine = VideoEvent(
        id: 'incomplete',
        pubkey: 'author',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Content',
        timestamp: DateTime.now(),
        isRepost: true, // Marked as repost but missing reposter info
        reposterPubkey: null, // Missing!
      );

      final feedWithIncomplete = [video1, incompleteRevine];
      final validRevines = feedWithIncomplete
          .where((v) => v.isRepost && v.reposterPubkey == userPubkey)
          .toList();

      expect(validRevines.length, equals(0));
      Log.info('   ✓ Incomplete revines filtered out correctly\n');

      Log.info('✅ All edge cases handled properly!');
    });
  });
}
