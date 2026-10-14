import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

void main() {
  late FakeCacheDao dao;
  late DateTime clock;

  Future<void> writeStale(String key, String payload) async {
    await dao.write(key: key, payload: payload, ttl: const Duration(hours: 1));
    clock = clock.add(const Duration(hours: 2));
  }

  setUp(() async {
    clock = DateTime.utc(2026, 10, 14);
    dao = FakeCacheDao(now: () => clock);
    await CacheSync.init(dao: dao);
  });

  group('CacheSync.watchOne', () {
    test('emits only live result when cache is empty', () async {
      final events = await CacheSync.watchOne<int>(
        key: 'test:int',
        fetch: () async => 42,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(42));
    });

    test('emits cached then live when cache is populated', () async {
      await dao.write(key: 'test:int', payload: '10');

      final events = await CacheSync.watchOne<int>(
        key: 'test:int',
        fetch: () async => 42,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, hasLength(2));
      expect(events[0], equals(const CacheResult.cached(10)));
      expect(events[1], equals(const CacheResult.live(42)));
    });

    // Overlay/isRefreshing contract: a live result MUST be emitted even when
    // the fetched value is identical to the cached value. Any consumer that
    // maps isStale → isRefreshing relies on this to dismiss loading overlays.
    test(
      'emits both cached and live when live data equals cached data',
      () async {
        await dao.write(key: 'same:key', payload: '42');

        final events = await CacheSync.watchOne<int>(
          key: 'same:key',
          fetch: () async => 42,
          fromJson: int.parse,
          toJson: (v) => r'$v',
        ).toList();

        expect(events, hasLength(2));
        expect(events[0], equals(const CacheResult.cached(42)));
        expect(events[1], equals(const CacheResult.live(42)));
      },
    );

    test('writes live result to cache', () async {
      await CacheSync.watchOne<int>(
        key: 'store:key',
        fetch: () async => 7,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).drain<void>();

      expect(dao.rawRead('store:key'), equals('7'));
    });

    test('does not write when toJson returns empty string', () async {
      await CacheSync.watchOne<int>(
        key: 'skip:key',
        fetch: () async => 99,
        fromJson: int.parse,
        toJson: (_) => '',
      ).drain<void>();

      expect(dao.rawRead('skip:key'), isNull);
    });

    test('forwards fetch errors as stream errors', () async {
      final stream = CacheSync.watchOne<int>(
        key: 'err:key',
        fetch: () async => throw StateError('boom'),
        fromJson: int.parse,
        toJson: (v) => '$v',
      );

      await expectLater(stream, emitsError(isA<StateError>()));
    });

    // UX contract: when a refresh fails the caller already received stale data
    // and should keep showing it. The cache entry must survive the error so the
    // next caller can serve the stale value again rather than a blank screen.
    test('emits stale cached value then error when cache has data '
        'and fetch fails — stale entry survives', () async {
      await dao.write(key: 'stale:err', payload: '99');

      final stream = CacheSync.watchOne<int>(
        key: 'stale:err',
        fetch: () async => throw StateError('network down'),
        fromJson: int.parse,
        toJson: (v) => '$v',
      );

      await expectLater(
        stream,
        emitsInOrder([
          isA<CacheResult<int>>()
              .having((r) => r.isStale, 'isStale', isTrue)
              .having((r) => r.data, 'data', equals(99)),
          emitsError(isA<StateError>()),
        ]),
      );

      // Cache entry must NOT be wiped after a failed refresh.
      expect(dao.rawRead('stale:err'), equals('99'));
    });

    test('cacheOnly policy never calls fetch', () async {
      await dao.write(key: 'only:key', payload: '5');
      var fetchCalled = false;

      final events = await CacheSync.watchOne<int>(
        key: 'only:key',
        fetch: () async {
          fetchCalled = true;
          return 999;
        },
        fromJson: int.parse,
        toJson: (v) => '$v',
        policy: CacheFetchPolicy.cacheOnly,
      ).toList();

      expect(fetchCalled, isFalse);
      expect(events, hasLength(1));
      expect(events[0].data, equals(5));
    });

    test('networkOnly policy ignores cache and does not emit cached', () async {
      await dao.write(key: 'net:key', payload: '1');

      final events = await CacheSync.watchOne<int>(
        key: 'net:key',
        fetch: () async => 2,
        fromJson: int.parse,
        toJson: (v) => '$v',
        policy: CacheFetchPolicy.networkOnly,
      ).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(2));
    });

    test(
      'cacheFirst policy returns cached value without calling fetch',
      () async {
        await dao.write(key: 'first:key', payload: '7');
        var fetchCalled = false;

        final events = await CacheSync.watchOne<int>(
          key: 'first:key',
          fetch: () async {
            fetchCalled = true;
            return 8;
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(fetchCalled, isFalse);
        expect(events, hasLength(1));
        expect(events[0].isLive, isFalse);
        expect(events[0].data, equals(7));
      },
    );

    test('ignores corrupted cache entry and fetches fresh', () async {
      await dao.write(key: 'bad:key', payload: 'NOT_A_NUMBER');

      final events = await CacheSync.watchOne<int>(
        key: 'bad:key',
        fetch: () async => 3,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(3));
    });

    test('fetches live data when cache read fails', () async {
      await CacheSync.init(dao: ThrowingCacheDao(throwOnRead: true));

      final events = await CacheSync.watchOne<int>(
        key: 'read:fails',
        fetch: () async => 4,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, equals([const CacheResult.live(4)]));
    });

    test('fetches live data when corrupted cache delete fails', () async {
      await CacheSync.init(
        dao: ThrowingCacheDao(readPayload: 'bad', throwOnDelete: true),
      );

      final events = await CacheSync.watchOne<int>(
        key: 'delete:fails',
        fetch: () async => 5,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, equals([const CacheResult.live(5)]));
    });

    test('emits live data when cache write fails', () async {
      await CacheSync.init(dao: ThrowingCacheDao(throwOnWrite: true));

      final events = await CacheSync.watchOne<int>(
        key: 'write:fails',
        fetch: () async => 6,
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, equals([const CacheResult.live(6)]));
    });

    test('respects TTL option — writes entry with expiry', () async {
      await CacheSync.watchOne<int>(
        key: 'ttl:key',
        fetch: () async => 5,
        fromJson: int.parse,
        toJson: (v) => '$v',
        ttl: const Duration(hours: 1),
      ).drain<void>();

      expect(dao.rawRead('ttl:key'), equals('5'));
    });

    group('stale entries', () {
      test('cacheFirst emits a stale value then the live value', () async {
        await writeStale('stale:first', '10');
        var fetchCalls = 0;

        final events = await CacheSync.watchOne<int>(
          key: 'stale:first',
          fetch: () async {
            fetchCalls++;
            return 42;
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          ttl: const Duration(hours: 1),
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(
          events,
          equals([const CacheResult.cached(10), const CacheResult.live(42)]),
        );
        expect(fetchCalls, equals(1));
      });

      test('cacheFirst fetches when nothing is cached', () async {
        final events = await CacheSync.watchOne<int>(
          key: 'missing:first',
          fetch: () async => 42,
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(events, equals([const CacheResult.live(42)]));
      });

      test('cacheFirst ends on a fresh value without fetching', () async {
        await dao.write(
          key: 'fresh:first',
          payload: '10',
          ttl: const Duration(hours: 1),
        );
        var fetchCalls = 0;

        final events = await CacheSync.watchOne<int>(
          key: 'fresh:first',
          fetch: () async {
            fetchCalls++;
            return 42;
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(events, equals([const CacheResult.cached(10)]));
        expect(fetchCalls, equals(0));
      });

      test('cacheAndNetwork serves an expired value before fetching', () async {
        await writeStale('stale:both', '10');

        final events = await CacheSync.watchOne<int>(
          key: 'stale:both',
          fetch: () async => 42,
          fromJson: int.parse,
          toJson: (v) => '$v',
        ).toList();

        expect(
          events,
          equals([const CacheResult.cached(10), const CacheResult.live(42)]),
        );
      });

      test('cacheOnly emits an expired value without fetching', () async {
        await writeStale('stale:only', '10');
        var fetchCalls = 0;

        final events = await CacheSync.watchOne<int>(
          key: 'stale:only',
          fetch: () async {
            fetchCalls++;
            return 42;
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheOnly,
        ).toList();

        expect(events, equals([const CacheResult.cached(10)]));
        expect(fetchCalls, equals(0));
        expect(dao.rawRead('stale:only'), equals('10'));
      });

      test('keeps the stale row when the refresh fails', () async {
        await writeStale('stale:err', '10');

        final stream = CacheSync.watchOne<int>(
          key: 'stale:err',
          fetch: () async => throw StateError('offline'),
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        );

        await expectLater(
          stream,
          emitsInOrder([
            const CacheResult.cached(10),
            emitsError(isA<StateError>()),
          ]),
        );
        expect(dao.rawRead('stale:err'), equals('10'));
      });
    });
  });
}
