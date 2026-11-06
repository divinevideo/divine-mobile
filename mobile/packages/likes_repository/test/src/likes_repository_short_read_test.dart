// ABOUTME: Regression tests for #9004: a relay read that ends short is not a
// ABOUTME: complete answer. Drives LikesRepository through a real NostrClient
// ABOUTME: and relay pool over a scripted relay that ends each read with EOSE,
// ABOUTME: CLOSED or a late answer, so the read's outcome is the pool's own.

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockAppDbClient extends Mock implements AppDbClient {}

/// How a [_ScriptedRelay] answers a read.
enum _Reply {
  /// Every matching event, then EOSE.
  answer,

  /// A CLOSED before any event, as funnelcake sends for an idle subscription.
  closed,

  /// The same answer as [answer], sent after the pool's settle window.
  late,
}

/// Which read a REQ is, judged from its single filter.
enum _Read { reactions, liveSubscription, targetedReactions, deletions, other }

_Read _classify(List<Filter> filters) {
  if (filters.length != 1) return _Read.other;
  final filter = filters.single;
  final kinds = filter.kinds ?? const <int>[];
  if (kinds.contains(EventKind.eventDeletion)) return _Read.deletions;
  if (!kinds.contains(EventKind.reaction)) return _Read.other;
  final targeted =
      (filter.e?.isNotEmpty ?? false) || (filter.a?.isNotEmpty ?? false);
  if (targeted) return _Read.targetedReactions;
  return filter.limit == 1 ? _Read.liveSubscription : _Read.reactions;
}

/// Late enough that a read which stops a settle window after the first relay
/// answers has already ended, and well inside the read's deadline.
final Duration _lateAnswer =
    RelayPool.querySettleWindow + const Duration(milliseconds: 500);

/// A relay whose answer to each kind of read is chosen by the test.
///
/// It keeps a reaction after its kind 5 unless [hidesDeleted] is set, as a
/// relay may (NIP-09 makes dropping it a SHOULD); funnelcake drops it.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url) : super(url, RelayStatus(url));

  final List<Event> store = [];
  Map<_Read, _Reply> replies = {};
  bool hidesDeleted = false;
  final List<_Read> reads = [];
  final List<Event> published = [];
  final List<Timer> _lateAnswers = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    for (final timer in _lateAnswers) {
      timer.cancel();
    }
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.isEmpty) return true;
    final type = message.first;
    if (type == 'REQ' && message.length > 2) {
      final subId = message[1] as String;
      final filters = [
        for (final f in message.skip(2))
          Filter.fromJson(Map<String, dynamic>.from(f as Map)),
      ];
      final read = _classify(filters);
      reads.add(read);
      unawaited(_answer(subId, filters, replies[read] ?? _Reply.answer));
    } else if (type == 'EVENT' && message.length > 1) {
      final event = Event.fromJson(
        Map<String, dynamic>.from(message[1] as Map),
      );
      published.add(event);
      store.add(event);
      unawaited(_ack(event.id));
    }
    return true;
  }

  bool isDeleted(Event event) => store.any(
    (d) =>
        d.kind == EventKind.eventDeletion &&
        d.pubkey == event.pubkey &&
        d.tags.any((t) => t.length > 1 && t[0] == 'e' && t[1] == event.id),
  );

  Future<void> _ack(String id) async {
    await pumpEventQueue();
    await _deliver(['OK', id, true, '']);
  }

  Future<void> _answer(String subId, List<Filter> filters, _Reply reply) async {
    // The pool records a query only after send() returns, so let it.
    await pumpEventQueue();
    switch (reply) {
      case _Reply.closed:
        await _deliver([
          'CLOSED',
          subId,
          'error: shutting down idle subscription',
        ]);
      case _Reply.late:
        _lateAnswers.add(
          Timer(
            _lateAnswer,
            () => unawaited(_answer(subId, filters, _Reply.answer)),
          ),
        );
      case _Reply.answer:
        final sent = <String>{};
        for (final filter in filters) {
          final matches =
              store
                  .where(filter.checkEvent)
                  .where((e) => !hidesDeleted || !isDeleted(e))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final limit = filter.limit;
          for (final event in limit == null ? matches : matches.take(limit)) {
            if (sent.add(event.id)) {
              await _deliver(['EVENT', subId, event.toJson()]);
            }
          }
        }
        await _deliver(['EOSE', subId]);
    }
  }

  Future<void> _deliver(List<dynamic> json) async {
    final handler = onMessage;
    if (handler == null) return;
    final dynamic result = handler(this, json);
    if (result is Future) await result;
  }
}

