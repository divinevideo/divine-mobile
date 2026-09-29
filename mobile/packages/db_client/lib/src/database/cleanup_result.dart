// ABOUTME: Result model for database startup cleanup operations.
// ABOUTME: Contains counts of expired data deleted during cleanup.

/// Result of database startup cleanup operations.
///
/// Contains counts of how many expired/old records were deleted
/// from each table during the cleanup process.
class CleanupResult {
  /// Creates a cleanup result with the given deletion counts.
  const CleanupResult({
    required this.expiredEventsDeleted,
    required this.expiredProfileStatsDeleted,
    required this.oldNotificationsDeleted,
    required this.orphanedVideoMetricsDeleted,
    required this.evictedUserProfilesDeleted,
  });

  /// Number of expired Nostr events deleted (includes events with NULL expiry).
  final int expiredEventsDeleted;

  /// Number of expired profile stats deleted.
  final int expiredProfileStatsDeleted;

  /// Number of old notifications deleted.
  final int oldNotificationsDeleted;

  /// Number of `video_metrics` rows deleted whose `event_id` no longer has a
  /// matching `event` row (stranded because `foreign_keys` enforcement is
  /// off, so the declared `ON DELETE CASCADE` never fires on its own).
  final int orphanedVideoMetricsDeleted;

  /// Number of `user_profiles` rows evicted to enforce the row cap, oldest
  /// by `last_fetched` first.
  final int evictedUserProfilesDeleted;

  /// Total number of records deleted across all tables.
  int get totalDeleted =>
      expiredEventsDeleted +
      expiredProfileStatsDeleted +
      oldNotificationsDeleted +
      orphanedVideoMetricsDeleted +
      evictedUserProfilesDeleted;

  @override
  String toString() {
    return 'CleanupResult('
        'events: $expiredEventsDeleted, '
        'profileStats: $expiredProfileStatsDeleted, '
        'notifications: $oldNotificationsDeleted, '
        'orphanedVideoMetrics: $orphanedVideoMetricsDeleted, '
        'evictedUserProfiles: $evictedUserProfilesDeleted)';
  }
}
