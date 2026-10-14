import 'dart:async';

import 'package:cache_sync/src/cache_dao.dart';
import 'package:cache_sync/src/cache_dao_impl.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:cache_sync/src/cache_entry.dart';
import 'package:cache_sync/src/cache_fetch_policy.dart';
import 'package:cache_sync/src/cache_result.dart';

/// Static facade for the stale-while-revalidate cache.
///
/// Call [init] once at app startup (or in test `setUp`) before using any
/// other method.
///
/// ```dart
/// // main.dart
/// await CacheSync.init();
///
/// // test
/// setUp(() => CacheSync.init(dao: FakeCacheDao()));
/// ```
abstract final class CacheSync {
  static late CacheDao _dao;

  /// Default cache size limit used in production (100 MB).
  ///
  /// Pass to [init] as `maxSizeBytes` or override with your own value.
  static const int defaultMaxSizeBytes = 100 * 1024 * 1024;

  /// Initialises the cache.
  ///
  /// - [maxSizeBytes] caps the total payload size; when exceeded the oldest
  ///   entries are evicted (LRU). Pass `null` to disable the limit.
  ///   Defaults to [defaultMaxSizeBytes] (100 MB) in production.
  /// - In tests inject a [CacheDao] implementation via [dao] to avoid disk I/O.
  ///   The [maxSizeBytes] parameter is ignored when [dao] is provided;
  ///   construct the fake with its own limit if needed.
  static Future<void> init({
    CacheDao? dao,
    int? maxSizeBytes = defaultMaxSizeBytes,
  }) async {
    if (dao != null) {
      _dao = dao;
      return;
    }
    // coverage:ignore-start
    final db = CacheDatabase();
    _dao = CacheDaoImpl(db, maxSizeBytes: maxSizeBytes);
    // coverage:ignore-end
  }

  /// Watches a single value backed by a [Future] fetch.
  ///
  /// Emits at most two events per call:
  ///   1. A [CacheResult.cached] if a cached value exists, fresh or stale. An
  ///      entry whose [ttl] has passed is served and kept, never deleted.
  ///   2. A [CacheResult.live] once the [fetch] Future resolves.
  ///
  /// The [ttl] only decides when to refresh. When [policy] is
  /// [CacheFetchPolicy.cacheFirst], a fresh cached value ends the stream
  /// without calling [fetch]; a stale one is emitted and then refreshed.
  ///
  /// If [toJson] returns an empty string the result is **not** written to the
  /// cache. This lets callers signal "do not cache this response" by returning
  /// an empty payload.
  ///
  /// Errors from [fetch] are forwarded as stream errors.
  static Stream<CacheResult<T>> watchOne<T>({
    required String key,
    required Future<T> Function() fetch,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    Duration? ttl,
    CacheFetchPolicy policy = CacheFetchPolicy.cacheAndNetwork,
  }) {
    late final StreamController<CacheResult<T>> controller;
    controller = StreamController<CacheResult<T>>(
      onListen: () => _driveWatchOne(
        controller: controller,
        key: key,
        fetch: fetch,
        fromJson: fromJson,
        toJson: toJson,
        ttl: ttl,
        policy: policy,
      ),
    );
    return controller.stream;
  }

  /// Watches a value backed by a [Stream] source.
  ///
  /// Behaves like [watchOne] but the fetch is an ongoing [Stream] rather than
  /// a one-shot [Future]. Each live event from [source] is written to the
  /// cache and re-emitted as [CacheResult.live].
  ///
  /// A cached value is served whether fresh or stale; the [ttl] only decides
  /// when to refresh. When [policy] is [CacheFetchPolicy.cacheFirst], a fresh
  /// cached value ends the stream without subscribing to [source]; a stale one
  /// is emitted and then [source] is subscribed to.
  ///
  /// Errors from [source] are forwarded as stream errors.
  static Stream<CacheResult<T>> watchStream<T>({
    required String key,
    required Stream<T> Function() source,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    Duration? ttl,
    CacheFetchPolicy policy = CacheFetchPolicy.cacheAndNetwork,
  }) {
    StreamIterator<T>? iterator;
    late final StreamController<CacheResult<T>> controller;
    controller = StreamController<CacheResult<T>>(
      onListen: () => _driveWatchStream(
        controller: controller,
        key: key,
        source: source,
        fromJson: fromJson,
        toJson: toJson,
        ttl: ttl,
        policy: policy,
        registerIterator: (value) => iterator = value,
      ),
      onCancel: () async {
        await iterator?.cancel();
      },
    );
    return controller.stream;
  }

