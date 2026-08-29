// ABOUTME: Shared Hive box names used by app storage owners and wipe policy.
// ABOUTME: Keeps cache recovery classification tied to the boxes it can affect.

abstract final class HiveBoxNames {
  static const hashtagStats = 'hashtag_stats';
  static const peopleLists = 'people_lists_v1';
  static const pendingUploads = 'pending_uploads';
  static const notifications = 'notifications';
  static const pushNotificationPreferencesDirty =
      'push_notification_preferences_dirty';

  static const Set<String> all = {
    hashtagStats,
    peopleLists,
    pendingUploads,
    notifications,
    pushNotificationPreferencesDirty,
  };
}
