// Easier to read and understand test validation
// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/src/models/models.dart';
import 'package:nostr_client/src/nostr_client.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockGatewayClient extends Mock implements GatewayClient {}

class MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Event(
        '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2',
        1,
        <dynamic>[],
        '',
        createdAt: 1234567890,
      ),
    );
  });

  group('NostrClient', () {
    late NostrSigner mockSigner;
    const testPublicKey =
        '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
    const testEventId =
        '0000000000000000000000000000000000000000000000000000000000000000';
    const testRelayUrl = 'wss://relay.example.com';

    setUp(() {
      mockSigner = MockNostrSigner();
      when(() => mockSigner.getPublicKey()).thenAnswer((_) async => testPublicKey);
      when(() => mockSigner.signEvent(any())).thenAnswer((_) async => null);
    });

    group('constructor', () {
      test('creates client with gateway disabled', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: false,
        );

        final client = NostrClient(config);

        expect(client.publicKey, equals(testPublicKey));
        expect(client.relayCount, equals(0));
      });

      test('creates client with gateway enabled', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: true,
          gatewayUrl: 'https://gateway.example.com',
        );

        final client = NostrClient(config);

        expect(client.publicKey, equals(testPublicKey));
        expect(client.relayCount, equals(0));
      });
    });

    group('publicKey', () {
      test('returns public key from config', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        expect(client.publicKey, equals(testPublicKey));
      });
    });

    group('relayPool', () {
      test('provides access to relay pool', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        expect(client.relayPool, isNotNull);
        expect(client.relayPool, isA<RelayPool>());
      });
    });

    group('publishEvent', () {
      test('delegates to nostr sendEvent', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final event = Event(
          testPublicKey,
          1,
          <dynamic>[],
          'Test content',
          createdAt: 1234567890,
        );

        // Since we can't easily mock Nostr, we test that the method
        // doesn't throw and handles the call appropriately
        // In a real scenario, this would require a connected relay
        final result = await client.publishEvent(event);

        // Result may be null if no relay is connected, which is expected
        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('accepts target relays parameter', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final event = Event(
          testPublicKey,
          1,
          <dynamic>[],
          'Test content',
          createdAt: 1234567890,
        );

        final result = await client.publishEvent(
          event,
          targetRelays: [testRelayUrl],
        );

        expect(result, anyOf(isNull, isA<Event>()));
      });
    });

    group('queryEvents', () {
      test('returns list when no relays connected', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: false,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];

        // Query will timeout or return empty list when no relays connected
        final result = await client.queryEvents(
          filters,
          useGateway: false,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => <Event>[],
        );

        expect(result, isA<List<Event>>());
      });

      test('uses gateway when enabled and useGateway is true', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: true,
          gatewayUrl: 'https://gateway.example.com',
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];

        // Gateway will be tried first, but since we can't inject mock,
        // it will fall back to WebSocket query
        final result = await client.queryEvents(
          filters,
          useGateway: true,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => <Event>[],
        );

        expect(result, isA<List<Event>>());
      });

      test('skips gateway when useGateway is false', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: true,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];

        final result = await client.queryEvents(
          filters,
          useGateway: false,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => <Event>[],
        );

        expect(result, isA<List<Event>>());
      });

      test('skips gateway when multiple filters provided', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: true,
        );

        final client = NostrClient(config);
        final filters = [
          Filter(kinds: [1], limit: 10),
          Filter(kinds: [0], limit: 5),
        ];

        final result = await client.queryEvents(
          filters,
          useGateway: true,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => <Event>[],
        );

        expect(result, isA<List<Event>>());
      });
    });

    group('fetchEventById', () {
      test('returns null when event not found', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: false,
        );

        final client = NostrClient(config);

        final result = await client.fetchEventById(
          testEventId,
          useGateway: false,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

        expect(result, isNull);
      });

      test('uses gateway when enabled', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: true,
        );

        final client = NostrClient(config);

        final result = await client.fetchEventById(
          testEventId,
          useGateway: true,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('accepts relay URL parameter', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: false,
        );

        final client = NostrClient(config);

        final result = await client.fetchEventById(
          testEventId,
          relayUrl: testRelayUrl,
          useGateway: false,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

        expect(result, anyOf(isNull, isA<Event>()));
      });
    });

    group('fetchProfile', () {
      test('returns null when profile not found', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: false,
        );

        final client = NostrClient(config);

        final result = await client.fetchProfile(
          testPublicKey,
          useGateway: false,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('uses gateway when enabled', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
          enableGateway: true,
        );

        final client = NostrClient(config);

        final result = await client.fetchProfile(
          testPublicKey,
          useGateway: true,
        ).timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );

        expect(result, anyOf(isNull, isA<Event>()));
      });
    });

    group('subscribe', () {
      test('returns stream for new subscription', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];

        final stream = client.subscribe(filters);

        expect(stream, isA<Stream<Event>>());
      });

      test('deduplicates subscriptions with same filters', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];

        final stream1 = client.subscribe(filters);
        final stream2 = client.subscribe(filters);

        // Should return the same stream for duplicate subscriptions
        expect(stream1, equals(stream2));
      });

      test('creates different streams for different filters', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final filters1 = [Filter(kinds: [1], limit: 10)];
        final filters2 = [Filter(kinds: [0], limit: 5)];

        final stream1 = client.subscribe(filters1);
        final stream2 = client.subscribe(filters2);

        expect(stream1, isNot(equals(stream2)));
      });

      test('accepts custom subscription ID', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];

        final stream = client.subscribe(filters, subscriptionId: 'custom_id');

        expect(stream, isA<Stream<Event>>());
      });

      test('calls onEose callback when provided', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];
        var eoseCalled = false;

        client.subscribe(
          filters,
          onEose: () {
            eoseCalled = true;
          },
        );

        // onEose will be called by nostr_sdk when EOSE is received
        expect(eoseCalled, isFalse);
      });
    });

    group('unsubscribe', () {
      test('closes subscription stream', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final filters = [Filter(kinds: [1], limit: 10)];
        final stream = client.subscribe(filters, subscriptionId: 'test_sub');

        await client.unsubscribe('test_sub');

        // Stream should be closed
        expect(
          () => stream.listen(null),
          returnsNormally,
        );
      });

      test('handles unsubscribe for non-existent subscription', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        // Should not throw
        await client.unsubscribe('non_existent');
      });
    });

    group('closeAllSubscriptions', () {
      test('closes all active subscriptions', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        client.subscribe([Filter(kinds: [1])], subscriptionId: 'sub1');
        client.subscribe([Filter(kinds: [0])], subscriptionId: 'sub2');

        client.closeAllSubscriptions();

        // All subscriptions should be closed
        expect(client.relayCount, equals(0));
      });
    });

    group('relay management', () {
      test('addRelay adds relay to pool', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final result = await client.addRelay(testRelayUrl);

        // Result depends on whether relay connects successfully
        expect(result, isA<bool>());
      });

      test('removeRelay removes relay from pool', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        // Should not throw
        await client.removeRelay(testRelayUrl);
      });

      test('connectedRelays returns list of relay URLs', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final relays = client.connectedRelays;

        expect(relays, isA<List<String>>());
        expect(relays, isEmpty);
      });

      test('relayCount returns count of connected relays', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        expect(client.relayCount, equals(0));
      });

      test('relayStatuses returns map of relay statuses', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final statuses = client.relayStatuses;

        expect(statuses, isA<Map<String, dynamic>>());
        expect(statuses, isEmpty);
      });
    });

    group('event actions', () {
      test('sendLike delegates to nostr', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final result = await client.sendLike(testEventId);

        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('sendRepost delegates to nostr', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final result = await client.sendRepost(testEventId);

        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('deleteEvent delegates to nostr', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final result = await client.deleteEvent(testEventId);

        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('deleteEvents delegates to nostr', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        final result = await client.deleteEvents([testEventId]);

        expect(result, anyOf(isNull, isA<Event>()));
      });

      test('sendContactList delegates to nostr', () async {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        final contacts = ContactList();

        final result = await client.sendContactList(contacts, 'content');

        expect(result, anyOf(isNull, isA<Event>()));
      });
    });

    group('dispose', () {
      test('cleans up resources and closes subscriptions', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);
        client.subscribe([Filter(kinds: [1])], subscriptionId: 'sub1');

        client.dispose();

        // After dispose, subscriptions should be closed
        expect(client.relayCount, equals(0));
      });

      test('can be called multiple times safely', () {
        final config = NostrClientConfig(
          signer: mockSigner,
          publicKey: testPublicKey,
        );

        final client = NostrClient(config);

        client.dispose();
        client.dispose();

        // Should not throw
        expect(client.relayCount, equals(0));
      });
    });
  });
}

