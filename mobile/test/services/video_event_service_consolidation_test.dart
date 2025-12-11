// ABOUTME: Tests for repost consolidation logic in VideoEventService
// ABOUTME: Verifies that duplicate reposts are consolidated into a single video with multiple reposter pubkeys

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/video_event.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import '../builders/test_video_event_builder.dart';

import 'video_event_service_consolidation_test.mocks.dart';

@GenerateMocks([NostrClient, SubscriptionManager])
void main() {
  late VideoEventService service;
  late MockNostrClient mockNostrService;
  late MockSubscriptionManager mockSubscriptionManager;

  setUp(() {
    mockNostrService = MockNostrClient();
    mockSubscriptionManager = MockSubscriptionManager();

    // Setup default mock behaviors
    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockNostrService.connectedRelayCount).thenReturn(1);
    when(mockNostrService.connectedRelays).thenReturn(['wss://test.relay']);

    service = VideoEventService(
      mockNostrService,
      subscriptionManager: mockSubscriptionManager,
    );
  });

  tearDown(() {
    service.dispose();
  });

  group('Repost Consolidation', () {
    test('Duplicate reposts are consolidated into single video', () {
      // Create an original video using builder
      final originalVideo = TestVideoEventBuilder.create(
        id: 'original123',
        pubkey: 'alice',
        videoUrl: 'https://example.com/video.mp4',
        title: 'Original Video',
      );

      // Bob reposts the video
      final bobRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo,
        repostEventId: 'repost1',
        reposterPubkey: 'bob',
        repostedAt: DateTime.now(),
      );

      // Charlie reposts the same video
      final charlieRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo,
        repostEventId: 'repost2',
        reposterPubkey: 'charlie',
        repostedAt: DateTime.now(),
      );

      // Add first repost
      service.addVideoEventForTesting(
        bobRepost,
        SubscriptionType.discovery,
        isHistorical: false,
      );

      // Add second repost of same video
      service.addVideoEventForTesting(
        charlieRepost,
        SubscriptionType.discovery,
        isHistorical: false,
      );

      // Verify: Should have only ONE video in the feed
      final videos = service.getVideos(SubscriptionType.discovery);
      expect(
        videos.length,
        1,
        reason: 'Should consolidate duplicate reposts into single video',
      );

      // Verify: The video should have both reposters in reposterPubkeys list
      final consolidatedVideo = videos.first;
      expect(consolidatedVideo.reposterPubkeys, isNotNull);
      expect(consolidatedVideo.reposterPubkeys!.length, 2);
      expect(
        consolidatedVideo.reposterPubkeys,
        containsAll(['bob', 'charlie']),
      );
    });

    test('Original (non-repost) videos are not affected by consolidation', () {
      // Create two different original videos
      final video1 = TestVideoEventBuilder.create(
        id: 'video1',
        pubkey: 'alice',
        videoUrl: 'https://example.com/video1.mp4',
        title: 'Video 1',
      );

      final video2 = TestVideoEventBuilder.create(
        id: 'video2',
        pubkey: 'bob',
        videoUrl: 'https://example.com/video2.mp4',
        title: 'Video 2',
      );

      // Add both original videos
      service.addVideoEventForTesting(
        video1,
        SubscriptionType.discovery,
        isHistorical: false,
      );
      service.addVideoEventForTesting(
        video2,
        SubscriptionType.discovery,
        isHistorical: false,
      );

      // Verify: Should have TWO videos in the feed
      final videos = service.getVideos(SubscriptionType.discovery);
      expect(
        videos.length,
        2,
        reason: 'Original videos should not be consolidated',
      );

      // Verify: Neither should have reposterPubkeys set
      expect(videos[0].reposterPubkeys, anyOf(isNull, isEmpty));
      expect(videos[1].reposterPubkeys, anyOf(isNull, isEmpty));
    });

    test('Repost consolidation preserves original video ID', () {
      // Create original video
      final originalVideo = TestVideoEventBuilder.create(
        id: 'original456',
        pubkey: 'alice',
        videoUrl: 'https://example.com/video.mp4',
        title: 'Original Video',
      );

      // Bob reposts
      final bobRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo,
        repostEventId: 'repost1',
        reposterPubkey: 'bob',
        repostedAt: DateTime.now(),
      );

      // Charlie reposts
      final charlieRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo,
        repostEventId: 'repost2',
        reposterPubkey: 'charlie',
        repostedAt: DateTime.now(),
      );

      // Add both reposts
      service.addVideoEventForTesting(
        bobRepost,
        SubscriptionType.discovery,
        isHistorical: false,
      );
      service.addVideoEventForTesting(
        charlieRepost,
        SubscriptionType.discovery,
        isHistorical: false,
      );

      // Verify: Video ID should be the original video ID, not a repost ID
      final videos = service.getVideos(SubscriptionType.discovery);
      expect(videos.length, 1);
      expect(
        videos.first.id,
        'original456',
        reason: 'Consolidated video should preserve original video ID',
      );
    });

    test(
      'Repost consolidation works across historical and real-time events',
      () {
        // Create original video
        final originalVideo = TestVideoEventBuilder.create(
          id: 'original789',
          pubkey: 'alice',
          videoUrl: 'https://example.com/video.mp4',
          title: 'Original Video',
        );

        // Historical repost from Bob
        final bobRepost = VideoEvent.createRepostEvent(
          originalEvent: originalVideo,
          repostEventId: 'repost1',
          reposterPubkey: 'bob',
          repostedAt: DateTime.now(),
        );

        // Real-time repost from Charlie
        final charlieRepost = VideoEvent.createRepostEvent(
          originalEvent: originalVideo,
          repostEventId: 'repost2',
          reposterPubkey: 'charlie',
          repostedAt: DateTime.now(),
        );

        // Add historical repost first
        service.addVideoEventForTesting(
          bobRepost,
          SubscriptionType.discovery,
          isHistorical: true,
        );

        // Add real-time repost
        service.addVideoEventForTesting(
          charlieRepost,
          SubscriptionType.discovery,
          isHistorical: false,
        );

        // Verify consolidation
        final videos = service.getVideos(SubscriptionType.discovery);
        expect(videos.length, 1);
        expect(videos.first.reposterPubkeys, containsAll(['bob', 'charlie']));
      },
    );

    test('Backward compatibility: reposterPubkey (singular) still works', () {
      // Create original video
      final originalVideo = TestVideoEventBuilder.create(
        id: 'originalABC',
        pubkey: 'alice',
        videoUrl: 'https://example.com/video.mp4',
        title: 'Original Video',
      );

      // Single repost from Bob
      final bobRepost = VideoEvent.createRepostEvent(
        originalEvent: originalVideo,
        repostEventId: 'repost1',
        reposterPubkey: 'bob',
        repostedAt: DateTime.now(),
      );

      service.addVideoEventForTesting(
        bobRepost,
        SubscriptionType.discovery,
        isHistorical: false,
      );

      final videos = service.getVideos(SubscriptionType.discovery);
      expect(videos.length, 1);

      // Verify: Single reposter should be accessible via reposterPubkey (singular)
      final video = videos.first;
      expect(
        video.reposterPubkey,
        'bob',
        reason:
            'Backward compatibility: reposterPubkey should work for single reposter',
      );

      // Verify: reposterPubkeys (plural) should contain bob
      expect(video.reposterPubkeys, contains('bob'));
    });
  });
}
