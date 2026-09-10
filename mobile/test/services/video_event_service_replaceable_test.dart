// ABOUTME: Tests for VideoEventService replaceable event handling (NIP-33)
// ABOUTME: Verifies that newer versions of replaceable events replace older ones

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  group('VideoEventService - Replaceable Events (NIP-33)', () {
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late VideoEventService service;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');

      service = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
    });

    test('newer video event replaces older one with same d-tag', () async {
      // Arrange: Create two versions of the same video (same pubkey + d-tag)
      const pubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const vineId = 'test-vine-abc';
      const videoUrl = 'https://example.com/video.mp4';

      // Old version (timestamp 1000)
      final oldEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Old Title'],
        ],
        'Old version',
        createdAt: 1000,
      );

      // New version (timestamp 2000) - same pubkey and d-tag
      final newEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'New Title'],
        ],
        'New version',
        createdAt: 2000,
      );

      // Act: Add old event first, then new event
      service.handleEventForTesting(oldEvent, SubscriptionType.discovery);
      service.handleEventForTesting(newEvent, SubscriptionType.discovery);

      // Assert: Should only have the newer event
      final videos = service.discoveryVideos;
      expect(videos.length, 1, reason: 'Should have exactly one video');
      expect(videos[0].id, newEvent.id, reason: 'Should be the newer event');
      expect(videos[0].title, 'New Title', reason: 'Should have newer title');
      expect(videos[0].createdAt, 2000, reason: 'Should have newer timestamp');
    });

    test('older video event is rejected when newer exists', () async {
      // Arrange: Create two versions with reversed timestamps
      const pubkey =
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
      const vineId = 'test-vine-xyz';
      const videoUrl = 'https://example.com/video2.mp4';

      // New version (timestamp 3000)
      final newEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Newer Title'],
        ],
        'New version',
        createdAt: 3000,
      );

      // Old version (timestamp 1500)
      final oldEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Older Title'],
        ],
        'Old version',
        createdAt: 1500,
      );

      // Act: Add newer event first, then try to add older
      service.handleEventForTesting(newEvent, SubscriptionType.discovery);
      service.handleEventForTesting(oldEvent, SubscriptionType.discovery);

      // Assert: Should still only have the newer event
      final videos = service.discoveryVideos;
      expect(videos.length, 1, reason: 'Should have exactly one video');
      expect(videos[0].id, newEvent.id, reason: 'Should keep the newer event');
      expect(videos[0].title, 'Newer Title', reason: 'Should keep newer title');
      expect(videos[0].createdAt, 3000, reason: 'Should have newer timestamp');
    });

    test('equal timestamp keeps the lower event id per NIP-01', () async {
      const pubkey =
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      const vineId = 'test-vine-equal-timestamp';
      const videoUrl = 'https://example.com/video-equal.mp4';

      final eventA = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Equal A'],
        ],
        'Equal A',
        createdAt: 4000,
      );
      final eventB = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Equal B'],
        ],
        'Equal B',
        createdAt: 4000,
      );
      final orderedById = [eventA, eventB]
        ..sort((a, b) => a.id.compareTo(b.id));
      final lowerIdEvent = orderedById.first;
      final higherIdEvent = orderedById.last;

      service.handleEventForTesting(higherIdEvent, SubscriptionType.discovery);
      service.handleEventForTesting(lowerIdEvent, SubscriptionType.discovery);

      final videos = service.discoveryVideos;
      expect(videos, hasLength(1));
      expect(videos.single.id, lowerIdEvent.id);
      expect(
        videos.single.title,
        lowerIdEvent == eventA ? 'Equal A' : 'Equal B',
      );
    });

    test('different d-tags create separate videos', () async {
      // Arrange: Same pubkey, different d-tags
      const pubkey =
          '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
      const videoUrl = 'https://example.com/video3.mp4';

      final event1 = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', 'vine-1'],
          ['url', videoUrl],
          ['title', 'Video 1'],
        ],
        'Video 1',
        createdAt: 1000,
      );

      final event2 = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', 'vine-2'],
          ['url', videoUrl],
          ['title', 'Video 2'],
        ],
        'Video 2',
        createdAt: 2000,
      );

      // Act: Add both events
      service.handleEventForTesting(event1, SubscriptionType.discovery);
      service.handleEventForTesting(event2, SubscriptionType.discovery);

      // Assert: Should have both videos (different d-tags)
      final videos = service.discoveryVideos;
      expect(videos.length, 2, reason: 'Should have two separate videos');
      expect(videos.map((v) => v.id).toSet(), {event1.id, event2.id});
    });

    test(
      'different subscription types track replaceable events separately',
      () async {
        // Arrange: Same video, different subscription types
        const pubkey =
            'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';
        const vineId = 'test-vine-separate';
        const videoUrl = 'https://example.com/video4.mp4';

        final oldEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'Old'],
          ],
          'Old',
          createdAt: 1000,
        );

        final newEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'New'],
          ],
          'New',
          createdAt: 2000,
        );

        // Act: Add old to discovery, new to homeFeed
        service.handleEventForTesting(oldEvent, SubscriptionType.discovery);
        service.handleEventForTesting(newEvent, SubscriptionType.homeFeed);

        // Then add new to discovery (should replace old)
        service.handleEventForTesting(newEvent, SubscriptionType.discovery);

        // Assert: Discovery should have new, homeFeed should have new
        final discoveryVideos = service.discoveryVideos;
        final homeFeedVideos = service.homeFeedVideos;

        expect(discoveryVideos.length, 1);
        expect(
          discoveryVideos[0].id,
          newEvent.id,
          reason: 'Discovery should have newer event',
        );
        expect(
          discoveryVideos[0].createdAt,
          2000,
          reason: 'Discovery should have newer timestamp',
        );

        expect(homeFeedVideos.length, 1);
        expect(
          homeFeedVideos[0].id,
          newEvent.id,
          reason: 'HomeFeed should have newer event',
        );
        expect(
          homeFeedVideos[0].createdAt,
          2000,
          reason: 'HomeFeed should have newer timestamp',
        );
      },
    );
  });

  group('VideoEventService - updateVideoEvent()', () {
    late _MockNostrClient mockNostrService;
    late _MockSubscriptionManager mockSubscriptionManager;
    late VideoEventService service;

    setUp(() {
      mockNostrService = _MockNostrClient();
      mockSubscriptionManager = _MockSubscriptionManager();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.publicKey).thenReturn('');

      service = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
        crashReporter: const SilentCrashReporter(),
      );
    });

    test('updateVideoEvent replaces video in discovery feed by vineId', () {
      // Arrange: Add a video to discovery feed
      const pubkey =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const vineId = 'update-test-vine';
      const videoUrl = 'https://example.com/video.mp4';

      final originalEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Original Title'],
        ],
        'Original description',
        createdAt: 1000,
      );

      service.handleEventForTesting(originalEvent, SubscriptionType.discovery);
      expect(service.discoveryVideos.length, 1);
      expect(service.discoveryVideos[0].title, 'Original Title');

      // Act: Create updated event with new metadata (different event.id but same vineId)
      final updatedEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Updated Title'],
        ],
        'Updated description',
        createdAt: 2000,
      );

      final updatedVideoEvent = VideoEvent.fromNostrEvent(updatedEvent);
      service.updateVideoEvent(updatedVideoEvent);

      // Assert: Should have replaced the original video
      final videos = service.discoveryVideos;
      expect(videos.length, 1, reason: 'Should still have one video');
      expect(
        videos[0].title,
        'Updated Title',
        reason: 'Title should be updated',
      );
      expect(
        videos[0].content,
        'Updated description',
        reason: 'Description should be updated',
      );
      expect(
        videos[0].id,
        updatedEvent.id,
        reason: 'Event ID should be the updated one',
      );
    });

    test(
      'updateVideoEvent replaces video across multiple subscription types',
      () {
        // Arrange: Add same video to both discovery and homeFeed
        const pubkey =
            'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
        const vineId = 'multi-feed-vine';
        const videoUrl = 'https://example.com/video.mp4';

        final originalEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'Original'],
          ],
          'Original',
          createdAt: 1000,
        );

        service.handleEventForTesting(
          originalEvent,
          SubscriptionType.discovery,
        );
        service.handleEventForTesting(originalEvent, SubscriptionType.homeFeed);

        expect(service.discoveryVideos.length, 1);
        expect(service.homeFeedVideos.length, 1);

        // Act: Update with new metadata
        final updatedEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'Updated'],
          ],
          'Updated',
          createdAt: 2000,
        );

        final updatedVideoEvent = VideoEvent.fromNostrEvent(updatedEvent);
        service.updateVideoEvent(updatedVideoEvent);

        // Assert: Should have updated in both feeds
        expect(service.discoveryVideos[0].title, 'Updated');
        expect(service.homeFeedVideos[0].title, 'Updated');
      },
    );

    test(
      'updateVideoEvent adds to discovery if video not found in any feed',
      () {
        // Arrange: Empty feeds
        expect(service.discoveryVideos.length, 0);

        // Act: Update a video that doesn't exist
        const pubkey =
            '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
        const vineId = 'new-vine';
        const videoUrl = 'https://example.com/video.mp4';

        final newEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'New Video'],
          ],
          'New video description',
          createdAt: 3000,
        );

        final newVideoEvent = VideoEvent.fromNostrEvent(newEvent);
        service.updateVideoEvent(newVideoEvent);

        // Assert: Should be added to discovery feed
        expect(
          service.discoveryVideos.length,
          1,
          reason: 'Should add to discovery when not found',
        );
        expect(service.discoveryVideos[0].title, 'New Video');
      },
    );

    test(
      'updateVideoEvent preserves nostrLikeCount from existing video',
      () {
        // Arrange: Add a video and inject a live like count (simulating a
        // batch relay fetch that ran before the user edited their hashtags).
        const pubkey =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        const vineId = 'like-count-preserve-vine';
        const videoUrl = 'https://example.com/video.mp4';

        final originalEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'Original Title'],
          ],
          'Original',
          createdAt: 1000,
        );

        service.handleEventForTesting(
          originalEvent,
          SubscriptionType.discovery,
        );

        // Simulate the batch like-count fetch result arriving and being stored.
        // VideoEvent.fromNostrEvent() always produces nostrLikeCount: null, so
        // we use copyWith to represent the runtime-injected state.
        final videoWithLikes = VideoEvent.fromNostrEvent(
          originalEvent,
        ).copyWith(nostrLikeCount: 42);
        service.updateVideoEvent(videoWithLikes);
        expect(
          service.discoveryVideos[0].nostrLikeCount,
          42,
          reason: 'Pre-condition: like count should be injected',
        );

        // Act: User edits hashtags — republishes with createdAt + 1.
        // VideoEvent.fromNostrEvent() on the new event yields nostrLikeCount: null.
        final editedEvent = sdk.Event(
          pubkey,
          NIP71VideoKinds.addressableShortVideo,
          [
            ['d', vineId],
            ['url', videoUrl],
            ['title', 'Original Title'],
            ['t', 'newtag'],
          ],
          'Original',
          createdAt: 1001,
        );

        final editedVideoEvent = VideoEvent.fromNostrEvent(editedEvent);
        expect(
          editedVideoEvent.nostrLikeCount,
          isNull,
          reason: 'Pre-condition: parsed event has no like count',
        );
        service.updateVideoEvent(editedVideoEvent);

        // Assert: Like count must survive the metadata edit.
        expect(
          service.discoveryVideos[0].nostrLikeCount,
          42,
          reason: 'nostrLikeCount should be preserved across a metadata edit',
        );
      },
    );

    test('updateVideoEvent calls notifyListeners when video is updated', () {
      // Arrange
      const pubkey =
          'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';
      const vineId = 'notify-test';
      const videoUrl = 'https://example.com/video.mp4';

      final originalEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Original'],
        ],
        'Original',
        createdAt: 1000,
      );

      service.handleEventForTesting(originalEvent, SubscriptionType.discovery);

      // Track listener notifications
      var notified = false;
      service.addListener(() => notified = true);

      // Act
      final updatedEvent = sdk.Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        [
          ['d', vineId],
          ['url', videoUrl],
          ['title', 'Updated'],
        ],
        'Updated',
        createdAt: 2000,
      );

      final updatedVideoEvent = VideoEvent.fromNostrEvent(updatedEvent);
      service.updateVideoEvent(updatedVideoEvent);

      // Assert
      expect(notified, true, reason: 'Should notify listeners on update');
    });
  });
}
