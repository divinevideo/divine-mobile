// ABOUTME: Tests that RelayPool.count reports whether every relay settled.
// ABOUTME: A relay that timed out or refused leaves the count a floor (#9223).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../support/fake_web_socket.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RelayPool.count completeness', () {
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

    void sendUnknownCommandNotice(FakeWebSocketChannel channel) {
      channel.simulateMessage(
        jsonEncode(['NOTICE', 'ERROR: bad msg: unknown cmd']),
      );
    }

    test('is complete when every relay answered', () async {
      final result = await countWith(
        (channelB) => answerCount(channelB, 7),
        id: 'all-answered',
      );

      expect(result.count, equals(7));
      expect(result.isComplete, isTrue);
    });

    test('is incomplete when a relay never answered', () async {
      final result = await countWith(null, id: 'b-timed-out');

      expect(result.count, equals(3));
      expect(result.isComplete, isFalse);
    });

    test('is incomplete when a relay refused with CLOSED', () async {
      final result = await countWith(refuseCount, id: 'b-refused');

      expect(result.count, equals(3));
      expect(result.isComplete, isFalse);
    });

    test(
      'stays complete when a relay replied it does not know COUNT',
      () async {
        final result = await countWith(
          sendUnknownCommandNotice,
          id: 'b-unknown-command',
        );

        expect(result.count, equals(3));
        expect(result.isComplete, isTrue);
      },
    );
  });
}
