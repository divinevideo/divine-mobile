// ABOUTME: Regression tests for RelayPool.unsubscribe's connected-state guard.
// ABOUTME: A disconnected relay must be torn down locally, not sent a CLOSE.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Relay whose connection state the test drives directly, recording every
/// frame the pool asks it to write.
class _StateControlledRelay extends Relay {
  _StateControlledRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  List<List<dynamic>> get closeFrames =>
      sentMessages.where((m) => m.isNotEmpty && m[0] == 'CLOSE').toList();

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  /// The socket died under a live subscription. The pool learns this from the
  /// status alone; the saved subscription stays behind for the reconnect.
  void dropSocket() => relayStatus.connected = ClientConnected.disconnect;

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(List<dynamic>.from(message));
    return relayStatus.connected == ClientConnected.connected;
  }
}

void main() {
  group('RelayPool.unsubscribe connected-state guard', () {
    const relayUrl = 'wss://relay.divine.video';
    const tempRelayUrl = 'wss://temp.divine.video';

    late Nostr nostr;
    late _StateControlledRelay relay;
    late _StateControlledRelay tempRelay;

    setUp(() async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      tempRelay = _StateControlledRelay(tempRelayUrl);
      nostr = Nostr(signer, [], (url) => tempRelay);
      await nostr.refreshPublicKey();
      relay = _StateControlledRelay(relayUrl);
      await nostr.relayPool.add(relay);
    });

    Future<String> subscribeToFeed() async {
      final subId = nostr.subscribe(
        [
          {
            'kinds': [34236],
          },
        ],
        (_) {},
        tempRelays: [tempRelayUrl],
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        relay.hasSubscriptionById(subId),
        isTrue,
        reason: 'the pool must have saved the subscription on the relay',
      );
      expect(tempRelay.hasSubscriptionById(subId), isTrue);
      return subId;
    }

    test('sends CLOSE while the socket is up', () async {
      final subId = await subscribeToFeed();

      nostr.unsubscribe(subId);

      expect(relay.closeFrames, [
        ['CLOSE', subId],
      ]);
      expect(relay.hasSubscriptionById(subId), isFalse);
    });

    test('drops the subscription locally when the socket is gone instead of '
        'writing a CLOSE it has nowhere to send', () async {
      final subId = await subscribeToFeed();
      relay.dropSocket();

      nostr.unsubscribe(subId);

      expect(
        relay.closeFrames,
        isEmpty,
        reason:
            'a CLOSE on a disconnected relay either drives a reconnect purely '
            'to deliver a teardown frame, or is queued for a replay where the '
            'id names a subscription only the dead socket ever had',
      );
      expect(
        relay.hasSubscriptionById(subId),
        isFalse,
        reason:
            'skipping the CLOSE must not leave the subscription saved — '
            'the reconnect would re-issue a REQ nobody is listening to',
      );
    });

    test('applies the same guard to temp relays', () async {
      final subId = await subscribeToFeed();
      tempRelay.dropSocket();

      nostr.unsubscribe(subId);

      expect(tempRelay.closeFrames, isEmpty);
      expect(tempRelay.hasSubscriptionById(subId), isFalse);
      // The healthy relay in the same sweep is unaffected.
      expect(relay.closeFrames, [
        ['CLOSE', subId],
      ]);
    });
  });
}
