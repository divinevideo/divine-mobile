// ABOUTME: TDD tests for VideoEventService infinite scroll with 'until' filter
// ABOUTME: Ensures proper pagination when reaching end of feed to load older content

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

import 'video_event_service_infinite_scroll_test.mocks.dart';

@GenerateMocks([INostrService, SubscriptionManager])
void main() {
  late VideoEventService videoEventService;
  late MockINostrService mockNostrService;
  late MockSubscriptionManager mockSubscriptionManager;

  setUp(() {
    mockNostrService = MockINostrService();
    mockSubscriptionManager = MockSubscriptionManager();

    // Setup basic mock behavior
    when(mockNostrService.isInitialized).thenReturn(true);
    when(mockNostrService.connectedRelayCount).thenReturn(3);
    when(
      mockSubscriptionManager.createSubscription(
        name: anyNamed('name'),
        filters: anyNamed('filters'),
        onEvent: anyNamed('onEvent'),
        onError: anyNamed('onError'),
        onComplete: anyNamed('onComplete'),
        timeout: anyNamed('timeout'),
        priority: anyNamed('priority'),
      ),
    ).thenAnswer((_) async => 'mock-subscription-id');

    videoEventService = VideoEventService(
      mockNostrService,
      subscriptionManager: mockSubscriptionManager,
    );
  });

  group('Infinite Scroll with Until Filter', () {
    test(
      'should use until filter when loading more events at end of feed',
      () async {
        // Arrange - Don't call subscribeToVideoFeed to avoid initial subscription
        // Just add events directly to establish state

        // Simulate having existing events with known timestamps
        final existingEvents = [
          _createMockVideoEvent('event1', 1704067200), // Jan 1, 2024 00:00:00
          _createMockVideoEvent('event2', 1704063600), // Dec 31, 2023 23:00:00
          _createMockVideoEvent('event3', 1704060000), // Dec 31, 2023 22:00:00
        ];

        // Add events to the service to establish oldest timestamp
        // The _addVideoToSubscription method automatically updates oldestTimestamp
        for (final event in existingEvents) {
          videoEventService.addVideoEventForTesting(
            event,
            SubscriptionType.discovery,
            isHistorical: false,
          );
        }

        // Verify the pagination state has the correct oldest timestamp
        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;
        expect(
          discoveryState.oldestTimestamp,
          equals(1704060000),
        ); // Should be automatically set

        // Setup mock for subscribeToEvents to capture the filter
        Filter? capturedFilter;
        final streamController = StreamController<Event>.broadcast();

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((invocation) {
          final filters = invocation.namedArguments[#filters] as List<Filter>;
          capturedFilter = filters.first;
          return streamController.stream;
        });

        // Act - Load more events (simulating reaching end of feed)
        videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 50);

        // Allow async operations to complete
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert - Verify that 'until' filter was applied with oldest timestamp
        verify(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).called(1);

        expect(capturedFilter, isNotNull);
        expect(capturedFilter!.until, equals(1704060000));
        expect(capturedFilter!.limit, equals(50));
        expect(capturedFilter!.kinds, contains(34236));

        // Cleanup
        await streamController.close();
      },
    );

    test('should not use until filter when no existing events', () async {
      // Arrange - Don't add any events, keep feed empty
      // Verify initial state
      final paginationStates = videoEventService
          .getPaginationStatesForTesting();
      final discoveryState = paginationStates[SubscriptionType.discovery]!;
      expect(
        discoveryState.oldestTimestamp,
        isNull,
      ); // Should be null initially

      // Setup mock for subscribeToEvents
      Filter? capturedFilter;
      final streamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((invocation) {
        final filters = invocation.namedArguments[#filters] as List<Filter>;
        capturedFilter = filters.first;
        return streamController.stream;
      });

      // Act - Load more events with empty feed
      videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 50);

      // Allow async operations to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert - Verify that no 'until' filter was applied
      verify(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).called(1);

      expect(capturedFilter, isNotNull);
      expect(
        capturedFilter!.until,
        isNull,
      ); // No until filter when no existing events
      expect(capturedFilter!.limit, equals(50));
      expect(capturedFilter!.kinds, contains(34236));

      // Cleanup
      await streamController.close();
    });

    test(
      'should properly update pagination state when receiving older events',
      () async {
        // Arrange - Add initial event to establish baseline
        final initialEvent = _createMockVideoEvent('initial', 1704067200);
        videoEventService.addVideoEventForTesting(
          initialEvent,
          SubscriptionType.discovery,
          isHistorical: false,
        );

        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;
        // The oldestTimestamp should already be set by addVideoEventForTesting
        expect(discoveryState.oldestTimestamp, equals(1704067200));

        // Setup stream for loadMoreEvents
        final streamController = StreamController<Event>.broadcast();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => streamController.stream);

        // Act - Load more and simulate receiving older events
        videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 3);
        discoveryState.startQuery();

        // Simulate receiving 3 older events through the stream
        final olderEvents = [
          _createMockNostrEvent('older1', 1704063600), // 1 hour older
          _createMockNostrEvent('older2', 1704060000), // 2 hours older
          _createMockNostrEvent('older3', 1704056400), // 3 hours older
        ];

        for (final event in olderEvents) {
          streamController.add(event);
          discoveryState.incrementEventCount();
          discoveryState.updateOldestTimestamp(event.createdAt);
        }

        // Complete the query
        discoveryState.completeQuery(3);

        // Assert
        expect(
          discoveryState.oldestTimestamp,
          equals(1704056400),
        ); // Should be oldest event
        expect(discoveryState.eventsReceivedInCurrentQuery, equals(3));
        expect(
          discoveryState.hasMore,
          isTrue,
        ); // Got exactly what we requested, so hasMore = true

        // Cleanup
        await streamController.close();
      },
    );

    test(
      'should set hasMore=false when fewer events received than requested',
      () async {
        // Arrange - Don't create initial subscription
        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;

        // Setup stream for loadMoreEvents
        final streamController = StreamController<Event>.broadcast();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => streamController.stream);

        // Act - Request 10 events but only receive 2
        videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 10);
        discoveryState.startQuery();

        // Simulate receiving only 2 events (less than requested)
        final fewEvents = [
          _createMockNostrEvent('event1', 1704063600),
          _createMockNostrEvent('event2', 1704060000),
        ];

        for (final event in fewEvents) {
          streamController.add(event);
          discoveryState.incrementEventCount();
        }

        // Complete the query
        discoveryState.completeQuery(10);

        // Assert
        expect(discoveryState.eventsReceivedInCurrentQuery, equals(2));
        expect(
          discoveryState.hasMore,
          isFalse,
        ); // Should be false since we got less than requested

        // Cleanup
        await streamController.close();
      },
    );

    test(
      'should continue loading older events with decreasing until timestamps',
      () async {
        // This test simulates multiple scroll-to-bottom events
        // Each should use the oldest timestamp from the previous load

        // Arrange - Don't create initial subscription
        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;

        final capturedFilters = <Filter>[];
        final streamController = StreamController<Event>.broadcast();

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((invocation) {
          final filters = invocation.namedArguments[#filters] as List<Filter>;
          capturedFilters.add(filters.first);
          return streamController.stream;
        });

        // First load - no until filter since no events yet
        videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 2);
        await Future.delayed(const Duration(milliseconds: 50));

        // Simulate receiving events and updating oldest timestamp
        // Add actual events to establish the oldest timestamp properly
        final firstBatchEvent = _createMockVideoEvent('batch1', 1704067200);
        videoEventService.addVideoEventForTesting(
          firstBatchEvent,
          SubscriptionType.discovery,
          isHistorical: true,
        );

        // Reset loading state but keep the oldest timestamp
        discoveryState.isLoading = false;
        discoveryState.hasMore = true;

        // Second load - should use until=1704067200
        videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 2);
        await Future.delayed(const Duration(milliseconds: 50));

        // Add more events with older timestamp
        final secondBatchEvent = _createMockVideoEvent('batch2', 1704060000);
        videoEventService.addVideoEventForTesting(
          secondBatchEvent,
          SubscriptionType.discovery,
          isHistorical: true,
        );

        // Reset loading state again
        discoveryState.isLoading = false;
        discoveryState.hasMore = true;

        // Third load - should use until=1704060000
        videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 2);
        await Future.delayed(const Duration(milliseconds: 50));

        // Assert - Check the progression of until filters
        expect(capturedFilters.length, greaterThanOrEqualTo(3));
        expect(capturedFilters[0].until, isNull); // First load has no until
        expect(
          capturedFilters[1].until,
          equals(1704067200),
        ); // Second load uses first timestamp
        expect(
          capturedFilters[2].until,
          equals(1704060000),
        ); // Third load uses second timestamp

        // Cleanup
        await streamController.close();
      },
    );

    test('should handle reaching true end of content gracefully', () async {
      // Arrange - Don't create initial subscription
      final paginationStates = videoEventService
          .getPaginationStatesForTesting();
      final discoveryState = paginationStates[SubscriptionType.discovery]!;

      // Add some initial events
      discoveryState.updateOldestTimestamp(1704067200);

      final streamController = StreamController<Event>.broadcast();
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => streamController.stream);

      // Act - Load more but receive no events (reached end)
      videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 50);
      discoveryState.startQuery();

      // Don't add any events - simulate end of content

      // Complete the query with 0 events
      discoveryState.completeQuery(50);

      // Assert
      expect(discoveryState.eventsReceivedInCurrentQuery, equals(0));
      expect(discoveryState.hasMore, isFalse); // No more content available
      expect(discoveryState.isLoading, isFalse);

      // Try to load more again - should exit early
      reset(mockNostrService);
      when(mockNostrService.isInitialized).thenReturn(true);

      // Reset the stream mock to ensure we're not accidentally triggering it
      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => streamController.stream);

      videoEventService.loadMoreEvents(SubscriptionType.discovery, limit: 50);
      await Future.delayed(const Duration(milliseconds: 50));

      // Should not make another subscription since hasMore=false
      verifyNever(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      );

      // Cleanup
      await streamController.close();
    });
  });
}

// Helper functions for creating mock data
VideoEvent _createMockVideoEvent(String id, int createdAt) {
  return VideoEvent(
    id: id,
    pubkey: 'mock-pubkey',
    createdAt: createdAt,
    content: 'Mock video content',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/video.mp4',
    title: 'Mock Video',
    hashtags: const ['test'],
  );
}

Event _createMockNostrEvent(String id, int createdAt) {
  // Create a valid 64-character hex pubkey (32 bytes = 64 hex chars)
  final validPubkey =
      '1234567890abcdef' * 4; // Repeat 16 chars 4 times = 64 chars

  return Event(
    validPubkey,
    34236, // kind - NIP-71 addressable short video
    [
      ['url', 'https://example.com/video.mp4'],
      ['title', 'Mock Video'],
      ['d', id], // Required d tag for kind 34236 events
    ], // tags
    'Mock video content', // content
    createdAt: createdAt,
  );
}
