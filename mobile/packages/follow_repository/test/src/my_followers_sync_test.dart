import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    }) => FollowRepository(
      nostrClient: client,
      indexerRelayUrls: indexers,
      funnelcakeApiClient: api,
      myFollowersDao: withDao ? dao : null,
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
        expect(filter.since, -600);
        expect(dao.rows[owner], {first: null, second: null});
      },
    );

    test(
      'failed incremental sync can retry without a stamped checkpoint',
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
    for (final outcome in [
      QueryEnd.deadline,
      QueryEnd.settledEarly,
      QueryEnd.socketDropped,
      QueryEnd.relayClosed,
      QueryEnd.noRelay,
      QueryEnd.complete,
    ]) {
      test(
        'returned $outcome relay outcome preserves known followers',
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
