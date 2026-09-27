// ABOUTME: Shared Hive box names used by app storage owners and wipe policy.
// ABOUTME: Keeps cache recovery classification tied to the boxes it can affect.

abstract final class HiveBoxNames {
  static const peopleLists = 'people_lists_v1';
  static const pendingUploads = 'pending_uploads';
  static const notifications = 'notifications';
  static const pushNotificationPreferencesDirty =
      'push_notification_preferences_dirty';

  /// Retired name of the box that backed the deleted `HashtagCacheService`.
  ///
  /// Not in [all]: nothing opens this box anymore. Kept as the single
  /// shared owner of the string so `CacheRecoveryService` and
  /// `HiveStorageService` can each delete a leftover file from a device
  /// that opened it before the service was removed, without duplicating
  /// the literal.
  static const legacyHashtagStats = 'hashtag_stats';

  static const Set<String> all = {
    peopleLists,
    pendingUploads,
    notifications,
    pushNotificationPreferencesDirty,
  };
}
