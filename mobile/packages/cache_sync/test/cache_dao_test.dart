import 'package:cache_sync/src/cache_dao_impl.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:cache_sync/src/cache_entry.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(CacheDaoImpl, () {
    late CacheDatabase db;
    late CacheDaoImpl dao;
    late DateTime clock;

    setUp(() {
      clock = DateTime.utc(2026, 10, 14);
      db = CacheDatabase.test(NativeDatabase.memory());
      dao = CacheDaoImpl(db, now: () => clock);
    });

    tearDown(() => db.close());

    group('write / read', () {
      test('returns null for absent key', () async {
        expect(await dao.readEntry('missing'), isNull);
      });

      test('returns payload for a written entry', () async {
        await dao.write(key: 'k1', payload: '{"x":1}');
        expect((await dao.readEntry('k1'))?.payload, equals('{"x":1}'));
      });

      test('overwrites existing entry', () async {
        await dao.write(key: 'k1', payload: 'first');
        await dao.write(key: 'k1', payload: 'second');
        expect((await dao.readEntry('k1'))?.payload, equals('second'));
      });
    });

    group('TTL staleness', () {
      test('readEntry returns an expired row as stale and keeps it', () async {
        await dao.write(
          key: 'expired',
          payload: 'old',
          ttl: const Duration(seconds: 1),
        );
        clock = clock.add(const Duration(seconds: 2));

        final entry = await dao.readEntry('expired');

        expect(entry, isNotNull);
        expect(entry!.isStale, isTrue);
        expect(entry.payload, equals('old'));
        expect(await dao.readEntry('expired'), isNotNull);
        expect(await dao.totalPayloadBytes(), equals(3));
      });

      test('readEntry returns a fresh row when TTL has not elapsed', () async {
        await dao.write(
          key: 'fresh',
          payload: 'data',
          ttl: const Duration(hours: 1),
        );
        clock = clock.add(const Duration(minutes: 59));

        final entry = await dao.readEntry('fresh');

        expect(
          entry,
          equals(const CacheEntry(payload: 'data', isStale: false)),
        );
      });

      test('entry without TTL is never stale', () async {
        await dao.write(key: 'immortal', payload: 'forever');
        clock = clock.add(const Duration(days: 3650));

        final entry = await dao.readEntry('immortal');

        expect(
          entry,
          equals(const CacheEntry(payload: 'forever', isStale: false)),
        );
      });

      test('rewriting a stale row makes it fresh again', () async {
        await dao.write(
          key: 'k',
          payload: 'old',
          ttl: const Duration(hours: 1),
        );
        clock = clock.add(const Duration(hours: 2));
        expect((await dao.readEntry('k'))!.isStale, isTrue);

        await dao.write(
          key: 'k',
          payload: 'new',
          ttl: const Duration(hours: 1),
        );

        expect(
          await dao.readEntry('k'),
          equals(const CacheEntry(payload: 'new', isStale: false)),
        );
      });
    });

    group('delete', () {
      test('removes entry', () async {
        await dao.write(key: 'del', payload: 'bye');
        await dao.delete('del');
        expect(await dao.readEntry('del'), isNull);
      });

      test('is a no-op for absent key', () async {
        await expectLater(dao.delete('no_such_key'), completes);
      });
    });

    group('deletePrefix', () {
      test('is a no-op for an empty store', () async {
        await expectLater(dao.deletePrefix('ghost'), completes);
      });

      test('removes all entries with the given prefix', () async {
        await dao.write(key: 'user1:home_feed', payload: 'a');
        await dao.write(key: 'user1:my_followers', payload: 'b');
        await dao.write(key: 'user2:home_feed', payload: 'c');

        await dao.deletePrefix('user1');

        expect(await dao.readEntry('user1:home_feed'), isNull);
        expect(await dao.readEntry('user1:my_followers'), isNull);
        expect((await dao.readEntry('user2:home_feed'))?.payload, equals('c'));
      });

      test('exact-key prefix removes prefixed siblings too', () async {
        await dao.write(key: 'abc', payload: 'a');
        await dao.write(key: 'abcdef', payload: 'b');

        await dao.deletePrefix('abc');

        expect(await dao.readEntry('abc'), isNull);
        expect(await dao.readEntry('abcdef'), isNull);
      });

      test('non-prefix substring is preserved', () async {
        await dao.write(key: 'prefixed', payload: 'a');
        await dao.write(key: 'wrap_prefixed_inner', payload: 'b');

        await dao.deletePrefix('prefix');

        expect(await dao.readEntry('prefixed'), isNull);
        expect(
          (await dao.readEntry('wrap_prefixed_inner'))?.payload,
          equals('b'),
        );
      });

      test('treats `_` in prefix as a literal, not a LIKE wildcard', () async {
        // Without LIKE escaping the SQL pattern `user_1%` would match
        // `userX1:home` because `_` is a single-char wildcard. The
        // escape clause must neutralize it.
        await dao.write(key: 'user_1:home', payload: 'a');
        await dao.write(key: 'userX1:home', payload: 'b');

        await dao.deletePrefix('user_1');

        expect(await dao.readEntry('user_1:home'), isNull);
        expect((await dao.readEntry('userX1:home'))?.payload, equals('b'));
      });

      test('treats `%` in prefix as a literal, not a LIKE wildcard', () async {
        // Without LIKE escaping the SQL pattern `pre%fix%` would match
        // `preXYZfix:home` because `%` is the any-string wildcard.
        await dao.write(key: 'pre%fix:home', payload: 'a');
        await dao.write(key: 'preXYZfix:home', payload: 'b');

        await dao.deletePrefix('pre%fix');

        expect(await dao.readEntry('pre%fix:home'), isNull);
        expect((await dao.readEntry('preXYZfix:home'))?.payload, equals('b'));
      });

      test(
        r'treats `\` in prefix as a literal, not the escape character',
        () async {
          // The escape char itself must round-trip cleanly.
          await dao.write(key: r'wrap\back:home', payload: 'a');
          await dao.write(key: 'wrap:home', payload: 'b');

          await dao.deletePrefix(r'wrap\back');

          expect(await dao.readEntry(r'wrap\back:home'), isNull);
          expect((await dao.readEntry('wrap:home'))?.payload, equals('b'));
        },
      );
    });

    group('totalPayloadBytes', () {
      test('returns 0 when store is empty', () async {
        expect(await dao.totalPayloadBytes(), equals(0));
      });

      test('returns sum of all payload lengths', () async {
        await dao.write(key: 'a', payload: 'hello'); // 5
        await dao.write(key: 'b', payload: 'world!'); // 6
        expect(await dao.totalPayloadBytes(), equals(11));
      });

      test('reflects overwritten payload size', () async {
        await dao.write(key: 'a', payload: 'hello'); // 5
        await dao.write(key: 'a', payload: 'hi'); // 2 — replaces
        expect(await dao.totalPayloadBytes(), equals(2));
      });
    });

    group('evictOldest', () {
      test('does nothing when bytesToFree is 0', () async {
        await dao.write(key: 'a', payload: 'hello');
        await dao.evictOldest(0);
        expect((await dao.readEntry('a'))?.payload, equals('hello'));
      });

      test('deletes oldest entry until enough bytes are freed', () async {
        await dao.write(key: 'old', payload: 'aaaa'); // 4 bytes, written first
        clock = clock.add(const Duration(seconds: 1));
        await dao.write(key: 'new', payload: 'bbbb'); // 4 bytes, written later

        await dao.evictOldest(4);

        expect(await dao.readEntry('old'), isNull);
        expect((await dao.readEntry('new'))?.payload, equals('bbbb'));
      });

      test('evicts multiple entries when one is not enough', () async {
        await dao.write(key: 'a', payload: 'aa'); // 2
        clock = clock.add(const Duration(seconds: 1));
        await dao.write(key: 'b', payload: 'bb'); // 2
        clock = clock.add(const Duration(seconds: 1));
        await dao.write(key: 'c', payload: 'cc'); // 2 — newest, kept

        await dao.evictOldest(4);

        expect(await dao.readEntry('a'), isNull);
        expect(await dao.readEntry('b'), isNull);
        expect((await dao.readEntry('c'))?.payload, equals('cc'));
      });
    });

    group('size-based LRU eviction via write', () {
      setUp(() async {
        await db.close();
        db = CacheDatabase.test(NativeDatabase.memory());
        dao = CacheDaoImpl(db, maxSizeBytes: 10, now: () => clock);
      });

      test('keeps entries within limit', () async {
        await dao.write(key: 'a', payload: 'aaaaa'); // 5
        await dao.write(key: 'b', payload: 'bbbbb'); // 5 — total: 10, ok

        expect((await dao.readEntry('a'))?.payload, equals('aaaaa'));
        expect((await dao.readEntry('b'))?.payload, equals('bbbbb'));
      });

      test('evicts oldest entry when limit is exceeded', () async {
        await dao.write(key: 'old', payload: 'aaaaaaaaaa'); // 10
        clock = clock.add(const Duration(seconds: 1));
        // 10 + 10 = 20 > limit 10, 'old' is evicted
        await dao.write(key: 'new', payload: 'bbbbbbbbbb');

        expect(await dao.readEntry('old'), isNull);
        expect((await dao.readEntry('new'))?.payload, equals('bbbbbbbbbb'));
      });

      test('does not evict when unlimited (maxSizeBytes: null)', () async {
        final unlimitedDao = CacheDaoImpl(db);
        await unlimitedDao.write(key: 'x', payload: 'x' * 1000);
        await unlimitedDao.write(key: 'y', payload: 'y' * 1000);

        expect(await unlimitedDao.totalPayloadBytes(), equals(2000));
        expect(await unlimitedDao.readEntry('x'), isNotNull);
        expect(await unlimitedDao.readEntry('y'), isNotNull);
      });

      test('overwriting with a smaller payload frees budget (counter '
          'tracks the replaced length, no spurious eviction)', () async {
        await dao.write(key: 'a', payload: 'aaaaaaaa'); // 8
        await dao.write(key: 'b', payload: 'bb'); // 2 — total 10
        // Shrink 'a' to 1 char: a correct counter drops the total to 3, so the
        // next write fits. A counter that ignored the replaced 8 chars would
        // think the store is full and evict.
        await dao.write(key: 'a', payload: 'a'); // total 3
        await dao.write(key: 'c', payload: 'ccccccc'); // 7 — total 10

        expect((await dao.readEntry('a'))?.payload, equals('a'));
        expect((await dao.readEntry('b'))?.payload, equals('bb'));
        expect((await dao.readEntry('c'))?.payload, equals('ccccccc'));
      });

      test('delete frees budget so a later write does not evict', () async {
        await dao.write(key: 'a', payload: 'aaaaa'); // 5
        await dao.write(key: 'b', payload: 'bbbbb'); // 5 — total 10
        await dao.delete('a'); // total 5
        await dao.write(key: 'c', payload: 'ccccc'); // 5 — total 10, no evict

        expect(await dao.readEntry('a'), isNull);
        expect((await dao.readEntry('b'))?.payload, equals('bbbbb'));
        expect((await dao.readEntry('c'))?.payload, equals('ccccc'));
      });

      test('uses the database length metric for non-BMP payloads', () async {
        await dao.write(key: 'emoji', payload: '😀' * 5);
        await dao.write(key: 'plain', payload: 'xxxxx');

        expect((await dao.readEntry('emoji'))?.payload, equals('😀' * 5));
        expect((await dao.readEntry('plain'))?.payload, equals('xxxxx'));
        expect(await dao.totalPayloadBytes(), equals(10));
      });

      test(
        'deletePrefix keeps the budget accurate for a later write',
        () async {
          await dao.write(key: 'user1:x', payload: 'xxxxx'); // 5
          await dao.write(key: 'user2:y', payload: 'yyyyy'); // 5 — total 10
          await dao.deletePrefix('user1:'); // removes user1:x → real total 5
          // The counter was invalidated and is recomputed from the sum, so this
          // write fits. A stale counter (still 10) would evict user2:y.
          await dao.write(key: 'user2:z', payload: 'zzzzz'); // 5 — total 10

          expect(await dao.readEntry('user1:x'), isNull);
          expect((await dao.readEntry('user2:y'))?.payload, equals('yyyyy'));
          expect((await dao.readEntry('user2:z'))?.payload, equals('zzzzz'));
        },
      );

      test('reconciles the running counter after 256 writes', () async {
        // The reconcile branch resets the counter after enough writes, so the
        // next write recomputes the value from the real DB sum.
        for (var i = 0; i < 256; i++) {
          await dao.write(key: 'k', payload: 'x');
        }
        // This 257th write exercises the post-reconcile path where _totalBytes
        // was nullified and must be recomputed via totalPayloadBytes().
        await dao.write(key: 'k', payload: 'x');
        expect((await dao.readEntry('k'))?.payload, equals('x'));
        expect(await dao.totalPayloadBytes(), equals(1));
      });
    });
  });
}
