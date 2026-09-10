// ABOUTME: Regression tests for zombie-socket remediation driven by a timed-out
// ABOUTME: one-shot query, mirroring the OK-timeout path on the publish side.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

/// Subscription id of the most recent REQ frame written to [channel].
String _lastReqSubId(FakeWebSocketChannel channel) {
  final frames = channel.sentMessages
      .map((m) => jsonDecode(m as String) as List<dynamic>)
      .where((m) => m.first == 'REQ');
  return frames.last[1] as String;
}

void main() {
  group('RelayPool zombie-socket remediation on query timeout', () {
    const relayUrl = 'wss://relay.divine.video';
    late Nostr nostr;
    late FakeWebSocketChannelFactory factory;
    late RelayBase relay;

    setUp(() async {
      final signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      factory = FakeWebSocketChannelFactory();
      relay = RelayBase(
        relayUrl,
        RelayStatus(relayUrl),
        channelFactory: factory,
      );
      await nostr.relayPool.add(relay);
    });

    Future<
      ({
        List<Event> events,
        bool timedOut,
        bool noRelaysParticipated,
        bool anyRelayAnswered,
        List<String> unsettledRelays,
      })
    >
    queryOnce() {
      return nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: const Duration(milliseconds: 100));
    }

    test('a relay that accepts the REQ and never sends a terminal frame is '
        'force-reconnected', () async {
      expect(factory.createdChannels, hasLength(1));
      final zombieChannel = factory.createdChannels.single;

      final result = await queryOnce();

      // The REQ was written; nothing came back, so the caller had to time out.
      expect(
        zombieChannel.sentMessages
            .map((m) => jsonDecode(m as String) as List<dynamic>)
            .where((m) => m.first == 'REQ'),
        hasLength(1),
      );
      expect(result.timedOut, isTrue);

      // Remediation runs asynchronously once the caller abandons the query.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'a socket that swallowed the REQ must be cycled',
      );
    });

    test('a relay that answers the REQ is left alone', () async {
      final channel = factory.createdChannels.single;

      final pending = queryOnce();
      await Future<void>.delayed(Duration.zero);
      channel.simulateMessage(jsonEncode(['EOSE', _lastReqSubId(channel)]));

      final result = await pending;
      expect(result.timedOut, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an EOSE-ing relay is healthy and must not be cycled',
      );
    });

    test(
      'a straggler the settle window abandons is still force-reconnected',
      () async {
        // A second relay answers, so the caller is released by the settle
        // window rather than by the timeout. Remediation keys off the query
        // being abandoned, not off how the caller was released.
        const answeringUrl = 'wss://answers.example';
        final answeringFactory = FakeWebSocketChannelFactory();
        await nostr.relayPool.add(
          RelayBase(
            answeringUrl,
            RelayStatus(answeringUrl),
            channelFactory: answeringFactory,
          ),
        );
        final answeringChannel = answeringFactory.createdChannels.single;

        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: const Duration(seconds: 4));
        await Future<void>.delayed(Duration.zero);
        answeringChannel.simulateMessage(
          jsonEncode(['EOSE', _lastReqSubId(answeringChannel)]),
        );

        final result = await pending;
        expect(result.timedOut, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          factory.createdChannels,
          hasLength(2),
          reason: 'the relay that swallowed the REQ is still the zombie',
        );
      },
    );

    test('a relay that stays inbound-active is left alone — silence '
        'discriminates zombie from slow', () async {
      final channel = factory.createdChannels.single;

      final pending = queryOnce();
      await Future<void>.delayed(Duration.zero);
      // No terminal frame for our REQ, but the connection is demonstrably
      // alive: it is serving other traffic.
      channel.simulateMessage(jsonEncode(['NOTICE', 'busy']));

      final result = await pending;
      expect(result.timedOut, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an inbound-active connection must not be cycled',
      );
    });
  });
}
