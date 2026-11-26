// ABOUTME: Validation probe for #9223: pool -> NostrClient -> RepostsRepository
// ABOUTME: with one relay that never answers COUNT. Scratch evidence only.

import 'dart:convert';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

import '../../../nostr_sdk/test/support/fake_web_socket.dart';

class _MockRelayManager extends Mock implements RelayManager {}

void main() {
  group(
    'RepostsRepository.getRepostCountByEventId over a real pool (#9223)',
    () {
      const relayAUrl = 'wss://relay-a.test';
      const relayBUrl = 'wss://relay-b.test';
      const videoEventId =
          '2e6763e2f81be92707635a221f4e27ad8740df553b1b5058cf5a8cb125a7cbd3';

      late FakeWebSocketChannelFactory factoryA;
      late FakeWebSocketChannelFactory factoryB;
      late Nostr nostr;
      late NostrClient client;
      late RepostsRepository repository;

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
        final relayManager = _MockRelayManager();
        when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
        client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: relayManager,
        );
        repository = RepostsRepository(nostrClient: client);
      });

      tearDown(() => nostr.close());

      List<String> countFrames(FakeWebSocketChannel channel) => channel
          .sentMessages
          .cast<String>()
          .where((f) => f.startsWith('["COUNT"'))
          .toList();

      void answerCount(FakeWebSocketChannel channel, int count) {
        final subId =
            (jsonDecode(countFrames(channel).last) as List<dynamic>)[1]
                as String;
        channel.simulateMessage(
          jsonEncode([
            'COUNT',
            subId,
            {'count': count},
          ]),
        );
      }

      Future<int?> fetch(void Function(FakeWebSocketChannel channelB)? relayB) {
        final result = repository.getRepostCountByEventId(videoEventId);
        return () async {
          await pumpEventQueue();
          answerCount(factoryA.lastChannel!, 3);
          relayB?.call(factoryB.lastChannel!);
          return result;
        }();
      }

      test('control: relay B answering 7 is the count shown', () async {
        expect(await fetch((b) => answerCount(b, 7)), equals(7));
      });

      test(
        'control: a fully settled count is cached and not asked again',
        () async {
          expect(await fetch((b) => answerCount(b, 0)), equals(3));
          final framesBefore = countFrames(factoryA.lastChannel!).length;

          expect(await repository.getRepostCountByEventId(videoEventId), 3);
          expect(countFrames(factoryA.lastChannel!), hasLength(framesBefore));
        },
      );

      test(
        'a count relay B never answered is not kept as the session count',
        () async {
          final first = await fetch(null);
          expect(
            first,
            equals(3),
            reason: 'relay A answered 3, relay B timed out',
          );
          final framesBefore = countFrames(factoryA.lastChannel!).length;

          final second = repository.getRepostCountByEventId(videoEventId);
          await pumpEventQueue();
          final askedAgain =
              countFrames(factoryA.lastChannel!).length > framesBefore;
          if (askedAgain) {
            answerCount(factoryA.lastChannel!, 3);
            answerCount(factoryB.lastChannel!, 7);
          }

          expect(
            askedAgain,
            isTrue,
            reason:
                'relay B never answered the first COUNT, so 3 was only a '
                'floor; the repository cached it and served ${await second} '
                'without '
                'asking a relay again',
          );
        },
        timeout: const Timeout(Duration(seconds: 20)),
      );
    },
  );
}
