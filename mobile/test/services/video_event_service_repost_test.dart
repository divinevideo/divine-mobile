// ABOUTME: Integration tests for VideoEventService Kind 16 generic repost event processing
// ABOUTME: Verifies that Kind 16 Nostr events are properly converted to VideoEvent reposts

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

import './video_event_service_repost_test.mocks.dart';

@GenerateMocks([INostrService, SubscriptionManager])
void main() {
  group('VideoEventService Kind 16 Generic Repost Processing', () {
    late VideoEventService videoEventService;
    late MockINostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockINostrService();
      mockSubscriptionManager = MockSubscriptionManager();
      eventStreamController = StreamController<Event>.broadcast();

      // Setup default mock behaviors
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(3);
      when(mockNostrService.connectedRelays).thenReturn([
        'wss://relay1.example.com',
        'wss://relay2.example.com',
        'wss://relay3.example.com',
      ]);
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => eventStreamController.stream);

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );
    });

    tearDown(() {
      eventStreamController.close();
      videoEventService.dispose();
    });

    test('should include Kind 16 events in subscription filter', () async {
      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Verify that the filter includes both Kind 22 and Kind 16
      verify(
        mockNostrService.subscribeToEvents(
          filters: argThat(
            predicate<List<Filter>>((filters) {
              if (filters.isEmpty) return false;
              final filter = filters.first;
              return filter.kinds != null &&
                  filter.kinds!.contains(22) &&
                  filter.kinds!.contains(16);
            }),
            named: 'filters',
          ),
        ),
      ).called(1);
    });

    test('should process Kind 16 repost event with cached original', () async {
      // Create original video event
      final originalEvent = Event(
        'author456', // pubkey
        22, // kind
        [
          ['url', 'https://example.com/video.mp4'],
          ['title', 'Original Video'],
        ], // tags
        'Original video content', // content
        createdAt: 1000, // optional createdAt
      );
      // Manually set id for testing
      originalEvent.id = 'original123';

      // Create repost event
      final repostEvent = Event(
        'reposter101', // pubkey
        6, // kind
        [
          ['e', 'original123'],
          ['p', 'author456'],
        ], // tags
        '', // content
        createdAt: 2000, // optional createdAt
      );
      // Manually set id for testing
      repostEvent.id = 'repost789';

      // Subscribe and add events
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // First add the original video
      eventStreamController.add(originalEvent);

      // Allow processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Then add the repost
      eventStreamController.add(repostEvent);

      // Allow processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify we have 2 events (original + repost)
      expect(videoEventService.discoveryVideos.length, 2);

      // Find the repost event
      final repostVideoEvent = videoEventService.discoveryVideos.firstWhere(
        (e) => e.isRepost && e.reposterId == 'repost789',
      );

      // Verify repost metadata
      expect(repostVideoEvent.isRepost, true);
      expect(repostVideoEvent.reposterId, 'repost789');
      expect(repostVideoEvent.reposterPubkey, 'reposter101');
      expect(repostVideoEvent.repostedAt, isNotNull);

      // Verify original content is preserved
      expect(repostVideoEvent.id, 'original123');
      expect(repostVideoEvent.pubkey, 'author456');
      expect(repostVideoEvent.title, 'Original Video');
      expect(repostVideoEvent.videoUrl, 'https://example.com/video.mp4');
    });

    test(
      'should fetch original event for Kind 16 repost when not cached',
      () async {
        // Create repost event without original being cached
        final repostEvent = Event(
          'reposter101', // pubkey
          6, // kind
          [
            ['e', 'original123'],
            ['p', 'author456'],
          ], // tags
          '', // content
          createdAt: 2000, // optional createdAt
        );
        // Manually set id for testing
        repostEvent.id = 'repost789';

        // Subscribe and add repost event
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        eventStreamController.add(repostEvent);

        // Allow processing
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify that a new subscription was created to fetch the original event
        verify(
          mockNostrService.subscribeToEvents(
            filters: argThat(
              predicate<List<Filter>>((filters) {
                if (filters.isEmpty) return false;
                final filter = filters.first;
                return filter.ids != null &&
                    filter.ids!.contains('original123') &&
                    filter.kinds != null &&
                    filter.kinds!.contains(22);
              }),
              named: 'filters',
            ),
          ),
        ).called(greaterThan(0));
      },
    );

    test('should skip Kind 16 repost without e tag', () async {
      // Create invalid repost event without e tag
      final invalidRepostEvent = Event(
        'reposter101', // pubkey
        6, // kind
        [
          ['p', 'author456'], // Only p tag, no e tag
        ], // tags
        '', // content
        createdAt: 2000, // optional createdAt
      );
      // Manually set id for testing
      invalidRepostEvent.id = 'repost789';

      // Subscribe and add event
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      eventStreamController.add(invalidRepostEvent);

      // Allow processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify no events were added
      expect(videoEventService.discoveryVideos.length, 0);
    });

    test('should handle Kind 16 repost when original is not a video', () async {
      // Create a non-video event (e.g., a text note)
      final nonVideoEvent = Event(
        'author456', // pubkey
        1, // kind - Kind 1 is a text note
        [], // tags
        'This is a text note', // content
        createdAt: 1000, // optional createdAt
      );
      // Manually set id for testing
      nonVideoEvent.id = 'text123';

      // Create repost of non-video
      final repostEvent = Event(
        'reposter101', // pubkey
        6, // kind
        [
          ['e', 'text123'],
          ['p', 'author456'],
        ], // tags
        '', // content
        createdAt: 2000, // optional createdAt
      );
      // Manually set id for testing
      repostEvent.id = 'repost789';

      // Setup a separate stream for fetching original
      final fetchStreamController = StreamController<Event>.broadcast();
      when(
        mockNostrService.subscribeToEvents(
          filters: argThat(
            predicate<List<Filter>>(
              (filters) =>
                  filters.any((f) => f.ids?.contains('text123') ?? false),
            ),
            named: 'filters',
          ),
        ),
      ).thenAnswer((_) => fetchStreamController.stream);

      // Subscribe and add repost
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      eventStreamController.add(repostEvent);

      // Allow initial processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Simulate fetching the non-video original
      fetchStreamController.add(nonVideoEvent);

      // Allow fetch processing
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify no events were added since original is not a video
      expect(videoEventService.discoveryVideos.length, 0);

      fetchStreamController.close();
    });

    test('should apply hashtag filter to Kind 16 reposts', () async {
      // Create original video with hashtags
      final originalEvent = Event(
        'author456', // pubkey
        22, // kind
        [
          ['url', 'https://example.com/video.mp4'],
          ['t', 'nostr'],
          ['t', 'video'],
        ], // tags
        'Video about nostr', // content
        createdAt: 1000, // optional createdAt
      );
      // Manually set id for testing
      originalEvent.id = 'original123';

      // Create repost
      final repostEvent = Event(
        'reposter101', // pubkey
        6, // kind
        [
          ['e', 'original123'],
          ['p', 'author456'],
        ], // tags
        '', // content
        createdAt: 2000, // optional createdAt
      );
      // Manually set id for testing
      repostEvent.id = 'repost789';

      // Subscribe with hashtag filter
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        hashtags: ['bitcoin'],
      );

      // Add original and repost
      eventStreamController.add(originalEvent);
      await Future.delayed(const Duration(milliseconds: 50));
      eventStreamController.add(repostEvent);
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify no events were added (doesn't match hashtag filter)
      expect(videoEventService.discoveryVideos.length, 0);

      // Now subscribe with matching hashtag
      await videoEventService.unsubscribeFromVideoFeed();
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        hashtags: ['nostr'],
      );

      // Add events again
      eventStreamController.add(originalEvent);
      await Future.delayed(const Duration(milliseconds: 50));
      eventStreamController.add(repostEvent);
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify both events were added
      expect(videoEventService.discoveryVideos.length, 2);
    });
  });
}
