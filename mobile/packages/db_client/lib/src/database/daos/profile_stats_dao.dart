// ABOUTME: Data Access Object for profile statistics cache operations.
// ABOUTME: Provides upsert, freshness-checked reads, and 30-day retention.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'profile_stats_dao.g.dart';

/// How long a profile stats row counts as fresh (5 minutes).
///
/// A freshness signal only: [ProfileStatsDao.getStats] returns `null` for an
/// older row so callers refetch, but the row stays on disk until
/// [profileStatsRetention] passes.
const profileStatsCacheDuration = Duration(minutes: 5);

/// How long a profile stats row is kept on disk (30 days).
///
/// Retention policy for the `profile_stats` table: a row is deleted only when
/// both its `cached_at` and (when set) its `follower_counts_updated_at` are
/// older than this window. [ProfileStatsDao.deleteExpired] enforces it, called
/// from `AppDatabase.runStartupCleanup`. Rows are never deleted because they
/// are merely stale; stale rows remain available through
/// [ProfileStatsDao.getStatsRaw] while a refresh runs. This also keeps the
/// persisted follower-count baseline across restarts, which the relay
/// fallback stabilizes partial observations against.
const profileStatsRetention = Duration(days: 30);

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
  /// - [deleteExpired] uses it as part of the retention clock, keeping a row
  ///   whose counts are newer than [profileStatsRetention] even after the rest
  ///   of the row is older than the window.
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
    final countsUpdatedAt = followerCount != null || followingCount != null
        ? DateTime.now()
        : existing?.followerCountsUpdatedAt;

    final companion = ProfileStatsCompanion.insert(
      pubkey: pubkey,
      videoCount: Value(videoCount ?? existing?.videoCount),
      followerCount: Value(followerCount ?? existing?.followerCount),
      followingCount: Value(followingCount ?? existing?.followingCount),
      totalViews: Value(totalViews ?? existing?.totalViews),
      totalLikes: Value(totalLikes ?? existing?.totalLikes),
      cachedAt: DateTime.now(),
      followerCountsUpdatedAt: Value(countsUpdatedAt),
    );

    await into(profileStats).insertOnConflictUpdate(companion);
  }

  /// Get stats for a pubkey (returns null if not found or stale).
  ///
  /// A row older than [expiry] is a freshness miss only: this returns `null`
  /// so the caller refetches, but the row is left on disk. Deletion is governed
  /// by [profileStatsRetention] in [deleteExpired]. Use [getStatsRaw] to read a
  /// stale row while a refresh runs.
  Future<ProfileStatRow?> getStats(
    String pubkey, {
    Duration expiry = profileStatsCacheDuration,
  }) async {
    final query = select(profileStats)..where((t) => t.pubkey.equals(pubkey));
    final result = await query.getSingleOrNull();

    if (result == null) return null;

    if (result.cachedAt.isBefore(DateTime.now().subtract(expiry))) {
      return null;
    }

    return result;
  }

  /// Delete stats for a pubkey
  Future<int> deleteStats(String pubkey) {
    return (delete(profileStats)..where((t) => t.pubkey.equals(pubkey))).go();
  }

  /// Deletes rows older than the [retention] window ([profileStatsRetention],
  /// 30 days by default).
  ///
  /// A row is deleted only when `cached_at` and `follower_counts_updated_at`
  /// are both older than the window. A row whose `follower_counts_updated_at`
  /// is NULL (written before that column existed, or never given a count) is
  /// judged by `cached_at` alone.
  ///
  /// Called from `AppDatabase.runStartupCleanup`. Freshness
  /// ([profileStatsCacheDuration]) plays no part here: a stale row stays until
  /// the retention window passes.
  Future<int> deleteExpired({
    Duration retention = profileStatsRetention,
  }) {
    final cutoff = DateTime.now().subtract(retention);
    return (delete(profileStats)..where(
          (t) =>
              t.cachedAt.isSmallerThanValue(cutoff) &
              (t.followerCountsUpdatedAt.isNull() |
                  t.followerCountsUpdatedAt.isSmallerThanValue(cutoff)),
        ))
        .go();
  }

  /// Read the stats row without expiry checking.
  ///
  /// Unlike [getStats], this returns stale rows too.
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
