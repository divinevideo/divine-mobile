// MPL-2.0
import 'dart:convert';
import 'dart:io';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

class _FakeRelay implements RelayGateway {
  final published = <Map<String, dynamic>>[];
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> f) =>
      const Stream.empty();
  @override
  Future<void> publish(Map<String, dynamic> e) async => published.add(e);
}

Map<String, dynamic> _signerFor(String secretHex) => {
  'secret': secretHex,
};

Future<Map<String, dynamic>> _sign(
  Map<String, dynamic> signer,
  Map<String, dynamic> template,
) async {
  final secret = signer['secret'] as String;
  final tags = (template['tags'] as List)
      .map((t) => (t as List).map((e) => '$e').toList())
      .toList();
  final id = computeEventId(
    pubkey: schnorr.getPublicKey(secret),
    createdAt: template['created_at'] as int,
    kind: template['kind'] as int,
    tags: tags,
    content: template['content'] as String,
  );
  return {
    ...template,
    'id': id,
    'pubkey': schnorr.getPublicKey(secret),
    'sig': schnorr.sign(secret, id, '00' * 32),
  };
}

String _readFixture() {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    for (final rel in [
      '../concord_protocol/test/fixtures/fixtures.json',
      'packages/concord_protocol/test/fixtures/fixtures.json',
    ]) {
      final file = File('${dir.path}/$rel');
      if (file.existsSync()) return file.readAsStringSync();
    }
    dir = dir.parent;
  }
  throw StateError('fixtures.json not found');
}

void main() {
  group('sealed', () {
    test(
      'SealedChatTransport publishes 1059 wraps and opens received wraps',
      () async {
        final fx = jsonDecode(_readFixture()) as Map<String, dynamic>;
        final alice =
            (fx['identities'] as Map)['alice'] as Map<String, dynamic>;
        final bob = (fx['identities'] as Map)['bob'] as Map<String, dynamic>;
        final secrets = fx['secrets'] as Map<String, dynamic>;
        final channelId =
            ((fx['derivations'] as Map)['publicChannel'] as Map)['channelId']
                as String;
        final stream = publicChannelKey(
          secrets['communityRoot'] as String,
          channelId,
          0,
        );
        final relay = _FakeRelay();
        final aliceSigner = _signerFor(alice['secret'] as String);
        final transport = SealedChatTransport(
          relay: relay,
          signer: (t) => _sign(aliceSigner, t),
        );
        final tags = [
          ['channel', channelId],
          ['epoch', '0'],
          ['ms', '5'],
          ['p', bob['pubkey'] as String],
        ];
        final rumor = <String, dynamic>{
          'id': computeEventId(
            pubkey: alice['pubkey'] as String,
            createdAt: 1700000200,
            kind: 9,
            tags: tags,
            content: 'live sealed hello',
          ),
          'kind': 9,
          'pubkey': alice['pubkey'],
          'created_at': 1700000200,
          'tags': tags,
          'content': 'live sealed hello',
        };
        await transport.sendRumor(
          rumor: rumor,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
        expect(relay.published, hasLength(1));
        expect(relay.published.single['kind'], 1059);
        expect(relay.published.single['pubkey'], stream.pubkey);

        // Bob (another signer) opens what Alice published.
        final bobTransport = SealedChatTransport(
          relay: _FakeRelay(),
          signer: (t) => _sign(_signerFor(bob['secret'] as String), t),
        );
        final opened = await bobTransport.openIncoming(
          wrap: relay.published.single,
          expectedChannelId: channelId,
          expectedEpoch: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
        expect(opened['tags'], contains(equals(['p', bob['pubkey']])));
        expect(
          relay.published.single['tags'],
          isNot(contains(equals(['p', bob['pubkey']]))),
        );
        expect(opened['content'], 'live sealed hello');
        expect(opened['author'], alice['pubkey']);
      },
    );
  });
}
