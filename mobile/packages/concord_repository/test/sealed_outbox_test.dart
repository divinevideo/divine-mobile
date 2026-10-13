import 'dart:async';
import 'dart:convert';
import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

class Relay implements RelayGateway {
  final events = StreamController<Map<String, dynamic>>.broadcast();
  final published = <Map<String, dynamic>>[];
  bool reject = false;
  Future<void> Function(Map<String, dynamic>)? beforeReject;
  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) =>
      events.stream;
  @override
  Future<void> publish(Map<String, dynamic> event) async {
    published.add(event);
    await beforeReject?.call(event);
    if (reject) throw StateError('relay rejected');
  }
}

class NoLegacyCipher implements StreamCipher {
  @override
  String seal(String p, String s) => throw StateError('legacy not supported');
  @override
  String open(String p, String s) => throw StateError('legacy not supported');
}

class DelayedStore extends InMemoryConcordStore {
  DelayedStore() : super('a' * 64);
  Completer<void>? blockRead;
  final reading = Completer<void>();
  int writes = 0;
  bool failRead = false;
  @override
  Future<String?> get(String key) async {
    if (key == 'sealed' && failRead) {
      failRead = false;
      throw StateError('read failed');
    }
    if (key == 'sealed' && blockRead != null) {
      reading.complete();
      await blockRead!.future;
    }
    return super.get(key);
  }

  @override
  Future<void> put(String key, String value) async {
    writes++;
    return super.put(key, value);
  }
}

Future<Map<String, dynamic>> sign(Map<String, dynamic> t) async {
  final secret = '01' * 32;
  final pubkey = schnorr.getPublicKey(secret);
  final id = computeEventId(
    pubkey: pubkey,
    createdAt: t['created_at'] as int,
    kind: t['kind'] as int,
    tags: (t['tags'] as List).cast<List<String>>(),
    content: t['content'] as String,
  );
  return {
    ...t,
    'pubkey': pubkey,
    'id': id,
    'sig': schnorr.sign(secret, id, '00' * 32),
  };
}

