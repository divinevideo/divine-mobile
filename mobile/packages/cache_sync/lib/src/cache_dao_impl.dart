import 'package:cache_sync/src/cache_dao.dart';
import 'package:cache_sync/src/cache_database.dart';
import 'package:cache_sync/src/cache_entry.dart';
import 'package:drift/drift.dart';

/// Drift-backed implementation of [CacheDao].
///
/// An expired row is returned as stale and kept; only size-based eviction and
/// explicit deletes remove rows.
///
/// When [maxSizeBytes] is set, LRU eviction runs **after every write**: the
/// oldest entries (by `cachedAt`) are deleted until the total payload size is
/// within the budget.
///
/// To keep that budget check cheap, the total payload size is held in a
/// running counter ([_totalBytes]) instead of a full-table
/// `SUM(LENGTH(payload))` scan on every write. The counter is seeded lazily
/// from [totalPayloadBytes], maintained on write/delete/evict, invalidated on
/// the bulk [deletePrefix] path, and periodically reconciled against the real
/// sum to bound drift from a concurrent same-key write. It is maintained only
/// when [maxSizeBytes] is set — an unbounded cache pays nothing.
class CacheDaoImpl implements CacheDao {
  /// Creates the DAO over [_db].
  ///
  /// [now] is the clock used for expiry checks and write timestamps. It
  /// defaults to `DateTime.now().toUtc()` and exists so tests can move time.
  CacheDaoImpl(this._db, {this.maxSizeBytes, DateTime Function()? now})
    : _now = now ?? _systemNow;

  final CacheDatabase _db;

  final DateTime Function() _now;

  static DateTime _systemNow() => DateTime.now().toUtc();

  /// Maximum total payload size in characters. `null` = unlimited.
  final int? maxSizeBytes;

  /// Running total payload size in characters, or `null` when not yet computed
  /// / invalidated (recomputed lazily via [_ensureTotalBytes]).
  int? _totalBytes;

  /// Writes since the running counter was last reconciled against the real
  /// `SUM`. Drift to zero forces a fresh [totalPayloadBytes] read.
  int _writesSinceReconcile = 0;

  /// Recompute the running counter from the real sum after this many writes, so
  /// any drift from an interleaved same-key write self-corrects.
  static const int _reconcileEveryWrites = 256;

  Expression<int> get _payloadLength => _db.cacheEntries.payload.length;

  @override
  Future<CacheEntry?> readEntry(String key) async {
    final row = await (_db.select(
      _db.cacheEntries,
    )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();

    if (row == null) return null;

    final expires = row.expiresAt;
    return CacheEntry(
      payload: row.payload,
      isStale: expires != null && _now().isAfter(expires),
    );
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    final now = _now();
    final limit = maxSizeBytes;

    // Seed the running counter from the PRE-write total and capture the
    // replaced payload's length, both before the upsert mutates the table, so
    // the counter stays exact across an overwrite (insertOnConflictUpdate
    // replaces an existing row). Only needed when a budget is enforced.
    final preWriteTotal = limit == null ? 0 : await _ensureTotalBytes();
    final replacedLength = limit == null
        ? 0
        : await _existingPayloadLength(key);

    await _db
        .into(_db.cacheEntries)
        .insertOnConflictUpdate(
          CacheEntriesCompanion.insert(
            cacheKey: key,
            payload: payload,
            cachedAt: now,
            expiresAt: Value(ttl != null ? now.add(ttl) : null),
          ),
        );

    if (limit == null) return;

    final newTotal = preWriteTotal - replacedLength + _payloadSize(payload);
    _totalBytes = newTotal;
    if (newTotal > limit) {
      await evictOldest(newTotal - limit);
    }

    if (++_writesSinceReconcile >= _reconcileEveryWrites) {
      _writesSinceReconcile = 0;
      _totalBytes = null;
    }
  }

  @override
  Future<void> delete(String key) async {
    // Keep the running counter exact: subtract the deleted row's length. Skip
    // the probe when no budget is enforced or the counter isn't initialised
    // (the next write recomputes it).
    final removedLength = (maxSizeBytes != null && _totalBytes != null)
        ? await _existingPayloadLength(key)
        : 0;
    await (_db.delete(
      _db.cacheEntries,
    )..where((t) => t.cacheKey.equals(key))).go();
    final total = _totalBytes;
    if (total != null) _totalBytes = total - removedLength;
  }

  @override
  Future<void> deletePrefix(String prefix) async {
    // Escape SQL LIKE wildcards (`%`, `_`) and the escape character
    // itself (`\`) so callers passing non-pubkey prefixes (or future
    // user-controlled input) cannot accidentally over-delete or
    // under-delete by including LIKE metacharacters.
    final escaped = prefix
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    await _db.customStatement(
      r"DELETE FROM cache_entries WHERE cache_key LIKE ?1 || '%' ESCAPE '\'",
      [escaped],
    );
    // A bulk delete can't cheaply report the freed byte count, so invalidate
    // the running counter and let the next write recompute it from the sum.
    _totalBytes = null;
  }

  @override
  Future<int> totalPayloadBytes() async {
    final result = await _db
        .customSelect(
          'SELECT COALESCE(SUM(LENGTH(payload)), 0) AS total '
          'FROM cache_entries',
          readsFrom: {_db.cacheEntries},
        )
        .getSingle();
    return result.read<int>('total');
  }

  @override
  Future<void> evictOldest(int bytesToFree) async {
    if (bytesToFree <= 0) return;
    await _db.transaction(() async {
      // Select only the key and payload LENGTH (oldest first) instead of
      // materialising every full payload into memory.
      final query = _db.selectOnly(_db.cacheEntries)
        ..addColumns([_db.cacheEntries.cacheKey, _payloadLength])
        ..orderBy([OrderingTerm.asc(_db.cacheEntries.cachedAt)]);
      final rows = await query.get();

      var freed = 0;
      final keysToDelete = <String>[];
      for (final row in rows) {
        if (freed >= bytesToFree) break;
        final key = row.read(_db.cacheEntries.cacheKey);
        if (key == null) continue;
        freed += row.read(_payloadLength) ?? 0;
        keysToDelete.add(key);
      }
      if (keysToDelete.isEmpty) return;

      // One bounded DELETE instead of a per-row delete loop.
      await (_db.delete(
        _db.cacheEntries,
      )..where((t) => t.cacheKey.isIn(keysToDelete))).go();

      final total = _totalBytes;
      if (total != null) _totalBytes = total - freed;
    });
  }

  /// Returns the running counter, computing it from the real sum on first use
  /// (or after invalidation).
  Future<int> _ensureTotalBytes() async {
    return _totalBytes ??= await totalPayloadBytes();
  }

  /// Length of the payload currently stored under [key], or 0 when absent.
  /// Indexed point lookup on the `cache_key` primary key.
  Future<int> _existingPayloadLength(String key) async {
    final query = _db.selectOnly(_db.cacheEntries)
      ..addColumns([_payloadLength])
      ..where(_db.cacheEntries.cacheKey.equals(key));
    final row = await query.getSingleOrNull();
    return row?.read(_payloadLength) ?? 0;
  }

  /// Matches SQLite `LENGTH(payload)` for JSON text payloads.
  static int _payloadSize(String payload) => payload.runes.length;
}
