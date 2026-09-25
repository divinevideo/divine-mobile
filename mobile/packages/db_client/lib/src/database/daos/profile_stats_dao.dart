// ABOUTME: Data Access Object for profile statistics cache operations.
// ABOUTME: Provides upsert with expiry checking.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'profile_stats_dao.g.dart';

/// Default cache duration for profile stats (5 minutes)
const profileStatsCacheDuration = Duration(minutes: 5);

/// How long follower/following counts stay useful after they were written.
///
/// Follower counts live in this row and have coordinated REST and relay
/// writers.
/// The relay fallback stabilizes partial observations against the persisted
/// value, which only works if the baseline survives a restart, so the counts
/// outlive the 5-minute stats cache.
///
/// This must stay comfortably longer than `FollowRepository`'s own staleness
/// window, so the baseline is still on disk for as long as the repository would
/// still trust it. Sizing them equally would race: the row could be swept in
/// the same launch the repository still wanted to compare against it.
const profileFollowerCountsCacheDuration = Duration(hours: 48);

@DriftAccessor(tables: [ProfileStats, VanishedProfiles])
class ProfileStatsDao extends DatabaseAccessor<AppDatabase>
    with _$ProfileStatsDaoMixin {
  ProfileStatsDao(super.attachedDatabase);

  /// Upserts profile stats, creating the row when absent.
  ///
  /// Only overwrites fields that are explicitly provided (non-null).
  /// Null parameters are left unchanged in the existing row, preventing
  /// partial REST responses from zeroing out previously cached values.
  ///
  /// No-ops for a pubkey carrying a `vanished_profiles` tombstone, so counters
  /// cannot be re-cached for an account that asked to be erased. Same rule and
  /// same reason as `UserProfilesDao.upsertProfile`: the writers span layers
  /// that cannot all reach `ProfileRepository` — the classic-viner seed import
  /// re-runs on every manifest bump.
  ///
  /// Writing either count refreshes `followerCountsUpdatedAt`, which answers
  /// one question for two readers: *when were these counts last written from
  /// a source we trust?*
  ///
  /// - [getStats] and [deleteExpired] use it as the retention clock, keeping a
  ///   row whose counts are newer than [profileFollowerCountsCacheDuration]
  ///   even after the rest of the row has expired.
  /// - `FollowRepository`'s relay-fallback hysteresis uses it to decide when a
  ///   baseline is old enough that a lower relay count should be accepted.
  ///
  /// Those two readers agree because every writer withholds each ambiguous
  /// zero field rather than storing it, so a stamp always means real data
  /// arrived for at least one count. REST-authoritative fields and relay
  /// fallback fields are combined before the row is written.
  Future<void> upsertStats({
    required String pubkey,
    int? videoCount,
    int? followerCount,
    int? followingCount,
    int? totalViews,
    int? totalLikes,
  }) async {
    final tombstone = await (select(
      vanishedProfiles,
    )..where((t) => t.pubkey.equals(pubkey))).getSingleOrNull();
    if (tombstone != null) return;

    final existing = await (select(
      profileStats,
    )..where((t) => t.pubkey.equals(pubkey))).getSingleOrNull();
    final existingTotalViews = existing?.totalViews;
    // Funnelcake collapses some ClickHouse failures into a successful zero
    // engagement response. Preserve a known positive total in that case; a
    // real new account can still cache zero when no positive value exists.
    final totalViewsToStore = totalViews == 0 && (existingTotalViews ?? 0) > 0
        ? existingTotalViews
        : totalViews ?? existingTotalViews;
    final countsUpdatedAt = followerCount != null || followingCount != null
        ? DateTime.now()
        : existing?.followerCountsUpdatedAt;

    final companion = ProfileStatsCompanion.insert(
      pubkey: pubkey,
      videoCount: Value(videoCount ?? existing?.videoCount),
      followerCount: Value(followerCount ?? existing?.followerCount),
      followingCount: Value(followingCount ?? existing?.followingCount),
      totalViews: Value(totalViewsToStore),
      totalLikes: Value(totalLikes ?? existing?.totalLikes),
      cachedAt: DateTime.now(),
      followerCountsUpdatedAt: Value(countsUpdatedAt),
    );

    await into(profileStats).insertOnConflictUpdate(companion);
  }

  /// Get stats for a pubkey (returns null if not found or expired).
  ///
  /// An expired row is only deleted when it carries nothing worth keeping.
  /// Follower counts outlive this cache ([followerCountsExpiry]) and form the
  /// shared baseline for REST/profile rendering and relay fallback, so evicting
  /// them here would reintroduce the loss [deleteExpired] avoids.
  Future<ProfileStatRow?> getStats(
    String pubkey, {
    Duration expiry = profileStatsCacheDuration,
    Duration followerCountsExpiry = profileFollowerCountsCacheDuration,
  }) async {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    // Check expiry
    final now = DateTime.now();
    if (result.cachedAt.isBefore(now.subtract(expiry))) {
      final hasCounts =
          result.followerCount != null || result.followingCount != null;
      final countsWrittenAt = result.followerCountsUpdatedAt ?? result.cachedAt;
      final countsWorthKeeping =
          hasCounts &&
          !countsWrittenAt.isBefore(now.subtract(followerCountsExpiry));
      if (!countsWorthKeeping) {
        await deleteStats(pubkey);
      }
      return null;
    }

    return result;
  }

  /// Delete stats for a pubkey
  Future<int> deleteStats(String pubkey) {
    return (delete(profileStats)..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Delete all expired stats.
  ///
  /// A row survives only while it still carries useful follower counts:
  /// it must hold at least one count, and that count must be newer than
  /// [followerCountsExpiry]. Everything else is governed by [expiry] alone.
  /// Dropping a row that still holds fresh follower counts would destroy the
  /// baseline `FollowRepository` stabilizes against, which is exactly the
  /// cross-restart case its hysteresis exists for.
  ///
  /// `follower_counts_updated_at` falls back to `cached_at` when NULL, matching
  /// `FollowRepository`'s own read. Rows written before that column existed
  /// carry counts with a NULL timestamp, and on the first launch after the
  /// v1 → v2 upgrade those are exactly the baselines worth keeping — treating
  /// NULL as "already expired" would delete them before the new column was ever
  /// populated.
  Future<int> deleteExpired({
    Duration expiry = profileStatsCacheDuration,
    Duration followerCountsExpiry = profileFollowerCountsCacheDuration,
  }) {
    final now = DateTime.now();
    final expiryTime = now.subtract(expiry);
    final followerExpiryTime = now.subtract(followerCountsExpiry);
    return (delete(profileStats)..where((t) {
          final hasCounts =
              t.followerCount.isNotNull() | t.followingCount.isNotNull();
          final countsWrittenAt = coalesce([
            t.followerCountsUpdatedAt,
            t.cachedAt,
          ]);
          final countsWorthKeeping =
              hasCounts &
              countsWrittenAt.isBiggerOrEqualValue(followerExpiryTime);
          return t.cachedAt.isSmallerThan(Variable(expiryTime)) &
              countsWorthKeeping.not();
        }))
        .go();
  }

  /// Read the stats row without expiry checking.
  ///
  /// Unlike [getStats], this never deletes expired rows.
  /// Use this when the consumer manages its own staleness logic
  /// (e.g., hysteresis with a custom stale duration).
  Future<ProfileStatRow?> getStatsRaw(String pubkey) async {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    return query.getSingleOrNull();
  }

  /// Watch stats for a pubkey.
  ///
  /// Returns a stream that emits the current [ProfileStatRow] whenever
  /// the row changes in the database. Emits `null` if no row exists.
  ///
  /// Unlike [getStats], this does not check expiry — consumers are
  /// responsible for interpreting [ProfileStatRow.cachedAt].
  Stream<ProfileStatRow?> watchStats(String pubkey) {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    return query.watchSingleOrNull();
  }

  /// Clear all profile stats
  Future<int> clearAll() {
    return delete(profileStats).go();
  }
}
