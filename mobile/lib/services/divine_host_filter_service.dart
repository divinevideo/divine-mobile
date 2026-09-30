import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for only showing Divine-hosted videos.
///
/// Defaults to `true` so new installs only see videos served from
/// `*.divine.video` hosts that we can moderate. Users opt in to the
/// wider Nostr media-host space by toggling this off in Safety settings.
class DivineHostFilterService extends ChangeNotifier {
  DivineHostFilterService(this._prefs) : _showDivineHostedOnly = _read(_prefs);

  /// Public so `UserDataCleanupService` can clear it by reference.
  /// A copied literal cannot detect that this key was renamed (#8314).
  static const String showDivineHostedOnlyStorageKey =
      'show_divine_hosted_only';

  final SharedPreferences _prefs;
  bool _showDivineHostedOnly;

  bool get showDivineHostedOnly => _showDivineHostedOnly;

  static bool _read(SharedPreferences prefs) =>
      prefs.getBool(showDivineHostedOnlyStorageKey) ?? true;

  /// Re-reads the stored preference, notifying only when it changed.
  ///
  /// The account-boundary sweep clears the key and calls this, so every
  /// holder of this instance sees the incoming account's setting.
  void reloadFromStorage() {
    final stored = _read(_prefs);
    if (stored == _showDivineHostedOnly) return;

    _showDivineHostedOnly = stored;
    notifyListeners();
  }

  Future<void> setShowDivineHostedOnly(bool value) async {
    if (_showDivineHostedOnly == value) return;

    await _prefs.setBool(showDivineHostedOnlyStorageKey, value);
    _showDivineHostedOnly = value;
    notifyListeners();
  }
}
