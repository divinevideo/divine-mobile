import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for only showing Divine-hosted videos.
///
/// Defaults to `true` so new installs only see videos served from
/// `*.divine.video` hosts that we can moderate. Users opt in to the
/// wider Nostr media-host space by toggling this off in Safety settings.
class DivineHostFilterService extends ChangeNotifier {
  DivineHostFilterService(
    this._prefs, {
    AccountPreferenceStore? accountPreferences,
  }) : _accountPreferences = accountPreferences,
       _showDivineHostedOnly =
           (accountPreferences?.read(showDivineHostedOnlyStorageKey) ??
                   (accountPreferences == null
                       ? _prefs.getBool(showDivineHostedOnlyStorageKey)
                       : null))
               as bool? ??
           true {
    _accountSubscription = _accountPreferences?.changes.listen(
      (_) => reloadFromStorage(),
    );
  }

  final AccountPreferenceStore? _accountPreferences;
  StreamSubscription<void>? _accountSubscription;

  @override
  void dispose() {
    unawaited(_accountSubscription?.cancel());
    super.dispose();
  }

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
    final stored = (_accountPreferences == null
        ? _read(_prefs)
        : _accountPreferences.read(showDivineHostedOnlyStorageKey) as bool? ??
              true);
    if (stored == _showDivineHostedOnly) return;

    _showDivineHostedOnly = stored;
    notifyListeners();
  }

  Future<void> setShowDivineHostedOnly(bool value) async {
    if (_showDivineHostedOnly == value && _accountPreferences == null) return;

    if (_accountPreferences != null) {
      await _accountPreferences.write(showDivineHostedOnlyStorageKey, value);
    } else {
      await _prefs.setBool(showDivineHostedOnlyStorageKey, value);
    }
    _showDivineHostedOnly = _accountPreferences == null
        ? value
        : _accountPreferences.read(showDivineHostedOnlyStorageKey) as bool? ??
              true;
    notifyListeners();
  }
}
