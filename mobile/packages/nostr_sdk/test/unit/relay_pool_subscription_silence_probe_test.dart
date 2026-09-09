// ABOUTME: Regression tests for the in-flight silence probe that repairs a
// ABOUTME: relay which never answered a live subscription's REQ (#7301).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

List<List<dynamic>> _reqFrames(FakeWebSocketChannel channel) => channel
    .sentMessages
    .map((m) => jsonDecode(m as String) as List<dynamic>)
    .where((m) => m.first == 'REQ')
    .toList();

void main() {
  group('RelayPool in-flight subscription silence probe', () {
    const relayUrl = 'wss://relay.divine.video';
    const probe = Duration(milliseconds: 20);
    // Comfortably past [probe] plus the reconnect's own async hops.
    const afterProbe = Duration(milliseconds: 80);

    late Nostr nostr;
    late FakeWebSocketChannelFactory factory;

    Future<void> setUpPool({Object? initialConnectError}) async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      factory = FakeWebSocketChannelFactory(readyError: initialConnectError);
      await nostr.relayPool.add(
        RelayBase(relayUrl, RelayStatus(relayUrl), channelFactory: factory),
      );
      nostr.relayPool.subscriptionSilenceProbe = probe;
    }

    String subscribeToFeed() => nostr.subscribe([
      {
        'kinds': [34236],
      },
    ], (_) {});

    test('a relay that swallowed the REQ is force-reconnected while the '
        'subscription is still live', () async {
      await setUpPool();
      final zombieChannel = factory.createdChannels.single;

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      expect(_reqFrames(zombieChannel), hasLength(1));

      // No unsubscribe: the caller is still waiting on this feed load.
      await Future<void>.delayed(afterProbe);

      expect(
        factory.createdChannels,
        hasLength(2),
        reason:
            'the socket must be cycled inside the load window, not at the '
            'teardown that follows the caller giving up',
      );
      expect(
        _reqFrames(factory.createdChannels.last).map((frame) => frame[1]),
        [subId],
        reason: 'the re-issued REQ is what lets the load still succeed',
      );
    });

    test('a relay that answered the subscription is left alone', () async {
      await setUpPool();
      final channel = factory.createdChannels.single;

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      channel.simulateMessage(jsonEncode(['EOSE', subId]));

      await Future<void>.delayed(afterProbe);

      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an EOSE-ing relay is healthy and must not be cycled',
      );
    });

    test('a relay that stays inbound-active is left alone — silence '
        'discriminates zombie from slow', () async {
      await setUpPool();
      final channel = factory.createdChannels.single;

      subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      // Nothing for our REQ, but the connection is demonstrably alive.
      channel.simulateMessage(jsonEncode(['NOTICE', 'busy']));

      await Future<void>.delayed(afterProbe);

      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an inbound-active connection must not be cycled',
      );
    });

    test('a relay that was disconnected when the REQ was queued is '
        'reconnected so the frame is written', () async {
      // The REQ is sent with `skipReconnect`, so a subscription issued while
      // the socket is down only ever reaches `pendingMessages`.
      await setUpPool(initialConnectError: Exception('connect failed'));
      expect(factory.createdChannels, hasLength(1));
      expect(_reqFrames(factory.createdChannels.single), isEmpty);

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      expect(
        _reqFrames(factory.createdChannels.single),
        isEmpty,
        reason: 'nothing can be written to a socket that never opened',
      );

      // The network came back; nothing periodic would have noticed.
      factory.readyError = null;
      await Future<void>.delayed(afterProbe);

      expect(factory.createdChannels, hasLength(2));
      expect(
        _reqFrames(factory.createdChannels.last).map((frame) => frame[1]),
        [subId],
        reason: 'the queued REQ must be written on the reconnected socket',
      );
    });

    test('a subscription torn down before the probe fires never charges the '
        'socket', () async {
      await setUpPool();

      final subId = subscribeToFeed();
      await Future<void>.delayed(Duration.zero);
      expect(nostr.relayPool.armedSilenceProbeSubscriptionIds, [
        subId,
      ], reason: 'the probe is armed while the load is live');

      // The user left the screen inside the relay's round-trip time.
      nostr.unsubscribe(subId);
      expect(
        nostr.relayPool.armedSilenceProbeSubscriptionIds,
        isEmpty,
        reason:
            'teardown disarms the probe; without this a torn-down load leaks '
            'a live timer that a same-id re-subscribe could let cycle a '
            'healthy connection',
      );
      await Future<void>.delayed(afterProbe);

      expect(
        factory.createdChannels,
        hasLength(1),
        reason:
            'teardown cancels the probe, which is what keeps navigation-speed '
            'exits from churning healthy connections',
      );
    });

    test(
      'cycles only the silent relay, sparing a sibling that answered',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
        await nostr.refreshPublicKey();

        const answeredUrl = 'wss://answered.divine.video';
        const silentUrl = 'wss://silent.divine.video';
        final answeredFactory = FakeWebSocketChannelFactory();
        final silentFactory = FakeWebSocketChannelFactory();
        await nostr.relayPool.add(
          RelayBase(
            answeredUrl,
            RelayStatus(answeredUrl),
            channelFactory: answeredFactory,
          ),
        );
        await nostr.relayPool.add(
          RelayBase(
            silentUrl,
            RelayStatus(silentUrl),
            channelFactory: silentFactory,
          ),
        );
        nostr.relayPool.subscriptionSilenceProbe = probe;

        final subId = subscribeToFeed();
        await Future<void>.delayed(Duration.zero);
        expect(
          _reqFrames(answeredFactory.createdChannels.single),
          hasLength(1),
        );
        expect(_reqFrames(silentFactory.createdChannels.single), hasLength(1));

        // Only the first relay answers; the second stays a silent zombie.
        answeredFactory.createdChannels.single.simulateMessage(
          jsonEncode(['EOSE', subId]),
        );

        await Future<void>.delayed(afterProbe);

        expect(
          silentFactory.createdChannels,
          hasLength(2),
          reason: 'the silent relay is the one the probe must cycle',
        );
        expect(
          answeredFactory.createdChannels,
          hasLength(1),
          reason:
              "a relay that EOSE'd is healthy and must not be cycled, even "
              'while a sibling on the same load is being repaired',
        );
      },
    );
  });
}
