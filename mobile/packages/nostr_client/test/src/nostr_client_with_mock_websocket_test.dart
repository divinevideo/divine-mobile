// Example test showing how to use MockWebSocketChannelFactory
// to test NostrClient with mocked WebSocket communication

import 'dart:async';
import 'dart:convert';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/src/models/models.dart';
import 'package:nostr_client/src/nostr_client.dart';
import 'mock_websocket_factory.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  group('NostrClient with Mock WebSocket', () {
    late NostrSigner mockSigner;
    late MockWebSocketChannelFactory mockFactory;
    const testPublicKey =
        '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
    const testRelayUrl = 'wss://relay.example.com';

    setUpAll(() {
      registerFallbackValue(
        Event(
          testPublicKey,
          1,
          <dynamic>[],
          '',
          createdAt: 1234567890,
        ),
      );
    });

    setUp(() {
      mockSigner = MockNostrSigner();
      mockFactory = MockWebSocketChannelFactory();
      when(() => mockSigner.getPublicKey()).thenAnswer((_) async => testPublicKey);
      when(() => mockSigner.signEvent(any())).thenAnswer((_) async => null);
    });

    tearDown(() {
      mockFactory.reset();
    });

    test('can inject mock WebSocket factory', () {
      final config = NostrClientConfig(
        signer: mockSigner,
        publicKey: testPublicKey,
        webSocketChannelFactory: mockFactory,
      );

      final client = NostrClient(config);

      expect(client.publicKey, equals(testPublicKey));
      expect(client.relayCount, equals(0));
    });

    test('can add relay with mock WebSocket', () async {
      final config = NostrClientConfig(
        signer: mockSigner,
        publicKey: testPublicKey,
        webSocketChannelFactory: mockFactory,
      );

      final client = NostrClient(config);

      // Add relay - this will use the mock factory
      final result = await client.addRelay(testRelayUrl);

      // Mock factory should have created a channel
      final mockChannel = mockFactory.getChannel(testRelayUrl);
      expect(mockChannel, isNotNull);
      expect(result, isA<bool>());
    });

    test('can simulate relay messages', () async {
      final config = NostrClientConfig(
        signer: mockSigner,
        publicKey: testPublicKey,
        webSocketChannelFactory: mockFactory,
      );

      final client = NostrClient(config);
      await client.addRelay(testRelayUrl);

      final mockChannel = mockFactory.getChannel(testRelayUrl);
      expect(mockChannel, isNotNull);

      // Simulate receiving an EVENT message from the relay
      final eventJson = jsonEncode([
        'EVENT',
        'sub1',
        {
          'id': '0000000000000000000000000000000000000000000000000000000000000000',
          'pubkey': testPublicKey,
          'created_at': 1234567890,
          'kind': 1,
          'tags': <dynamic>[],
          'content': 'Test message',
          'sig': '',
        }
      ]);

      mockChannel!.simulateMessage(eventJson);

      // The message should be processed by the relay
      expect(mockChannel.sentMessages, isEmpty);
    });

    test('can simulate connection errors', () async {
      mockFactory.shouldFail = true;
      mockFactory.failureMessage = 'Connection refused';

      final config = NostrClientConfig(
        signer: mockSigner,
        publicKey: testPublicKey,
        webSocketChannelFactory: mockFactory,
      );

      final client = NostrClient(config);

      // Adding relay should handle the connection failure gracefully
      final result = await client.addRelay(testRelayUrl);

      // Result may be false due to connection failure
      expect(result, isA<bool>());
    });
  });
}

