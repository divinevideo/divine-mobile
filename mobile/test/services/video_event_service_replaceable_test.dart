// ABOUTME: Tests for VideoEventService replaceable event handling (NIP-33)
// ABOUTME: Verifies that newer versions of replaceable events replace older ones

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as sdk;
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

@GenerateMocks([INostrService, SubscriptionManager])
import 'video_event_service_replaceable_test.mocks.dart';

void main() {
  group('VideoEventService - Replaceable Events (NIP-33)', () {
    late MockINostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late VideoEventService service;

    setUp(() {
      mockNostrService = MockINostrService();
      mockSubscriptionManager = MockSubscriptionManager();

      when(mockNostrService.isInitialized).thenReturn(true);

      service = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
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

    test('non-replaceable events (kind 22) are not deduplicated', () async {
      // Arrange: Two different kind 22 events (non-addressable)
      const pubkey =
          '9876543210abcdef9876543210abcdef9876543210abcdef9876543210abcdef';
      const videoUrl = 'https://example.com/video5.mp4';

      final event1 = sdk.Event(
        pubkey,
        NIP71VideoKinds.shortVideo, // Kind 22 is NOT replaceable
        [
          ['url', videoUrl],
          ['title', 'Video 1'],
        ],
        'Video 1',
        createdAt: 1000,
      );

      final event2 = sdk.Event(
        pubkey,
        NIP71VideoKinds.shortVideo,
        [
          ['url', videoUrl],
          ['title', 'Video 2'],
        ],
        'Video 2',
        createdAt: 2000,
      );

      // Act: Add both events
      service.handleEventForTesting(event1, SubscriptionType.discovery);
      service.handleEventForTesting(event2, SubscriptionType.discovery);

      // Assert: Should have both videos (kind 22 is not replaceable)
      final videos = service.discoveryVideos;
      expect(
        videos.length,
        2,
        reason: 'Kind 22 events should not replace each other',
      );
    });
  });
}
