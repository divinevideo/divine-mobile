// ABOUTME: Reclaims retired event caches in small, resumable transactions.
// ABOUTME: Never scans active caches or touches durable user tables.
import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

/// Old cache storage, retained by the metadata-only v36 upgrade.
const retiredEventCacheTable = 'retired_event_cache_v36';

/// Derived metrics must retire with their old event cache.
const retiredVideoMetricsTable = 'retired_video_metrics_v36';

/// Idle-only maintenance for caches replaced by schema v36.
class RetiredEventCache {
  /// Uses the device-lifetime database connection.
  RetiredEventCache(this._db);

  static const _batchSize = 250;

  final AppDatabase _db;

  /// Deletes at most 250 retired rows. Returns whether another pass is needed.
  ///
  /// Metrics go first, so FK cascades cannot turn a small event batch into a
  /// large metrics deletion. Empty tables alone are dropped; their indexes are
  /// then empty too. No row decoding, full-table count, or VACUUM is needed.
  Future<bool> pruneBatch() => _db.transaction(() async {
    for (final table in [retiredVideoMetricsTable, retiredEventCacheTable]) {
      final exists = await _db
          .customSelect(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name = ?",
            variables: [Variable.withString(table)],
          )
          .get();
      if (exists.isEmpty) continue;
      final deleted = await _db.customUpdate(
        'DELETE FROM $table WHERE rowid IN '
        '(SELECT rowid FROM $table LIMIT $_batchSize)',
      );
      if (deleted > 0) return true;
      await _db.customStatement('DROP TABLE $table');
    }
    return false;
  });
}
