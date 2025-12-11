// ABOUTME: Data Access Object for hashtag statistics cache operations.
// ABOUTME: Provides upsert with expiry checking.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'hashtag_stats_dao.g.dart';

/// Default cache duration for hashtag stats (1 hour)
const hashtagStatsCacheDuration = Duration(hours: 1);

@DriftAccessor(tables: [HashtagStats])
class HashtagStatsDao extends DatabaseAccessor<AppDatabase>
    with _$HashtagStatsDaoMixin {
  HashtagStatsDao(super.attachedDatabase);

  /// Upsert a single hashtag stat
  Future<void> upsertHashtag({
    required String hashtag,
    int? videoCount,
    int? totalViews,
    int? totalLikes,
  }) {
    return into(hashtagStats).insertOnConflictUpdate(
      HashtagStatsCompanion.insert(
        hashtag: hashtag,
        videoCount: Value(videoCount),
        totalViews: Value(totalViews),
        totalLikes: Value(totalLikes),
        cachedAt: DateTime.now(),
      ),
    );
  }

  /// Upsert multiple hashtag stats in a batch
  Future<void> upsertBatch(List<HashtagStatsCompanion> stats) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(hashtagStats, stats);
    });
  }

  /// Get popular hashtags sorted by video count
  Future<List<HashtagStatRow>> getPopularHashtags({
    int limit = 20,
    Duration expiry = hashtagStatsCacheDuration,
  }) async {
    final expiryTime = DateTime.now().subtract(expiry);
    final query = select(hashtagStats)
      ..where((t) => t.cachedAt.isBiggerThan(Variable(expiryTime)))
      ..orderBy([
        (t) => OrderingTerm(expression: t.videoCount, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query.get();
  }

  /// Check if cache is fresh
  Future<bool> isCacheFresh({
    Duration expiry = hashtagStatsCacheDuration,
  }) async {
    final expiryTime = DateTime.now().subtract(expiry);
    final query = select(hashtagStats)
      ..where((t) => t.cachedAt.isBiggerThan(Variable(expiryTime)))
      ..limit(1);
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Delete all expired hashtag stats
  Future<int> deleteExpired({Duration expiry = hashtagStatsCacheDuration}) {
    final expiryTime = DateTime.now().subtract(expiry);
    return (delete(hashtagStats)..where(
          (t) => t.cachedAt.isSmallerThan(
            Variable(expiryTime),
          ),
        ))
        .go();
  }

  /// Clear all hashtag stats
  Future<int> clearAll() {
    return delete(hashtagStats).go();
  }
}