class _MemoryLikesStorage implements LikesLocalStorage {
  final Map<String, LikeRecord> records = {};

  @override
  Future<void> saveLikeRecord(LikeRecord record) async {
    records[record.targetEventId] = record;
  }

  @override
  Future<void> saveLikeRecordsBatch(List<LikeRecord> batch) async {
    for (final record in batch) {
      records[record.targetEventId] = record;
    }
  }

  @override
  Future<bool> deleteLikeRecord(String targetEventId) async =>
      records.remove(targetEventId) != null;

  @override
  Future<LikeRecord?> getLikeRecord(String targetEventId) async =>
      records[targetEventId];

  @override
  Future<LikeRecord?> getLikeRecordByAddressableId(String addressableId) async {
    for (final record in records.values) {
      if (record.addressableId == addressableId) return record;
    }
    return null;
  }

  @override
  Future<String?> getReactionEventId(String targetEventId) async =>
      records[targetEventId]?.reactionEventId;

  @override
  Future<List<LikeRecord>> getAllLikeRecords() async => records.values.toList();

  @override
  Future<Set<String>> getLikedEventIds() async => records.keys.toSet();

  @override
  Future<bool> isLiked(String targetEventId) async =>
      records.containsKey(targetEventId);

  @override
  Future<void> clearAll() async => records.clear();
}

// Synthetic keys and ids only.
const _userSecret =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _author =
    '4f2c1b7e9a3d5c8f0e6b2a1d7c9e3f5a8b0d2c4e6f8a1b3c5d7e9f0a2b4c6d8e';
const _target =
    'abababababababababababababababababababababababababababababababab';
const _otherTarget =
    'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
const _coord = '34236:$_author:short-read-9004';
const _relayUrl = 'wss://scripted.example';

int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class _Harness {
  _Harness({
    required this.repo,
    required this.relay,
    required this.storage,
    required this.signer,
    required this.user,
  });

  final LikesRepository repo;
  final _ScriptedRelay relay;
  final _MemoryLikesStorage storage;
  final LocalNostrSigner signer;
  final String user;

  Future<Event> _sign(Event event) async => (await signer.signEvent(event))!;

  Future<Event> reaction(
    String target, {
    required int createdAt,
    String content = '+',
    String? coord,
  }) => _sign(
    Event(
      user,
      EventKind.reaction,
      [
        ['e', target],
        if (coord != null) ['a', coord],
        ['p', _author],
        ['k', '34236'],
      ],
      content,
      createdAt: createdAt,
    ),
  );

  Future<Event> deletion(List<String> ids, {required int createdAt}) => _sign(
    Event(
      user,
      EventKind.eventDeletion,
      [
        for (final id in ids) ['e', id],
        ['k', '7'],
      ],
      '',
      createdAt: createdAt,
    ),
  );
}

Future<_Harness> _harness({
  AppDatabase? cacheDb,
  List<_ScriptedRelay> otherRelays = const [],
}) async {
  final signer = LocalNostrSigner(_userSecret);
  final nostr = Nostr(signer, [], _ScriptedRelay.new);
  final user = await nostr.ensurePublicKey();
  final relay = _ScriptedRelay(_relayUrl);
  for (final scripted in [relay, ...otherRelays]) {
    expect(await nostr.relayPool.add(scripted), isTrue);
  }
  final urls = [_relayUrl, for (final other in otherRelays) other.url];

  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(urls);
  when(() => relayManager.configuredRelays).thenReturn(urls);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  when(relayManager.retryDisconnectedRelays).thenAnswer((_) async {});

  AppDbClient? dbClient;
  if (cacheDb != null) {
    final mock = _MockAppDbClient();
    when(() => mock.database).thenReturn(cacheDb);
    dbClient = mock;
  }
  final client = NostrClient.forTesting(
    nostr: nostr,
    relayManager: relayManager,
    dbClient: dbClient,
  );
  final storage = _MemoryLikesStorage();
  final repo = LikesRepository(nostrClient: client, localStorage: storage);
  addTearDown(() async {
    repo.dispose();
    await client.dispose();
  });
  return _Harness(
    repo: repo,
    relay: relay,
    storage: storage,
    signer: signer,
    user: user,
  );
}

