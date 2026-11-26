// ABOUTME: Validation probe for #9223: getLikeCount for an addressable video
// ABOUTME: when the settle window cuts a silent relay off. Scratch only.

import 'dart:convert';

import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

import '../../../nostr_sdk/test/support/fake_web_socket.dart';

class _MockRelayManager extends Mock implements RelayManager {}

void main() {
  group('LikesRepository.getLikeCount with an addressable id (#9223)', () {
    const relayAUrl = 'wss://relay-a.test';
    const relayBUrl = 'wss://relay-b.test';
    const videoEventId =
        '2e6763e2f81be92707635a221f4e27ad8740df553b1b5058cf5a8cb125a7cbd3';
    final addressableId = '34236:${'a' * 64}:clip-9223';

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

    List<String> reqSubIds(FakeWebSocketChannel channel) => channel.sentMessages
        .cast<String>()
        .where((f) => f.startsWith('["REQ"'))
        .map((f) => (jsonDecode(f) as List<dynamic>)[1] as String)
        .toList();

    void eoseAll(FakeWebSocketChannel channel) {
      for (final subId in reqSubIds(channel)) {
        channel.simulateMessage(jsonEncode(['EOSE', subId]));
      }
    }

    int reqCount() =>
        reqSubIds(factoryA.lastChannel!).length +
        reqSubIds(factoryB.lastChannel!).length;

    Future<int?> fetch(
      void Function(FakeWebSocketChannel a, FakeWebSocketChannel b) relays,
    ) async {
      final result = repository.getLikeCount(
        videoEventId,
        addressableId: addressableId,
      );
      await pumpEventQueue();
      relays(factoryA.lastChannel!, factoryB.lastChannel!);
      return result;
    }

    test('control: no relay answering leaves the count unknown and asks '
        'again (#10846)', () async {
      expect(await fetch((_, _) {}), isNull);

      final before = reqCount();
      final again = repository.getLikeCount(
        videoEventId,
        addressableId: addressableId,
      );
      await pumpEventQueue();
      expect(reqCount(), greaterThan(before));
      eoseAll(factoryA.lastChannel!);
      eoseAll(factoryB.lastChannel!);
      expect(await again, equals(0));
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('a count relay A never answered is not cached once the settle '
        'window cuts it off', () async {
      final first = await fetch((_, b) => eoseAll(b));

      final before = reqCount();
      final again = repository.getLikeCount(
        videoEventId,
        addressableId: addressableId,
      );
      await pumpEventQueue();
      final askedAgain = reqCount() > before;
      if (askedAgain) {
        eoseAll(factoryA.lastChannel!);
        eoseAll(factoryB.lastChannel!);
      }

      expect(
        askedAgain,
        isTrue,
        reason:
            'relay A never answered, but the settle window ended the read as '
            'finished, so getLikeCount cached $first and then served '
            '${await again} without asking a relay',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
