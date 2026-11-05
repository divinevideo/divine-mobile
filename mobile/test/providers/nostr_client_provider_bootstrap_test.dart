// ABOUTME: Tests the bootstrap kind:10002 publish gate in NostrService.
// ABOUTME: Only an indexer acceptance may report the relay list as published.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  const primaryRelay = 'wss://relay.divine.video';
  final indexer = IndexerRelayConfig.defaultIndexers.first;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group('NostrService.bootstrapCallbackFor', () {
    late _MockNostrClient client;
    late Event event;
    late List<String> targets;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      client = _MockNostrClient();
      event = Event('0' * 64, 10002, [
        ['r', primaryRelay],
      ], '');
      when(() => client.publicKey).thenReturn(event.pubkey);
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: false, noRelays: false),
      );
      targets = [primaryRelay, ...IndexerRelayConfig.defaultIndexers];
    });

    void stubOutcome(PublishOutcome outcome) {
      when(
        () => client.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => outcome);
    }

    test(
      'does not replace an existing relay list missed by discovery',
      () async {
        when(
          () => client.queryEventsDetailed(
            any(),
            useCache: false,
            requireAllRelaysSettled: true,
            tempRelays: any(named: 'tempRelays'),
          ),
        ).thenAnswer(
          (_) async => (events: [event], timedOut: false, noRelays: false),
        );
        stubOutcome(
          PublishOutcome(
            eventId: event.id,
            acceptedBy: [indexer],
            rejectedBy: const {},
            noResponseFrom: const [],
          ),
        );

        await NostrService.bootstrapCallbackFor(client)(event, targets);

        verifyNever(
          () => client.publishEventAwaitOk(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      },
    );

    test('does not bootstrap after an inconclusive relay read', () async {
      when(
        () => client.queryEventsDetailed(
          any(),
          useCache: false,
          requireAllRelaysSettled: true,
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer(
        (_) async => (events: <Event>[], timedOut: true, noRelays: false),
      );
      stubOutcome(
        PublishOutcome(
          eventId: event.id,
          acceptedBy: [indexer],
          rejectedBy: const {},
          noResponseFrom: const [],
        ),
      );

      expect(
        await NostrService.bootstrapCallbackFor(client)(event, targets),
        isFalse,
      );
      verifyNever(
        () => client.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      );
    });

    test('reports not-published when only the Divine relay accepted', () async {
      // The caller records a permanent "already bootstrapped" flag on true,
      // and discovery never queries the Divine relay — so accepting this
      // would strand the user on the fallback relay set forever.
      stubOutcome(
        const PublishOutcome(
          eventId: 'bootstrap-event',
          acceptedBy: [primaryRelay],
          rejectedBy: {},
          noResponseFrom: [],
          unreachableTargets: IndexerRelayConfig.defaultIndexers,
        ),
      );

      expect(
        await NostrService.bootstrapCallbackFor(client)(event, targets),
        isFalse,
      );
    });

    test('reports published when one indexer accepted', () async {
      stubOutcome(
        PublishOutcome(
          eventId: 'bootstrap-event',
          acceptedBy: [primaryRelay, indexer],
          rejectedBy: const {},
          noResponseFrom: const [],
          unreachableTargets: IndexerRelayConfig.defaultIndexers
              .where((relay) => relay != indexer)
              .toList(),
        ),
      );

      expect(
        await NostrService.bootstrapCallbackFor(client)(event, targets),
        isTrue,
      );
    });

    test('reports not-published when nothing accepted', () async {
      stubOutcome(
        PublishOutcome(
          eventId: 'bootstrap-event',
          acceptedBy: const [],
          rejectedBy: const {},
          noResponseFrom: const [],
          unreachableTargets: targets,
        ),
      );

      expect(
        await NostrService.bootstrapCallbackFor(client)(event, targets),
        isFalse,
      );
    });
  });
}
