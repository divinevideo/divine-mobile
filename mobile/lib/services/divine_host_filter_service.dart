import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for only showing Divine-hosted videos.
///
/// Defaults to `true` so new installs only see videos served from
/// `*.divine.video` hosts that we can moderate. Users opt in to the
/// wider Nostr media-host space by toggling this off in Safety settings.
class DivineHostFilterService extends ChangeNotifier {
  DivineHostFilterService(this._prefs)
    : _showDivineHostedOnly =
          _prefs.getBool(showDivineHostedOnlyStorageKey) ?? true;

  /// Public so `UserDataCleanupService` can clear it by reference.
  /// A copied literal cannot detect that this key was renamed (#8314).
  static const String showDivineHostedOnlyStorageKey =
      'show_divine_hosted_only';

  final SharedPreferences _prefs;
  bool _showDivineHostedOnly;

  bool get showDivineHostedOnly => _showDivineHostedOnly;

  Future<void> setShowDivineHostedOnly(bool value) async {
    if (_showDivineHostedOnly == value) return;

    await _prefs.setBool(showDivineHostedOnlyStorageKey, value);
    _showDivineHostedOnly = value;
    notifyListeners();
  }
}
