// ABOUTME: Tests for SubscriptionManager smart event cache pruning
// ABOUTME: Verifies that cached events are not re-requested from relay

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';

@GenerateNiceMocks([MockSpec<INostrService>()])
import 'subscription_manager_cache_test.mocks.dart';

void main() {
  group('SubscriptionManager Event Cache Pruning', () {
    late MockINostrService mockNostrService;
    late StreamController<Event> eventController;

    setUp(() {
      mockNostrService = MockINostrService();
      eventController = StreamController<Event>.broadcast();

      when(
        mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
      ).thenAnswer((_) => eventController.stream);
    });

    tearDown(() {
      eventController.close();
    });

    test(
      'should prune cached event IDs from filter and deliver cached events immediately',
      () async {
        // Arrange: Create mock cached events
        final cachedEvent1 = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          0,
          [],
          '{"name": "User 1"}',
        );

        final cachedEvent2 = Event(
          'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
          1,
          [],
          'Note content',
        );

        // Use event IDs as cache keys
        final cachedEvents = {
          cachedEvent1.id: cachedEvent1,
          cachedEvent2.id: cachedEvent2,
        };

        // Cache lookup function
        Event? getCachedEvent(String eventId) => cachedEvents[eventId];

        final manager = SubscriptionManager(
          mockNostrService,
          getCachedEvent: getCachedEvent,
        );

        // Track which events were delivered
        final deliveredEvents = <Event>[];

        // Act: Create subscription requesting 3 events (2 cached, 1 not)
        final filter = Filter(
          ids: [cachedEvent1.id, cachedEvent2.id, 'uncached_id_3'],
        );

        await manager.createSubscription(
          name: 'test_subscription',
          filters: [filter],
          onEvent: (event) => deliveredEvents.add(event),
        );

        // Wait for microtasks to complete (cached events delivered async)
        await Future.delayed(Duration.zero);

        // Assert: Cached events should be delivered immediately
        expect(deliveredEvents.length, 2);
        expect(
          deliveredEvents.map((e) => e.id),
          containsAll([cachedEvent1.id, cachedEvent2.id]),
        );

        // Assert: Relay subscription should only request uncached event
        final capturedFilter =
            verify(
                  mockNostrService.subscribeToEvents(
                    filters: captureAnyNamed('filters'),
                  ),
                ).captured.single
                as List<Filter>;

        expect(capturedFilter.length, 1);
        expect(capturedFilter[0].ids, ['uncached_id_3']);
      },
    );

    test(
      'should skip relay subscription entirely if all events are cached',
      () async {
        // Arrange: Create mock cached events
        final cachedEvent1 = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          0,
          [],
          '{}',
        );

        final cachedEvents = {cachedEvent1.id: cachedEvent1};
        Event? getCachedEvent(String eventId) => cachedEvents[eventId];

        final manager = SubscriptionManager(
          mockNostrService,
          getCachedEvent: getCachedEvent,
        );

        final deliveredEvents = <Event>[];
        var completeCalled = false;

        // Act: Request only cached events
        final filter = Filter(ids: [cachedEvent1.id]);

        await manager.createSubscription(
          name: 'test_subscription',
          filters: [filter],
          onEvent: (event) => deliveredEvents.add(event),
          onComplete: () => completeCalled = true,
        );

        await Future.delayed(Duration.zero);

        // Assert: Cached event delivered
        expect(deliveredEvents.length, 1);
        expect(deliveredEvents[0].id, cachedEvent1.id);

        // Assert: No relay subscription created
        verifyNever(
          mockNostrService.subscribeToEvents(filters: anyNamed('filters')),
        );

        // Assert: onComplete was called immediately
        expect(completeCalled, true);
      },
    );

    test(
      'should work with filters without event IDs (pass through unchanged)',
      () async {
        // Arrange
        final manager = SubscriptionManager(
          mockNostrService,
          getCachedEvent: (_) => null,
        );

        // Act: Create subscription without event IDs
        final filter = Filter(kinds: [0, 1], authors: ['pubkey1', 'pubkey2']);

        await manager.createSubscription(
          name: 'test_subscription',
          filters: [filter],
          onEvent: (_) {},
        );

        // Assert: Filter passed through unchanged
        final capturedFilter =
            verify(
                  mockNostrService.subscribeToEvents(
                    filters: captureAnyNamed('filters'),
                  ),
                ).captured.single
                as List<Filter>;

        expect(capturedFilter.length, 1);
        expect(capturedFilter[0].kinds, [0, 1]);
        expect(capturedFilter[0].authors, ['pubkey1', 'pubkey2']);
        expect(capturedFilter[0].ids, null);
      },
    );

    test(
      'should work without cache function (pass through all events)',
      () async {
        // Arrange: No cache function provided
        final manager = SubscriptionManager(mockNostrService);

        // Act: Create subscription with event IDs
        final filter = Filter(ids: ['id1', 'id2']);

        await manager.createSubscription(
          name: 'test_subscription',
          filters: [filter],
          onEvent: (_) {},
        );

        // Assert: All event IDs passed to relay (no caching)
        final capturedFilter =
            verify(
                  mockNostrService.subscribeToEvents(
                    filters: captureAnyNamed('filters'),
                  ),
                ).captured.single
                as List<Filter>;

        expect(capturedFilter.length, 1);
        expect(capturedFilter[0].ids, ['id1', 'id2']);
      },
    );

    test('should handle mixed filters (some with IDs, some without)', () async {
      // Arrange
      final cachedEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        0,
        [],
        '{}',
      );

      final manager = SubscriptionManager(
        mockNostrService,
        getCachedEvent: (id) => id == cachedEvent.id ? cachedEvent : null,
      );

      final deliveredEvents = <Event>[];

      // Act: Multiple filters, one with IDs, one without
      final filter1 = Filter(ids: [cachedEvent.id, 'uncached_id']);
      final filter2 = Filter(kinds: [1], authors: ['pubkey1']);

      await manager.createSubscription(
        name: 'test_subscription',
        filters: [filter1, filter2],
        onEvent: (event) => deliveredEvents.add(event),
      );

      await Future.delayed(Duration.zero);

      // Assert: Cached event delivered
      expect(deliveredEvents.length, 1);
      expect(deliveredEvents[0].id, cachedEvent.id);

      // Assert: Both filters sent to relay (filter1 pruned, filter2 unchanged)
      final capturedFilters =
          verify(
                mockNostrService.subscribeToEvents(
                  filters: captureAnyNamed('filters'),
                ),
              ).captured.single
              as List<Filter>;

      expect(capturedFilters.length, 2);
      expect(capturedFilters[0].ids, ['uncached_id']);
      expect(capturedFilters[1].kinds, [1]);
      expect(capturedFilters[1].authors, ['pubkey1']);
    });
  });
}
