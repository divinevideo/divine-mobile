// ABOUTME: Tests SubscriptionManager event forwarding and filter preservation.
// ABOUTME: Replaces the stale red-phase and commented-out legacy test suites.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subscription_manager.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  setUpAll(() => registerFallbackValue(<Filter>[]));

  group(SubscriptionManager, () {
    late _MockNostrClient client;
    late StreamController<Event> events;
    late SubscriptionManager manager;

    setUp(() {
      client = _MockNostrClient();
      events = StreamController<Event>.broadcast();
      when(() => client.subscribe(any())).thenAnswer((_) => events.stream);
      manager = SubscriptionManager(client);
    });

    tearDown(() async {
      await manager.dispose();
      await events.close();
    });

    test('forwards subscribed events to the callback', () async {
      final received = <Event>[];
      final event = Event('a' * 64, 22, const [], 'video')..id = 'b' * 64;
      final subscriptionId = await manager.createSubscription(
        name: 'videos',
        filters: [
          Filter(kinds: [22]),
        ],
        onEvent: received.add,
      );

      events.add(event);
      await pumpEventQueue();

      expect(received, [same(event)]);
      await manager.cancelSubscription(subscriptionId);
    });

    test('preserves tag filters while capping the relay limit', () async {
      final filter = Filter(
        kinds: [22],
        authors: ['c' * 64],
        t: const ['vine', 'funny'],
        h: const ['group'],
        e: ['d' * 64],
        p: ['e' * 64],
        limit: 250,
      );

      await manager.createSubscription(
        name: 'filtered',
        filters: [filter],
        onEvent: (_) {},
      );

      final captured = verify(() => client.subscribe(captureAny())).captured;
      final forwarded = (captured.single as List<Filter>).single;
      expect(forwarded.kinds, [22]);
      expect(forwarded.authors, ['c' * 64]);
      expect(forwarded.t, const ['vine', 'funny']);
      expect(forwarded.h, const ['group']);
      expect(forwarded.e, ['d' * 64]);
      expect(forwarded.p, ['e' * 64]);
      expect(forwarded.limit, 100);
    });

    test('reports completion when every requested event is cached', () async {
      final cached = Event('f' * 64, 1, const [], 'cached')..id = '1' * 64;
      final received = <Event>[];
      var completed = false;
      final cachedManager = SubscriptionManager(
        client,
        getCachedEvent: (id) => id == cached.id ? cached : null,
      );
      addTearDown(cachedManager.dispose);

      await cachedManager.createSubscription(
        name: 'cached',
        filters: [
          Filter(ids: [cached.id]),
        ],
        onEvent: received.add,
        onComplete: () => completed = true,
      );
      await pumpEventQueue();

      expect(received, [same(cached)]);
      expect(completed, isTrue);
      verifyNever(() => client.subscribe(any()));
    });
  });
}
