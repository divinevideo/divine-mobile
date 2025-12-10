// ABOUTME: Data Access Object for profile statistics cache operations.
// ABOUTME: Provides upsert with expiry checking.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'profile_stats_dao.g.dart';

/// Default cache duration for profile stats (5 minutes)
const profileStatsCacheDuration = Duration(minutes: 5);

@DriftAccessor(tables: [ProfileStats])
class ProfileStatsDao extends DatabaseAccessor<AppDatabase>
    with _$ProfileStatsDaoMixin {
  ProfileStatsDao(super.attachedDatabase);

  /// Upsert profile stats (insert or update)
  Future<void> upsertStats({
    required String pubkey,
    int? videoCount,
    int? followerCount,
    int? followingCount,
    int? totalViews,
    int? totalLikes,
  }) {
    return into(profileStats).insertOnConflictUpdate(
      ProfileStatsCompanion.insert(
        pubkey: pubkey,
        videoCount: Value(videoCount),
        followerCount: Value(followerCount),
        followingCount: Value(followingCount),
        totalViews: Value(totalViews),
        totalLikes: Value(totalLikes),
        cachedAt: DateTime.now(),
      ),
    );
  }

  /// Get stats for a pubkey (returns null if not found or expired)
  Future<ProfileStatRow?> getStats(
    String pubkey, {
    Duration expiry = profileStatsCacheDuration,
  }) async {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    // Check expiry
    final expiryTime = DateTime.now().subtract(expiry);
    if (result.cachedAt.isBefore(expiryTime)) {
      // Expired - delete and return null
      await deleteStats(pubkey);
      return null;
    }

    return result;
  }

  /// Delete stats for a pubkey
  Future<int> deleteStats(String pubkey) {
    return (delete(profileStats)..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Delete all expired stats
  Future<int> deleteExpired({Duration expiry = profileStatsCacheDuration}) {
    final expiryTime = DateTime.now().subtract(expiry);
    return (delete(profileStats)..where(
          (t) => t.cachedAt.isSmallerThan(
            Variable(expiryTime),
          ),
        ))
        .go();
  }

  /// Clear all profile stats
  Future<int> clearAll() {
    return delete(profileStats).go();
  }
}
