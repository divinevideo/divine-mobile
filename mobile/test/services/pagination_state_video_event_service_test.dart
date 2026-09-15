// ABOUTME: Tests pagination state behavior and its VideoEventService integration.
// ABOUTME: Covers result counts, cursors, resets, and load-more decisions.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/services/pagination_state.dart';
import 'package:openvine/services/video_event_service.dart'
    hide PaginationState;

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  late VideoEventService videoEventService;
  late _MockNostrClient mockNostrService;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  setUp(() {
    mockNostrService = _MockNostrClient();

    // Setup basic mock behavior
    when(() => mockNostrService.isInitialized).thenReturn(true);
    when(() => mockNostrService.publicKey).thenReturn('');
    when(
      () => mockNostrService.connectedRelayCount,
    ).thenReturn(3); // Mock having connected relays
    videoEventService = VideoEventService(
      mockNostrService,
      crashReporter: const SilentCrashReporter(),
    );
  });

  group('PaginationState', () {
    test('should initialize with hasMore=true and no events received', () {
      // Act
      final paginationState = PaginationState();

      // Assert
      expect(paginationState.hasMore, isTrue);
      expect(paginationState.isLoading, isFalse);
      expect(paginationState.eventsReceivedInCurrentQuery, equals(0));
      expect(paginationState.oldestTimestamp, isNull);
    });

    test(
      'should start query by resetting event counter and setting isLoading',
      () {
        // Arrange
        final paginationState = PaginationState();
        paginationState.eventsReceivedInCurrentQuery =
            5; // Simulate previous query

        // Act
        paginationState.startQuery();

        // Assert
        expect(paginationState.isLoading, isTrue);
        expect(paginationState.eventsReceivedInCurrentQuery, equals(0));
      },
    );

    test('should increment event counter correctly', () {
      // Arrange
      final paginationState = PaginationState();
      paginationState.startQuery();

      // Act
      paginationState.incrementEventCount();
      paginationState.incrementEventCount();
      paginationState.incrementEventCount();

      // Assert
      expect(paginationState.eventsReceivedInCurrentQuery, equals(3));
    });

    test('should record received count without lowering an existing tally', () {
      // Arrange
      final paginationState = PaginationState();
      paginationState.startQuery();
      paginationState.recordReceivedCount(5);

      // Act
      paginationState.recordReceivedCount(3);

      // Assert
      expect(paginationState.eventsReceivedInCurrentQuery, equals(5));
    });

    test(
      'should set hasMore=false when fewer events received than requested',
      () {
        // Arrange
        final paginationState = PaginationState();
        paginationState.startQuery();
        paginationState.incrementEventCount(); // Only 1 event received

        // Act
        paginationState.completeQuery(5); // But 5 were requested

        // Assert
        expect(paginationState.hasMore, isFalse);
        expect(paginationState.isLoading, isFalse);
      },
    );

    test(
      'should keep hasMore=true when equal events received as requested',
      () {
        // Arrange
        final paginationState = PaginationState();
        paginationState.startQuery();

        // Simulate receiving exactly the requested number of events
        for (var i = 0; i < 5; i++) {
          paginationState.incrementEventCount();
        }

        // Act
        paginationState.completeQuery(5); // Exactly 5 requested and received

        // Assert
        expect(paginationState.hasMore, isTrue);
        expect(paginationState.isLoading, isFalse);
      },
    );

    test(
      'should keep hasMore=true when more events received than requested',
      () {
        // Arrange
        final paginationState = PaginationState();
        paginationState.startQuery();

        // Simulate receiving more than requested (edge case)
        for (var i = 0; i < 7; i++) {
          paginationState.incrementEventCount();
        }

        // Act
        paginationState.completeQuery(5); // Only 5 requested but 7 received

        // Assert
        expect(paginationState.hasMore, isTrue);
        expect(paginationState.isLoading, isFalse);
      },
    );

    test('should track oldest timestamp correctly', () {
      // Arrange
      final paginationState = PaginationState();

      // Act
      paginationState.updateOldestTimestamp(1000);
      paginationState.updateOldestTimestamp(800); // Older
      paginationState.updateOldestTimestamp(1200); // Newer (should not update)

      // Assert
      expect(paginationState.oldestTimestamp, equals(800));
    });

    test('should reset all state correctly', () {
      // Arrange
      final paginationState = PaginationState();
      paginationState.startQuery();
      paginationState.incrementEventCount();
      paginationState.updateOldestTimestamp(1000);
      paginationState.markEventSeen('test-event-id');
      paginationState.hasMore = false;

      // Act
      paginationState.reset();

      // Assert
      expect(paginationState.hasMore, isTrue);
      expect(paginationState.isLoading, isFalse);
      expect(paginationState.eventsReceivedInCurrentQuery, equals(0));
      expect(paginationState.oldestTimestamp, isNull);
      expect(paginationState.seenEventIds, isEmpty);
    });
  });

  group('VideoEventService Pagination', () {
    test(
      'should reset and refetch when pagination state has no more content',
      () async {
        // Arrange - Get the pagination state and set hasMore=false
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        reset(mockNostrService);
        when(() => mockNostrService.isInitialized).thenReturn(true);
        when(() => mockNostrService.connectedRelayCount).thenReturn(3);

        // Access the pagination state and mark it as having no more
        // content. isLoading is still set from the subscribe above, and it
        // short-circuits loadMoreEvents first, so clear it — otherwise this
        // test passes on the already-loading guard the next test covers and
        // says nothing about hasMore.
        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;
        discoveryState
          ..isLoading = false
          ..hasMore = false;

        // Act
        await videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 50,
        );

        // Assert - hasMore=false does not stop the load. loadMoreEvents
        // resets the pagination state and queries again so a viewer who
        // reaches the end of the feed can keep scrolling.
        verify(() => mockNostrService.subscribe(any())).called(1);
        expect(discoveryState.hasMore, isTrue);
      },
    );

    test(
      'should return early when pagination state is already loading',
      () async {
        // Arrange
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        reset(mockNostrService);
        when(() => mockNostrService.isInitialized).thenReturn(true);

        // Set isLoading=true
        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;
        discoveryState.isLoading = true;

        // Act
        await videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 50,
        );

        // Assert - Should not create new subscriptions since already
        // loading
        verifyNever(() => mockNostrService.subscribe(any()));
      },
    );
  });

  group('Historical Events Processing', () {
    test(
      'should increment event counter when processing historical events',
      () async {
        // This test validates that historical events are properly counted
        // which is critical for the hasMore flag logic

        // Arrange
        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        final paginationStates = videoEventService
            .getPaginationStatesForTesting();
        final discoveryState = paginationStates[SubscriptionType.discovery]!;
        discoveryState.startQuery(); // Simulate starting a historical query

        // Act - Simulate processing historical events
        final mockEvent1 = _createMockVideoEvent('historical1', 1000);
        final mockEvent2 = _createMockVideoEvent('historical2', 900);

        // Add events as historical (this would normally be done by
        // _handleHistoricalVideoEvent)
        videoEventService.addVideoEventForTesting(
          mockEvent1,
          SubscriptionType.discovery,
          isHistorical: true,
        );
        videoEventService.addVideoEventForTesting(
          mockEvent2,
          SubscriptionType.discovery,
          isHistorical: true,
        );

        // Assert
        expect(discoveryState.eventsReceivedInCurrentQuery, equals(2));
      },
    );

    test('should not increment counter for real-time events during '
        'historical query', () async {
      // Arrange
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );

      final paginationStates = videoEventService
          .getPaginationStatesForTesting();
      final discoveryState = paginationStates[SubscriptionType.discovery]!;
      discoveryState.startQuery();

      // Act - Add a real-time event (not historical)
      final mockEvent = _createMockVideoEvent('realtime1', 1000);
      videoEventService.addVideoEventForTesting(
        mockEvent,
        SubscriptionType.discovery,
        isHistorical: false,
      );

      // Assert - Counter should not increment for real-time events
      expect(discoveryState.eventsReceivedInCurrentQuery, equals(0));
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
