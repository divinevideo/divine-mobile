// ABOUTME: Tests for SubscriptionManager smart event cache pruning
// ABOUTME: Verifies that cached events are not re-requested from relay

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subscription_manager.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('SubscriptionManager Event Cache Pruning', () {
    late _MockNostrClient mockNostrService;
    late StreamController<Event> eventController;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      mockNostrService = _MockNostrClient();
      eventController = StreamController<Event>.broadcast();

      when(
        () => mockNostrService.subscribe(any()),
      ).thenAnswer((_) => eventController.stream);
    });

    tearDown(() => eventController.close());

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
          onEvent: deliveredEvents.add,
          onComplete: () => completeCalled = true,
        );

        await pumpEventQueue();

        // Assert: Cached event delivered
        expect(deliveredEvents.length, 1);
        expect(deliveredEvents[0].id, cachedEvent1.id);

        // Assert: No relay subscription created
        verifyNever(() => mockNostrService.subscribe(any()));

        // Assert: onComplete was called immediately
        expect(completeCalled, true);
      },
    );
  });
}
