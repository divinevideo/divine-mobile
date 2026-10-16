import 'dart:async';
import 'dart:convert';
import 'package:cache_sync/cache_sync.dart';
import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/relay/relay_info.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    // Existing event-list fixtures describe complete reads. Individual tests
    // override readEvents to model the real client's partial-result metadata.
    when(() => readEvents(any(), requireAllRelaysSettled: true)).thenAnswer(
      (invocation) async => QueryResult(
        events: await queryEvents(
          invocation.positionalArguments.single as List<Filter>,
        ),
        endedBy: QueryEnd.complete,
        confirmedExhaustive: true,
      ),
    );
  }
}

class _MockApi extends Mock implements FunnelcakeApiClient {}

class _MockStatsDao extends Mock implements ProfileStatsDao {}

// The DAO itself has SQLite tests; this double keeps sync timing deterministic.
class _MemoryFollowersDao extends Fake implements MyFollowersDao {
  final rows = <String, Map<String, int?>>{};
  int replacements = 0;
  @override
  Future<List<({String pubkey, int? followedAt})>> followersOf(
    String owner,
  ) async => [
    for (final row in (rows[owner] ?? <String, int?>{}).entries)
      (pubkey: row.key, followedAt: row.value),
  ];
  @override
  Future<int?> newestFollowedAt(String owner) async {
    final dates =
        (rows[owner] ?? <String, int?>{}).values.whereType<int>().toList()
          ..sort();
    return dates.lastOrNull;
  }

  @override
  Future<void> upsertAll({
    required String ownerPubkey,
    required Iterable<({String pubkey, int? followedAt})> followers,
    required int seenAt,
  }) async {
    final target = rows.putIfAbsent(ownerPubkey, () => {});
    for (final follower in followers) {
      final previous = target[follower.pubkey];
      final next = follower.followedAt;
      target[follower.pubkey] =
          previous == null || (next != null && next > previous)
          ? next
          : previous;
    }
  }

  @override
  Future<void> replaceAll({
    required String ownerPubkey,
    required Iterable<({String pubkey, int? followedAt})> followers,
    required int seenAt,
  }) async {
    replacements++;
    rows[ownerPubkey] = {};
    await upsertAll(
      ownerPubkey: ownerPubkey,
      followers: followers,
      seenAt: seenAt,
    );
  }
}

class _UnreadableFollowersDao extends _MemoryFollowersDao {
  @override
  Future<List<({String pubkey, int? followedAt})>> followersOf(
    String owner,
  ) async => throw StateError('database is locked');
}

class _FlakyFollowersDao extends _MemoryFollowersDao {
  bool failReads = false;
  @override
  Future<List<({String pubkey, int? followedAt})>> followersOf(String owner) {
    if (failReads) throw StateError('database is locked');
    return super.followersOf(owner);
  }
}

class _UnwritableFollowersDao extends _MemoryFollowersDao {
  void Function()? beforeFailure;
  @override
  Future<void> replaceAll({
    required String ownerPubkey,
    required Iterable<({String pubkey, int? followedAt})> followers,
    required int seenAt,
  }) async {
    beforeFailure?.call();
    throw StateError('database is full');
  }
}

class _CappedFollowerIndexer extends _CompleteFollowerIndexer {
  _CappedFollowerIndexer(
    super.url,
    super.relayStatus,
    super.follower, {
    this.count = 1,
    int? maxLimit = 1,
  }) {
    if (maxLimit != null) {
      info = RelayInfo('', '', '', '', const [], '', '', maxLimit: maxLimit);
    }
  }
  final int count;
  late List<dynamic> request;
  @override
  Future<bool> doConnect() async {
    request = List<dynamic>.of(pendingMessages.first);
    for (var i = 0; i < count; i++) {
      await onMessage?.call(this, [
        'EVENT',
        'test',
        {
          'pubkey': i == 0 ? follower : i.toRadixString(16).padLeft(64, '0'),
          'created_at': 100,
        },
      ]);
    }
    await onMessage?.call(this, ['EOSE', 'test']);
    return true;
  }
}

class _PartialRelay extends RelayBase {
  _PartialRelay(super.url, super.relayStatus, this.follower);
  final String follower;
  @override
  Future<bool> doConnect() async {
    await onMessage?.call(this, [
      'EVENT',
      'test',
      {'pubkey': follower, 'created_at': 100},
    ]);
    return true;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async => true;
  @override
  Future<void> disconnect() async {}
}

class _CompleteFollowerIndexer extends _PartialRelay {
  _CompleteFollowerIndexer(super.url, super.relayStatus, super.follower);

  @override
  Future<bool> doConnect() async {
    await super.doConnect();
    await onMessage?.call(this, ['EOSE', 'test']);
    return true;
  }
}

// Only transport is scripted: the production SDK verifies frames and computes
// the outcome metadata from the exact filter emitted by FollowRepository.
class _FollowerContractRelay extends Relay {
  _FollowerContractRelay()
    : super('wss://followers.example', RelayStatus('wss://followers.example'));

