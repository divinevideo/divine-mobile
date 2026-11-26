// ABOUTME: Validation probe for #9223: a COUNT that only some relays settled.
// ABOUTME: Scratch evidence for the issue validation, not a shipped test.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RelayPool.count when one relay does not settle (#9223)', () {
    const relayAUrl = 'wss://relay-a.test';
    const relayBUrl = 'wss://relay-b.test';
    final filters = [
      {
        'kinds': [16],
        '#e': [
          '2e6763e2f81be92707635a221f4e27ad8740df553b1b5058cf5a8cb125a7cbd3',
        ],
      },
    ];

    late FakeWebSocketChannelFactory factoryA;
    late FakeWebSocketChannelFactory factoryB;
    late Nostr nostr;

    setUp(() async {
      factoryA = FakeWebSocketChannelFactory();
      factoryB = FakeWebSocketChannelFactory();
      nostr = Nostr(
        LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        ),
        [],
        (url) => RelayBase(url, RelayStatus(url), channelFactory: factoryA),
      );
      expect(
        await nostr.relayPool.add(
          RelayBase(
            relayAUrl,
            RelayStatus(relayAUrl),
            channelFactory: factoryA,
          ),
        ),
        isTrue,
      );
      expect(
        await nostr.relayPool.add(
          RelayBase(
            relayBUrl,
            RelayStatus(relayBUrl),
            channelFactory: factoryB,
          ),
        ),
        isTrue,
      );
    });

    tearDown(() => nostr.close());

    String lastCountSubId(FakeWebSocketChannel channel) {
      final frame = channel.sentMessages
          .cast<String>()
          .where((f) => f.startsWith('["COUNT"'))
          .last;
      return (jsonDecode(frame) as List<dynamic>)[1] as String;
    }

    void answerCount(FakeWebSocketChannel channel, int count) {
      channel.simulateMessage(
        jsonEncode([
          'COUNT',
          lastCountSubId(channel),
          {'count': count},
        ]),
      );
    }

    void refuseCount(FakeWebSocketChannel channel) {
      channel.simulateMessage(
        jsonEncode(['CLOSED', lastCountSubId(channel), 'error: storage busy']),
      );
    }

    /// Runs one COUNT where relay A answers 3 and [relayB] decides what B does.
    Future<CountResponse> countWith(
      void Function(FakeWebSocketChannel channelB)? relayB, {
      required String id,
    }) async {
      final result = nostr.relayPool.count(
        filters,
        id: id,
        timeout: const Duration(milliseconds: 200),
      );
      await pumpEventQueue();
      answerCount(factoryA.lastChannel!, 3);
      relayB?.call(factoryB.lastChannel!);
      return result;
    }

    test('control: relay B answering a larger count changes the result, so B '
        'holds data the result depends on', () async {
      final withB = await countWith(
        (channelB) => answerCount(channelB, 7),
        id: 'control-b-answers-7',
      );

      expect(withB.count, equals(7));
    });

    test('control: two fully settled COUNTs with the same answers compare '
        'equal', () async {
      final first = await countWith(
        (channelB) => answerCount(channelB, 0),
        id: 'control-full-1',
      );
      final second = await countWith(
        (channelB) => answerCount(channelB, 0),
        id: 'control-full-2',
      );

      expect(first, equals(second));
    });

    test('a COUNT relay B never answered is distinguishable from one relay B '
        'answered', () async {
      final fullySettled = await countWith(
        (channelB) => answerCount(channelB, 0),
        id: 'full',
      );
      final bTimedOut = await countWith(null, id: 'b-timed-out');

      expect(
        bTimedOut,
        isNot(equals(fullySettled)),
        reason:
            'relay B timed out, so 3 is only a floor, but the pool returned '
            '$bTimedOut, the same value it returns when every relay answered '
            '($fullySettled)',
      );
    });

    test('a COUNT relay B refused with CLOSED is distinguishable from one '
        'relay B answered', () async {
      final fullySettled = await countWith(
        (channelB) => answerCount(channelB, 0),
        id: 'full-2',
      );
      final bRefused = await countWith(refuseCount, id: 'b-refused');

      expect(
        bRefused,
        isNot(equals(fullySettled)),
        reason:
            'relay B refused with CLOSED, so 3 is only a floor, but the pool '
            'returned $bRefused, the same value it returns when every relay '
            'answered ($fullySettled)',
      );
    });
  });
}
