// ABOUTME: Tests that every test starts with no CacheSync store installed.
// ABOUTME: Regression test for #11186, where one suite's entries leaked on.

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cache_sync_isolation.dart';

const _key = 'cache-sync-isolation-test:entry';

String _fromJson(String json) => json;

Future<String?> _read() => CacheSync.read(key: _key, fromJson: _fromJson);

final class _OneEntryCacheDao implements CacheDao {
  @override
  Future<CacheEntry?> readEntry(String key) async =>
      key == _key ? const CacheEntry(payload: 'cached', isStale: false) : null;

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deletePrefix(String prefix) async {}

  @override
  Future<int> totalPayloadBytes() async => 0;

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

void main() {
  group('resetCacheSyncStore', () {
    test('drops the store an earlier caller installed', () async {
      await CacheSync.init(dao: _OneEntryCacheDao());
      expect(await _read(), equals('cached'));

      await resetCacheSyncStore();

      await expectLater(_read(), throwsA(isA<Error>()));
    });

    test('fails a write instead of keeping it', () async {
      await resetCacheSyncStore();

      await expectLater(
        CacheSync.write(key: _key, value: 'written', toJson: (v) => v),
        throwsA(
          isA<Error>().having(
            (error) => error.toString(),
            'message',
            contains('CacheSync.init(dao: ...)'),
          ),
        ),
      );
    });
  });

  group('flutter_test_config', () {
    // Runs before the root setUp of the first test in this group, the way a
    // store left behind by an earlier suite does in the merged isolate.
    setUpAll(() => CacheSync.init(dao: _OneEntryCacheDao()));

    test('starts each test without the store installed before it', () async {
      await expectLater(_read(), throwsA(isA<Error>()));
    });
  });
}
