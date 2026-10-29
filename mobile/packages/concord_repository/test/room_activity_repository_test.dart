// MPL-2.0
import 'dart:async';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

final String _own = schnorr.getPublicKey('01'.padLeft(64, '0'));
final String _other = schnorr.getPublicKey('02'.padLeft(64, '0'));
final String _third = schnorr.getPublicKey('03'.padLeft(64, '0'));
const _now = 200000;

class _Relay implements RelayGateway {
  final events = StreamController<Map<String, dynamic>>.broadcast();
  int subscriptions = 0;

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) {
    subscriptions++;
    return events.stream;
  }

  @override
  Future<void> publish(Map<String, dynamic> event) async {}
}

class _HistoryRelay extends _Relay implements RelayHistoryStatus {
  final history = Completer<void>();

  @override
  Future<void> get historyReady => history.future;

  @override
  bool get historyLimited => false;
}

class _Cipher implements StreamCipher {
  @override
  String open(String ciphertext, String streamId) =>
      throw UnsupportedError('No legacy envelopes');

  @override
  String seal(String plaintext, String streamId) =>
      throw UnsupportedError('No legacy envelopes');
}

class _Store extends InMemoryConcordStore {
  _Store() : super(_own);
  bool failRead = false;
  bool failWrite = false;
  Completer<void>? reading;
  Completer<void>? resumeRead;
  Completer<void>? writing;
  Completer<void>? resumeWrite;

  @override
  Future<String?> get(String key) async {
    if (failRead) throw StateError('storage unavailable');
    if (resumeRead != null) {
      if (!reading!.isCompleted) reading!.complete();
      await resumeRead!.future;
    }
    return super.get(key);
  }

  @override
  Future<void> put(String key, String value) async {
    if (failWrite) throw StateError('write unavailable');
    if (resumeWrite != null) {
      if (!writing!.isCompleted) writing!.complete();
      await resumeWrite!.future;
    }
    return super.put(key, value);
  }
}

class _Room {
  _Room(
    this.channelId, {
    int historyLimit = 200,
    _Store? store,
    _Relay? relay,
  }) : store = store ?? _Store(),
       relay = relay ?? _Relay() {
    transport = SealedChatTransport(
      relay: this.relay,
      signer: (event) async {
        final id = computeEventId(
          pubkey: _own,
          createdAt: event['created_at'] as int,
          kind: event['kind'] as int,
          tags: (event['tags'] as List).cast<List<String>>(),
          content: event['content'] as String,
        );
        return {
          ...event,
          'pubkey': _own,
          'id': id,
          'sig': schnorr.sign('01'.padLeft(64, '0'), id, '00' * 32),
        };
      },
    );
    repository = ConcordRepository(
      relay: this.relay,
      store: this.store,
      cipher: _Cipher(),
      sealedTransport: transport,
      historyLimit: historyLimit,
    );
    key = publicChannelKey('34' * 32, channelId, 0);
    addTearDown(this.relay.events.close);
  }

  final String channelId;
  final _Store store;
  final _Relay relay;
  late final ConcordRepository repository;
  late final SealedChatTransport transport;
  late final GroupKey key;

  RoomActivityChannel get source => RoomActivityChannel(
    channelId: channelId,
    repository: repository,
    store: store,
    streamSeedHex: key.seedHex,
    streamPubkey: key.pubkey,
  );

  Future<void> seed(
    List<ChatMessage> messages, {
    Set<String> pending = const {},
  }) => store.writeBatch({
    'index': messages.map((m) => m.id).join(','),
    for (final message in messages) ...{
      'msg:${message.id}': message.body,
      'meta:${message.id}':
          '$channelId|${message.author}|${message.createdAt}|'
          '${message.expiresAt ?? ''}',
      if (!pending.contains(message.id)) 'sent:${message.id}': '1',
    },
  });

  ChatMessage message(
    String id, {
    String? author,
    int createdAt = _now,
    int? expiresAt,
  }) => ChatMessage(
    id: id * 64,
    channelId: channelId,
    author: author ?? _other,
    body: 'Message $id',
    createdAt: createdAt,
    expiresAt: expiresAt,
  );

  Future<void> ingest({
    required int kind,
    String body = 'Delivered',
    String? target,
    int createdAt = _now,
    int? expiresAt,
  }) async {
    await repository.ingestSealedWrap(
      await prepare(
        kind: kind,
        body: body,
        target: target,
        createdAt: createdAt,
        expiresAt: expiresAt,
      ),
    );
    await pumpEventQueue();
  }

