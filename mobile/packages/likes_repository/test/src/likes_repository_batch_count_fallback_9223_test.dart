// ABOUTME: Validation probe for #9223: getLikeCounts' client-side counting
// ABOUTME: fallback over a real pool whose relays do not answer. Scratch only.

import 'dart:convert';

import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

import '../../../nostr_sdk/test/support/fake_web_socket.dart';

class _MockRelayManager extends Mock implements RelayManager {}

void main() {
  group('LikesRepository.getLikeCounts without addressable ids (#9223)', () {
    const relayAUrl = 'wss://relay-a.test';
    const relayBUrl = 'wss://relay-b.test';
    const videoEventId =
        '2e6763e2f81be92707635a221f4e27ad8740df553b1b5058cf5a8cb125a7cbd3';

    late FakeWebSocketChannelFactory factoryA;
    late FakeWebSocketChannelFactory factoryB;
    late Nostr nostr;
    late LikesRepository repository;

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
      for (final (url, factory) in [
        (relayAUrl, factoryA),
        (relayBUrl, factoryB),
      ]) {
        expect(
          await nostr.relayPool.add(
            RelayBase(url, RelayStatus(url), channelFactory: factory),
          ),
          isTrue,
        );
      }
      final relayManager = _MockRelayManager();
      when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
      when(
        () => relayManager.connectedRelays,
      ).thenReturn([relayAUrl, relayBUrl]);
      repository = LikesRepository(
        nostrClient: NostrClient.forTesting(
          nostr: nostr,
          relayManager: relayManager,
        ),
      );
    });

    tearDown(() => nostr.close());

    List<String> frames(FakeWebSocketChannel channel, String verb) => channel
        .sentMessages
        .cast<String>()
        .where((f) => f.startsWith('["$verb"'))
        .toList();

    String lastSubId(FakeWebSocketChannel channel, String verb) =>
        (jsonDecode(frames(channel, verb).last) as List<dynamic>)[1] as String;

    void sendEose(FakeWebSocketChannel channel) => channel.simulateMessage(
      jsonEncode(['EOSE', lastSubId(channel, 'REQ')]),
    );

    void answerCount(FakeWebSocketChannel channel, int count) =>
        channel.simulateMessage(
          jsonEncode([
            'COUNT',
            lastSubId(channel, 'COUNT'),
            {'count': count},
          ]),
        );

    /// Runs getLikeCounts; [relays] decides what each relay does with the REQ.
    Future<Map<String, int>> batch(
      void Function(FakeWebSocketChannel a, FakeWebSocketChannel b) relays,
    ) async {
      final result = repository.getLikeCounts([videoEventId]);
      await pumpEventQueue();
      relays(factoryA.lastChannel!, factoryB.lastChannel!);
      return result;
    }

    /// Whether a later getLikeCount asks a relay, and what it returns.
    Future<({bool askedRelay, int? count})> followUp() async {
      final before =
          frames(factoryA.lastChannel!, 'COUNT').length +
          frames(factoryB.lastChannel!, 'COUNT').length;
      final result = repository.getLikeCount(videoEventId);
      await pumpEventQueue();
      final asked =
          frames(factoryA.lastChannel!, 'COUNT').length +
              frames(factoryB.lastChannel!, 'COUNT').length >
          before;
      if (asked) {
        answerCount(factoryA.lastChannel!, 5);
        answerCount(factoryB.lastChannel!, 5);
      }
      return (askedRelay: asked, count: await result);
    }

    test('control: both relays answering "none" is cached as 0', () async {
      final counts = await batch((a, b) {
        sendEose(a);
        sendEose(b);
      });
      expect(counts, equals({videoEventId: 0}));

      final next = await followUp();
      expect(next.askedRelay, isFalse);
      expect(next.count, equals(0));
    });

    test('control: without the batch, getLikeCount asks the relays', () async {
      final next = await followUp();
      expect(next.askedRelay, isTrue);
      expect(next.count, equals(5));
    });

    test('a batch no relay answered does not become a cached 0', () async {
      final counts = await batch((_, _) {});

      final next = await followUp();
      expect(
        next.askedRelay,
        isTrue,
        reason:
            'no relay answered the reaction query, yet getLikeCounts returned '
            '$counts and cached it; getLikeCount then served ${next.count} '
            'without asking a relay',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a batch only relay B answered does not become a cached 0', () async {
      final counts = await batch((_, b) => sendEose(b));

      final next = await followUp();
      expect(
        next.askedRelay,
        isTrue,
        reason:
            'relay A never answered the reaction query, yet getLikeCounts '
            'returned $counts and cached it; getLikeCount then served '
            '${next.count} without asking a relay',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
