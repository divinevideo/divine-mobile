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

  /// Whether a published event is stored and acknowledged with `OK true`;
  /// otherwise the relay refuses it.
  bool acceptsEvents = true;
  final List<_Read> reads = [];
  final List<Event> published = [];
  final List<Timer> _lateAnswers = [];
  final Map<_Read, Completer<void>> _awaitedReads = {};

  /// Completes when this relay next receives a read of [read].
  Future<void> nextRead(_Read read) =>
      (_awaitedReads[read] ??= Completer<void>()).future;

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
      _awaitedReads.remove(read)?.complete();
      unawaited(_answer(subId, filters, replies[read] ?? _Reply.answer));
    } else if (type == 'EVENT' && message.length > 1) {
      final event = Event.fromJson(
        Map<String, dynamic>.from(message[1] as Map),
      );
      published.add(event);
      if (acceptsEvents) store.add(event);
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
    await _deliver([
      'OK',
      id,
      acceptsEvents,
      if (acceptsEvents) '' else 'error: this relay refuses events',
    ]);
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
    required this.queued,
    required this.connectivity,
  });

  final LikesRepository repo;
  final _ScriptedRelay relay;
  final _MemoryLikesStorage storage;
  final LocalNostrSigner signer;
  final String user;

  /// Every action handed to the offline queue, as `like:<id>` or
  /// `unlike:<id>`.
  final List<String> queued;
  final _Connectivity connectivity;

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

  /// This account's `+` reactions on [target] the relay holds and has no
  /// deletion for.
  Iterable<Event> livePlusOn(String target) => relay.store.where(
    (e) =>
        e.kind == EventKind.reaction &&
        e.content == '+' &&
        e.pubkey == user &&
        e.tags.any((t) => t.length > 1 && t[0] == 'e' && t[1] == target) &&
        !relay.isDeleted(e),
  );

  Iterable<Event> get publishedReactions =>
      relay.published.where((e) => e.kind == EventKind.reaction);

  Future<String> likeTarget() => repo.likeEvent(
    eventId: _target,
    authorPubkey: _author,
    addressableId: _coord,
    targetKind: 34236,
  );

  Future<String> replayQueuedLike() => repo.executeLikeAction(
    eventId: _target,
    authorPubkey: _author,
    addressableId: _coord,
    targetKind: 34236,
  );
}

class _Connectivity {
  bool online = true;
}

Future<_Harness> _harness({
  AppDatabase? cacheDb,
  List<_ScriptedRelay> otherRelays = const [],
  bool withQueue = true,
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
  final queued = <String>[];
  final connectivity = _Connectivity();
  final repo = LikesRepository(
    nostrClient: client,
    localStorage: storage,
    isOnline: () => connectivity.online,
    queueOfflineAction: withQueue
        ? ({
            required isLike,
            required eventId,
            required authorPubkey,
            addressableId,
            targetKind,
          }) async {
            queued.add('${isLike ? 'like' : 'unlike'}:$eventId');
          }
        : null,
  );
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
    queued: queued,
    connectivity: connectivity,
  );
}

