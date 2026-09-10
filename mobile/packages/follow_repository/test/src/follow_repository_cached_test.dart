// ABOUTME: Tests for FollowRepository's CacheSync-backed watcher methods
// ABOUTME: Covers cache emission, live emission, count derivation, forceRefresh

import 'dart:async';
import 'dart:math';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    // Self-registered so the stub below works in every file that builds this
    // mock, whether or not that file has its own `setUpAll`. Idempotent.
    registerFallbackValue(Duration.zero);
    // The pre-broadcast read of our own kind 3 goes through
    // `queryEventsDetailed` so it can tell a relay's "I hold nothing" apart
    // from an answer nobody gave (#8265). Default to a *settled* empty answer
    // — the relay replied and holds nothing — which is the state every test
    // here was written in, and which still broadcasts. Tests about the
    // inconclusive read override this with `timedOut` or `noRelays`.
    when(
      () => queryEventsDetailed(
        any(),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (_) async => (
        events: <Event>[],
        timedOut: false,
        noRelays: false,
        anyRelayAnswered: false,
        unsettledRelays: const <String>[],
      ),
    );
  }
}

class _RecordingCacheDao extends FakeCacheDao {
  Duration? lastTtl;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    lastTtl = ttl;
    await super.write(key: key, payload: payload, ttl: ttl);
  }
}

/// Subclass that overrides the data-source methods wrapped by the cached
/// watchers, so tests can drive deterministic input without standing up a
/// full Nostr stack.
class _TestableFollowRepository extends FollowRepository {
  _TestableFollowRepository({
    required super.nostrClient,
    required this.myFollowingStream,
    required this.othersFollowersResult,
    required this.othersFollowingResult,
    this.myFollowersResult = const [],
    this.myFollowerCountResult = 0,
    this.othersFollowerCountResult = 0,
    Stream<FollowersSnapshot>? myFollowersStream,
  }) : _myFollowersStream = myFollowersStream,
       super(indexerRelayUrls: const []);

  final List<String> myFollowersResult;
  final int myFollowerCountResult;
  final int othersFollowerCountResult;
  // Injected only in regression tests that need to simulate the two-phase
  // emission pattern of the production watchMyFollowers() method.
  final Stream<FollowersSnapshot>? _myFollowersStream;
  final Stream<FollowingSnapshot> myFollowingStream;
  final List<String> othersFollowersResult;
  final FollowingSnapshot othersFollowingResult;

  int getFollowersCallCount = 0;
  int getMyFollowersCallCount = 0;
  int getOthersFollowingCallCount = 0;

  @override
  Future<List<String>> getMyFollowers() async {
    getMyFollowersCallCount++;
    return myFollowersResult;
  }

  @override
  Future<int> getMyFollowerCount() async => myFollowerCountResult;

  // The cached watchers fetch a whole snapshot rather than a pubkey list, so
  // the list overrides above are routed through here to keep feeding them.
  @override
  Future<FollowersSnapshot> fetchMyFollowersSnapshot() async {
    final pubkeys = await getMyFollowers();
    final countFromService = await getMyFollowerCount();
    return FollowersSnapshot(
      pubkeys: pubkeys,
      count: max(pubkeys.length, countFromService),
    );
  }

  @override
  Future<FollowersSnapshot> fetchFollowersSnapshot(String pubkey) async {
    final pubkeys = await getFollowers(pubkey);
    final countFromService = await getFollowerCount(pubkey);
    return FollowersSnapshot(
      pubkeys: pubkeys,
      count: max(pubkeys.length, countFromService),
    );
  }

  @override
  Stream<FollowersSnapshot> watchMyFollowers() {
    // When a custom stream is injected (regression tests), use it; otherwise
    // fall back to a single-value stream derived from myFollowersResult.
    return _myFollowersStream ??
        Stream.value(
          FollowersSnapshot(
            pubkeys: myFollowersResult,
            count: myFollowerCountResult,
          ),
        );
  }

  @override
  Stream<FollowingSnapshot> watchMyFollowing() => myFollowingStream;

  @override
  Future<List<String>> getFollowers(String pubkey) async {
    getFollowersCallCount++;
    return othersFollowersResult;
  }

  @override
  Future<int> getFollowerCount(String pubkey) async =>
      othersFollowerCountResult;

