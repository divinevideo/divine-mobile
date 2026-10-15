import 'package:cache_sync/src/cache_entry.dart';

/// Abstract interface for the cache DAO.
///
/// Decoupled from Drift so tests can inject a fake DAO.
abstract interface class CacheDao {
  /// Returns the entry for [key], or `null` when it is absent.
  ///
  /// An entry past its `expiresAt` deadline is returned with
  /// [CacheEntry.isStale] set; it is never deleted by a read. A TTL only
  /// decides when to refresh, not whether the data may be shown.
  Future<CacheEntry?> readEntry(String key);

  /// Writes [payload] for [key].
  ///
  /// - If [ttl] is provided the row's `expiresAt` is set to `now + ttl`.
  /// - If [ttl] is `null` the entry never expires.
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  });

  /// Removes the single entry for [key], if present.
  Future<void> delete(String key);

  /// Removes all entries whose `cacheKey` starts with [prefix].
  ///
  /// Intended for account-scoped invalidation: when signing out account A,
  /// pass A's pubkey hex as the prefix to clear all of A's cached data
  /// without touching other accounts on the same device. Cache keys are
  /// expected to follow the `${pubkey}:${operation}` convention (RFC #4244).
  ///
  /// [prefix] is matched **literally** — implementations are responsible
  /// for escaping any SQL `LIKE` metacharacters (`%`, `_`, `\`) in
  /// [prefix] before executing the query, so callers can pass arbitrary
  /// string prefixes without escaping themselves.
  Future<void> deletePrefix(String prefix);

  /// Returns the total size of all `payload` strings, in characters.
  ///
  /// Uses SQLite `LENGTH` semantics for text payloads, suitable as an
  /// approximation of storage bytes for JSON-heavy payloads.
  Future<int> totalPayloadBytes();

  /// Deletes the oldest entries (by write time, ascending) until at least
  /// [bytesToFree] characters have been freed.
  ///
  /// Does nothing when [bytesToFree] ≤ 0 or the store is empty.
  Future<void> evictOldest(int bytesToFree);
}