  /// Reads the cached value for [key], or `null` when absent, stale, or
  /// corrupt.
  ///
  /// This is the direct disk-read counterpart to [watchOne] — it never
  /// performs a network fetch. A stale entry returns `null` but is **not**
  /// deleted; use [readEntry] to read it. A cache entry that fails [fromJson]
  /// is deleted and `null` is returned.
  static Future<T?> read<T>({
    required String key,
    required T Function(String json) fromJson,
  }) async {
    final entry = await readEntry<T>(key: key, fromJson: fromJson);
    if (entry == null || entry.isStale) return null;
    return entry.data;
  }

  /// Reads the cached value for [key] together with whether its TTL passed.
  ///
  /// Returns `null` when the entry is absent or corrupt (a corrupt entry is
  /// deleted). A stale entry is returned with `isStale: true` and is kept, so
  /// callers can show it and refresh in the background.
  static Future<({T data, bool isStale})?> readEntry<T>({
    required String key,
    required T Function(String json) fromJson,
  }) async {
    final entry = await _dao.readEntry(key);
    if (entry == null || entry.payload.isEmpty) return null;
    try {
      return (data: fromJson(entry.payload), isStale: entry.isStale);
    } on Object {
      await _dao.delete(key);
      return null;
    }
  }

  /// Writes [value] to the cache under [key].
  ///
  /// When [toJson] returns an empty string the value is **not** persisted —
  /// the same "do not cache" signal [watchOne] honours. [ttl] sets the
  /// entry's expiry; `null` means it never expires.
  static Future<void> write<T>({
    required String key,
    required T value,
    required String Function(T value) toJson,
    Duration? ttl,
  }) async {
    final payload = toJson(value);
    if (payload.isEmpty) return;
    await _dao.write(key: key, payload: payload, ttl: ttl);
  }

  /// Removes the cached entry for [key].
  static Future<void> invalidate(String key) => _dao.delete(key);

  /// Removes all cached entries whose keys start with [prefix].
  ///
  /// Account-scoped invalidation: cache keys follow the
  /// `${pubkeyHex}:${operation}` convention (RFC #4244), so calling
  /// `invalidatePrefix(pubkeyHex)` at sign-out clears every entry for that
  /// account without touching other accounts on the same device.
  ///
  /// ```dart
  /// // In AuthService.signOut, after capturing currentPubkey:
  /// await CacheSync.invalidatePrefix(currentPubkey);
  /// ```
  ///
  /// [prefix] is matched literally — SQL `LIKE` wildcards (`%`, `_`) and
  /// the escape character (`\`) in [prefix] are escaped before query
  /// execution, so passing e.g. `'user_1'` matches the literal key
  /// `'user_1:foo'` and not `'userX1:foo'`.
  ///
  /// Throws [ArgumentError] when [prefix] is empty: an empty prefix would
  /// match every key and full-wipe the cache, which is never the intent of
  /// a *scoped* invalidation call. The guard is runtime-enforced so the
  /// blast-radius footgun cannot regress in release builds.
  static Future<void> invalidatePrefix(String prefix) {
    if (prefix.isEmpty) {
      throw ArgumentError.value(
        prefix,
        'prefix',
        'invalidatePrefix requires a non-empty prefix to avoid wiping '
            'every cached entry. Pass a pubkey hex or other namespacing '
            'prefix.',
      );
    }
    return _dao.deletePrefix(prefix);
  }

