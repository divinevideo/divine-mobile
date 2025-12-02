// ABOUTME: Tests for video pagination and relay loading in VideoEventService
// ABOUTME: Verifies that the service properly loads videos from relays when scrolling

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'dart:async';

@GenerateMocks([INostrService, SubscriptionManager])
import 'video_event_service_pagination_test.mocks.dart';

void main() {
  group('VideoEventService Pagination', () {
    late VideoEventService videoEventService;
    late MockINostrService mockNostrService;
    late MockSubscriptionManager mockSubscriptionManager;

    setUp(() {
      mockNostrService = MockINostrService();
      mockSubscriptionManager = MockSubscriptionManager();

      // Setup basic mock responses
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.connectedRelayCount).thenReturn(1);
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

    test(
      'should request new videos from relay when loadMoreEvents is called',
      () async {
        // Arrange
        final testEvents = [
          _createTestVideoEvent(
            'test1',
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
          _createTestVideoEvent(
            'test2',
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - 100,
          ),
        ];

        // Create a stream controller to control event emission
        final streamController = StreamController<Event>.broadcast();

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => streamController.stream);

        // Act
        final loadMoreFuture = videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 50,
        );

        // Emit test events
        for (final event in testEvents) {
          streamController.add(event);
        }

        // Close stream to signal completion
        streamController.close();

        // Wait for processing
        await loadMoreFuture;
        await Future.delayed(Duration(milliseconds: 100));

        // Assert - Verify the filter was created correctly
        final capturedFilters = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
          ),
        ).captured;

        expect(capturedFilters.isNotEmpty, true);
        final filters = capturedFilters.first as List<Filter>;
        expect(filters.isNotEmpty, true);
        expect(
          filters.first.kinds,
          contains(34236),
        ); // NIP-71 kind 34236 video events
        expect(filters.first.limit, greaterThan(0));
      },
    );

    test(
      'should reset pagination when hasMore is false but few videos exist',
      () async {
        // Arrange - simulate a state where pagination thinks there's no more content
        // First, set up initial state with some videos
        videoEventService.resetPaginationState(SubscriptionType.discovery);

        // Create a stream controller
        final streamController = StreamController<Event>.broadcast();

        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => streamController.stream);

        // Act - First load should work
        final firstLoad = videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 10,
        );

        // Emit fewer events than requested to trigger hasMore = false
        streamController.add(
          _createTestVideoEvent(
            'test1',
            DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );
        streamController.close();

        await firstLoad;
        await Future.delayed(Duration(milliseconds: 100));

        // Now try to load more - it should reset and allow loading
        final secondController = StreamController<Event>.broadcast();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => secondController.stream);

        final secondLoad = videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 50,
        );

        secondController.close();
        await secondLoad;

        // Assert - should have made two subscription calls
        verify(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).called(2);
      },
    );

    test('should handle empty responses from relay gracefully', () async {
      // Arrange
      final streamController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => streamController.stream);

      // Act
      final loadMoreFuture = videoEventService.loadMoreEvents(
        SubscriptionType.discovery,
        limit: 50,
      );

      // Close stream immediately without emitting events
      streamController.close();

      // Should complete without error
      await expectLater(loadMoreFuture, completes);
    });

    test(
      'should use oldest timestamp from existing events after pagination reset',
      () async {
        // This test ensures that when pagination is reset due to hasMore=false,
        // the until parameter uses the oldest timestamp from existing events
        // to properly request older content from the relay

        // Arrange - Add some initial events with specific timestamps
        final oldestTimestamp =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - 3600; // 1 hour ago
        final newerTimestamp =
            DateTime.now().millisecondsSinceEpoch ~/ 1000 - 1800; // 30 min ago

        // First subscription to get initial events
        final firstStreamController = StreamController<Event>.broadcast();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => firstStreamController.stream);

        await videoEventService.subscribeToVideoFeed(
          subscriptionType: SubscriptionType.discovery,
          limit: 10,
        );

        // Emit initial events with specific timestamps
        firstStreamController.add(
          _createTestVideoEvent('oldest', oldestTimestamp),
        );
        firstStreamController.add(
          _createTestVideoEvent('newer', newerTimestamp),
        );
        firstStreamController.close();

        await Future.delayed(Duration(milliseconds: 100));

        // Reset mock for next query
        reset(mockNostrService);
        when(mockNostrService.isInitialized).thenReturn(true);
        when(mockNostrService.connectedRelayCount).thenReturn(1);

        // Now test that pagination reset preserves the oldest timestamp
        videoEventService.resetPaginationState(SubscriptionType.discovery);

        final secondStreamController = StreamController<Event>.broadcast();
        when(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        ).thenAnswer((_) => secondStreamController.stream);

        // Act - Load more events after reset
        final loadMoreFuture = videoEventService.loadMoreEvents(
          SubscriptionType.discovery,
          limit: 50,
        );

        secondStreamController.close();
        await loadMoreFuture;

        // Assert - Verify the filter used the oldest timestamp as 'until'
        final capturedFilters = verify(
          mockNostrService.subscribeToEvents(
            filters: captureAnyNamed('filters'),
          ),
        ).captured;

        expect(capturedFilters.isNotEmpty, true);
        final filters = capturedFilters.first as List<Filter>;
        expect(filters.isNotEmpty, true);

        // The filter should have 'until' set to the oldest timestamp from existing events
        // This ensures we get older videos, not the same ones again
        expect(filters.first.until, equals(oldestTimestamp));
      },
    );
  });
}

// Helper function to create test video events
Event _createTestVideoEvent(String id, int timestamp) {
  // Event constructor: Event(pubkey, kind, tags, content, {createdAt})
  return Event(
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // 64-char hex pubkey
    34236, // kind
    [
      ['d', 'video_$id'],
      ['url', 'https://example.com/video_$id.mp4'],
      ['thumb', 'https://example.com/thumb_$id.jpg'],
    ], // tags
    'Test video $id', // content
    createdAt: timestamp,
  );
}
