// ABOUTME: Integration tests for relay-specific NIP-42 authentication functionality
// ABOUTME: Tests the complete flow of configuring and using per-relay authentication

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class MockRelay extends RelayBase {
  final List<List<dynamic>> sentMessages = [];
  bool shouldSendAuthChallenge = false;
  String authChallenge = 'test-challenge-123';

  MockRelay(String url) : super(url, RelayStatus(url));

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(message);

    // Simulate auth challenge response if configured
    if (shouldSendAuthChallenge && message[0] == 'REQ') {
      Future.delayed(const Duration(milliseconds: 100), () {
        // Simulate AUTH challenge from relay
        onMessage?.call(this, ['AUTH', authChallenge]);
      });
    }

    return true;
  }

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  void clearSentMessages() {
    sentMessages.clear();
  }

  Future<void> deliver(List<dynamic> message) async {
    final result = onMessage?.call(this, message);
    if (result is Future) {
      await result;
    }
  }
}

void main() {
  group('Relay Authentication Integration Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late String testPrivateKey;

    setUp(() async {
      testPrivateKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      signer = LocalNostrSigner(testPrivateKey);

      nostr = Nostr(signer, [], (url) => MockRelay(url));
      await nostr.refreshPublicKey();
    });

    test('Configure relay with alwaysAuth', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);
      await nostr.relayPool.add(relay);

      // Initially alwaysAuth should be false
      expect(nostr.getRelayAuthConfig()[relayUrl], isFalse);

      // Configure relay to always authenticate
      nostr.setRelayAlwaysAuth(relayUrl, true);
      expect(nostr.getRelayAuthConfig()[relayUrl], isTrue);

      // Disable authentication requirement
      nostr.setRelayAlwaysAuth(relayUrl, false);
      expect(nostr.getRelayAuthConfig()[relayUrl], isFalse);
    });

    test('Configure multiple relays with authentication', () async {
      final relay1 = MockRelay('wss://relay1.com');
      final relay2 = MockRelay('wss://relay2.com');
      final relay3 = MockRelay('wss://relay3.com');

      await nostr.relayPool.add(relay1);
      await nostr.relayPool.add(relay2);
      await nostr.relayPool.add(relay3);

      // Configure multiple relays at once
      nostr.configureRelayAuth({
        'wss://relay1.com': true,
        'wss://relay2.com': false,
        'wss://relay3.com': true,
      });

      final config = nostr.getRelayAuthConfig();
      expect(config['wss://relay1.com'], isTrue);
      expect(config['wss://relay2.com'], isFalse);
      expect(config['wss://relay3.com'], isTrue);
    });

    test('Subscriptions trigger AUTH when relay requires alwaysAuth', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);
      relay.shouldSendAuthChallenge = true;

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      nostr.subscribe([
        Filter(kinds: [EventKind.textNote]).toJson(),
      ], (event) {});

      expect(relay.sentMessages, hasLength(1));
      expect(relay.sentMessages.first[0], equals('REQ'));
      expect(relay.pendingAuthedMessages, isEmpty);
    });

    test('Events queued when relay requires alwaysAuth', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      // Send an event
      final event = Event(
        nostr.publicKey,
        EventKind.textNote,
        [],
        'Test message',
      );

      await nostr.sendEvent(event);

      // Event should be queued for authentication
      expect(relay.sentMessages.isEmpty, isTrue);
      expect(relay.pendingAuthedMessages.isNotEmpty, isTrue);
      expect(relay.pendingAuthedMessages.first[0], equals('EVENT'));
    });

    test('Subscriptions are re-sent after authentication succeeds', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      // Queue a subscription
      nostr.subscribe([
        Filter(kinds: [EventKind.textNote]).toJson(),
      ], (event) {});

      expect(relay.sentMessages.length, equals(1));
      expect(relay.sentMessages.first[0], equals('REQ'));

      await relay.deliver(['AUTH', relay.authChallenge]);
      expect(relay.sentMessages.length, equals(2));
      expect(relay.sentMessages.last[0], equals('AUTH'));
      final authEvent = relay.sentMessages.last[1] as Map<String, dynamic>;
      final authEventId = authEvent['id'];
      expect(authEventId, isA<String>());

      await relay.deliver(['OK', authEventId, true, '']);

      expect(relay.sentMessages.length, equals(3));
      expect(relay.sentMessages.last[0], equals('REQ'));
      expect(relay.pendingAuthedMessages.isEmpty, isTrue);
      expect(relay.relayStatus.authed, isTrue);
    });

    test('Mixed relay configuration - some with alwaysAuth', () async {
      final authRelay = MockRelay('wss://auth.relay.com');
      final normalRelay = MockRelay('wss://normal.relay.com');

      await nostr.relayPool.add(authRelay);
      await nostr.relayPool.add(normalRelay);

      // Only auth relay requires authentication
      nostr.setRelayAlwaysAuth('wss://auth.relay.com', true);

      // Send an event
      final event = Event(
        nostr.publicKey,
        EventKind.textNote,
        [],
        'Test message',
      );

      await nostr.sendEvent(event);

      // Auth relay should queue the message
      expect(authRelay.sentMessages.isEmpty, isTrue);
      expect(authRelay.pendingAuthedMessages.length, equals(1));

      // Normal relay should send immediately
      expect(normalRelay.sentMessages.length, equals(1));
      expect(normalRelay.sentMessages.first[0], equals('EVENT'));
      expect(normalRelay.pendingAuthedMessages.isEmpty, isTrue);
    });
  });
}
