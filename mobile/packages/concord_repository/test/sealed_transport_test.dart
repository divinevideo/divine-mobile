// MPL-2.0
import 'dart:convert';
import 'dart:io';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

String _readFixture() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    for (final rel in [
      '../concord_protocol/test/fixtures/fixtures.json',
      'packages/concord_protocol/test/fixtures/fixtures.json',
      'test/fixtures/fixtures.json',
    ]) {
      final file = File('${dir.path}/$rel');
      if (file.existsSync()) return file.readAsStringSync();
    }
    dir = dir.parent;
  }
  throw StateError('fixtures.json not found from ${Directory.current.path}');
}

void main() {
  group('sealed', () {
    test('sealed plane round-trips and rejects tampered wrap author', () async {
      final fx = jsonDecode(_readFixture()) as Map<String, dynamic>;
      final alice = (fx['identities'] as Map)['alice'] as Map<String, dynamic>;
      final secrets = fx['secrets'] as Map<String, dynamic>;
      final channelId =
          ((fx['derivations'] as Map)['publicChannel'] as Map)['channelId']
              as String;
      final stream = publicChannelKey(
        secrets['communityRoot'] as String,
        channelId,
        0,
      );
      final rumor = <String, dynamic>{
        'id': computeEventId(
          pubkey: alice['pubkey'] as String,
          createdAt: 1700000000,
          kind: 9,
          tags: [
            ['channel', channelId],
            ['epoch', '0'],
            ['ms', '42'],
          ],
          content: 'sealed hello',
        ),
        'kind': 9,
        'pubkey': alice['pubkey'],
        'created_at': 1700000000,
        'tags': [
          ['channel', channelId],
          ['epoch', '0'],
          ['ms', '42'],
        ],
        'content': 'sealed hello',
      };
      final seal = await sealRumor(
        rumor: rumor,
        sealKind: 20013,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
        authorSecretHex: alice['secret'] as String,
      );
      expect(seal['kind'], 20013);
      final wrap = await wrapSeal(
        seal: seal,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
      expect(wrap['kind'], 1059);
      expect(wrap['pubkey'], stream.pubkey);
      final opened = await openWrap(
        wrap: wrap,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
      expect(opened['content'], 'sealed hello');
      expect(opened['author'], alice['pubkey']);
      await expectLater(
        openWrap(
          wrap: {...wrap, 'pubkey': alice['pubkey']},
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        ),
        throwsA(anything),
      );
    });
  });
}
