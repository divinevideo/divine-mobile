import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_gateway/nostr_gateway.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class _MockNostr extends Mock implements Nostr {}

class _MockGatewayClient extends Mock implements GatewayClient {}

class _MockRelayManager extends Mock implements RelayManager {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

class _FakeContactList extends Fake implements ContactList {}

class _FakeRelay extends Fake implements Relay {
  @override
  final String url = 'wss://fake.example.com';

  @override
  RelayStatus relayStatus = RelayStatus('wss://fake.example.com');
}

const testPublicKey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Event _createTestEvent({
  String? id,
  String? pubkey,
  int? kind,
  String? content,
  int? createdAt,
}) {
  final eventPubkey = pubkey ?? testPublicKey;
  final eventKind = kind ?? EventKind.textNote;
  final eventContent = content ?? 'Test content';
  final event = Event(
    eventPubkey,
    eventKind,
    <List<dynamic>>[],
    eventContent,
    createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  if (id != null) {
    // Override the generated ID for testing
    event.id = id;
  }
  return event;
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  late _MockNostr mockNostr;
  late _MockGatewayClient mockGatewayClient;
  late _MockRelayManager mockRelayManager;
  late NostrClient client;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(_FakeContactList());
    registerFallbackValue(_FakeRelay());
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(RelayType.all);
  });

  setUp(() {
    mockNostr = _MockNostr();
    mockGatewayClient = _MockGatewayClient();
    mockRelayManager = _MockRelayManager();

    // Set up default mock behavior
    when(() => mockNostr.publicKey).thenReturn(testPublicKey);
    when(() => mockNostr.close()).thenReturn(null);
    when(() => mockRelayManager.dispose()).thenAnswer((_) async {});

    client = NostrClient.forTesting(
      nostr: mockNostr,
      relayManager: mockRelayManager,
      gatewayClient: mockGatewayClient,
    );
  });

  tearDown(() {
    reset(mockNostr);
    reset(mockGatewayClient);
    reset(mockRelayManager);
  });