  @override
  Future<FollowingSnapshot> getOthersFollowing(String pubkey) async {
    getOthersFollowingCallCount++;
    return othersFollowingResult;
  }
}

void main() {
  late _RecordingCacheDao dao;
  late _MockNostrClient mockNostrClient;

  setUp(() async {
    dao = _RecordingCacheDao();
    await CacheSync.init(dao: dao);
    mockNostrClient = _MockNostrClient();
    when(() => mockNostrClient.publicKey).thenReturn('current-user');
  });

  group('FollowRepository.watchMyFollowersCached', () {
    test('writes the cache with the profile-list TTL', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['a'],
        myFollowerCountResult: 1,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      await repo.watchMyFollowersCached().drain<void>();

      expect(dao.lastTtl, const Duration(seconds: 30));
    });

    test('emits live result when cache is empty', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['a', 'b'],
        myFollowerCountResult: 2,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo.watchMyFollowersCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['a', 'b']);
      expect(events[0].data.count, 2);
    });

    test('emits cached then live when cache is populated', () async {
      await dao.write(
        key: 'current-user:my_followers',
        payload: const FollowersSnapshot(
          pubkeys: ['cached'],
          count: 1,
        ).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['live'],
        myFollowerCountResult: 1,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo.watchMyFollowersCached().take(2).toList();

      expect(events, hasLength(2));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['cached']);
      expect(events[1].isLive, isTrue);
      expect(events[1].data.pubkeys, ['live']);
    });

    test('uses current-user scoped cache key', () async {
      await dao.write(
        key: 'alice:my_followers',
        payload: const FollowersSnapshot(
          pubkeys: ['alice_cached'],
          count: 1,
        ).toJson(),
      );
      when(() => mockNostrClient.publicKey).thenReturn('bob');

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowersResult: const ['bob_live'],
        myFollowerCountResult: 1,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo.watchMyFollowersCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['bob_live']);
    });

    test(
      'regression – disk cache and in-memory followers cache both populated: '
      'emits exactly [cached, live] with network data, not the in-memory '
      'snapshot',
      () async {
        await dao.write(
          key: 'current-user:my_followers',
          payload: const FollowersSnapshot(
            pubkeys: ['disk'],
            count: 1,
          ).toJson(),
        );

        // _myFollowersStream emits two values, replicating the two-phase
        // emission pattern that watchMyFollowers() uses when
        // _hasMyFollowersCache is true: first the in-memory snapshot, then
        // the live network data.
        //
        // Regression: the old CacheSync.watchStream-based implementation
        // tagged the first (in-memory) emission as CacheResult.live, so
        // take(2) returned [cached(disk), live(in_memory)] and
        // events[1].data.pubkeys equalled ['in_memory'] instead of
        // ['network']. This test would have failed against the old code.
        //
        // With the fix (CacheSync.watchOne), watchMyFollowers() is not called
        // at all; getMyFollowers()/getMyFollowerCount() drive the single live
        // fetch and produce exactly [cached(disk), live(network)].
        final repo = _TestableFollowRepository(
          nostrClient: mockNostrClient,
          myFollowersResult: const ['network'],
          myFollowerCountResult: 1,
          myFollowersStream: Stream.fromIterable([
            const FollowersSnapshot(pubkeys: ['in_memory'], count: 1),
            const FollowersSnapshot(pubkeys: ['network'], count: 1),
          ]),
          myFollowingStream: const Stream.empty(),
          othersFollowersResult: const [],
          othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
        );

        final events = await repo.watchMyFollowersCached().take(2).toList();

        expect(events, hasLength(2));
        expect(events[0].isLive, isFalse);
        expect(events[0].data.pubkeys, ['disk']);
        expect(events[1].isLive, isTrue);
        // Must be ['network'] from getMyFollowers(), NOT ['in_memory'] from
        // the watchMyFollowers() in-memory cache phase.
        expect(events[1].data.pubkeys, ['network']);
        expect(repo.getMyFollowersCallCount, 1);
      },
    );
  });

  group('FollowRepository.watchMyFollowingCached', () {
    test('writes the cache with the profile-list TTL', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['network'],
          count: 1,
        ),
      );

      await repo.watchMyFollowingCached().drain<void>();

      expect(dao.lastTtl, const Duration(seconds: 30));
    });

    test('emits live result from a fresh getOthersFollowing fetch, '
        'NOT from the watchMyFollowing BehaviorSubject replay', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        // BehaviorSubject replay value — must be IGNORED by the new
        // watchOne-based implementation so CacheSync alone owns
        // stale/live semantics.
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['in_memory_replay'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['network'],
          count: 1,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['network']);
      expect(repo.getOthersFollowingCallCount, 1);
    });

    test('emits cached (stale) then live (fresh) — proves CacheSync owns '
        'the single stale/live boundary', () async {
      await dao.write(
        key: 'bob:my_following',
        payload: const FollowingSnapshot(pubkeys: ['disk'], count: 1).toJson(),
      );
      when(() => mockNostrClient.publicKey).thenReturn('bob');

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        // In-memory replay should NEVER be mis-tagged as live by the
        // wrapper. This is the regression check for the reviewer's
        // "double cache layer" concern.
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['in_memory_replay'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['network'],
          count: 1,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(2).toList();

      expect(events, hasLength(2));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['disk']);
      expect(events[1].isLive, isTrue);
      // Must be ['network'] from getOthersFollowing(), NOT
      // ['in_memory_replay'] from the BehaviorSubject.
      expect(events[1].data.pubkeys, ['network']);
      expect(repo.getOthersFollowingCallCount, 1);
    });

    test('uses current-user scoped cache key', () async {
      await dao.write(
        key: 'alice:my_following',
        payload: const FollowingSnapshot(
          pubkeys: ['alice_cached'],
          count: 1,
        ).toJson(),
      );
      when(() => mockNostrClient.publicKey).thenReturn('bob');

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: Stream.value(
          const FollowingSnapshot(pubkeys: ['bob_in_memory'], count: 1),
        ),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['bob_live'],
          count: 1,
        ),
      );

      final events = await repo.watchMyFollowingCached().take(1).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      // Bob's own pubkey was used to query — not Alice's cached entry.
      expect(events[0].data.pubkeys, ['bob_live']);
    });
  });

  group('FollowRepository.watchOthersFollowersCached', () {
    test('uses max of follower list length and authoritative count', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['p1', 'p2', 'p3'],
        othersFollowerCountResult: 10,
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].data.pubkeys, ['p1', 'p2', 'p3']);
      expect(events[0].data.count, 10);
    });

    test('expired cached entry refetches live data', () async {
      await dao.write(
        key: 'target:others_followers',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
        ttl: const Duration(microseconds: 1),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['fresh']);
    });

    test('uses cacheFirst policy for fresh cached profile lists', () async {
      await dao.write(
        key: 'target:others_followers',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
        ttl: const Duration(hours: 1),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowerCountResult: 5,
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['stale']);
      expect(repo.getFollowersCallCount, 0);
    });

    test('forceRefresh skips cached emission', () async {
      await dao.write(
        key: 'target:others_followers',
        payload: const FollowersSnapshot(pubkeys: ['stale'], count: 1).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['fresh'],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      final events = await repo
          .watchOthersFollowersCached('target', forceRefresh: true)
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['fresh']);
    });

    test('uses pubkey-scoped cache key', () async {
      await dao.write(
        key: 'alice:others_followers',
        payload: const FollowersSnapshot(
          pubkeys: ['alice_cached'],
          count: 1,
        ).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const ['bob_live'],
        othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
      );

      // Querying 'bob' must NOT see 'alice's cache.
      final events = await repo
          .watchOthersFollowersCached('bob')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['bob_live']);
    });
  });

  group('FollowRepository.watchOthersFollowingCached', () {
    test('emits live FollowingSnapshot from getOthersFollowing', () async {
      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['f1', 'f2'],
          count: 2,
        ),
      );

      final events = await repo
          .watchOthersFollowingCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['f1', 'f2']);
      expect(events[0].data.count, 2);
    });

    test('uses cacheFirst policy for fresh cached following lists', () async {
      await dao.write(
        key: 'target:others_following',
        payload: const FollowingSnapshot(pubkeys: ['stale'], count: 1).toJson(),
        ttl: const Duration(hours: 1),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['fresh'],
          count: 1,
        ),
      );

      final events = await repo
          .watchOthersFollowingCached('target')
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isFalse);
      expect(events[0].data.pubkeys, ['stale']);
      expect(repo.getOthersFollowingCallCount, 0);
    });

    test('forceRefresh skips cached emission', () async {
      await dao.write(
        key: 'target:others_following',
        payload: const FollowingSnapshot(pubkeys: ['stale'], count: 1).toJson(),
      );

      final repo = _TestableFollowRepository(
        nostrClient: mockNostrClient,
        myFollowingStream: const Stream.empty(),
        othersFollowersResult: const [],
        othersFollowingResult: const FollowingSnapshot(
          pubkeys: ['fresh'],
          count: 1,
        ),
      );

      final events = await repo
          .watchOthersFollowingCached('target', forceRefresh: true)
          .take(1)
          .toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data.pubkeys, ['fresh']);
    });
  });

  group('cache key shape guardrail (#4382 re-orphan prevention)', () {
    // follow_repository was the sole cache_sync key-writer that ever used the
    // orphan-prone legacy `operation_${pubkey}` underscore shape (between #4251
    // and #4361, before RFC #4244's `${pubkey}:operation` colon shape landed).
    // Those keys did not start with the pubkey, so invalidatePrefix(pubkey)
    // never reached them, and with no TTL they were never re-read. These tests
    // fail loudly if any key builder ever re-emits one of those legacy
    // prefixes, which would silently re-introduce that orphan-prone shape.
    //
    // All four current builders are covered — my_followers_, my_following_,
    // others_followers_, others_following_ — so the guard has no 2-of-4 blind
    // spot.
    void expectNoLegacyPrefixedKey() {
      const legacyPrefixes = [
        'my_followers_',
        'my_following_',
        'others_followers_',
        'others_following_',
      ];
      expect(
        dao.keys.every(
          (k) => legacyPrefixes.every((prefix) => !k.startsWith(prefix)),
        ),
        isTrue,
        reason:
            'follow_repository cache keys must use the RFC #4244 '
            'pubkey-prefixed "pubkey:operation" shape, never the legacy '
            '"operation_pubkey" shape (#4382).',
      );
    }

    test(
      'watchMyFollowersCached writes a colon-scoped key, not legacy',
      () async {
        final repo = _TestableFollowRepository(
          nostrClient: mockNostrClient,
          myFollowersResult: const ['a'],
          myFollowerCountResult: 1,
          myFollowingStream: const Stream.empty(),
          othersFollowersResult: const [],
          othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
        );

        await repo.watchMyFollowersCached().take(1).toList();

        expect(dao.rawRead('current-user:my_followers'), isNotNull);
        expect(dao.keys, isNotEmpty);
        expectNoLegacyPrefixedKey();
      },
    );

    test(
      'watchMyFollowingCached writes a colon-scoped key, not legacy',
      () async {
        final repo = _TestableFollowRepository(
          nostrClient: mockNostrClient,
          myFollowingStream: const Stream.empty(),
          othersFollowersResult: const [],
          othersFollowingResult: const FollowingSnapshot(
            pubkeys: ['a'],
            count: 1,
          ),
        );

        await repo.watchMyFollowingCached().take(1).toList();

        expect(dao.rawRead('current-user:my_following'), isNotNull);
        expect(dao.keys, isNotEmpty);
        expectNoLegacyPrefixedKey();
      },
    );

    test(
      'watchOthersFollowersCached writes a colon-scoped key, not legacy',
      () async {
        final repo = _TestableFollowRepository(
          nostrClient: mockNostrClient,
          myFollowingStream: const Stream.empty(),
          othersFollowersResult: const ['a'],
          othersFollowerCountResult: 1,
          othersFollowingResult: const FollowingSnapshot(pubkeys: [], count: 0),
        );

        await repo.watchOthersFollowersCached('target').take(1).toList();

        expect(dao.rawRead('target:others_followers'), isNotNull);
        expect(dao.keys, isNotEmpty);
        expectNoLegacyPrefixedKey();
      },
    );

    test(
      'watchOthersFollowingCached writes a colon-scoped key, not legacy',
      () async {
        final repo = _TestableFollowRepository(
          nostrClient: mockNostrClient,
          myFollowingStream: const Stream.empty(),
          othersFollowersResult: const [],
          othersFollowingResult: const FollowingSnapshot(
            pubkeys: ['a'],
            count: 1,
          ),
        );

        await repo.watchOthersFollowingCached('target').take(1).toList();

        expect(dao.rawRead('target:others_following'), isNotNull);
        expect(dao.keys, isNotEmpty);
        expectNoLegacyPrefixedKey();
      },
    );
  });
}
