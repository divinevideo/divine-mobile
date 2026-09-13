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

    /// Removes the age floor so a 100ms read can exercise the repair itself.
    ///
    /// Called per test rather than from [setUp]: a group-wide override leaves
    /// the shipped default exercised by nothing, and silently applies to every
    /// test added here later.
    void ignoreQueryAgeFloor() =>
        nostr.relayPool.minQueryAgeBeforeRepair = Duration.zero;

    Future<({List<Event> events, bool timedOut, bool noRelaysParticipated})>
    queryOnce() {
      return nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: const Duration(milliseconds: 100));
    }

    test('the shipped age floor sits between the settle window and the '
        'default read timeout', () {
      // Every other test here runs the knob at zero or at a value chosen to
      // suppress the repair, so the shipped default is the one value nothing
      // exercises -- and its dartdoc leans on both of these bounds.
      final floor = nostr.relayPool.minQueryAgeBeforeRepair;
      expect(
        floor,
        greaterThan(RelayPool.querySettleWindow),
        reason:
            'a query the settle window completed on the first relay\'s EOSE '
            'says nothing about the slower ones, so it must fall under the '
            'floor rather than force-cycle them',
      );
      expect(
        floor,
        lessThan(const Duration(seconds: 5)),
        reason:
            'a caller that spent the SDK default read timeout in full waited '
            'long enough for the silence to be evidence',
      );
    });

    test('a relay that accepts the REQ and never sends a terminal frame is '
        'force-reconnected', () async {
      ignoreQueryAgeFloor();
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
      await pumpEventQueue();
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'a socket that swallowed the REQ must be cycled',
      );
    });

    test('a relay that answers the REQ is left alone', () async {
      ignoreQueryAgeFloor();
      final channel = factory.createdChannels.single;

      final pending = queryOnce();
      await Future<void>.delayed(Duration.zero);
      channel.simulateMessage(jsonEncode(['EOSE', _lastReqSubId(channel)]));

      final result = await pending;
      expect(result.timedOut, isFalse);

      await pumpEventQueue();
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an EOSE-ing relay is healthy and must not be cycled',
      );
    });

    test(
      'a straggler the settle window abandons is still force-reconnected',
      () async {
        ignoreQueryAgeFloor();
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

        await pumpEventQueue();
        expect(
          factory.createdChannels,
          hasLength(2),
          reason: 'the relay that swallowed the REQ is still the zombie',
        );
      },
    );

    test('a query released before minQueryAgeBeforeRepair is not evidence '
        'against the socket (#7301)', () async {
      // The read below waits 100ms, far short of the floor: a caller that
      // gave the relay no real chance to answer proves nothing about the
      // socket, however silent the relay was inside that window.
      nostr.relayPool.minQueryAgeBeforeRepair = const Duration(seconds: 4);
      final zombieChannel = factory.createdChannels.single;

      final result = await queryOnce();
      expect(result.timedOut, isTrue);
      expect(
        zombieChannel.sentMessages
            .map((m) => jsonDecode(m as String) as List<dynamic>)
            .where((m) => m.first == 'REQ'),
        hasLength(1),
      );

      await pumpEventQueue();
      expect(
        factory.createdChannels,
        hasLength(1),
        reason:
            'a relay that went unanswered for 100ms has not been shown to '
            'be a zombie; cycling it would replay every subscription it '
            'carries',
      );

      // Positive control. The assertion above is a negative, which no amount
      // of waiting can establish on its own: a repair that simply never runs
      // looks identical to one the floor suppressed. Drop the floor and the
      // same silent socket is cycled, so the green above is the floor's doing.
      ignoreQueryAgeFloor();
      await queryOnce();
      await pumpEventQueue();
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'only the floor was holding the repair back',
      );
    });

    test(
      'a straggler the settle window abandons inside minQueryAgeBeforeRepair '
      'is left alone (#7301)',
      () async {
        // A second relay answers at once, so the settle window releases the
        // straggler about a second after the REQ — routine for a relay that
        // is merely slower than its peer, and no evidence of a dead socket.
        nostr.relayPool.minQueryAgeBeforeRepair = const Duration(seconds: 4);
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

        await pumpEventQueue();
        expect(
          factory.createdChannels,
          hasLength(1),
          reason: 'the slower relay keeps its socket and its subscriptions',
        );

        // Positive control, as above: prove the force-cycle is still
        // observable here and only the floor suppressed it.
        ignoreQueryAgeFloor();
        await queryOnce();
        await pumpEventQueue();
        expect(
          factory.createdChannels,
          hasLength(2),
          reason: 'only the floor was holding the repair back',
        );
      },
    );

    test('a relay that stays inbound-active is left alone — silence '
        'discriminates zombie from slow', () async {
      ignoreQueryAgeFloor();
      final channel = factory.createdChannels.single;

      final pending = queryOnce();
      await Future<void>.delayed(Duration.zero);
      // No terminal frame for our REQ, but the connection is demonstrably
      // alive: it is serving other traffic.
      channel.simulateMessage(jsonEncode(['NOTICE', 'busy']));

      final result = await pending;
      expect(result.timedOut, isTrue);

      await pumpEventQueue();
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an inbound-active connection must not be cycled',
      );
    });
  });
}