void main() {
  setUpAll(() => registerFallbackValue(''));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Nip89ClientTag.resetForTest);

  group('LikesRepository when a relay read ends short (#9004)', () {
    group('syncUserReactions', () {
      /// A like taken back with a kind 5, a live like on another target,
      /// and a relay that keeps reactions after their deletion.
      Future<(_Harness, Event, Event)> seeded({
        List<_ScriptedRelay> otherRelays = const [],
      }) async {
        final h = await _harness(otherRelays: otherRelays);
        final retracted = await h.reaction(
          _target,
          createdAt: _now - 7200,
          coord: _coord,
        );
        final unlike = await h.deletion(
          [retracted.id],
          createdAt: _now - 3600,
        );
        final live = await h.reaction(_otherTarget, createdAt: _now - 60);
        h.relay.store.addAll([retracted, unlike, live]);
        return (h, retracted, live);
      }

      test('saves no like when the deletions read is refused', () async {
        final (h, _, _) = await seeded();
        h.relay.replies = {_Read.deletions: _Reply.closed};

        await h.repo.syncUserReactions();

        expect(await h.repo.isLiked(_target), isFalse);
        expect(await h.repo.isLiked(_otherTarget), isFalse);
        expect(h.storage.records, isEmpty);
      });

      test('saves the live like and leaves the retracted one out when the '
          'reads complete', () async {
        final (h, _, live) = await seeded();

        await h.repo.syncUserReactions();

        expect(await h.repo.isLiked(_target), isFalse);
        expect(h.storage.records[_otherTarget]?.reactionEventId, live.id);
      });

      test('waits for a deletion from a relay that answers after the settle '
          'window', () async {
        final fast = _ScriptedRelay('wss://fast.example');
        final (h, retracted, _) = await seeded(otherRelays: [fast]);
        // The fast relay kept the reaction but never got the kind 5.
        fast.store.add(retracted);
        h.relay.replies = {_Read.deletions: _Reply.late};

        await h.repo.syncUserReactions();

        expect(await h.repo.isLiked(_target), isFalse);
        expect(h.storage.records, isNot(contains(_target)));
      });

      test(
        'finds an unlike older than 500 other deletions and still saves the '
        'live like',
        () async {
          final h = await _harness();
          final retracted = await h.reaction(
            _target,
            createdAt: _now - 100000,
            coord: _coord,
          );
          final unlike = await h.deletion(
            [retracted.id],
            createdAt: _now - 90000,
          );
          final live = await h.reaction(_otherTarget, createdAt: _now - 60);
          h.relay.store.addAll([retracted, unlike, live]);
          for (var i = 0; i < 500; i++) {
            final id = '2${i.toRadixString(16).padLeft(63, '0')}';
            h.relay.store.add(
              await h.deletion([id], createdAt: _now - 80000 + i),
            );
          }

          await h.repo.syncUserReactions();

          expect(await h.repo.isLiked(_target), isFalse);
          expect(h.storage.records[_otherTarget]?.reactionEventId, live.id);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );

      test('keeps a downvote out when the deletions read is refused', () async {
        final h = await _harness();
        final downvote = await h.reaction(
          _target,
          createdAt: _now - 7200,
          content: '-',
        );
        final retraction = await h.deletion(
          [downvote.id],
          createdAt: _now - 3600,
        );
        h.relay
          ..store.addAll([downvote, retraction])
          ..replies = {_Read.deletions: _Reply.closed};

        await h.repo.syncUserReactions();

        expect(await h.repo.isDownvoted(_target), isFalse);
      });
    });

    group('initialize', () {
      test('does not restore a like whose deletion the startup read '
          'missed', () async {
        final h = await _harness();
        final retracted = await h.reaction(
          _target,
          createdAt: _now - 7200,
          coord: _coord,
        );
        final unlike = await h.deletion(
          [retracted.id],
          createdAt: _now - 3600,
        );
        final newer = await h.reaction(_otherTarget, createdAt: _now - 60);
        h.relay
          ..store.addAll([retracted, unlike, newer])
          ..replies = {_Read.deletions: _Reply.closed};

        await h.repo.initialize();

        expect(await h.repo.isLiked(_target), isFalse);
        expect(h.storage.records, isNot(contains(_target)));
      });

      test('does not restore a retracted like this device cached', () async {
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final h = await _harness(cacheDb: db);
        final retracted = await h.reaction(
          _target,
          createdAt: _now - 7200,
          coord: _coord,
        );
        // This device read the like earlier; the unlike came from another
        // device, and the relay no longer serves the reaction.
        await db.nostrEventsDao.upsertEvent(retracted);
        final unlike = await h.deletion(
          [retracted.id],
          createdAt: _now - 3600,
        );
        final newer = await h.reaction(_otherTarget, createdAt: _now - 60);
        h.relay
          ..hidesDeleted = true
          ..store.addAll([retracted, unlike, newer])
          ..replies = {_Read.deletions: _Reply.closed};

        await h.repo.initialize();

        expect(await h.repo.isLiked(_target), isFalse);
        expect(h.storage.records, isNot(contains(_target)));
      });
    });
  });
}
