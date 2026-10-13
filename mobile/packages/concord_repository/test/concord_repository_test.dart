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
      expect(relay.published.single['kind'], streamWrapKind);
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
    test(
      'offline restart restores messages; interrupted publish retries',
      () async {
        final relay = _FakeRelay();
        final store = InMemoryConcordStore('a' * 64);
        final repo = ConcordRepository(
          relay: relay,
          store: store,
          cipher: _Cipher(),
        );
        await repo.send(
          communityId: 'c',
          channelId: 'general',
          author: 'a' * 64,
          body: 'persisted',
          createdAt: 1,
        );
        // Simulate restart with a fresh repository over the same store,
        // plus an interrupted publish (msg persisted, never marked sent).
        await store.put('msg:pending1', 'draft');
        await store.put('meta:pending1', 'general|${'a' * 64}|2|');
        final idx = await store.get('index');
        await store.put('index', '$idx,pending1');
        final restarted = ConcordRepository(
          relay: relay,
          store: store,
          cipher: _Cipher(),
        );
        final pending = await restarted.restore();
        expect(
          restarted.timeline(now: 10).messages.map((m) => m.body),
          containsAll(['persisted', 'draft']),
        );
        expect(pending, ['pending1']);
        await restarted.retryPending();
        expect(await store.get('sent:pending1'), '1');
      },
    );
    test('purgeExpired drops expired messages from store index', () async {
      final relay = _FakeRelay();
      final store = InMemoryConcordStore('a' * 64);
      final repo = ConcordRepository(
        relay: relay,
        store: store,
        cipher: _Cipher(),
      );
      await repo.send(
        communityId: 'c',
        channelId: 'general',
        author: 'a' * 64,
        body: 'ephemeral',
        createdAt: 1,
        expiresAt: 5,
      );
      await repo.purgeExpired(now: 10);
      expect(repo.timeline(now: 10).messages, isEmpty);
      expect(await store.get('index'), '');
    });
    test('purgeExpired removes the expired message rows', () async {
      final store = InMemoryConcordStore('a' * 64);
      final repo = ConcordRepository(
        relay: _FakeRelay(),
        store: store,
        cipher: _Cipher(),
      );
      await repo.send(
        communityId: 'c',
        channelId: 'general',
        author: 'a' * 64,
        body: 'ephemeral',
        createdAt: 1,
        expiresAt: 5,
      );
      final id = repo.timeline(now: 1).messages.single.id;
      expect(await store.get('msg:$id'), 'ephemeral');
      await repo.purgeExpired(now: 10);
      for (final key in ['msg', 'meta', 'sent']) {
        expect(await store.get('$key:$id'), isNull, reason: key);
      }
    });
    test('purgeExpired before restore keeps unexpired messages', () async {
      final store = InMemoryConcordStore('a' * 64);
      await ConcordRepository(
        relay: _FakeRelay(),
        store: store,
        cipher: _Cipher(),
      ).send(
        communityId: 'c',
        channelId: 'general',
        author: 'a' * 64,
        body: 'kept',
        createdAt: 1,
      );
      final restarted = ConcordRepository(
        relay: _FakeRelay(),
        store: store,
        cipher: _Cipher(),
      );
      await restarted.purgeExpired(now: 10);
      await restarted.restore();
      expect(restarted.timeline(now: 10).messages.single.body, 'kept');
    });
  });
  group(InMemoryConcordStore, () {
    test('scoped prefixes the key with the account', () {
      expect(
        InMemoryConcordStore('a' * 64).scoped('index'),
        'concord:v1:${'a' * 64}:index',
      );
    });
    test('clearAccount removes the account rows', () async {
      final store = InMemoryConcordStore('a' * 64);
      await store.put('index', 'x');
      expect(await store.get('index'), 'x');
      await store.clearAccount();
      expect(await store.get('index'), isNull);
    });
  });
}
