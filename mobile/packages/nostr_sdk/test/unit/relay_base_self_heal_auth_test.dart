// ABOUTME: Regression tests for NIP-42 state on a socket the transport dropped
// ABOUTME: and reconnects on its own, without passing through Relay.connect.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

import '../support/fake_web_socket.dart';

void main() {
  group('RelayBase NIP-42 state across a dropped socket', () {
    const relayUrl = 'wss://relay.divine.video';
    const testPrivateKey =
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

    late FakeWebSocketChannelFactory factory;
    late RelayBase relay;

    setUp(() {
      factory = FakeWebSocketChannelFactory();
      relay = RelayBase(
        relayUrl,
        RelayStatus(relayUrl),
        channelFactory: factory,
      );
    });

    /// Records a completed handshake the way `RelayPool` does on `OK` for the
    /// AUTH event: the relay is known to challenge, and this socket answered.
    void markAuthenticated() {
      relay.relayStatus
        ..alwaysAuth = true
        ..authed = true;
    }

    test('a remote close clears authed, so the self-healed socket has to '
        'answer a fresh challenge', () async {
      addTearDown(() async {
        await relay.disconnect();
        relay.dispose();
      });
      expect(await relay.connect(), isTrue);
      markAuthenticated();

      // The manager's own reconnect follows this drop; nothing above it
      // calls Relay.connect or forceReconnect, which are where the flag was
      // reset before (#8992).
      await factory.lastChannel!.closeFromRemote();
      await pumpEventQueue();

      expect(relay.relayStatus.connected, equals(ClientConnected.disconnect));
      expect(relay.relayStatus.authed, isFalse);
      expect(
        relay.relayStatus.alwaysAuth,
        isTrue,
        reason: 'the relay is still known to gate on NIP-42',
      );
    });

    test('an EVENT published while a dropped auth-gated socket self-heals is '
        'held for the handshake, not queued for an unauthenticated '
        'replay', () async {
      final signer = LocalNostrSigner(testPrivateKey);
      final nostr = Nostr(
        signer,
        [],
        (url) => RelayBase(url, RelayStatus(url)),
      );
      addTearDown(nostr.close);
      await nostr.refreshPublicKey();
      expect(await nostr.relayPool.add(relay), isTrue);
      markAuthenticated();

      await factory.lastChannel!.closeFromRemote();
      await pumpEventQueue();

      final event = Event(nostr.publicKey, EventKind.textNote, [], 'hello');
      await nostr.sendEvent(event);

      // Parked frames are written only once the fresh socket's AUTH succeeds.
      // The other queue is flushed by onConnected before any challenge can
      // arrive, and a fire-and-forget EVENT refused there with auth-required
      // is never retried.
      expect(
        relay.pendingAuthedMessages.map((m) => m.first),
        equals(['EVENT']),
      );
      expect(relay.pendingMessages, isEmpty);
    });
  });
}