  static Future<void> _driveWatchOne<T>({
    required StreamController<CacheResult<T>> controller,
    required String key,
    required Future<T> Function() fetch,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    required Duration? ttl,
    required CacheFetchPolicy policy,
  }) async {
    // 1. Serve from cache when applicable.
    final servedFresh = await _serveCached(
      controller: controller,
      key: key,
      fromJson: fromJson,
      policy: policy,
    );

    if (policy == CacheFetchPolicy.cacheOnly ||
        (policy == CacheFetchPolicy.cacheFirst && servedFresh)) {
      await controller.close();
      return;
    }

    // 2. Fetch from network.
    try {
      final value = await fetch();
      final payload = toJson(value);
      if (payload.isNotEmpty) {
        await _writePayloadBestEffort(key: key, payload: payload, ttl: ttl);
      }
      if (!controller.isClosed) {
        controller.add(CacheResult.live(value));
      }
    } on Object catch (e, st) {
      if (!controller.isClosed) {
        controller.addError(e, st);
      }
    } finally {
      if (!controller.isClosed) await controller.close();
    }
  }

  static Future<void> _driveWatchStream<T>({
    required StreamController<CacheResult<T>> controller,
    required String key,
    required Stream<T> Function() source,
    required T Function(String json) fromJson,
    required String Function(T value) toJson,
    required Duration? ttl,
    required CacheFetchPolicy policy,
    required void Function(StreamIterator<T> iterator) registerIterator,
  }) async {
    // 1. Serve from cache when applicable.
    final servedFresh = await _serveCached(
      controller: controller,
      key: key,
      fromJson: fromJson,
      policy: policy,
    );

    if (policy == CacheFetchPolicy.cacheOnly ||
        (policy == CacheFetchPolicy.cacheFirst && servedFresh)) {
      await controller.close();
      return;
    }

    // 2. Subscribe to source stream.
    if (controller.isClosed) return;

    StreamIterator<T>? iterator;

    try {
      iterator = StreamIterator<T>(source());
      registerIterator(iterator);

      while (!controller.isClosed && await iterator.moveNext()) {
        final value = iterator.current;
        final payload = toJson(value);
        if (payload.isNotEmpty) {
          await _writePayloadBestEffort(key: key, payload: payload, ttl: ttl);
        }
        if (!controller.isClosed) {
          controller.add(CacheResult.live(value));
        }
      }
    } on Object catch (e, st) {
      if (!controller.isClosed) {
        controller.addError(e, st);
      }
    } finally {
      await iterator?.cancel();
      if (!controller.isClosed) await controller.close();
    }
  }

  /// Emits the cached value for [key] (fresh or stale) when [policy] reads
  /// the cache, and reports whether a **fresh** one was served.
  ///
  /// A corrupt entry is deleted and treated as absent.
  static Future<bool> _serveCached<T>({
    required StreamController<CacheResult<T>> controller,
    required String key,
    required T Function(String json) fromJson,
    required CacheFetchPolicy policy,
  }) async {
    if (policy == CacheFetchPolicy.networkOnly) return false;
    final cached = await _readEntryBestEffort(key);
    if (cached == null || cached.payload.isEmpty) return false;
    try {
      controller.add(CacheResult.cached(fromJson(cached.payload)));
    } on Object {
      await _deletePayloadBestEffort(key);
      return false;
    }
    return !cached.isStale;
  }

  static Future<CacheEntry?> _readEntryBestEffort(String key) async {
    try {
      return await _dao.readEntry(key);
    } on Object {
      return null;
    }
  }

  static Future<void> _writePayloadBestEffort({
    required String key,
    required String payload,
    required Duration? ttl,
  }) async {
    try {
      await _dao.write(key: key, payload: payload, ttl: ttl);
    } on Object {
      // Cache persistence is best-effort; callers must still receive live data.
    }
  }

  static Future<void> _deletePayloadBestEffort(String key) async {
    try {
      await _dao.delete(key);
    } on Object {
      // Corrupt entries should not prevent a live refresh.
    }
  }
}