  Future<Map<String, dynamic>> prepare({
    required int kind,
    String body = 'Delivered',
    String? target,
    int createdAt = _now,
    int? expiresAt,
  }) async {
    final tags = [
      ['channel', channelId],
      ['epoch', '0'],
      if (target != null) ['e', target],
      if (expiresAt != null) ['expiration', '$expiresAt'],
    ];
    final rumor = <String, dynamic>{
      'pubkey': _own,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': body,
      'id': computeEventId(
        pubkey: _own,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: body,
      ),
    };
    return transport.prepareRumor(
      rumor: rumor,
      streamSeedHex: key.seedHex,
      streamPubkey: key.pubkey,
    );
  }
}

RoomActivityRepository _activity(List<_Room> rooms, {int Function()? now}) {
  final activity = RoomActivityRepository(
    ownPubkey: _own,
    channels: rooms.map((room) => room.source).toList(),
    now: now ?? () => _now,
  );
  addTearDown(activity.close);
  return activity;
}

void main() {
  group('RoomActivityRepository', () {
    test('rooms stay loading until historical delivery reaches EOSE', () async {
      final relay = _HistoryRelay();
      final room = _Room('12' * 32, relay: relay);
      final activity = _activity([room]);
      final starting = activity.start();
      await pumpEventQueue();
      expect(activity.summaries[room.channelId]!.loading, isTrue);
      relay.history.complete();
      await starting;
      expect(activity.summaries[room.channelId]!.loading, isFalse);
    });

    test('close releases a room still awaiting its history boundary', () async {
      final room = _Room('12' * 32, relay: _HistoryRelay());
      final activity = _activity([room]);
      final starting = activity.start();
      await pumpEventQueue();
      await activity.close();
      await starting;
      expect(room.relay.events.hasListener, isFalse);
    });

    test(
      'EOSE waits for async verified ingestion before clearing loading',
      () async {
        final relay = _HistoryRelay();
        final room = _Room('12' * 32, relay: relay);
        final activity = _activity([room]);
        final starting = activity.start();
        await pumpEventQueue();
        final wrap = await room.prepare(kind: 9);
        room.store
          ..writing = Completer<void>()
          ..resumeWrite = Completer<void>();
        relay.events.add(wrap);
        await room.store.writing!.future;
        relay.history.complete();
        await pumpEventQueue();
        expect(activity.summaries[room.channelId]!.loading, isTrue);
        room.store.resumeWrite!.complete();
        await starting;
        expect(activity.summaries[room.channelId]!.loading, isFalse);
        expect(activity.summaries[room.channelId]!.recentMessageCount, 1);
      },
    );

    test(
      'distinguishes loading from a successfully loaded empty room',
      () async {
        final room = _Room('12' * 32);
        final activity = _activity([room]);
        expect(activity.summaries[room.channelId]!.loading, isTrue);
        await activity.start();
        final summary = activity.summaries[room.channelId]!;
        expect(summary.loading, isFalse);
        expect(summary.loadFailed, isFalse);
        expect(summary.unreadCount, 0);
        expect(summary.recentMessageCount, 0);
        expect(summary.recentAuthors, isEmpty);
        expect(summary.latestMessage, isNull);
        expect(activity.repositoryFor(room.channelId), same(room.repository));
      },
    );

    test(
      'counts unique recent contributors and excludes self from unread',
      () async {
        final room = _Room('12' * 32);
        await room.seed([
          room.message('a', createdAt: _now - 86401),
          room.message('b', createdAt: _now - 86400),
          room.message('c', author: _third, createdAt: _now - 5),
          room.message('d', createdAt: _now - 2),
          room.message('d', createdAt: _now - 2),
          room.message('e', author: _own),
        ]);
        final activity = _activity([room]);
        await activity.start();
        final summary = activity.summaries[room.channelId]!;
        expect(summary.unreadCount, 4);
        expect(summary.recentMessageCount, 4);
        expect(summary.recentAuthors, [_own, _other, _third]);
        expect(summary.latestMessage!.id, 'e' * 64);
      },
    );

    test(
      'pending messages never inflate activity or the latest preview',
      () async {
        final room = _Room('12' * 32);
        await room.seed(
          [
            room.message('a', createdAt: _now - 1),
            room.message('b'),
          ],
          pending: {'b' * 64},
        );
        final activity = _activity([room]);
        await activity.start();
        final summary = activity.summaries[room.channelId]!;
        expect(summary.unreadCount, 1);
        expect(summary.recentMessageCount, 1);
        expect(summary.latestMessage!.id, 'a' * 64);
      },
    );

    test(
      'read snapshots persist without swallowing late same-time arrivals',
      () async {
        final room = _Room('12' * 32);
        final first = room.message('a');
        await room.seed([first]);
        final activity = _activity([room]);
        await activity.start();
        await activity.markRead(room.channelId, [first]);
        expect(activity.summaries[room.channelId]!.unreadCount, 0);
        await activity.close();

        final reopened = _Room(room.channelId, store: room.store);
        await reopened.seed([first, reopened.message('b')]);
        final restarted = _activity([reopened]);
        await restarted.start();
        expect(restarted.summaries[room.channelId]!.unreadCount, 1);
        await restarted.markRead(room.channelId, [first]);
        expect(restarted.summaries[room.channelId]!.unreadCount, 1);
      },
    );

    test('room snapshots and writes stay isolated across channels', () async {
      final general = _Room('12' * 32);
      final introductions = _Room('13' * 32);
      final first = general.message('a');
      await general.seed([first]);
      await introductions.seed([introductions.message('b')]);
      final activity = _activity([general, introductions]);
      await activity.start();
      await activity.markRead(general.channelId, [first]);
      expect(activity.summaries[general.channelId]!.unreadCount, 0);
      expect(activity.summaries[introductions.channelId]!.unreadCount, 1);
      expect(() => activity.summaries.clear(), throwsUnsupportedError);
      expect(
        () =>
            activity.summaries[introductions.channelId]!.recentAuthors.clear(),
        throwsUnsupportedError,
      );
    });

    test('folds edits, deletion, expiry and duplicate deliveries', () async {
      var now = _now;
      final room = _Room('12' * 32);
      final activity = _activity([room], now: () => now);
      await activity.start();
      await room.ingest(kind: 9, expiresAt: _now + 5);
      final id = activity.summaries[room.channelId]!.latestMessage!.id;
      await room.ingest(kind: 9, expiresAt: _now + 5);
      expect(activity.summaries[room.channelId]!.recentMessageCount, 1);
      await room.ingest(kind: 3302, target: id, body: 'Edited');
      expect(
        activity.summaries[room.channelId]!.latestMessage!.effectiveBody,
        'Edited',
      );
      await room.ingest(kind: 5, target: id);
      expect(activity.summaries[room.channelId]!.recentMessageCount, 0);
      await room.ingest(kind: 9, body: 'Expiring', expiresAt: _now + 5);
      now += 5;
      await room.repository.purgeExpired(now: now);
      await pumpEventQueue();
      expect(activity.summaries[room.channelId]!.latestMessage, isNull);
    });

    test(
      'history warning includes retained controls that consume the limit',
      () async {
        final room = _Room('12' * 32, historyLimit: 2);
        final activity = _activity([room]);
        await activity.start();
        await room.ingest(kind: 9);
        final id = activity.summaries[room.channelId]!.latestMessage!.id;
        expect(activity.summaries[room.channelId]!.historyLimited, isFalse);
        await room.ingest(kind: 3302, target: id, body: 'Updated');
        expect(activity.summaries[room.channelId]!.historyLimited, isTrue);
        expect(activity.summaries[room.channelId]!.recentMessageCount, 1);
      },
    );

    test(
      'aggregate stays a lower bound after reading only retained messages',
      () async {
        final capped = _Room('12' * 32, historyLimit: 2);
        final other = _Room('13' * 32);
        final activity = RoomActivityRepository(
          ownPubkey: _third,
          channels: [capped.source, other.source],
          now: () => _now,
        );
        addTearDown(activity.close);
        await activity.start();
        for (var index = 0; index < 3; index++) {
          await capped.ingest(kind: 9, body: 'Capped message $index');
          await other.ingest(kind: 9, body: 'Other message $index');
        }

        final retained = capped.repository.timeline(now: _now).messages;
        expect(retained, hasLength(2));
        expect(activity.summaries[capped.channelId]!.unreadCount, 2);
        await activity.markRead(capped.channelId, retained);

        // The evicted third message was never included in a read snapshot.
        expect(activity.summaries[capped.channelId]!.unreadCount, 0);
        expect(activity.summaries[capped.channelId]!.historyLimited, isTrue);
        expect(activity.summaries[other.channelId]!.unreadCount, 3);
        expect(activity.summaries[other.channelId]!.historyLimited, isFalse);
        expect(activity.summaries.values.totalUnread, 3);
        expect(activity.summaries.values.totalUnreadLimited, isTrue);
      },
    );

    test(
      'one storage failure leaves healthy rooms usable and can retry',
      () async {
        final failed = _Room('12' * 32)..store.failRead = true;
        final healthy = _Room('13' * 32);
        await healthy.seed([healthy.message('a')]);
        final activity = _activity([failed, healthy]);
        await activity.start();
        expect(activity.summaries[failed.channelId]!.loadFailed, isTrue);
        expect(activity.summaries[failed.channelId]!.loading, isFalse);
        expect(activity.summaries[healthy.channelId]!.unreadCount, 1);
        await expectLater(
          activity.ensureStarted(failed.channelId),
          throwsStateError,
        );
        failed.store.failRead = false;
        await activity.start();
        expect(activity.summaries[failed.channelId]!.loadFailed, isFalse);
        expect(healthy.relay.subscriptions, 1);
      },
    );

    test('concurrent starts share one subscription per source', () async {
      final room = _Room('12' * 32);
      final activity = _activity([room]);
      await Future.wait([
        activity.start(),
        activity.ensureStarted(room.channelId),
        activity.start(),
      ]);
      expect(room.relay.subscriptions, 1);
    });

    test(
      'relay errors set a retryable state instead of escaping unhandled',
      () async {
        final room = _Room('12' * 32);
        final activity = _activity([room]);
        await activity.start();
        room.relay.events.addError(StateError('connection lost'));
        await pumpEventQueue();
        expect(activity.summaries[room.channelId]!.loadFailed, isTrue);
        await activity.ensureStarted(room.channelId);
        expect(activity.summaries[room.channelId]!.loadFailed, isFalse);
        expect(room.relay.subscriptions, 2);
      },
    );

    test(
      'serializes concurrent read snapshots without losing persisted IDs',
      () async {
        final room = _Room('12' * 32);
        final first = room.message('a');
        final second = room.message('b');
        await room.seed([first, second]);
        final activity = _activity([room]);
        await activity.start();
        room.store
          ..writing = Completer<void>()
          ..resumeWrite = Completer<void>();
        final markingFirst = activity.markRead(room.channelId, [first]);
        await room.store.writing!.future;
        final markingSecond = activity.markRead(room.channelId, [second]);
        room.store.resumeWrite!.complete();
        await Future.wait([markingFirst, markingSecond]);
        expect(activity.summaries[room.channelId]!.unreadCount, 0);
        await activity.close();
        final reopened = _activity([_Room(room.channelId, store: room.store)]);
        await reopened.start();
        expect(reopened.summaries[room.channelId]!.unreadCount, 0);
      },
    );

    test(
      'failed read-state writes keep messages unread until persisted',
      () async {
        final room = _Room('12' * 32);
        final first = room.message('a');
        await room.seed([first]);
        final activity = _activity([room]);
        await activity.start();
        room.store.failWrite = true;
        await expectLater(
          activity.markRead(room.channelId, [first]),
          throwsStateError,
        );
        expect(activity.summaries[room.channelId]!.unreadCount, 1);
        room.store.failWrite = false;
        await activity.markRead(room.channelId, [first]);
        expect(activity.summaries[room.channelId]!.unreadCount, 0);
      },
    );

    test(
      'close stops live delivery before draining a blocked read receipt',
      () async {
        final room = _Room('12' * 32);
        final first = room.message('a');
        await room.seed([first]);
        final activity = _activity([room]);
        await activity.start();
        room.store
          ..writing = Completer<void>()
          ..resumeWrite = Completer<void>();
        final marking = activity.markRead(room.channelId, [first]);
        await room.store.writing!.future;
        var closed = false;
        final closing = activity.close().then((_) => closed = true);
        try {
          await pumpEventQueue();
          expect(room.relay.events.hasListener, isFalse);
          expect(closed, isFalse);
        } finally {
          room.store.resumeWrite!.complete();
          await Future.wait<void>([marking, closing]);
        }
        final reopened = _activity([_Room(room.channelId, store: room.store)]);
        await reopened.start();
        expect(reopened.summaries[room.channelId]!.unreadCount, 0);
      },
    );

    test(
      'close cancels listeners and is safe before a blocked restore finishes',
      () async {
        final room = _Room('12' * 32);
        room.store
          ..reading = Completer<void>()
          ..resumeRead = Completer<void>();
        final activity = _activity([room]);
        final starting = activity.start();
        await room.store.reading!.future;
        await activity.close();
        room.store.resumeRead!.complete();
        await starting;
        expect(room.relay.events.hasListener, isFalse);
        expect(room.relay.subscriptions, 0);
        await expectLater(
          activity.ensureStarted(room.channelId),
          throwsStateError,
        );
      },
    );
  });

  group('RoomActivityTotals', () {
    RoomActivitySummary summary(
      String channelId,
      int unreadCount, {
      bool historyLimited = false,
    }) => RoomActivitySummary(
      channelId: channelId,
      unreadCount: unreadCount,
      historyLimited: historyLimited,
      loading: false,
    );

    test('totalUnread sums unread messages across rooms', () {
      expect([summary('a', 2), summary('b', 3)].totalUnread, 5);
    });

    test('totalUnreadLimited includes rooms with no retained unread', () {
      expect(
        [
          summary('a', 0, historyLimited: true),
          summary('b', 3),
        ].totalUnreadLimited,
        isTrue,
      );
    });

    test('totalUnreadLimited follows a limited room with unread messages', () {
      expect(
        [
          summary('a', 2, historyLimited: true),
          summary('b', 3),
        ].totalUnreadLimited,
        isTrue,
      );
    });
  });
}