  group('NostrClient', () {
    group('constructor and properties', () {
      test('publicKey returns the nostr public key', () {
        expect(client.publicKey, equals(testPublicKey));
        verify(() => mockNostr.publicKey).called(1);
      });

      test('creates client with null gatewayClient', () {
        final localMockRelayManager = _MockRelayManager();
        final clientWithoutGateway = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: localMockRelayManager,
        );
        expect(clientWithoutGateway.publicKey, equals(testPublicKey));
      });
    });

    group('publishEvent', () {
      test('publishes event successfully', () async {
        final event = _createTestEvent();
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        final result = await client.publishEvent(event);

        expect(result, equals(event));
        verify(
          () => mockNostr.sendEvent(
            event,
          ),
        ).called(1);
      });

      test('publishes event with target relays', () async {
        final event = _createTestEvent();
        final targetRelays = ['wss://relay1.example.com'];
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => event);

        await client.publishEvent(event, targetRelays: targetRelays);

        verify(
          () => mockNostr.sendEvent(
            event,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendEvent fails', () async {
        final event = _createTestEvent();
        when(
          () => mockNostr.sendEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.publishEvent(event);

        expect(result, isNull);
      });
    });

    group('queryEvents', () {
      test('uses gateway when enabled and single filter', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent(), _createTestEvent()];
        final response = GatewayResponse(
          events: events,
          eose: true,
          complete: true,
          cached: true,
        );

        when(
          () => mockGatewayClient.query(any()),
        ).thenAnswer((_) async => response);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
        verify(() => mockGatewayClient.query(any())).called(1);
        verifyNever(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        );
      });

      test('falls back to WebSocket when gateway returns empty', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];
        const emptyResponse = GatewayResponse(
          events: [],
          eose: true,
          complete: true,
          cached: false,
        );

        when(
          () => mockGatewayClient.query(any()),
        ).thenAnswer((_) async => emptyResponse);
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
        verify(() => mockGatewayClient.query(any())).called(1);
        verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('falls back to WebSocket when gateway throws', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockGatewayClient.query(any()),
        ).thenThrow(Exception('Gateway error'));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
      });

      test('skips gateway when useGateway is false', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters, useGateway: false);

        expect(result, equals(events));
        verifyNever(() => mockGatewayClient.query(any()));
      });

      test('skips gateway when multiple filters provided', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
        verifyNever(() => mockGatewayClient.query(any()));
      });

      test('passes all parameters to WebSocket query', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];
        final tempRelays = ['wss://temp.example.com'];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        await client.queryEvents(
          filters,
          subscriptionId: 'test-sub',
          tempRelays: tempRelays,
          relayTypes: [RelayType.normal],
          sendAfterAuth: true,
          useGateway: false,
        );

        verify(
          () => mockNostr.queryEvents(
            any(),
            id: 'test-sub',
            tempRelays: tempRelays,
            relayTypes: [RelayType.normal],
            sendAfterAuth: true,
          ),
        ).called(1);
      });

      test('works without gateway client', () async {
        final localMockRelayManager = _MockRelayManager();
        final clientWithoutGateway = NostrClient.forTesting(
          nostr: mockNostr,
          relayManager: localMockRelayManager,
        );
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await clientWithoutGateway.queryEvents(filters);

        expect(result, equals(events));
      });
    });

    group('fetchEventById', () {
      test('uses gateway when enabled', () async {
        const eventId = 'test-event-id';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockGatewayClient.getEvent(eventId),
        ).thenAnswer((_) async => event);

        final result = await client.fetchEventById(eventId);

        expect(result, equals(event));
        verify(() => mockGatewayClient.getEvent(eventId)).called(1);
      });

      test('falls back to WebSocket when gateway returns null', () async {
        const eventId = 'test-event-id';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockGatewayClient.getEvent(eventId),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        final result = await client.fetchEventById(eventId);

        expect(result, equals(event));
      });

      test('falls back to WebSocket when gateway throws', () async {
        const eventId = 'test-event-id';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockGatewayClient.getEvent(eventId),
        ).thenThrow(Exception('Gateway error'));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        final result = await client.fetchEventById(eventId);

        expect(result, equals(event));
      });

      test('skips gateway when useGateway is false', () async {
        const eventId = 'test-event-id';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        await client.fetchEventById(eventId, useGateway: false);

        verifyNever(() => mockGatewayClient.getEvent(any()));
      });

      test('uses provided relayUrl', () async {
        const eventId = 'test-event-id';
        const relayUrl = 'wss://relay.example.com';
        final event = _createTestEvent(id: eventId);

        when(
          () => mockGatewayClient.getEvent(eventId),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [event]);

        await client.fetchEventById(eventId, relayUrl: relayUrl);

        verify(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: [relayUrl],
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('returns null when no events found', () async {
        const eventId = 'nonexistent-id';

        when(
          () => mockGatewayClient.getEvent(eventId),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.fetchEventById(eventId);

        expect(result, isNull);
      });
    });

    group('fetchProfile', () {
      test('uses gateway when enabled', () async {
        const pubkey = testPublicKey;
        final profileEvent = _createTestEvent(
          pubkey: pubkey,
          kind: EventKind.metadata,
          content: '{"name":"Test User"}',
        );

        when(
          () => mockGatewayClient.getProfile(pubkey),
        ).thenAnswer((_) async => profileEvent);

        final result = await client.fetchProfile(pubkey);

        expect(result, equals(profileEvent));
        verify(() => mockGatewayClient.getProfile(pubkey)).called(1);
      });

      test('falls back to WebSocket when gateway returns null', () async {
        const pubkey = testPublicKey;
        final profileEvent = _createTestEvent(
          pubkey: pubkey,
          kind: EventKind.metadata,
        );

        when(
          () => mockGatewayClient.getProfile(pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent]);

        final result = await client.fetchProfile(pubkey);

        expect(result, equals(profileEvent));
      });

      test('falls back to WebSocket when gateway throws', () async {
        const pubkey = testPublicKey;
        final profileEvent = _createTestEvent(
          pubkey: pubkey,
          kind: EventKind.metadata,
        );

        when(
          () => mockGatewayClient.getProfile(pubkey),
        ).thenThrow(Exception('Gateway error'));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent]);

        final result = await client.fetchProfile(pubkey);

        expect(result, equals(profileEvent));
      });

      test('skips gateway when useGateway is false', () async {
        const pubkey = testPublicKey;
        final profileEvent = _createTestEvent(
          pubkey: pubkey,
          kind: EventKind.metadata,
        );

        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => [profileEvent]);

        await client.fetchProfile(pubkey, useGateway: false);

        verifyNever(() => mockGatewayClient.getProfile(any()));
      });

      test('returns null when no profile found', () async {
        const pubkey = testPublicKey;

        when(
          () => mockGatewayClient.getProfile(pubkey),
        ).thenAnswer((_) async => null);
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => []);

        final result = await client.fetchProfile(pubkey);

        expect(result, isNull);
      });
    });

    group('subscribe', () {
      test('creates subscription and returns stream', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn('test-sub-id');

        final stream = client.subscribe(filters);

        expect(stream, isA<Stream<Event>>());
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('creates new subscription for different filters', () {
        final filters1 = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final filters2 = [
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn('test-sub-id');

        client
          ..subscribe(filters1)
          ..subscribe(filters2);

        // Should create two separate subscriptions
        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(2);
      });

      test('uses custom subscription ID when provided', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        const customId = 'my-custom-subscription';

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn(customId);

        client.subscribe(filters, subscriptionId: customId);

        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: customId,
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).called(1);
      });

      test('passes all parameters correctly', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn('test-sub-id');

        client.subscribe(
          filters,
          subscriptionId: 'test-id',
          tempRelays: tempRelays,
          targetRelays: targetRelays,
          relayTypes: [RelayType.normal],
          sendAfterAuth: true,
        );

        verify(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: 'test-id',
            tempRelays: tempRelays,
            targetRelays: targetRelays,
            relayTypes: [RelayType.normal],
            sendAfterAuth: true,
          ),
        ).called(1);
      });

      test('handles nostr returning different subscription ID', () {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        // Nostr returns a different ID than what was requested
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn('nostr-generated-id');

        final stream = client.subscribe(filters, subscriptionId: 'my-id');

        expect(stream, isA<Stream<Event>>());
      });
    });

    group('unsubscribe', () {
      test('unsubscribes and closes stream', () async {
        const subscriptionId = 'test-sub-id';
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn(subscriptionId);
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client.subscribe(filters, subscriptionId: subscriptionId);
        await client.unsubscribe(subscriptionId);

        verify(() => mockNostr.unsubscribe(subscriptionId)).called(1);
      });

      test('handles unsubscribing non-existent subscription', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        // Should not throw
        await client.unsubscribe('nonexistent-id');

        verify(() => mockNostr.unsubscribe('nonexistent-id')).called(1);
      });
    });

    group('closeAllSubscriptions', () {
      test('closes all active subscriptions', () async {
        final filters1 = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final filters2 = [
          Filter(kinds: [EventKind.metadata], limit: 5),
        ];

        var callCount = 0;
        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) => 'sub-${callCount++}');
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client
          ..subscribe(filters1)
          ..subscribe(filters2)
          ..closeAllSubscriptions();

        verify(() => mockNostr.unsubscribe(any())).called(2);
      });

      test('handles no active subscriptions', () {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        // Should not throw
        client.closeAllSubscriptions();

        verifyNever(() => mockNostr.unsubscribe(any()));
      });
    });

    group('addRelay', () {
      test('delegates to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.addRelay(relayUrl),
        ).thenAnswer((_) async => true);

        final result = await client.addRelay(relayUrl);

        expect(result, isTrue);
        verify(() => mockRelayManager.addRelay(relayUrl)).called(1);
      });

      test('returns false when RelayManager returns false', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.addRelay(relayUrl),
        ).thenAnswer((_) async => false);

        final result = await client.addRelay(relayUrl);

        expect(result, isFalse);
      });
    });

    group('removeRelay', () {
      test('delegates to RelayManager', () async {
        const relayUrl = 'wss://relay.example.com';
        when(
          () => mockRelayManager.removeRelay(relayUrl),
        ).thenAnswer((_) async => true);

        final result = await client.removeRelay(relayUrl);

        expect(result, isTrue);
        verify(() => mockRelayManager.removeRelay(relayUrl)).called(1);
      });
    });

    group('connectedRelays', () {
      test('delegates to RelayManager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(() => mockRelayManager.connectedRelays).thenReturn(expectedRelays);

        final result = client.connectedRelays;

        expect(result, equals(expectedRelays));
        verify(() => mockRelayManager.connectedRelays).called(1);
      });

      test('returns empty list when no relays connected', () {
        when(() => mockRelayManager.connectedRelays).thenReturn([]);

        final result = client.connectedRelays;

        expect(result, isEmpty);
      });
    });

    group('connectedRelayCount', () {
      test('delegates to RelayManager', () {
        when(() => mockRelayManager.connectedRelayCount).thenReturn(3);

        expect(client.connectedRelayCount, equals(3));
        verify(() => mockRelayManager.connectedRelayCount).called(1);
      });

      test('returns 0 when no relays connected', () {
        when(() => mockRelayManager.connectedRelayCount).thenReturn(0);

        expect(client.connectedRelayCount, equals(0));
      });
    });

    group('relayStatuses', () {
      test('delegates to RelayManager', () {
        final expectedStatuses = {
          'wss://relay1.example.com': RelayConnectionStatus.connected(
            'wss://relay1.example.com',
          ),
          'wss://relay2.example.com': RelayConnectionStatus.connected(
            'wss://relay2.example.com',
          ),
        };
        when(
          () => mockRelayManager.currentStatuses,
        ).thenReturn(expectedStatuses);

        final result = client.relayStatuses;

        expect(result, equals(expectedStatuses));
        verify(() => mockRelayManager.currentStatuses).called(1);
      });

      test('returns empty map when no relays', () {
        when(() => mockRelayManager.currentStatuses).thenReturn({});

        final result = client.relayStatuses;

        expect(result, isEmpty);
      });
    });

    group('configuredRelays', () {
      test('delegates to RelayManager', () {
        final expectedRelays = [
          'wss://relay1.example.com',
          'wss://relay2.example.com',
        ];
        when(
          () => mockRelayManager.configuredRelays,
        ).thenReturn(expectedRelays);

        final result = client.configuredRelays;

        expect(result, equals(expectedRelays));
        verify(() => mockRelayManager.configuredRelays).called(1);
      });
    });

    group('configuredRelayCount', () {
      test('delegates to RelayManager', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(2);

        expect(client.configuredRelayCount, equals(2));
        verify(() => mockRelayManager.configuredRelayCount).called(1);
      });

      test('returns 0 when no relays configured', () {
        when(() => mockRelayManager.configuredRelayCount).thenReturn(0);

        expect(client.configuredRelayCount, equals(0));
      });
    });

    group('relayStatusStream', () {
      test('delegates to RelayManager', () async {
        final controller =
            StreamController<Map<String, RelayConnectionStatus>>.broadcast();
        when(
          () => mockRelayManager.statusStream,
        ).thenAnswer((_) => controller.stream);

        final result = client.relayStatusStream;

        expect(result, isNotNull);
        verify(() => mockRelayManager.statusStream).called(1);

        await controller.close();
      });
    });

    group('retryDisconnectedRelays', () {
      test('delegates to RelayManager', () async {
        when(mockRelayManager.retryDisconnectedRelays).thenAnswer((_) async {});

        await client.retryDisconnectedRelays();

        verify(mockRelayManager.retryDisconnectedRelays).called(1);
      });
    });

    group('sendLike', () {
      test('sends like successfully', () async {
        const eventId = 'event-to-like';
        final likeEvent = _createTestEvent(kind: EventKind.reaction);

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => likeEvent);

        final result = await client.sendLike(eventId);

        expect(result, equals(likeEvent));
        verify(
          () => mockNostr.sendLike(
            eventId,
          ),
        ).called(1);
      });

      test('sends like with custom content', () async {
        const eventId = 'event-to-like';
        const content = '❤️';
        final likeEvent = _createTestEvent(kind: EventKind.reaction);

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => likeEvent);

        await client.sendLike(eventId, content: content);

        verify(
          () => mockNostr.sendLike(
            eventId,
            content: content,
          ),
        ).called(1);
      });

      test('sends like with relay parameters', () async {
        const eventId = 'event-to-like';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final likeEvent = _createTestEvent(kind: EventKind.reaction);

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => likeEvent);

        await client.sendLike(
          eventId,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendLike(
            eventId,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendLike fails', () async {
        const eventId = 'event-to-like';

        when(
          () => mockNostr.sendLike(
            any(),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendLike(eventId);

        expect(result, isNull);
      });
    });

    group('sendRepost', () {
      test('sends repost successfully', () async {
        const eventId = 'event-to-repost';
        final repostEvent = _createTestEvent(kind: EventKind.repost);

        when(
          () => mockNostr.sendRepost(
            any(),
            relayAddr: any(named: 'relayAddr'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        final result = await client.sendRepost(eventId);

        expect(result, equals(repostEvent));
        verify(
          () => mockNostr.sendRepost(
            eventId,
          ),
        ).called(1);
      });

      test('sends repost with all parameters', () async {
        const eventId = 'event-to-repost';
        const relayAddr = 'wss://relay.example.com';
        const content = '{"event":"data"}';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final repostEvent = _createTestEvent(kind: EventKind.repost);

        when(
          () => mockNostr.sendRepost(
            any(),
            relayAddr: any(named: 'relayAddr'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => repostEvent);

        await client.sendRepost(
          eventId,
          relayAddr: relayAddr,
          content: content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendRepost(
            eventId,
            relayAddr: relayAddr,
            content: content,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendRepost fails', () async {
        const eventId = 'event-to-repost';

        when(
          () => mockNostr.sendRepost(
            any(),
            relayAddr: any(named: 'relayAddr'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendRepost(eventId);

        expect(result, isNull);
      });
    });

    group('deleteEvent', () {
      test('deletes event successfully', () async {
        const eventId = 'event-to-delete';
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        final result = await client.deleteEvent(eventId);

        expect(result, equals(deleteEvent));
        verify(
          () => mockNostr.deleteEvent(
            eventId,
          ),
        ).called(1);
      });

      test('deletes event with relay parameters', () async {
        const eventId = 'event-to-delete';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        await client.deleteEvent(
          eventId,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.deleteEvent(
            eventId,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when deleteEvent fails', () async {
        const eventId = 'event-to-delete';

        when(
          () => mockNostr.deleteEvent(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.deleteEvent(eventId);

        expect(result, isNull);
      });
    });

    group('deleteEvents', () {
      test('deletes multiple events successfully', () async {
        final eventIds = ['event-1', 'event-2', 'event-3'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        final result = await client.deleteEvents(eventIds);

        expect(result, equals(deleteEvent));
        verify(
          () => mockNostr.deleteEvents(
            eventIds,
          ),
        ).called(1);
      });

      test('deletes events with relay parameters', () async {
        final eventIds = ['event-1', 'event-2'];
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final deleteEvent = _createTestEvent(kind: EventKind.eventDeletion);

        when(
          () => mockNostr.deleteEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => deleteEvent);

        await client.deleteEvents(
          eventIds,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.deleteEvents(
            eventIds,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when deleteEvents fails', () async {
        final eventIds = ['event-1', 'event-2'];

        when(
          () => mockNostr.deleteEvents(
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.deleteEvents(eventIds);

        expect(result, isNull);
      });
    });

    group('sendContactList', () {
      test('sends contact list successfully', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';
        final contactListEvent = _createTestEvent(kind: EventKind.contactList);

        when(
          () => mockNostr.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => contactListEvent);

        final result = await client.sendContactList(contacts, content);

        expect(result, equals(contactListEvent));
        verify(
          () => mockNostr.sendContactList(
            contacts,
            content,
          ),
        ).called(1);
      });

      test('sends contact list with relay parameters', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';
        final tempRelays = ['wss://temp.example.com'];
        final targetRelays = ['wss://target.example.com'];
        final contactListEvent = _createTestEvent(kind: EventKind.contactList);

        when(
          () => mockNostr.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => contactListEvent);

        await client.sendContactList(
          contacts,
          content,
          tempRelays: tempRelays,
          targetRelays: targetRelays,
        );

        verify(
          () => mockNostr.sendContactList(
            contacts,
            content,
            tempRelays: tempRelays,
            targetRelays: targetRelays,
          ),
        ).called(1);
      });

      test('returns null when sendContactList fails', () async {
        final contacts = ContactList();
        const content = '{"relay":"preferences"}';

        when(
          () => mockNostr.sendContactList(
            any(),
            any(),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final result = await client.sendContactList(contacts, content);

        expect(result, isNull);
      });
    });

    group('dispose', () {
      test('closes all subscriptions and nostr client', () async {
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        await client.dispose();

        verify(() => mockNostr.close()).called(1);
      });

      test('closes active subscriptions before disposing', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];

        when(
          () => mockNostr.subscribe(
            any(),
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenReturn('test-sub-id');
        when(() => mockNostr.unsubscribe(any())).thenReturn(null);

        client.subscribe(filters);
        await client.dispose();

        verify(() => mockNostr.unsubscribe(any())).called(1);
        verify(() => mockNostr.close()).called(1);
      });
    });

    group('gateway fallback behavior', () {
      test('handles GatewayException gracefully', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockGatewayClient.query(any()),
        ).thenThrow(const GatewayException('Server error', statusCode: 500));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
      });

      test('handles network errors gracefully', () async {
        final filters = [
          Filter(kinds: [EventKind.textNote], limit: 10),
        ];
        final events = [_createTestEvent()];

        when(
          () => mockGatewayClient.query(any()),
        ).thenThrow(Exception('Network timeout'));
        when(
          () => mockNostr.queryEvents(
            any(),
            id: any(named: 'id'),
            tempRelays: any(named: 'tempRelays'),
            relayTypes: any(named: 'relayTypes'),
            sendAfterAuth: any(named: 'sendAfterAuth'),
          ),
        ).thenAnswer((_) async => events);

        final result = await client.queryEvents(filters);

        expect(result, equals(events));
      });
    });
  });
}