void main() {
  setUpAll(() => registerFallbackValue(''));
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(Nip89ClientTag.resetForTest);

  group('LikesRepository when a relay read ends short (#9004)', () {
    group('likeEvent', () {
      /// The account already likes [_target] on the relay, and the startup
      /// snapshot is incomplete, so the tap has to ask the relay. A newer
      /// like on another target is what the live subscription replays.
      Future<(_Harness, Event)> likedOnRelay({
        List<_ScriptedRelay> otherRelays = const [],
        AppDatabase? cacheDb,
      }) async {
        final h = await _harness(otherRelays: otherRelays, cacheDb: cacheDb);
        final existing = await h.reaction(
          _target,
          createdAt: _now - 7200,
          coord: _coord,
        );
        final newer = await h.reaction(_otherTarget, createdAt: _now - 60);
        h.relay
          ..store.addAll([existing, newer])
          ..replies = {_Read.reactions: _Reply.closed};
        await h.repo.initialize();
        expect(await h.repo.isLiked(_target), isFalse, reason: 'precondition');
        return (h, existing);
      }

      test('queues the like instead of publishing when a relay refuses '
          'the check', () async {
        final (h, _) = await likedOnRelay();
        h.relay.replies = {_Read.targetedReactions: _Reply.closed};

        final returned = await h.likeTarget();

        expect(h.relay.reads, contains(_Read.targetedReactions));
        expect(h.publishedReactions, isEmpty);
        expect(h.queued, equals(['like:$_target']));
        expect(returned, startsWith('pending_like_'));
        expect(await h.repo.isLiked(_target), isTrue);
        expect(h.livePlusOn(_target), hasLength(1));
      });

      test('adopts the existing like when the check completes', () async {
        final (h, existing) = await likedOnRelay();
        h.relay.replies = {};

        await expectLater(
          h.likeTarget(),
          throwsA(isA<AlreadyLikedException>()),
        );

        expect(h.publishedReactions, isEmpty);
        expect(h.queued, isEmpty);
        expect(h.storage.records[_target]?.reactionEventId, existing.id);
      });

      test('waits for a relay that answers after the settle window', () async {
        final fast = _ScriptedRelay('wss://fast.example');
        final (h, existing) = await likedOnRelay(otherRelays: [fast]);
        // The fast relay holds nothing and answers at once; the relay that
        // holds the like answers a moment later.
        h.relay.replies = {_Read.targetedReactions: _Reply.late};

        await expectLater(
          h.likeTarget(),
          throwsA(isA<AlreadyLikedException>()),
        );

        expect(h.publishedReactions, isEmpty);
        expect(h.queued, isEmpty);
        expect(h.storage.records[_target]?.reactionEventId, existing.id);
      });

      test('adopts a like this device cached even when a relay refuses '
          'the check', () async {
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final (h, existing) = await likedOnRelay(cacheDb: db);
        await db.nostrEventsDao.upsertEvent(existing);
        h.relay.replies = {_Read.targetedReactions: _Reply.closed};

        await expectLater(
          h.likeTarget(),
          throwsA(isA<AlreadyLikedException>()),
        );

        expect(h.publishedReactions, isEmpty);
        expect(h.queued, isEmpty);
        expect(h.livePlusOn(_target), hasLength(1));
      });

      group('when the account liked the target and took it back', () {
        Future<(_Harness, Event)> retractedOnRelay({
          bool withQueue = true,
        }) async {
          final h = await _harness(withQueue: withQueue);
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
            ..replies = {_Read.reactions: _Reply.closed};
          await h.repo.initialize();
          expect(
            await h.repo.isLiked(_target),
            isFalse,
            reason: 'precondition',
          );
          return (h, retracted);
        }

        test('queues the like when the check cannot read the '
            'deletion', () async {
          final (h, retracted) = await retractedOnRelay();
          h.relay.replies = {_Read.deletions: _Reply.closed};

          final returned = await h.likeTarget();

          expect(h.relay.reads, contains(_Read.deletions));
          expect(h.relay.published, isEmpty);
          expect(h.queued, equals(['like:$_target']));
          expect(returned, startsWith('pending_like_'));
          expect(
            h.storage.records[_target]?.reactionEventId,
            isNot(retracted.id),
          );
        });

        test('publishes a fresh like when the check reads the '
            'deletion', () async {
          final (h, retracted) = await retractedOnRelay();
          h.relay.replies = {};

          final returned = await h.likeTarget();

          expect(returned, isNot(retracted.id));
          expect(h.publishedReactions, hasLength(1));
          expect(h.livePlusOn(_target).single.id, returned);
          expect(h.queued, isEmpty);
        });

        test('publishes a fresh like rather than adopt the old one when '
            'no queue is wired', () async {
          final (h, retracted) = await retractedOnRelay(withQueue: false);
          h.relay.replies = {_Read.deletions: _Reply.closed};

          final returned = await h.likeTarget();

          expect(returned, isNot(retracted.id));
          expect(h.publishedReactions, hasLength(1));
          expect(h.storage.records[_target]?.reactionEventId, returned);
        });
      });

      test(
        'queues the like when the startup snapshot was capped',
        () async {
          final h = await _harness();
          h.relay.store.add(
            await h.reaction(_target, createdAt: _now - 100000, coord: _coord),
          );
          for (var i = 0; i < 500; i++) {
            final id = '1${i.toRadixString(16).padLeft(63, '0')}';
            h.relay.store.add(
              await h.reaction(id, createdAt: _now - 50000 + i),
            );
          }
          await h.repo.initialize();
          // The newest 500 synced, which left the target's older like out.
          expect(await h.repo.getLikedEventIds(), hasLength(500));
          expect(await h.repo.isLiked(_target), isFalse);
          h.relay.replies = {_Read.targetedReactions: _Reply.closed};

          await h.likeTarget();

          expect(h.publishedReactions, isEmpty);
          expect(h.queued, equals(['like:$_target']));
          expect(h.livePlusOn(_target), hasLength(1));
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    });

    group('executeLikeAction', () {
      /// A tap whose relay check was refused, so the like waits in the
      /// queue for the replay below. With [likedOnRelay] the account already
      /// holds a live like on the target, which is returned.
      Future<(_Harness, Event?)> queuedLike({bool likedOnRelay = false}) async {
        final h = await _harness();
        final existing = likedOnRelay
            ? await h.reaction(_target, createdAt: _now - 7200, coord: _coord)
            : null;
        final newer = await h.reaction(_otherTarget, createdAt: _now - 60);
        h.relay
          ..store.addAll([?existing, newer])
          ..replies = {_Read.reactions: _Reply.closed};
        await h.repo.initialize();
        h.relay.replies = {_Read.targetedReactions: _Reply.closed};
        await h.likeTarget();
        expect(h.queued, equals(['like:$_target']), reason: 'precondition');
        expect(h.publishedReactions, isEmpty, reason: 'precondition');
        return (h, existing);
      }

      test('adopts the existing like once the check completes', () async {
        final (h, existing) = await queuedLike(likedOnRelay: true);
        h.relay.replies = {};

        final returned = await h.replayQueuedLike();

        expect(returned, existing!.id);
        expect(h.publishedReactions, isEmpty);
        expect(h.storage.records[_target]?.reactionEventId, existing.id);
        expect(h.livePlusOn(_target), hasLength(1));
      });

      test('publishes once the check proves there is no like', () async {
        final (h, _) = await queuedLike();
        h.relay.replies = {};

        final returned = await h.replayQueuedLike();

        expect(h.publishedReactions, hasLength(1));
        expect(h.livePlusOn(_target).single.id, returned);
        expect(h.storage.records[_target]?.reactionEventId, returned);
      });

      test('checks again when the re-check ends short, and adopts the like '
          'once the relay answers', () async {
        final (h, existing) = await queuedLike(likedOnRelay: true);

        // A throw is what makes the queue retry the action after a backoff.
        await expectLater(
          h.replayQueuedLike(),
          throwsA(isA<LikeFailedException>()),
        );
        expect(h.publishedReactions, isEmpty);
        h.relay.replies = {};

        expect(await h.replayQueuedLike(), existing!.id);
        expect(h.publishedReactions, isEmpty);
        expect(h.livePlusOn(_target), hasLength(1));
      });

      test('publishes on the last attempt when every re-check ends short, so '
          'the like is not lost', () async {
        final (h, _) = await queuedLike();

        for (var attempt = 1; attempt < 3; attempt++) {
          await expectLater(
            h.replayQueuedLike(),
            throwsA(isA<LikeFailedException>()),
          );
        }
        expect(h.publishedReactions, isEmpty);

        final returned = await h.replayQueuedLike();

        expect(h.publishedReactions, hasLength(1));
        expect(h.storage.records[_target]?.reactionEventId, returned);
      });

      test('drops a like taken back between re-checks', () async {
        final (h, _) = await queuedLike();
        await expectLater(
          h.replayQueuedLike(),
          throwsA(isA<LikeFailedException>()),
        );

        await h.repo.unlikeEvent(_target, addressableId: _coord);
        expect(h.queued, equals(['like:$_target', 'unlike:$_target']));
        h.relay.replies = {};

        expect(await h.replayQueuedLike(), startsWith('pending_like_'));
        expect(h.relay.published, isEmpty);
        expect(await h.repo.isLiked(_target), isFalse);
      });

      test('retracts what it published when the like is taken back '
          'meanwhile', () async {
        final (h, _) = await queuedLike();
        h.relay.replies = {_Read.targetedReactions: _Reply.late};

        final checkStarted = h.relay.nextRead(_Read.targetedReactions);
        final replay = h.replayQueuedLike();
        await checkStarted;
        await h.repo.unlikeEvent(_target, addressableId: _coord);
        await replay;

        expect(h.publishedReactions, hasLength(1));
        expect(h.livePlusOn(_target), isEmpty);
        expect(await h.repo.isLiked(_target), isFalse);
        expect(h.storage.records, isNot(contains(_target)));
      });

      test('ends without a retry when the like is taken back while its '
          'publish fails', () async {
        final (h, _) = await queuedLike();
        h.relay
          ..replies = {_Read.targetedReactions: _Reply.late}
          ..acceptsEvents = false;

        final checkStarted = h.relay.nextRead(_Read.targetedReactions);
        final replay = h.replayQueuedLike();
        await checkStarted;
        await h.repo.unlikeEvent(_target, addressableId: _coord);

        // A replay that threw would be retried, and the retry would publish
        // the like the user took back.
        expect(await replay, startsWith('pending_like_'));
        expect(h.livePlusOn(_target), isEmpty);
        expect(await h.repo.isLiked(_target), isFalse);
      });

      test('publishes rather than adopt a like whose deletion the check '
          'still cannot read', () async {
        final h = await _harness();
        final retracted = await h.reaction(
          _target,
          createdAt: _now - 7200,
          coord: _coord,
        );
        final unlike = await h.deletion([retracted.id], createdAt: _now - 3600);
        final newer = await h.reaction(_otherTarget, createdAt: _now - 60);
        h.relay
          ..store.addAll([retracted, unlike, newer])
          ..replies = {_Read.reactions: _Reply.closed};
        await h.repo.initialize();
        h.relay.replies = {_Read.deletions: _Reply.closed};
        await h.likeTarget();
        expect(h.queued, equals(['like:$_target']), reason: 'precondition');

        for (var attempt = 1; attempt < 3; attempt++) {
          await expectLater(
            h.replayQueuedLike(),
            throwsA(isA<LikeFailedException>()),
          );
        }
        final returned = await h.replayQueuedLike();

        expect(returned, isNot(retracted.id));
        expect(h.livePlusOn(_target).single.id, returned);
        expect(h.storage.records[_target]?.reactionEventId, returned);
      });
    });

    group('unlikeEvent', () {
      test('queues the unlike of a like still waiting in the queue, so the '
          'queue drops both', () async {
        final h = await _harness();
        h.connectivity.online = false;
        await h.likeTarget();
        expect(h.queued, equals(['like:$_target']), reason: 'precondition');
        h.connectivity.online = true;

        await h.repo.unlikeEvent(_target, addressableId: _coord);

        expect(h.queued, equals(['like:$_target', 'unlike:$_target']));
        expect(h.relay.published, isEmpty);
        expect(await h.repo.isLiked(_target), isFalse);
      });
    });

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
