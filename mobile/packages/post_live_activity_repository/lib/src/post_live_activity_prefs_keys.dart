/// Preference keys the post Live Activity stores.
///
/// Both describe this device's Lock Screen, not an account, so they are
/// declared [deviceScopedPrefsKeys] and survive an account switch.
abstract final class PostLiveActivityPrefsKeys {
  /// The in-app toggle; absent means on.
  static const enabled = 'post_live_activity_enabled';

  /// Set once the first-run note has been shown on this device.
  static const firstRunNoteShown = 'post_live_activity_first_run_note_shown';

  /// Keys the account-cleanup sweep must leave in place.
  static const List<String> deviceScopedPrefsKeys = [
    enabled,
    firstRunNoteShown,
  ];
}
