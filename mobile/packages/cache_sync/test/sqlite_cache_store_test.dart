import 'package:cache_sync/cache_sync.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  group(SqliteCacheStore, () {
    test(
      'account invalidation preserves another account in real SQLite',
      () async {
        const alice =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const bob =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final store = SqliteCacheStore(NativeDatabase.memory());
        addTearDown(store.close);
        await CacheSync.init(dao: store.dao);

        await CacheSync.write(
          key: '$alice:home_feed',
          value: 'Alice feed',
          toJson: (value) => value,
        );
        await CacheSync.write(
          key: '$alice:video_lists',
          value: 'Alice lists',
          toJson: (value) => value,
        );
        await CacheSync.write(
          key: '$bob:home_feed',
          value: 'Bob feed',
          toJson: (value) => value,
        );

        await CacheSync.invalidatePrefix(alice);

        expect(await store.dao.read('$alice:home_feed'), isNull);
        expect(await store.dao.read('$alice:video_lists'), isNull);
        expect(
          await CacheSync.read<String>(
            key: '$bob:home_feed',
            fromJson: (payload) => payload,
          ),
          'Bob feed',
        );
      },
    );

    test(
      'awaited close releases SQLite and a fresh scope has no old data',
      () async {
        final nativeDatabase = sqlite3.openInMemory();
        final first = SqliteCacheStore(NativeDatabase.opened(nativeDatabase));
        addTearDown(first.close);
        await CacheSync.init(dao: first.dao);
        await CacheSync.write(
          key: 'scope:list',
          value: 'previous scope',
          toJson: (value) => value,
        );
        expect(await first.dao.read('scope:list'), 'previous scope');

        await first.close();

        expect(
          () => nativeDatabase.select('SELECT 1'),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          first.dao.read('scope:list'),
          throwsA(isA<StateError>()),
        );

        final second = SqliteCacheStore(NativeDatabase.memory());
        addTearDown(second.close);
        await CacheSync.init(dao: second.dao);
        expect(
          await CacheSync.read<String>(
            key: 'scope:list',
            fromJson: (payload) => payload,
          ),
          isNull,
        );
        await CacheSync.write(
          key: 'scope:list',
          value: 'fresh scope',
          toJson: (value) => value,
        );
        expect(await second.dao.read('scope:list'), 'fresh scope');
      },
    );

    test('custom payload budget applies to an injected SQLite DAO', () async {
      final store = SqliteCacheStore(
        NativeDatabase.memory(),
        maxSizeBytes: 8,
      );
      addTearDown(store.close);
      await CacheSync.init(dao: store.dao);

      await CacheSync.write(
        key: 'oversized',
        value: '123456789',
        toJson: (value) => value,
      );
      expect(await store.dao.read('oversized'), isNull);
      expect(await store.dao.totalPayloadBytes(), 0);

      await CacheSync.write(
        key: 'within-budget',
        value: '12345678',
        toJson: (value) => value,
      );
      expect(await store.dao.read('within-budget'), '12345678');
      expect(await store.dao.totalPayloadBytes(), 8);
    });

    test('null payload budget keeps an otherwise oversized payload', () async {
      final store = SqliteCacheStore(
        NativeDatabase.memory(),
        maxSizeBytes: null,
      );
      addTearDown(store.close);
      await CacheSync.init(dao: store.dao);

      await CacheSync.write(
        key: 'unbounded',
        value: '123456789',
        toJson: (value) => value,
      );

      expect(await store.dao.read('unbounded'), '123456789');
      expect(await store.dao.totalPayloadBytes(), 9);
    });
  });
}