void main() {
  group('retryPending', () {
    test('sealed retry republishes the original wrap after restart', () async {
      final relay = Relay()..reject = true;
      addTearDown(relay.events.close);
      final store = InMemoryConcordStore('a' * 64);
      ConcordRepository repo() => ConcordRepository(
        relay: relay,
        store: store,
        cipher: NoLegacyCipher(),
        sealedTransport: SealedChatTransport(relay: relay, signer: sign),
      );
      final stream = publicChannelKey('02' * 32, '03' * 32, 0);
      await expectLater(
        repo().sendSealedMessage(
          channelId: '03' * 32,
          author: schnorr.getPublicKey('01' * 32),
          body: 'recover me',
          createdAt: 10,
          ms: 125,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        ),
        throwsStateError,
      );
      final original = jsonEncode(relay.published.single);
      relay.reject = false;
      final restarted = repo();
      await restarted.restore();
      await restarted.retryPending();
      expect(restarted.pendingIds, isEmpty);
      expect(relay.published, hasLength(2));
      expect(jsonEncode(relay.published.last), original);
    });
  });

  group('startChannel', () {
    test(
      'incoming wraps render once, survive restart, and expire from storage',
      () async {
        final relay = Relay();
        addTearDown(relay.events.close);
        final store = InMemoryConcordStore('a' * 64);
        final stream = publicChannelKey('02' * 32, '03' * 32, 0);
        var now = 10;
        ConcordRepository repo() => ConcordRepository(
          relay: relay,
          store: store,
          cipher: NoLegacyCipher(),
          sealedTransport: SealedChatTransport(relay: relay, signer: sign),
        );
        final sender = repo();
        final wrap = await sender.sendSealedMessage(
          channelId: '03' * 32,
          author: schnorr.getPublicKey('01' * 32),
          body: 'incoming',
          createdAt: 10,
          expiresAt: 15,
          ms: 125,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
        final receivingStore = InMemoryConcordStore('b' * 64);
        final receiver = ConcordRepository(
          relay: relay,
          store: receivingStore,
          cipher: NoLegacyCipher(),
          sealedTransport: SealedChatTransport(relay: relay, signer: sign),
        );
        addTearDown(receiver.close);
        await receiver.startChannel(
          channelId: '03' * 32,
          epoch: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
          now: () => now,
        );
        final changed = receiver.changes.first;
        relay.events.add(wrap);
        await changed;
        expect(receiver.timeline(now: now).messages.single.body, 'incoming');
        await receiver.ingestSealedWrap(wrap);
        expect(receiver.timeline(now: now).messages, hasLength(1));
        expect(await receivingStore.get('sealed'), isNot(contains('incoming')));
        now = 15;
        await receiver.purgeExpired(now: now);
        expect(receiver.timeline(now: now).messages, isEmpty);
        expect(
          jsonDecode((await receivingStore.get('sealed'))!) as Map,
          isEmpty,
        );
        await receiver.ingestSealedWrap(wrap);
        expect(
          jsonDecode((await receivingStore.get('sealed'))!) as Map,
          isEmpty,
        );
      },
    );
  });

  group('sendSealedMessage', () {
    test(
      'failed acknowledgement stays pending and signing failure stores nothing',
      () async {
        final relay = Relay()..reject = true;
        addTearDown(relay.events.close);
        final store = InMemoryConcordStore('a' * 64);
        final transport = SealedChatTransport(relay: relay, signer: sign);
        final repo = ConcordRepository(
          relay: relay,
          store: store,
          cipher: NoLegacyCipher(),
          sealedTransport: transport,
        );
        addTearDown(repo.close);
        final stream = publicChannelKey('02' * 32, '03' * 32, 0);
        await expectLater(
          repo.sendSealedMessage(
            channelId: '03' * 32,
            author: schnorr.getPublicKey('01' * 32),
            body: 'pending',
            createdAt: 10,
            ms: 125,
            streamSeedHex: stream.seedHex,
            streamPubkey: stream.pubkey,
          ),
          throwsStateError,
        );
        expect(repo.pendingIds, hasLength(1));
        await expectLater(repo.retryPending(), throwsStateError);
        expect(repo.pendingIds, hasLength(1));
        final emptyStore = InMemoryConcordStore('b' * 64);
        final refused = ConcordRepository(
          relay: relay,
          store: emptyStore,
          cipher: NoLegacyCipher(),
          sealedTransport: SealedChatTransport(
            relay: relay,
            signer: (_) async => throw StateError('refused'),
          ),
        );
        addTearDown(refused.close);
        await expectLater(
          refused.sendSealedMessage(
            channelId: '03' * 32,
            author: schnorr.getPublicKey('01' * 32),
            body: 'draft',
            createdAt: 10,
            ms: 125,
            streamSeedHex: stream.seedHex,
            streamPubkey: stream.pubkey,
          ),
          throwsStateError,
        );
        expect(await emptyStore.get('sealed'), isNull);
        expect(refused.timeline(now: 10).messages, isEmpty);
      },
    );
  });

  group('startChannel', () {
    test(
      'restart decrypts ciphertext history and closing cancels subscription',
      () async {
        final relay = Relay();
        addTearDown(relay.events.close);
        final store = InMemoryConcordStore('a' * 64);
        ConcordRepository make() => ConcordRepository(
          relay: relay,
          store: store,
          cipher: NoLegacyCipher(),
          sealedTransport: SealedChatTransport(relay: relay, signer: sign),
        );
        final stream = publicChannelKey('02' * 32, '03' * 32, 0);
        final original = make();
        await original.sendSealedMessage(
          channelId: '03' * 32,
          author: schnorr.getPublicKey('01' * 32),
          body: 'history',
          createdAt: 10,
          ms: 125,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
        await original.close();
        final restarted = make();
        await restarted.startChannel(
          channelId: '03' * 32,
          epoch: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
          now: () => 11,
        );
        expect(restarted.timeline(now: 11).messages.single.body, 'history');
        expect(restarted.pendingIds, isEmpty);
        expect(relay.events.hasListener, isTrue);
        await restarted.close();
        expect(relay.events.hasListener, isFalse);
      },
    );
  });

  group('ingestSealedWrap', () {
    test(
      'a verified subscription echo reconciles a lost publish acknowledgement',
      () async {
        final relay = Relay()..reject = true;
        addTearDown(relay.events.close);
        final repo = ConcordRepository(
          relay: relay,
          store: InMemoryConcordStore('a' * 64),
          cipher: NoLegacyCipher(),
          sealedTransport: SealedChatTransport(relay: relay, signer: sign),
        );
        addTearDown(repo.close);
        final stream = publicChannelKey('02' * 32, '03' * 32, 0);
        await repo.startChannel(
          channelId: '03' * 32,
          epoch: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
          now: () => 10,
        );
        relay.beforeReject = repo.ingestSealedWrap;
        await repo.sendSealedMessage(
          channelId: '03' * 32,
          author: schnorr.getPublicKey('01' * 32),
          body: 'echoed',
          createdAt: 10,
          ms: 125,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
        expect(repo.pendingIds, isEmpty);
        expect(repo.timeline(now: 10).messages, hasLength(1));
      },
    );
  });

  group('retryPending', () {
    test(
      'a late retry acknowledgement cannot restore an expired record',
      () async {
        final relay = Relay()..reject = true;
        addTearDown(relay.events.close);
        final store = InMemoryConcordStore('a' * 64);
        final repo = ConcordRepository(
          relay: relay,
          store: store,
          cipher: NoLegacyCipher(),
          sealedTransport: SealedChatTransport(relay: relay, signer: sign),
        );
        addTearDown(repo.close);
        final stream = publicChannelKey('02' * 32, '03' * 32, 0);
        var now = 10;
        await repo.startChannel(
          channelId: '03' * 32,
          epoch: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
          now: () => now,
        );
        await expectLater(
          repo.sendSealedMessage(
            channelId: '03' * 32,
            author: schnorr.getPublicKey('01' * 32),
            body: 'expires',
            createdAt: 10,
            expiresAt: 15,
            ms: 125,
            streamSeedHex: stream.seedHex,
            streamPubkey: stream.pubkey,
          ),
          throwsStateError,
        );
        relay.reject = false;
        final awaitingAck = Completer<void>();
        final ack = Completer<void>();
        relay.beforeReject = (_) {
          awaitingAck.complete();
          return ack.future;
        };
        final retry = repo.retryPending();
        await awaitingAck.future;
        now = 15;
        await repo.purgeExpired(now: now);
        ack.complete();
        await retry;
        expect(jsonDecode((await store.get('sealed'))!) as Map, isEmpty);
        expect(repo.pendingIds, isEmpty);
      },
    );
  });

  group('startChannel', () {
    test(
      'restoring alongside expired history does not apply a reaction twice',
      () async {
        final relay = Relay();
        addTearDown(relay.events.close);
        final store = InMemoryConcordStore('a' * 64);
        final transport = SealedChatTransport(relay: relay, signer: sign);
        ConcordRepository make() => ConcordRepository(
          relay: relay,
          store: store,
          cipher: NoLegacyCipher(),
          sealedTransport: transport,
        );
        final stream = publicChannelKey('02' * 32, '03' * 32, 0);
        Future<void> start(ConcordRepository repo, int now) =>
            repo.startChannel(
              channelId: '03' * 32,
              epoch: 0,
              streamSeedHex: stream.seedHex,
              streamPubkey: stream.pubkey,
              now: () => now,
            );
        final repo = make();
        await start(repo, 11);
        for (final expiry in <int?>[null, 12]) {
          await repo.sendSealedMessage(
            channelId: '03' * 32,
            author: schnorr.getPublicKey('01' * 32),
            body: '$expiry',
            createdAt: 10,
            expiresAt: expiry,
            ms: 125,
            streamSeedHex: stream.seedHex,
            streamPubkey: stream.pubkey,
          );
        }
        final target = repo
            .timeline(now: 11)
            .messages
            .firstWhere((m) => m.expiresAt == null)
            .id;
        final tags = [
          ['channel', '03' * 32],
          ['epoch', '0'],
          ['ms', '1'],
          ['e', target],
          ['k', '9'],
        ];
        final author = schnorr.getPublicKey('01' * 32);
        final rumor = <String, dynamic>{
          'kind': 7,
          'pubkey': author,
          'created_at': 11,
          'content': '+',
          'tags': tags,
          'id': computeEventId(
            pubkey: author,
            createdAt: 11,
            kind: 7,
            tags: tags,
            content: '+',
          ),
        };
        await repo.ingestSealedWrap(
          await transport.prepareRumor(
            rumor: rumor,
            streamSeedHex: stream.seedHex,
            streamPubkey: stream.pubkey,
          ),
        );
        expect(repo.timeline(now: 11).reactions[target], {'+': 1});
        await repo.close();
        final restarted = make();
        addTearDown(restarted.close);
        await start(restarted, 12);
        expect(restarted.timeline(now: 12).reactions[target], {'+': 1});
      },
    );
  });

  group('close', () {
    test('closing during restore prevents late storage writes', () async {
      final relay = Relay();
      addTearDown(relay.events.close);
      final store = DelayedStore();
      final repo = ConcordRepository(
        relay: relay,
        store: store,
        cipher: NoLegacyCipher(),
        sealedTransport: SealedChatTransport(relay: relay, signer: sign),
      );
      final stream = publicChannelKey('02' * 32, '03' * 32, 0);
      await repo.sendSealedMessage(
        channelId: '03' * 32,
        author: schnorr.getPublicKey('01' * 32),
        body: 'expired',
        createdAt: 10,
        expiresAt: 15,
        ms: 125,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
      );
      store.blockRead = Completer<void>();
      final starting = repo.startChannel(
        channelId: '03' * 32,
        epoch: 0,
        streamSeedHex: stream.seedHex,
        streamPubkey: stream.pubkey,
        now: () => 15,
      );
      await store.reading.future;
      await repo.close();
      final writesAtClose = store.writes;
      store.blockRead!.complete();
      await starting;
      expect(store.writes, writesAtClose);
      expect(relay.events.hasListener, isFalse);
    });
  });

  group('startChannel', () {
    test('a failed restore cannot be overwritten by a new send', () async {
      final relay = Relay();
      addTearDown(relay.events.close);
      final store = DelayedStore();
      ConcordRepository make() => ConcordRepository(
        relay: relay,
        store: store,
        cipher: NoLegacyCipher(),
        sealedTransport: SealedChatTransport(relay: relay, signer: sign),
      );
      final stream = publicChannelKey('02' * 32, '03' * 32, 0);
      Future<void> send(ConcordRepository repo, String body) async {
        await repo.sendSealedMessage(
          channelId: '03' * 32,
          author: schnorr.getPublicKey('01' * 32),
          body: body,
          createdAt: 10,
          ms: 125,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        );
      }

      final original = make();
      await send(original, 'saved');
      await original.close();
      final saved = await store.get('sealed');
      store.failRead = true;
      final restarted = make();
      addTearDown(restarted.close);
      await expectLater(
        restarted.startChannel(
          channelId: '03' * 32,
          epoch: 0,
          streamSeedHex: stream.seedHex,
          streamPubkey: stream.pubkey,
        ),
        throwsStateError,
      );
      await expectLater(send(restarted, 'new'), throwsStateError);
      expect(await store.get('sealed'), saved);
    });
  });
}
