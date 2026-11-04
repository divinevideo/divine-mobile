import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

class _Relay implements RelayGateway {
  final published = <Map<String, dynamic>>[];
  @override
  Future<void> publish(Map<String, dynamic> event) async {
    published.add(event);
  }

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      const Stream.empty();
}

class _Cipher implements StreamCipher {
  @override
  String open(String p, String k) => throw UnimplementedError();
  @override
  String seal(String p, String k) => throw UnimplementedError();
}

void main() {
  test(
    'a signer returning after authority changes cannot publish or accept the draft into its outbox',
    () async {
      var allowed = true;
      final relay = _Relay();
      final secret = '33' * 32;
      final author = schnorr.getPublicKey(secret);
      final stream = publicChannelKey('11' * 32, '22' * 32, 0);
      final transport = SealedChatTransport(
        relay: relay,
        signer: (template) async {
          allowed = false;
          final id = computeEventId(
            pubkey: author,
            createdAt: template['created_at'] as int,
            kind: template['kind'] as int,
            tags: (template['tags'] as List).cast<List<String>>(),
            content: template['content'] as String,
          );
          return {
            ...template,
            'pubkey': author,
            'id': id,
            'sig': schnorr.sign(secret, id, '00' * 32),
          };
        },
      );
      final repo = ConcordRepository(
        relay: relay,
        store: InMemoryConcordStore(author),
        cipher: _Cipher(),
        sealedTransport: transport,
        canPublish: () => allowed,
      );
      await expectLater(
        repo.sendSealedMessage(
          channelId: '22' * 32,
          author: author,
          body: 'keep this draft',
          createdAt: 1,
          ms: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        ),
        throwsStateError,
      );
      expect(relay.published, isEmpty);
      expect(repo.pendingIds, isEmpty);
      await repo.close();
    },
  );
}
