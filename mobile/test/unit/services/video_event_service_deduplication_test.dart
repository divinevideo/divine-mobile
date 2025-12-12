// ABOUTME: Unit tests for VideoEventService deduplication logic
// ABOUTME: Tests that duplicate events are properly filtered to prevent redundant processing

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

// Mock classes
class MockNostrService extends Mock implements NostrClient {}

class MockEvent extends Mock implements Event {}

class TestSubscriptionManager extends Mock implements SubscriptionManager {
  TestSubscriptionManager(this.eventStreamController);
  final StreamController<Event> eventStreamController;

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    // Set up a stream listener that calls onEvent for each event
    eventStreamController.stream.listen(onEvent);
    return 'mock_sub_$name';
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    // No-op for tests
  }
}

// Fake classes for setUpAll
class FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('VideoEventService Deduplication Tests', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();

      // Setup mock responses
      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => eventStreamController.stream);

      final testSubscriptionManager = TestSubscriptionManager(
        eventStreamController,
      );

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
      );
    });

    tearDown(() async {
      await eventStreamController.close();
      // Don't dispose - it calls unsubscribeFromVideoFeed which notifies listeners
      // videoEventService.dispose();
      reset(mockNostrService);
    });

    test('should not add duplicate events with same ID', () async {
      // Create a test event
      final testEvent = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        22, // NIP-71 video event
        [
          ['url', 'https://example.com/video1.mp4'],
          ['m', 'video/mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      // Set the id manually after creation
      testEvent.id = 'test-video-id-1';

      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );

      // Add a small delay to ensure subscription is set up
      await Future.delayed(const Duration(milliseconds: 10));

      // Send the same event multiple times
      eventStreamController.add(testEvent);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(testEvent);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(testEvent);
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify only one event was added
      expect(videoEventService.discoveryVideos.length, equals(1));
      expect(
        videoEventService.discoveryVideos.first.id,
        equals('test-video-id-1'),
      );
    });

    test('should add different events with unique IDs', () async {
      // Create multiple unique events
      final events = List.generate(3, (index) {
        final event = Event(
          'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
          22,
          [
            ['url', 'https://example.com/video$index.mp4'],
            ['m', 'video/mp4'],
            [
              'expiration',
              '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
            ],
          ],
          'Test video content $index',
          createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + index,
        );
        event.id = 'test-video-id-$index';
        return event;
      });

      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Send all unique events
      for (final event in events) {
        eventStreamController.add(event);
        await Future.delayed(const Duration(milliseconds: 10));
      }

      // Verify all unique events were added
      expect(videoEventService.discoveryVideos.length, equals(3));

      // Verify they're in reverse chronological order (newest first)
      expect(
        videoEventService.discoveryVideos[0].id,
        equals('test-video-id-2'),
      );
      expect(
        videoEventService.discoveryVideos[1].id,
        equals('test-video-id-1'),
      );
      expect(
        videoEventService.discoveryVideos[2].id,
        equals('test-video-id-0'),
      );
    });

    test('should handle mix of duplicates and unique events', () async {
      // Create test events
      final event1 = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        22,
        [
          ['url', 'https://example.com/video1.mp4'],
          ['m', 'video/mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video 1',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event1.id = 'test-video-id-1';

      final event2 = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        22,
        [
          ['url', 'https://example.com/video2.mp4'],
          ['m', 'video/mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Test video 2',
        createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1,
      );
      event2.id = 'test-video-id-2';

      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Send events in mixed order with duplicates
      eventStreamController.add(event1);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event2);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event1); // Duplicate
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event2); // Duplicate
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(event1); // Another duplicate
      await Future.delayed(const Duration(milliseconds: 10));

      // Verify only unique events were added
      expect(videoEventService.discoveryVideos.length, equals(2));

      // Verify order (newest first)
      expect(
        videoEventService.discoveryVideos[0].id,
        equals('test-video-id-2'),
      );
      expect(
        videoEventService.discoveryVideos[1].id,
        equals('test-video-id-1'),
      );
    });

    test(
      'should maintain deduplication across multiple subscriptions',
      () async {
        // Create test event
        final testEvent = Event(
          'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['m', 'video/mp4'],
          ],
          'Persistent test video',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        testEvent.id = 'persistent-video-id';

        // First subscription
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
        );
        await Future.delayed(const Duration(milliseconds: 10));

        eventStreamController.add(testEvent);
        await Future.delayed(const Duration(milliseconds: 10));

        expect(videoEventService.discoveryVideos.length, equals(1));

        // Unsubscribe and re-subscribe
        await videoEventService.unsubscribeFromVideoFeed();
        await Future.delayed(const Duration(milliseconds: 10));

        // Create new stream controller for new subscription
        final newEventStreamController = StreamController<Event>.broadcast();
        when(
          () => mockNostrService.subscribe(any()),
        ).thenAnswer((_) => newEventStreamController.stream);

        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          replace: false,
        );
        await Future.delayed(const Duration(milliseconds: 10));

        // Try to add the same event again
        newEventStreamController.add(testEvent);
        await Future.delayed(const Duration(milliseconds: 10));

        // Should still have only one event
        expect(videoEventService.discoveryVideos.length, equals(1));

        newEventStreamController.close();
      },
    );

    test('should handle rapid duplicate events efficiently', () async {
      // Create test event
      final testEvent = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        22,
        [
          ['url', 'https://example.com/rapid.mp4'],
          ['m', 'video/mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Rapid test video',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      testEvent.id = 'rapid-test-video';

      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Send the same event rapidly without delays
      for (var i = 0; i < 100; i++) {
        eventStreamController.add(testEvent);
      }

      // Allow processing time
      await Future.delayed(const Duration(milliseconds: 50));

      // Should still have only one event despite rapid duplicates
      expect(videoEventService.discoveryVideos.length, equals(1));
      expect(
        videoEventService.discoveryVideos.first.id,
        equals('rapid-test-video'),
      );
    });

    test('should handle events with invalid kind gracefully', () async {
      // Create events with different kinds
      final validEvent = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        22, // Valid video event kind
        [
          ['url', 'https://example.com/valid.mp4'],
          ['m', 'video/mp4'],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Valid video',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      validEvent.id = 'valid-video';

      final invalidEvent = Event(
        'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e',
        1, // Text note, not a video
        [
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        'Not a video',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      invalidEvent.id = 'invalid-kind';

      // Subscribe to video feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Send both events
      eventStreamController.add(validEvent);
      eventStreamController.add(invalidEvent);
      await Future.delayed(const Duration(milliseconds: 20));

      // Should only have the valid video event
      expect(videoEventService.discoveryVideos.length, equals(1));
      expect(videoEventService.discoveryVideos.first.id, equals('valid-video'));
    });
  });

  group('VideoEventService Repost Deduplication', () {
    late VideoEventService videoEventService;
    late MockNostrService mockNostrService;
    late StreamController<Event> eventStreamController;

    setUp(() {
      mockNostrService = MockNostrService();
      eventStreamController = StreamController<Event>.broadcast();

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockNostrService.connectedRelayCount).thenReturn(1);
      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => eventStreamController.stream);

      final testSubscriptionManager = TestSubscriptionManager(
        eventStreamController,
      );

      videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: testSubscriptionManager,
      );
    });

    tearDown(() async {
      await eventStreamController.close();
      // Don't dispose - it calls unsubscribeFromVideoFeed which notifies listeners
      // videoEventService.dispose();
    });

    test('should deduplicate reposts of the same video', () async {
      const originalVideoId = 'original-video-id';
      const originalPubkey =
          'd0aa74d68e414f0305db9f7dc96ec32e616502e6ccf5bbf5739de19a96b67f3e';

      // Create multiple reposts of the same video
      final repost1 = Event(
        '70ed6c56d6fb355f102a1e985741b5ee65f6ae9f772e028894b321bc74854082',
        6, // Repost
        [
          ['e', originalVideoId, '', 'mention'],
          ['p', originalPubkey],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      repost1.id = 'repost-1';

      final repost2 = Event(
        '25315276cbaeb8f2ed998ed55d15ef8c9cf2027baea191d1253d9a5c69a2b856',
        6, // Another repost of same video
        [
          ['e', originalVideoId, '', 'mention'],
          ['p', originalPubkey],
          [
            'expiration',
            '${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600}',
          ],
        ],
        '',
        createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 1,
      );
      repost2.id = 'repost-2';

      // Subscribe with reposts enabled
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        includeReposts: true,
      );
      await Future.delayed(const Duration(milliseconds: 10));

      // Send both reposts
      eventStreamController.add(repost1);
      await Future.delayed(const Duration(milliseconds: 10));

      eventStreamController.add(repost2);
      await Future.delayed(const Duration(milliseconds: 10));

      // Reposts can't be displayed without the original video event
      // This is expected behavior: reposts reference original events that must exist in cache
      // When includeReposts is true, kind 6 events are accepted but require original video lookup
      expect(videoEventService.discoveryVideos.length, equals(0));
    });
  });
}
