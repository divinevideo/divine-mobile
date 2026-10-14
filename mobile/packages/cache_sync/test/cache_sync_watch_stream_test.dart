import 'dart:async';

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

  group('CacheSync.watchStream', () {
    test('emits only live results when cache is empty', () async {
      final events = await CacheSync.watchStream<int>(
        key: 'ws:empty',
        source: () => Stream.fromIterable([1, 2, 3]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, hasLength(3));
      expect(events.map((e) => e.data), equals([1, 2, 3]));
      expect(events.every((e) => e.isLive), isTrue);
    });

    test('emits cached first then live events', () async {
      await dao.write(key: 'ws:hit', payload: '0');

      final events = await CacheSync.watchStream<int>(
        key: 'ws:hit',
        source: () => Stream.fromIterable([10, 20]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events[0], equals(const CacheResult.cached(0)));
      expect(events.skip(1).map((e) => e.data), equals([10, 20]));
    });

    // Overlay/isRefreshing contract: a live result MUST be emitted even when
    // the source emits a value identical to the cached value. Any consumer
    // that maps isStale → isRefreshing relies on this to dismiss overlays.
    test(
      'emits both cached and live when live data equals cached data',
      () async {
        await dao.write(key: 'ws:same', payload: '7');

        final events = await CacheSync.watchStream<int>(
          key: 'ws:same',
          source: () => Stream.value(7),
          fromJson: int.parse,
          toJson: (v) => r'$v',
        ).toList();

        expect(events, hasLength(2));
        expect(events[0], equals(const CacheResult.cached(7)));
        expect(events[1], equals(const CacheResult.live(7)));
      },
    );

    test('writes last live value to cache', () async {
      await CacheSync.watchStream<int>(
        key: 'ws:write',
        source: () => Stream.fromIterable([7, 8, 9]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).drain<void>();

      expect(dao.rawRead('ws:write'), equals('9'));
    });

    test('does not write when toJson returns empty string', () async {
      await CacheSync.watchStream<int>(
        key: 'ws:skip',
        source: () => Stream.fromIterable([1]),
        fromJson: int.parse,
        toJson: (_) => '',
      ).drain<void>();

      expect(dao.rawRead('ws:skip'), isNull);
    });

    test('forwards source errors as stream errors', () async {
      final stream = CacheSync.watchStream<int>(
        key: 'ws:err',
        source: () => Stream<int>.error(StateError('bad')),
        fromJson: int.parse,
        toJson: (v) => '$v',
      );

      await expectLater(stream, emitsError(isA<StateError>()));
    });

    // UX contract: when the source fails the caller already received stale data
    // and should keep showing it. The cache entry must survive the error so the
    // next caller can serve the stale value again rather than a blank screen.
    test('emits stale cached value then error when cache has data '
        'and source fails — stale entry survives', () async {
      await dao.write(key: 'ws:stale:err', payload: '77');

      final stream = CacheSync.watchStream<int>(
        key: 'ws:stale:err',
        source: () => Stream<int>.error(StateError('relay disconnected')),
        fromJson: int.parse,
        toJson: (v) => '$v',
      );

      await expectLater(
        stream,
        emitsInOrder([
          isA<CacheResult<int>>()
              .having((r) => r.isStale, 'isStale', isTrue)
              .having((r) => r.data, 'data', equals(77)),
          emitsError(isA<StateError>()),
        ]),
      );

      // Cache entry must NOT be wiped after a failed source — no data loss.
      expect(dao.rawRead('ws:stale:err'), equals('77'));
    });

    test('cacheOnly policy never subscribes to source', () async {
      await dao.write(key: 'ws:only', payload: '5');
      var subscribed = false;

      final events = await CacheSync.watchStream<int>(
        key: 'ws:only',
        source: () {
          subscribed = true;
          return Stream.fromIterable([999]);
        },
        fromJson: int.parse,
        toJson: (v) => '$v',
        policy: CacheFetchPolicy.cacheOnly,
      ).toList();

      expect(subscribed, isFalse);
      expect(events, hasLength(1));
      expect(events[0].data, equals(5));
    });

    test('networkOnly policy ignores cache', () async {
      await dao.write(key: 'ws:net', payload: '1');

      final events = await CacheSync.watchStream<int>(
        key: 'ws:net',
        source: () => Stream.fromIterable([2]),
        fromJson: int.parse,
        toJson: (v) => '$v',
        policy: CacheFetchPolicy.networkOnly,
      ).toList();

      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(2));
    });

    test(
      'cacheFirst policy returns cached value without subscribing',
      () async {
        await dao.write(key: 'ws:first', payload: '7');
        var subscribed = false;

        final events = await CacheSync.watchStream<int>(
          key: 'ws:first',
          source: () {
            subscribed = true;
            return Stream.fromIterable([8]);
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(subscribed, isFalse);
        expect(events, hasLength(1));
        expect(events[0].isLive, isFalse);
        expect(events[0].data, equals(7));
      },
    );

    test('deletes corrupted cache entry and serves live events', () async {
      await dao.write(key: 'ws:corrupt', payload: 'NOT_AN_INT');

      final events = await CacheSync.watchStream<int>(
        key: 'ws:corrupt',
        source: () => Stream.fromIterable([42]),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      // Corrupted cache is skipped; only live value is served.
      expect(events, hasLength(1));
      expect(events[0].isLive, isTrue);
      expect(events[0].data, equals(42));
      // Corrupted entry was deleted and replaced with the live value.
      expect(dao.rawRead('ws:corrupt'), equals('42'));
    });

    test('serves live events when cache read fails', () async {
      await CacheSync.init(dao: ThrowingCacheDao(throwOnRead: true));

      final events = await CacheSync.watchStream<int>(
        key: 'ws:read:fails',
        source: () => Stream.value(4),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, equals([const CacheResult.live(4)]));
    });

    test('serves live events when corrupted cache delete fails', () async {
      await CacheSync.init(
        dao: ThrowingCacheDao(readPayload: 'bad', throwOnDelete: true),
      );

      final events = await CacheSync.watchStream<int>(
        key: 'ws:delete:fails',
        source: () => Stream.value(5),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, equals([const CacheResult.live(5)]));
    });

    test('emits live events when cache write fails', () async {
      await CacheSync.init(dao: ThrowingCacheDao(throwOnWrite: true));

      final events = await CacheSync.watchStream<int>(
        key: 'ws:write:fails',
        source: () => Stream.value(6),
        fromJson: int.parse,
        toJson: (v) => '$v',
      ).toList();

      expect(events, equals([const CacheResult.live(6)]));
    });

    test(
      'cancelling outer subscription cancels source stream immediately',
      () async {
        final sourceCanceled = Completer<void>();
        final source = StreamController<int>(
          onCancel: () {
            if (!sourceCanceled.isCompleted) {
              sourceCanceled.complete();
            }
          },
        );

        final subscription = CacheSync.watchStream<int>(
          key: 'ws:cancel',
          source: () => source.stream,
          fromJson: int.parse,
          toJson: (v) => '$v',
        ).listen((_) {});

        source.add(1);
        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        await expectLater(sourceCanceled.future, completes);

        source.add(2);
        await Future<void>.delayed(Duration.zero);

        expect(dao.rawRead('ws:cancel'), equals('1'));
        await source.close();
      },
    );

    group('stale entries', () {
      test('cacheFirst emits a stale value then the live values', () async {
        await writeStale('ws:stale:first', '10');
        var subscriptions = 0;

        final events = await CacheSync.watchStream<int>(
          key: 'ws:stale:first',
          source: () {
            subscriptions++;
            return Stream.fromIterable([42]);
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
        expect(subscriptions, equals(1));
      });

      test('cacheFirst subscribes when nothing is cached', () async {
        final events = await CacheSync.watchStream<int>(
          key: 'ws:missing:first',
          source: () => Stream.fromIterable([42]),
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(events, equals([const CacheResult.live(42)]));
      });

      test('cacheFirst ends on a fresh value without subscribing', () async {
        await dao.write(
          key: 'ws:fresh:first',
          payload: '10',
          ttl: const Duration(hours: 1),
        );
        var subscriptions = 0;

        final events = await CacheSync.watchStream<int>(
          key: 'ws:fresh:first',
          source: () {
            subscriptions++;
            return Stream.fromIterable([42]);
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheFirst,
        ).toList();

        expect(events, equals([const CacheResult.cached(10)]));
        expect(subscriptions, equals(0));
      });

      test(
        'cacheAndNetwork serves an expired value before the source',
        () async {
          await writeStale('ws:stale:both', '10');

          final events = await CacheSync.watchStream<int>(
            key: 'ws:stale:both',
            source: () => Stream.fromIterable([42]),
            fromJson: int.parse,
            toJson: (v) => '$v',
          ).toList();

          expect(
            events,
            equals([const CacheResult.cached(10), const CacheResult.live(42)]),
          );
        },
      );

      test('cacheOnly emits an expired value without subscribing', () async {
        await writeStale('ws:stale:only', '10');
        var subscriptions = 0;

        final events = await CacheSync.watchStream<int>(
          key: 'ws:stale:only',
          source: () {
            subscriptions++;
            return Stream.fromIterable([42]);
          },
          fromJson: int.parse,
          toJson: (v) => '$v',
          policy: CacheFetchPolicy.cacheOnly,
        ).toList();

        expect(events, equals([const CacheResult.cached(10)]));
        expect(subscriptions, equals(0));
        expect(dao.rawRead('ws:stale:only'), equals('10'));
      });
    });
  });
}
