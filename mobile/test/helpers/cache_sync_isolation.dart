// ABOUTME: Puts CacheSync back to "no store installed" before every test.
// ABOUTME: Stops one suite's cached entries reaching later suites (#11186).

import 'package:cache_sync/cache_sync.dart';

/// Returns [CacheSync] to the state a fresh isolate starts in: no store, so
/// every call that reaches the store fails and the best-effort paths fall
/// back to the network.
///
/// [CacheSync] is static, so the store a suite installs with
/// `CacheSync.init(dao: ...)` outlives it in the merged
/// `very_good test --optimization` isolate, and a later suite reads its
/// entries back (#11186). The root `flutter_test_config.dart` calls this
/// before every test, so a test sees the same cache whichever suites ran
/// before it. A test that needs a store installs its own in `setUp`.
Future<void> resetCacheSyncStore() =>
    CacheSync.init(dao: const _NoCacheSyncStore());

/// Fails every call the way the unset `CacheSync._dao` does: synchronously,
/// with an [Error] that no `on StateError` or `on Exception` clause catches.
final class _NoCacheSyncStore implements CacheDao {
  const _NoCacheSyncStore();

  @override
  Future<CacheEntry?> readEntry(String key) => throw _CacheSyncNotInitialized();

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) => throw _CacheSyncNotInitialized();

  @override
  Future<void> delete(String key) => throw _CacheSyncNotInitialized();

  @override
  Future<void> deletePrefix(String prefix) => throw _CacheSyncNotInitialized();

  @override
  Future<int> totalPayloadBytes() => throw _CacheSyncNotInitialized();

  @override
  Future<void> evictOldest(int bytesToFree) => throw _CacheSyncNotInitialized();
}

final class _CacheSyncNotInitialized extends Error {
  @override
  String toString() =>
      'CacheSync has no store in this test. Install one with '
      'CacheSync.init(dao: ...) in setUp (#11186).';
}
