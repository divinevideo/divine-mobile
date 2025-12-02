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
  bool send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
  }) {
    sentMessages.add(message);

    // Simulate auth challenge response if configured
    if (shouldSendAuthChallenge && message[0] == 'REQ') {
      Future.delayed(Duration(milliseconds: 100), () {
        // Simulate AUTH challenge from relay
        onMessage?.call(this, ['AUTH', authChallenge]);
      });
    }

    return true;
  }

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.CONNECTED;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.DISCONNECT;
  }

  void clearSentMessages() {
    sentMessages.clear();
  }

  void sendPendingMessages() {
    while (pendingAuthedMessages.isNotEmpty) {
      final message = pendingAuthedMessages.removeAt(0);
      send(message);
    }
  }
}

void main() {
  group('Relay Authentication Integration Tests', () {
    late Nostr nostr;
    late LocalNostrSigner signer;
    late String testPrivateKey;
    late String testPublicKey;

    setUp(() {
      testPrivateKey =
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
      testPublicKey =
          '87979b28328fa41994eb9a5d9c76cdf3a605df66fbb4c5f82c3608939b2545d5';
      signer = LocalNostrSigner(testPrivateKey);

      nostr = Nostr(signer, testPublicKey, [], (url) => MockRelay(url));
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

    test('Messages queued when relay requires alwaysAuth', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);
      relay.shouldSendAuthChallenge = true;

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      // Subscribe should be queued for authentication
      final subscription = nostr.subscribe([
        Filter(kinds: [EventKind.TEXT_NOTE]).toJson(),
      ], (event) {});

      // Message should be in pending auth messages, not sent yet
      expect(relay.sentMessages.isEmpty, isTrue);
      expect(relay.pendingAuthedMessages.isNotEmpty, isTrue);
      expect(relay.pendingAuthedMessages.first[0], equals('REQ'));
    });

    test('Events queued when relay requires alwaysAuth', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      // Send an event
      final event = Event(
        testPublicKey,
        EventKind.TEXT_NOTE,
        [],
        'Test message',
      );

      await nostr.sendEvent(event);

      // Event should be queued for authentication
      expect(relay.sentMessages.isEmpty, isTrue);
      expect(relay.pendingAuthedMessages.isNotEmpty, isTrue);
      expect(relay.pendingAuthedMessages.first[0], equals('EVENT'));
    });

    test('Messages sent after authentication when alwaysAuth is true', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      // Queue a subscription
      nostr.subscribe([
        Filter(kinds: [EventKind.TEXT_NOTE]).toJson(),
      ], (event) {});

      expect(relay.sentMessages.isEmpty, isTrue);
      expect(relay.pendingAuthedMessages.length, equals(1));

      // Simulate successful authentication
      relay.relayStatus.authed = true;

      // Manually trigger sending of pending messages (normally done after AUTH response)
      relay.sendPendingMessages();

      // Now the message should be sent
      expect(relay.sentMessages.length, equals(1));
      expect(relay.sentMessages.first[0], equals('REQ'));
      expect(relay.pendingAuthedMessages.isEmpty, isTrue);
    });

    test('Auth challenge functionality basic test', () async {
      final relayUrl = 'wss://auth.relay.com';
      final relay = MockRelay(relayUrl);

      await nostr.relayPool.add(relay);
      nostr.setRelayAlwaysAuth(relayUrl, true);

      // Send subscription that should be queued for auth
      nostr.subscribe([
        Filter(kinds: [EventKind.TEXT_NOTE]).toJson(),
      ], (event) {});

      // Message should be queued for authentication
      expect(relay.pendingAuthedMessages.isNotEmpty, isTrue);
      expect(relay.pendingAuthedMessages.first[0], equals('REQ'));
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
        testPublicKey,
        EventKind.TEXT_NOTE,
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
