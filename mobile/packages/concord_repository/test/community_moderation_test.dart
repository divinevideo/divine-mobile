import 'dart:convert';
import 'dart:io';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

class _Relay implements RelayGateway {
  @override
  Future<void> publish(Map<String, dynamic> event) async {}
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      const Stream.empty();
}

class _Cipher implements StreamCipher {
  @override
  String open(String a, String b) => throw UnimplementedError();
  @override
  String seal(String a, String b) => throw UnimplementedError();
}

void main() {
  test(
    'bridge moderation hides banned authors and cited moderator removals from retained history',
    () async {
      final fixture =
          jsonDecode(
                File(
                  '../concord_protocol/test/fixtures/community-moderation.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final event = fixture['bundleEvent'] as Map<String, dynamic>;
      final fragment = ConcordInviteFragment.decode(
        Uri.parse(fixture['inviteUrl'] as String).fragment,
      );
      final bundle = await openInviteBundle(
        event: event,
        expectedSigner: event['pubkey'] as String,
        token: fragment.token,
        nowMs: 0,
      );
      final read = controlReadKey(
        bundle.communityRoot,
        bundle.communityId,
        bundle.rootEpoch,
      );
      final editions = <ConcordEdition>[];
      for (final wrap in fixture['controlEvents'] as List) {
        editions.add(
          ConcordEdition.parse(
            await openControlWrap(
              wrap: wrap as Map<String, dynamic>,
              readKey: read,
              streamPubkey: bundle.controlPubkey!,
            ),
          ),
        );
      }
      final state = foldCommunityControl(
        editions,
        communityId: bundle.communityId,
        owner: bundle.owner,
      );
      final channel =
          ((fixture['expected'] as Map)['message'] as Map)['channelId']
              as String;
      final stream = publicChannelKey(bundle.communityRoot, channel, 0);
      final store = InMemoryConcordStore('44' * 32);
      final relay = _Relay();
      ConcordRepository repo() => ConcordRepository(
        relay: relay,
        store: store,
        cipher: _Cipher(),
        sealedTransport: SealedChatTransport(
          relay: relay,
          signer: (_) async => throw UnimplementedError(),
        ),
        controlState: () => state,
      );
      final first = repo();
      await first.startChannel(
        channelId: channel,
        epoch: 0,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
      for (final name in ['chatEvent', 'bannedChatEvent'])
        await first.ingestSealedWrap(fixture[name] as Map<String, dynamic>);
      expect(first.timeline(now: 1793761700).messages.length, 1);
      await first.ingestSealedWrap(
        fixture['moderatorDeleteEvent'] as Map<String, dynamic>,
      );
      expect(first.timeline(now: 1793761700).messages, isEmpty);
      await first.close();
      final restored = repo();
      await restored.startChannel(
        channelId: channel,
        epoch: 0,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
      expect(restored.timeline(now: 1793761700).messages, isEmpty);
      await restored.close();
    },
  );
}
