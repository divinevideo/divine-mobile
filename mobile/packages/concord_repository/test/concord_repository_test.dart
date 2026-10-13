// MPL-2.0
import 'dart:convert';
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

class _Cipher implements StreamCipher {
  @override
  String seal(String p, String s) => base64.encode(utf8.encode(p));
  @override
  String open(String c, String s) => utf8.decode(base64.decode(c));
}

void main() {
  group('ConcordRepository', () {
    test('send publishes non-NIP-59 envelope; accounts isolated', () async {
      final relay = _FakeRelay();
      final storeA = InMemoryConcordStore('a' * 64);
      final repo = ConcordRepository(
        relay: relay,
        store: storeA,
        cipher: _Cipher(),
      );
      await repo.send(
        communityId: 'c',
        channelId: 'general',
        author: 'a' * 64,
        body: 'hi',
        createdAt: 1,
      );
      expect(relay.published.single['kind'], streamEnvelopeKind);
      await repo.acceptInvite('c');
      expect(await repo.hasAcceptedInvite('c'), isTrue);
      final storeB = InMemoryConcordStore('b' * 64);
      expect(
        await ConcordRepository(
          relay: relay,
          store: storeB,
          cipher: _Cipher(),
        ).hasAcceptedInvite('c'),
        isFalse,
      );
      expect(repo.timeline(now: 10).messages.single.body, 'hi');
    });
  });
}