  late Completer<String> nextRequest;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    return true;
  }

  @override
  void saveQuery(Subscription subscription) {
    super.saveQuery(subscription);
    nextRequest.complete(subscription.id);
  }

  Future<void> deliver(List<dynamic> message) async {
    final handler = onMessage;
    expect(handler, isNotNull);
    final result = handler!(this, message);
    if (result is Future) await result;
  }
}

void main() {
  group('persistent follower sync', () {
    final owner = 'a' * 64;
    final otherOwner = 'b' * 64;
    final first = '1' * 64;
    final second = '2' * 64;
    final stale = '3' * 64;
    late _MockNostrClient client;
    late _MockApi api;
    late _MemoryFollowersDao dao;
    late FollowRepository repository;
    late int now;
    late bool online;

    Event contact(String author, int at) => Event(
      author,
      EventKind.contactList,
      [
        ['p', owner],
      ],
      '',
      createdAt: at,
    );
    FollowRepository build({
      List<String> indexers = const [],
      RelayFactory? relayFactory,
      bool withDao = true,
      ProfileStatsDao? statsDao,
    }) => FollowRepository(
      nostrClient: client,
      indexerRelayUrls: indexers,
      funnelcakeApiClient: api,
      myFollowersDao: withDao ? dao : null,
      profileStatsDao: statsDao,
      nowSeconds: () => now,
      isOnline: () => online,
      relayFactory: relayFactory,
      indexerQueryTimeout: const Duration(milliseconds: 10),
      indexerOperationTimeout: const Duration(milliseconds: 20),
    );
    Future<void> stamp({int? full, int? incremental}) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('my_followers_full_sync_$owner', full ?? now);
      await prefs.setInt(
        'my_followers_incremental_sync_$owner',
        incremental ?? now,
      );
    }

    setUpAll(() => registerFallbackValue(<Filter>[]));
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      now = 1700000000;
      online = true;
      dao = _MemoryFollowersDao();
      client = _MockNostrClient();
      api = _MockApi();
      when(() => client.publicKey).thenReturn(owner);
      when(() => client.hasKeys).thenReturn(true);
      when(() => client.queryEvents(any())).thenAnswer((_) async => []);
      when(
        () => client.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => client.unsubscribe(any())).thenAnswer((_) async {});
      when(() => api.isAvailable).thenReturn(false);
      repository = build();
    });
    tearDown(() => repository.dispose());

    test(
      'initialize loads persisted followers so relationshipTo is mutual with no fetch',
      () async {
        dao.rows[owner] = {first: 100};
        SharedPreferences.setMockInitialValues({
          'following_list_$owner': jsonEncode([first]),
        });
        await repository.initialize();
        expect(repository.relationshipTo(first), FollowRelationship.mutual);
        verifyNever(() => client.queryEvents(any()));
      },
    );
    test(
      'initialize still loads the following list when persisted followers '
      'cannot be read',
      () async {
        dao = _UnreadableFollowersDao();
        await repository.dispose();
        repository = build();
        SharedPreferences.setMockInitialValues({
          'following_list_$owner': jsonEncode([first]),
        });
        await repository.initialize();
        expect(repository.isInitialized, isTrue);
        expect(repository.followingPubkeys, [first]);
        expect(repository.relationshipTo(first), FollowRelationship.youFollow);
      },
    );
    test('seed replaces the table on full success', () async {
      when(
        () => client.queryEvents(any()),
      ).thenAnswer((_) async => [contact(first, 100)]);
      await repository.syncMyFollowers();
      expect(dao.rows[owner], {first: 100});
      expect(dao.replacements, 1);
      expect(repository.relationshipTo(first), FollowRelationship.followsYou);
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'my_followers_full_sync_$owner',
        ),
        now,
      );
    });
    test(
      'cleared owner checkpoints reseed while other owner markers survive',
      () async {
        final checkpoints = MyFollowersSyncState();
        await repository.syncMyFollowers();
        await checkpoints.stampFull(otherOwner, 123);
        await checkpoints.stampFullAttempt(otherOwner, 456);
        await checkpoints.clear(owner);
        expect(await checkpoints.read(owner), (
          full: null,
          incremental: null,
          attempt: null,
          fullAttempt: null,
        ));
        expect(await checkpoints.read(otherOwner), (
          full: 123,
          incremental: 123,
          attempt: 456,
          fullAttempt: 456,
        ));
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => [contact(first, 100)]);
        await repository.syncMyFollowers();
        expect(dao.rows[owner], {first: 100});
        expect((await checkpoints.read(owner)).full, now);
        verify(() => client.queryEvents(any())).called(2);
      },
    );

    test(
      'queued full fetch rejects an owner that changed while waiting',
      () async {
        final started = Completer<void>();
        final response = Completer<List<Event>>();
        when(() => client.queryEvents(any())).thenAnswer((_) {
          started.complete();
          return response.future;
        });
        final firstFetch = repository.getMyFollowers();
        await started.future;
        final queued = repository.getMyFollowers();
        when(() => client.publicKey).thenReturn(otherOwner);
        response.complete([contact(first, 100)]);
        await firstFetch;
        expect(await queued, isEmpty);
        expect(dao.rows, isEmpty);
        verify(() => client.queryEvents(any())).called(1);
      },
    );

    test('successful empty seed is not repeated on the next open', () async {
      await repository.syncMyFollowers();
      now += 901;
      await repository.syncMyFollowers();
      verify(() => client.queryEvents(any())).called(2);
      expect(dao.replacements, 1);
      expect(dao.rows[owner], isEmpty);
    });

    test(
      'partial full attempts retry daily with merge-only incrementals between',
      () async {
        when(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).thenAnswer(
          (_) async => QueryResult(
            events: [contact(first, 100)],
            endedBy: QueryEnd.deadline,
          ),
        );
        await repository.syncMyFollowers();
        expect(
          (await SharedPreferences.getInstance()).getInt(
            'my_followers_full_sync_$owner',
          ),
          isNull,
        );
        await repository.syncMyFollowers();
        verify(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).called(1);
        now += 901;
        await repository.syncMyFollowers();
        verify(() => client.queryEvents(any())).called(1);
        expect(dao.replacements, 0);
        expect(dao.rows[owner], {first: 100});
        now += 86400;
        when(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).thenAnswer(
          (_) async => QueryResult(
            events: [contact(first, 100), contact(second, 50)],
            endedBy: QueryEnd.complete,
            confirmedExhaustive: true,
          ),
        );
        await repository.syncMyFollowers();
        expect(dao.rows[owner], {first: 100, second: 50});
        expect(
          (await SharedPreferences.getInstance()).getInt(
            'my_followers_full_sync_$owner',
          ),
          now,
        );
      },
    );

    test(
      'picker emits while background sync is pending and persists in order',
      () async {
        dao.rows[owner] = {stale: 50};
        await stamp(incremental: now - 901);
        final started = Completer<void>();
        final response = Completer<List<Event>>();
        when(() => client.queryEvents(any())).thenAnswer((_) {
          started.complete();
          return response.future;
        });
        final sync = repository.syncMyFollowers();
        await started.future;
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getFollowers(pubkey: owner, limit: 5000)).thenAnswer(
          (_) async => PaginatedPubkeys(pubkeys: [first], total: 1),
        );
        when(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).thenAnswer(
          (_) async => const QueryResult(
            events: [],
            endedBy: QueryEnd.complete,
            confirmedExhaustive: true,
          ),
        );
        final emissions = <List<String>>[];
        final stream = repository.streamMyFollowers().forEach(emissions.add);
        await pumpEventQueue();
        expect(emissions, [
          [first],
        ]);
        expect(dao.rows[owner], {stale: 50});
        response.complete([contact(second, now)]);
        await sync;
        await stream;
        expect(dao.rows[owner], {first: null});
        expect(dao.replacements, 1);
      },
    );

    test(
      'queued picker persistence rejects an account switched during fetch',
      () async {
        await stamp(incremental: now - 901);
        final started = Completer<void>();
        final response = Completer<List<Event>>();
        when(() => client.queryEvents(any())).thenAnswer((_) {
          started.complete();
          return response.future;
        });
        final sync = repository.syncMyFollowers();
        await started.future;
        when(() => api.isAvailable).thenReturn(true);
        when(() => api.getFollowers(pubkey: owner, limit: 5000)).thenAnswer(
          (_) async => PaginatedPubkeys(pubkeys: [first], total: 1),
        );
        when(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).thenAnswer(
          (_) async => const QueryResult(
            events: [],
            endedBy: QueryEnd.complete,
            confirmedExhaustive: true,
          ),
        );
        final emissions = <List<String>>[];
        final stream = repository.streamMyFollowers().forEach(emissions.add);
        await pumpEventQueue();
        expect(emissions, [
          [first],
        ]);
        when(() => client.publicKey).thenReturn(otherOwner);
        response.complete([contact(second, now)]);
        await sync;
        await stream;
        expect(dao.rows, isEmpty);
        expect((await MyFollowersSyncState().read(otherOwner)).full, isNull);
        expect(repository.relationshipTo(first), FollowRelationship.none);
      },
    );

    for (final fullPath in ['get', 'stream']) {
      test(
        '$fullPath orders partial full persistence before an eligible incremental',
        () async {
          dao.rows[owner] = {first: 100};
          await stamp(incremental: now - 901);
          final started = Completer<void>();
          final response = Completer<QueryResult>();
          when(
            () => client.readEvents(any(), requireAllRelaysSettled: true),
          ).thenAnswer((_) {
            started.complete();
            return response.future;
          });
          when(
            () => client.queryEvents(any()),
          ).thenAnswer((_) async => [contact(second, now)]);
          final full = fullPath == 'get'
              ? repository.getMyFollowers()
              : repository.streamMyFollowers().toList();
          await started.future;
          now += 901;
          final incremental = repository.syncMyFollowers();
          await pumpEventQueue();
          // The incremental fetch must not overlap an older full snapshot.
          verifyNever(() => client.queryEvents(any()));
          response.complete(
            QueryResult(
              events: [contact(first, 100)],
              endedBy: QueryEnd.deadline,
            ),
          );
          await full;
          await incremental;
          verify(() => client.queryEvents(any())).called(1);
          expect(dao.rows[owner], {first: 100, second: now});
          expect(
            (await SharedPreferences.getInstance()).getInt(
              'my_followers_incremental_sync_$owner',
            ),
            now,
          );
        },
      );
    }

    for (final completedEmpty in [false, true]) {
      test(
        'durable ${completedEmpty ? "empty" : "populated"} snapshot outranks older CacheSync before live network',
        () async {
          final cacheDao = FakeCacheDao();
          await CacheSync.init(dao: cacheDao);
          await cacheDao.write(
            key: '$owner:my_followers',
            payload: FollowersSnapshot(pubkeys: [stale], count: 12).toJson(),
          );
          dao.rows[owner] = completedEmpty ? {} : {first: 100};
          if (completedEmpty) await stamp();
          final stats = _MockStatsDao();
          when(() => stats.getStatsRaw(owner)).thenAnswer(
            (_) async => ProfileStatRow(
              pubkey: owner,
              followerCount: 99,
              cachedAt: DateTime.now(),
            ),
          );
          when(
            () => stats.upsertStats(
              pubkey: any(named: 'pubkey'),
              followerCount: any(named: 'followerCount'),
              followingCount: any(named: 'followingCount'),
            ),
          ).thenAnswer((_) async {});
          await repository.dispose();
          repository = build(statsDao: stats);
          final started = Completer<void>();
          final response = Completer<List<Event>>();
          when(() => client.queryEvents(any())).thenAnswer((_) {
            if (!started.isCompleted) started.complete();
            return response.future;
          });
          final results = <CacheResult<FollowersSnapshot>>[];
          final done = Completer<void>();
          final subscription = repository.watchMyFollowersCached().listen(
            results.add,
            onDone: done.complete,
          );
          await started.future;
          await pumpEventQueue();
          expect(results, hasLength(1));
          expect(results.single.isStale, isTrue);
          expect(
            results.single.data.pubkeys,
            completedEmpty ? isEmpty : [first],
          );
          expect(
            results.single.data.count,
            99,
            reason:
                'authoritative baseline is independent of relationship rows and older cache',
          );
          response.complete([contact(second, 200)]);
          await done.future;
          expect(results, hasLength(2));
          expect(results.last.isLive, isTrue);
          expect(results.last.data.pubkeys, [second]);
          await subscription.cancel();
        },
      );
    }

    test('durable rows do not invent an authoritative count', () async {
      await CacheSync.init(dao: FakeCacheDao());
      dao.rows[owner] = {first: 100};
      final snapshot = await repository.watchMyFollowersCached().first;
      expect(snapshot.isStale, isTrue);
      expect(snapshot.data.pubkeys, [first]);
      expect(snapshot.data.count, 0);
    });

    test('partial source failure merges instead of replacing', () async {
      dao.rows[owner] = {stale: 50};
      when(() => api.isAvailable).thenReturn(true);
      when(
        () => api.getFollowers(pubkey: owner, limit: 5000),
      ).thenAnswer((_) async => PaginatedPubkeys(pubkeys: [first, second]));
      when(
        () => client.queryEvents(any()),
      ).thenThrow(StateError('relay unavailable'));
      await repository.syncMyFollowers();
      expect(dao.rows[owner], {stale: 50, first: null, second: null});
      expect(dao.replacements, 0);
      expect(repository.relationshipTo(stale), FollowRelationship.followsYou);
    });
    test('incremental query uses since = high-water mark minus 600', () async {
      dao.rows[owner] = {first: now - 100};
      await stamp(incremental: now - 901);
      when(
        () => client.queryEvents(any()),
      ).thenAnswer((_) async => [contact(second, now - 50)]);
      await repository.syncMyFollowers();
      final filter =
          (verify(() => client.queryEvents(captureAny())).captured.single
                  as List<Filter>)
              .single;
      expect(filter.since, now - 700);
      expect(filter.p, [owner]);
      expect(filter.kinds, [EventKind.contactList]);
      expect(dao.rows[owner], {first: now - 100, second: now - 50});
      expect(
        (await SharedPreferences.getInstance()).getInt(
          'my_followers_incremental_sync_$owner',
        ),
        now,
      );
    });
    test('high-water mark is clamped to now', () async {
      dao.rows[owner] = {first: now + 86400};
      await stamp(incremental: now - 901);
      await repository.syncMyFollowers();
      final filter =
          (verify(() => client.queryEvents(captureAny())).captured.single
                  as List<Filter>)
              .single;
      expect(filter.since, now - 600);
    });
    test('reconcile after 7 days removes an unfollower', () async {
      dao.rows[owner] = {first: 100, stale: 50};
      await stamp(full: now - 604801);
      when(
        () => client.queryEvents(any()),
      ).thenAnswer((_) async => [contact(first, 100)]);
      await repository.syncMyFollowers();
      expect(dao.rows[owner], {first: 100});
      expect(repository.relationshipTo(stale), FollowRelationship.none);
    });
    test('no sync inside the 15-minute window', () async {
      dao.rows[owner] = {first: 100};
      await stamp(incremental: now - 899);
      await repository.syncMyFollowers();
      verifyNever(() => client.queryEvents(any()));
      expect(dao.rows[owner], {first: 100});
    });
    test('offline does nothing', () async {
      online = false;
      await repository.syncMyFollowers();
      verifyNever(() => client.queryEvents(any()));
      expect(dao.rows, isEmpty);
    });
    test('no keys does nothing', () async {
      when(() => client.hasKeys).thenReturn(false);
      await repository.syncMyFollowers();
      verifyNever(() => client.queryEvents(any()));
      expect(dao.rows, isEmpty);
    });
    test(
      'concurrent syncMyFollowers calls share one fetch and future',
      () async {
        final response = Completer<List<Event>>();
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) => response.future);
        final one = repository.syncMyFollowers();
        final two = repository.syncMyFollowers();
        expect(identical(one, two), isTrue);
        response.complete([contact(first, 100)]);
        await Future.wait([one, two]);
        verify(() => client.queryEvents(any())).called(1);
        expect(dao.replacements, 1);
      },
    );
    for (final failure in ['read', 'write']) {
      for (final path in ['get', 'stream', 'cached']) {
        test(
          '$path returns live followers despite durable $failure failure',
          () async {
            dao = failure == 'read'
                ? _UnreadableFollowersDao()
                : _UnwritableFollowersDao();
            await repository.dispose();
            repository = build();
            when(
              () => client.queryEvents(any()),
            ).thenAnswer((_) async => [contact(first, 100)]);
            if (path == 'get') {
              expect(await repository.getMyFollowers(), [first]);
            } else if (path == 'stream') {
              expect(await repository.streamMyFollowers().toList(), [
                [first],
              ]);
            } else {
              final cacheDao = FakeCacheDao();
              await CacheSync.init(dao: cacheDao);
              await cacheDao.write(
                key: '$owner:my_followers',
                payload: FollowersSnapshot(pubkeys: [stale], count: 1).toJson(),
              );
              final results = await repository
                  .watchMyFollowersCached()
                  .toList();
              expect(results.first.data.pubkeys, [stale]);
              expect(results.last.isLive, isTrue);
              expect(results.last.data.pubkeys, [first]);
            }
            expect(
              repository.relationshipTo(first),
              FollowRelationship.followsYou,
            );
            expect((await MyFollowersSyncState().read(owner)).full, isNull);
          },
        );
      }
    }

    test(
      'indexer advertises a smaller cap so EOSE cannot prune known rows',
      () async {
        dao.rows[owner] = {stale: 50};
        await repository.dispose();
        late _CappedFollowerIndexer indexer;
        repository = build(
          indexers: ['wss://capped.example'],
          relayFactory: (url, status) =>
              indexer = _CappedFollowerIndexer(url, status, first),
        );
        await repository.syncMyFollowers();
        final request = indexer.request;
        expect((request[2] as Map<String, dynamic>)['limit'], 5000);
        expect(dao.rows[owner], {stale: 50, first: 100});
        expect(dao.replacements, 0);
        expect((await MyFollowersSyncState().read(owner)).full, isNull);
      },
    );

    test(
      'indexer EOSE at the requested limit remains merge-only without NIP-11',
      () async {
        dao.rows[owner] = {stale: 50};
        await repository.dispose();
        repository = build(
          indexers: ['wss://capped.example'],
          relayFactory: (url, status) => _CappedFollowerIndexer(
            url,
            status,
            first,
            count: 5000,
            maxLimit: null,
          ),
        );
        await repository.syncMyFollowers();
        expect(dao.rows[owner], hasLength(5001));
        expect(dao.rows[owner]![stale], 50);
        expect(dao.replacements, 0);
        expect((await MyFollowersSyncState().read(owner)).full, isNull);
      },
    );

    test(
      'partial storage fallback keeps earlier in-memory followers',
      () async {
        final flakyDao = _FlakyFollowersDao();
        dao = flakyDao;
        await repository.dispose();
        repository = build();
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => [contact(first, 100)]);
        await repository.getMyFollowers();
        final completedAt = now;
        now += 901;
        flakyDao.failReads = true;
        when(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).thenAnswer(
          (_) async => QueryResult(
            events: [contact(second, 200)],
            endedBy: QueryEnd.deadline,
          ),
        );
        expect(await repository.getMyFollowers(), [second]);
        expect(repository.relationshipTo(first), FollowRelationship.followsYou);
        expect(
          repository.relationshipTo(second),
          FollowRelationship.followsYou,
        );
        expect((await MyFollowersSyncState().read(owner)).full, completedAt);
      },
    );

    test(
      'failed persistence cannot cache followers into a switched account',
      () async {
        final failingDao = _UnwritableFollowersDao()
          ..beforeFailure = () =>
              when(() => client.publicKey).thenReturn(otherOwner);
        dao = failingDao;
        await repository.dispose();
        repository = build();
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => [contact(first, 100)]);
        expect(await repository.getMyFollowers(), [first]);
        expect(repository.relationshipTo(first), FollowRelationship.none);
        expect((await MyFollowersSyncState().read(owner)).full, isNull);
        expect((await MyFollowersSyncState().read(otherOwner)).full, isNull);
      },
    );

    test('getMyFollowers persists to the table', () async {
      when(
        () => client.queryEvents(any()),
      ).thenAnswer((_) async => [contact(first, 100)]);
      expect(await repository.getMyFollowers(), [first]);
      expect(dao.rows[owner], {first: 100});
    });
    test(
      'getMyFollowers preserves stored rows after partial failure',
      () async {
        dao.rows[owner] = {stale: 50};
        when(() => api.isAvailable).thenReturn(true);
        when(
          () => api.getFollowers(pubkey: owner, limit: 5000),
        ).thenAnswer((_) async => throw StateError('api unavailable'));
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => [contact(first, 100)]);
        await repository.getMyFollowers();
        expect(dao.rows[owner], {stale: 50, first: 100});
      },
    );
    test('streamMyFollowers persists the completed union', () async {
      when(
        () => client.queryEvents(any()),
      ).thenAnswer((_) async => [contact(first, 100)]);
      await repository.streamMyFollowers().drain<void>();
      expect(dao.rows[owner], {first: 100});
    });
    test('relay timeout preserves stored rows', () {
      fakeAsync((async) {
        dao.rows[owner] = {stale: 50};
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) => Completer<List<Event>>().future);
        var done = false;
        unawaited(repository.syncMyFollowers().then((_) => done = true));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 9))
          ..flushMicrotasks();
        expect(done, isTrue);
        expect(dao.rows[owner], {stale: 50});
        expect(dao.replacements, 0);
      });
    });
    test(
      'indexer partial timeout preserves stored rows and useful new rows',
      () async {
        dao.rows[owner] = {stale: 50};
        await repository.dispose();
        repository = build(
          indexers: ['wss://relay.example.com'],
          relayFactory: (url, status) => _PartialRelay(url, status, first),
        );
        await repository.syncMyFollowers();
        expect(dao.rows[owner], {stale: 50, first: 100});
        expect(dao.replacements, 0);
      },
    );
    test(
      'account switch during fetch does not persist or expose old followers',
      () async {
        final response = Completer<List<Event>>();
        final started = Completer<void>();
        when(() => client.queryEvents(any())).thenAnswer((_) {
          started.complete();
          return response.future;
        });
        final sync = repository.syncMyFollowers();
        await started.future;
        when(() => client.publicKey).thenReturn(otherOwner);
        response.complete([contact(first, 100)]);
        await sync;
        expect(dao.rows, isEmpty);
        expect(repository.relationshipTo(first), FollowRelationship.none);
      },
    );
    test('dispose during fetch does not persist followers', () async {
      final response = Completer<List<Event>>();
      final started = Completer<void>();
      when(() => client.queryEvents(any())).thenAnswer((_) {
        started.complete();
        return response.future;
      });
      final sync = repository.syncMyFollowers();
      await started.future;
      await repository.dispose();
      response.complete([contact(first, 100)]);
      await sync;
      expect(dao.rows, isEmpty);
    });
    test('stream partial failure preserves known followers', () async {
      dao.rows[owner] = {stale: 50};
      when(() => api.isAvailable).thenReturn(true);
      when(
        () => api.getFollowers(pubkey: owner, limit: 5000),
      ).thenAnswer((_) async => throw StateError('api unavailable'));
      when(
        () => client.queryEvents(any()),
      ).thenAnswer((_) async => [contact(first, 100)]);
      await repository.streamMyFollowers().drain<void>();
      expect(dao.rows[owner], {stale: 50, first: 100});
      expect(repository.relationshipTo(stale), FollowRelationship.followsYou);
    });

    test(
      'incremental undated rows start at zero and demote future events',
      () async {
        dao.rows[owner] = {first: null};
        await stamp(incremental: now - 901);
        when(() => client.queryEvents(any())).thenAnswer(
          (_) async => [
            contact(second, now + 86400),
          ],
        );
        await repository.syncMyFollowers();
        final filter =
            (verify(() => client.queryEvents(captureAny())).captured.single
                    as List<Filter>)
                .single;
        expect(filter.since, 0);
        expect(dao.rows[owner], {first: null, second: null});
      },
    );

    test(
      'failed incremental sync retries after the attempt throttle',
      () async {
        dao.rows[owner] = {first: 100};
        await stamp(incremental: now - 901);
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => throw StateError('offline'));
        await expectLater(repository.syncMyFollowers(), throwsStateError);
        expect(
          (await SharedPreferences.getInstance()).getInt(
            'my_followers_incremental_sync_$owner',
          ),
          now - 901,
        );
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => [contact(second, 200)]);
        await repository.syncMyFollowers();
        expect(dao.rows[owner], {first: 100});
        now += 901;
        await repository.syncMyFollowers();
        expect(dao.rows[owner], {first: 100, second: 200});
      },
    );

    test('sync without a DAO or with an empty owner does nothing', () async {
      await repository.dispose();
      repository = build(withDao: false);
      await repository.syncMyFollowers();
      await repository.dispose();
      repository = build();
      when(() => client.publicKey).thenReturn('');
      await repository.syncMyFollowers();
      verifyNever(() => client.queryEvents(any()));
      expect(dao.rows, isEmpty);
    });

    test(
      'cached follower relationships are isolated after an account change',
      () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer((_) async => [contact(first, 100)]);
        await repository.getMyFollowers();
        expect(repository.relationshipTo(first), FollowRelationship.followsYou);
        when(() => client.publicKey).thenReturn(otherOwner);
        expect(repository.relationshipTo(first), FollowRelationship.none);
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        final snapshots = await repository.watchMyFollowers().toList();
        expect(snapshots, hasLength(1));
        expect(snapshots.single.pubkeys, isEmpty);
        expect(dao.rows[owner], {first: 100});
        expect(dao.rows[otherOwner], isEmpty);
      },
    );
    group('production SDK relay completion contract', () {
      late Nostr sdk;
      late _FollowerContractRelay relay;
      late Event followerEvent;
      late List<QueryResult> outcomes;
      late List<Filter> sentFilters;

      setUp(() async {
        sdk = Nostr(
          LocalNostrSigner('1' * 64),
          const [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        relay = _FollowerContractRelay();
        expect(await sdk.relayPool.add(relay), isTrue);
        final author = await sdk.ensurePublicKey();
        followerEvent = (await sdk.nostrSigner.signEvent(
          contact(author, 100),
        ))!;
        outcomes = [];
        sentFilters = [];
        when(
          () => client.readEvents(any(), requireAllRelaysSettled: true),
        ).thenAnswer((call) async {
          final filters = call.positionalArguments.single as List<Filter>;
          sentFilters.addAll(filters);
          relay.nextRequest = Completer<String>();
          final pending = sdk.readEvents(
            filters.map((filter) => filter.toJson()).toList(),
            requireAllRelaysSettled: true,
          );
          final id = await relay.nextRequest.future;
          await relay.deliver(['EVENT', id, followerEvent.toJson()]);
          // Ordinary EOSE: no NIP-67 finish hint.
          await relay.deliver(['EOSE', id]);
          final result = await pending;
          outcomes.add(result);
          return result;
        });
      });
      tearDown(() => sdk.close());

      test(
        'nonempty EOSE without NIP-11 completes bounded full reconciliation',
        () async {
          // Exercise the real merger with all three source adapters active.
          await repository.dispose();
          var indexerConnections = 0;
          repository = build(
            indexers: ['wss://indexer.example'],
            relayFactory: (url, status) {
              indexerConnections++;
              return _CompleteFollowerIndexer(url, status, second);
            },
          );
          when(() => api.isAvailable).thenReturn(true);
          when(() => api.getFollowers(pubkey: owner, limit: 5000)).thenAnswer(
            (_) async => PaginatedPubkeys(pubkeys: [first], total: 1),
          );
          dao.rows[owner] = {stale: 50};
          expect(relay.info, isNull);
          await repository.syncMyFollowers();
          expect(outcomes.single.endedBy, QueryEnd.complete);
          expect(outcomes.single.confirmedExhaustive, isFalse);
          expect(outcomes.single.possiblyCapped, isFalse);
          expect(sentFilters.single.limit, 5000);
          expect(dao.rows[owner], {
            first: null,
            second: 100,
            followerEvent.pubkey: 100,
          });
          expect(dao.replacements, 1);
          final checkpoint = await MyFollowersSyncState().read(owner);
          expect(checkpoint.full, now);
          expect(checkpoint.incremental, now);
          await repository.syncMyFollowers();
          expect(outcomes, hasLength(1));
          expect(indexerConnections, 1);
          verify(() => api.getFollowers(pubkey: owner, limit: 5000)).called(1);
          expect(dao.replacements, 1);
        },
      );

      test(
        'real capped EOSE merges and retries before claiming full completion',
        () async {
          relay.info = RelayInfo('', '', '', '', const [], '', '', maxLimit: 1);
          dao.rows[owner] = {stale: 50};
          await repository.syncMyFollowers();
          expect(outcomes.single.endedBy, QueryEnd.complete);
          expect(outcomes.single.possiblyCapped, isTrue);
          expect(dao.rows[owner], {stale: 50, followerEvent.pubkey: 100});
          expect(dao.replacements, 0);
          final checkpoint = await MyFollowersSyncState().read(owner);
          expect(checkpoint.full, isNull);
          expect(checkpoint.incremental, isNull);
          expect(checkpoint.attempt, now);
          await repository.syncMyFollowers();
          expect(outcomes, hasLength(1));
          now += 86401;
          await repository.syncMyFollowers();
          expect(outcomes, hasLength(2));
          expect(outcomes.last.possiblyCapped, isTrue);
          expect((await MyFollowersSyncState().read(owner)).full, isNull);
          expect(dao.rows[owner], {stale: 50, followerEvent.pubkey: 100});
          expect(dao.replacements, 0);

          // A later uncapped response can authoritatively remove the old row.
          relay.info = null;
          now += 86401;
          await repository.syncMyFollowers();
          expect(outcomes, hasLength(3));
          expect(outcomes.last.possiblyCapped, isFalse);
          expect(dao.rows[owner], {followerEvent.pubkey: 100});
          expect(dao.replacements, 1);
          expect((await MyFollowersSyncState().read(owner)).full, now);
        },
      );
    });

    for (final outcome in [
      QueryEnd.deadline,
      QueryEnd.settledEarly,
      QueryEnd.socketDropped,
      QueryEnd.relayClosed,
      QueryEnd.noRelay,
      QueryEnd.complete,
    ]) {
      test(
        // The complete case is capped: an uncapped complete read reconciles.
        'returned ${outcome == QueryEnd.complete ? 'capped ' : ''}$outcome '
        'relay outcome preserves known followers',
        () async {
          dao.rows[owner] = {stale: 50};
          final events = outcome == QueryEnd.noRelay
              ? <Event>[]
              : [contact(first, 100), contact(second, 200)];
          when(() => client.queryEvents(any())).thenAnswer((_) async => events);
          when(
            () => client.readEvents(any(), requireAllRelaysSettled: true),
          ).thenAnswer(
            (_) async => QueryResult(
              events: events,
              endedBy: outcome,
              possiblyCapped: outcome == QueryEnd.complete,
            ),
          );
          await repository.syncMyFollowers();
          expect(dao.rows[owner], {
            stale: 50,
            if (events.isNotEmpty) first: 100,
            if (events.isNotEmpty) second: 200,
          });
          expect(dao.replacements, 0);
          verify(
            () => client.readEvents(any(), requireAllRelaysSettled: true),
          ).called(1);
        },
      );
    }

    for (final operation in ['get', 'stream']) {
      test(
        '$operation retains stored followers for a partial relay read',
        () async {
          dao.rows[owner] = {stale: 50};
          final events = [contact(first, 100)];
          when(() => client.queryEvents(any())).thenAnswer((_) async => events);
          when(
            () => client.readEvents(any(), requireAllRelaysSettled: true),
          ).thenAnswer(
            (_) async => QueryResult(
              events: events,
              endedBy: QueryEnd.deadline,
            ),
          );
          if (operation == 'get') {
            expect(await repository.getMyFollowers(), [first]);
          } else {
            expect(await repository.streamMyFollowers().toList(), [
              [first],
            ]);
          }
          expect(dao.rows[owner], {stale: 50, first: 100});
          expect(dao.replacements, 0);
        },
      );
    }

    for (final hasMore in [true, false]) {
      test(
        'API page hasMore=$hasMore preserves followers beyond the page',
        () async {
          dao.rows[owner] = {stale: 50};
          when(() => api.isAvailable).thenReturn(true);
          when(() => api.getFollowers(pubkey: owner, limit: 5000)).thenAnswer(
            (_) async => PaginatedPubkeys(
              pubkeys: [first, second],
              hasMore: hasMore,
              total: hasMore ? 0 : 3,
            ),
          );
          await repository.syncMyFollowers();
          expect(dao.rows[owner], {stale: 50, first: null, second: null});
          expect(dao.replacements, 0);
          verify(() => api.getFollowers(pubkey: owner, limit: 5000)).called(1);
        },
      );
    }
  });
}
