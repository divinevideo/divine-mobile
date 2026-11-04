import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

import 'fixture_reader.dart';

void main() {
  final fixture = readConcordFixture('community-interop.json');
  final event = fixture['bundleEvent'] as Map<String, dynamic>;
  final fragment = ConcordInviteFragment.decode(
    Uri.parse(fixture['inviteUrl'] as String).fragment,
  );
  test(
    'opens the bridge signed kind33301 bundle using the v4 fragment',
    () async {
      final bundle = await openInviteBundle(
        event: event,
        expectedSigner: event['pubkey'] as String,
        token: fragment.token,
        nowMs: 0,
      );
      expect(bundle.communityId, (fixture['expected'] as Map)['communityId']);
    },
  );
  test(
    'rejects forged and wrong-coordinate bundles before decrypting',
    () async {
      for (final wrong in [
        {...event, 'content': '${event['content']}x'},
        {...event, 'kind': 1},
        {...event, 'pubkey': '11' * 32},
      ]) {
        await expectLater(
          openInviteBundle(
            event: wrong,
            expectedSigner: event['pubkey'] as String,
            token: fragment.token,
            nowMs: 0,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'opens split-control bridge editions with the independent read key',
    () async {
      final bundle = await openInviteBundle(
        event: event,
        expectedSigner: event['pubkey'] as String,
        token: fragment.token,
        nowMs: 0,
      );
      final key = controlReadKey(
        bundle.communityRoot,
        bundle.communityId,
        bundle.rootEpoch,
      );
      for (final raw in fixture['controlEvents'] as List) {
        final opened = await openControlWrap(
          wrap: raw as Map<String, dynamic>,
          readKey: key,
          streamPubkey: bundle.controlPubkey!,
        );
        expect(opened['kind'], 3308);
      }
    },
  );
  test(
    'folds owner-rooted public rooms, moderator and bans like the bridge',
    () async {
      final bundle = await openInviteBundle(
        event: event,
        expectedSigner: event['pubkey'] as String,
        token: fragment.token,
        nowMs: 0,
      );
      final key = controlReadKey(
        bundle.communityRoot,
        bundle.communityId,
        bundle.rootEpoch,
      );
      final editions = <ConcordEdition>[];
      for (final raw in fixture['controlEvents'] as List) {
        editions.add(
          ConcordEdition.parse(
            await openControlWrap(
              wrap: raw as Map<String, dynamic>,
              readKey: key,
              streamPubkey: bundle.controlPubkey!,
            ),
          ),
        );
      }
      final folded = foldCommunityControl(
        editions,
        communityId: bundle.communityId,
        owner: bundle.owner,
      );
      final expected = fixture['expected'] as Map;
      expect(folded.publicChannels.map((c) => c.name).toSet(), {
        'general',
        'introductions',
      });
      expect(folded.banned, {expected['bannedMember']});
      expect(folded.canManageMessages(expected['moderator'] as String), isTrue);
      expect(folded.canManageMessages(expected['member'] as String), isFalse);
      expect(folded.name, 'Synthetic shared community');
      final reversed = foldCommunityControl(
        editions.reversed.toList(),
        communityId: bundle.communityId,
        owner: bundle.owner,
      );
      expect(reversed.publicChannels.map((c) => c.name).toSet(), {
        'general',
        'introductions',
      });
    },
  );
  test('control streams reject noncanonical millisecond tags', () async {
    final read = controlReadKey('11' * 32, '22' * 32, 0);
    final author = schnorr.getPublicKey('33' * 32);
    for (final value in ['1000', '1e2', '01', '-1', '']) {
      final tags = <List<String>>[
        ['ms', value],
      ];
      final rumor = <String, dynamic>{
        'kind': 3308,
        'content': '{}',
        'pubkey': author,
        'created_at': 1,
        'tags': tags,
        'id': computeEventId(
          pubkey: author,
          createdAt: 1,
          kind: 3308,
          tags: tags,
          content: '{}',
        ),
      };
      final seal = await sealRumor(
        rumor: rumor,
        sealKind: 20014,
        streamSeedHex: read.seedHex,
        streamPubkey: read.pubkey,
        authorSecretHex: '33' * 32,
      );
      final wrap = await wrapSeal(
        seal: seal,
        streamSeedHex: read.seedHex,
        streamPubkey: read.pubkey,
      );
      await expectLater(
        openControlWrap(wrap: wrap, readKey: read, streamPubkey: read.pubkey),
        throwsFormatException,
      );
    }
  });
}
