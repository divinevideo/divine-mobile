import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_cache_dao.dart';

void main() {
  late FakeCacheDao dao;
  late DateTime clock;

  setUp(() async {
    clock = DateTime.utc(2026, 10, 14);
    dao = FakeCacheDao(now: () => clock);
    await CacheSync.init(dao: dao);
  });

  group('CacheSync.write', () {
    test('persists a value that read can return', () async {
      await CacheSync.write<int>(
        key: 'k',
        value: 7,
        toJson: (v) => '$v',
      );

      final value = await CacheSync.read<int>(
        key: 'k',
        fromJson: int.parse,
      );
      expect(value, equals(7));
    });

    test('does not persist when toJson returns an empty string', () async {
      await CacheSync.write<int>(
        key: 'k',
        value: 7,
        toJson: (_) => '',
      );

      expect(dao.rawRead('k'), isNull);
    });

    test('applies the provided ttl', () async {
      await CacheSync.write<int>(
        key: 'k',
        value: 7,
        toJson: (v) => '$v',
        ttl: const Duration(hours: 1),
      );
      expect(await CacheSync.read<int>(key: 'k', fromJson: int.parse), 7);

      clock = clock.add(const Duration(hours: 2));

      final entry = await CacheSync.readEntry<int>(
        key: 'k',
        fromJson: int.parse,
      );
      expect(entry?.isStale, isTrue);
    });
  });

  group('CacheSync.read', () {
    test('returns null for an absent key', () async {
      final value = await CacheSync.read<int>(key: 'nope', fromJson: int.parse);
      expect(value, isNull);
    });

    test('deletes and returns null on a corrupt entry', () async {
      await dao.write(key: 'k', payload: 'not-an-int');

      final value = await CacheSync.read<int>(key: 'k', fromJson: int.parse);

      expect(value, isNull);
      expect(dao.rawRead('k'), isNull);
    });

    test('returns null for a stale entry without deleting it', () async {
      await dao.write(key: 'k', payload: '7', ttl: const Duration(hours: 1));
      clock = clock.add(const Duration(hours: 2));

      final value = await CacheSync.read<int>(key: 'k', fromJson: int.parse);
      final entry = await CacheSync.readEntry<int>(
        key: 'k',
        fromJson: int.parse,
      );

      expect(value, isNull);
      expect(entry, isNotNull);
      expect(entry!.data, equals(7));
      expect(entry.isStale, isTrue);
      expect(dao.rawRead('k'), equals('7'));
    });
  });

  group('CacheSync.readEntry', () {
    test('returns null for an absent key', () async {
      final entry = await CacheSync.readEntry<int>(
        key: 'nope',
        fromJson: int.parse,
      );
      expect(entry, isNull);
    });

    test('returns a fresh entry with isStale false', () async {
      await dao.write(key: 'k', payload: '7', ttl: const Duration(hours: 1));

      final entry = await CacheSync.readEntry<int>(
        key: 'k',
        fromJson: int.parse,
      );

      expect(entry, isNotNull);
      expect(entry!.data, equals(7));
      expect(entry.isStale, isFalse);
    });

    test('deletes and returns null on a corrupt entry', () async {
      await dao.write(key: 'k', payload: 'not-an-int');

      final entry = await CacheSync.readEntry<int>(
        key: 'k',
        fromJson: int.parse,
      );

      expect(entry, isNull);
      expect(dao.rawRead('k'), isNull);
    });
  });
}
