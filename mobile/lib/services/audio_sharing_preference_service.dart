// ABOUTME: Service for managing the global audio sharing preference
// ABOUTME: Controls whether user's audio is available for reuse by default

import 'dart:async';

import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for managing the user's preference for making audio available
/// for reuse by other users. This is a global setting that can be overridden
/// on a per-video basis during publishing.
class AudioSharingPreferenceService {
  AudioSharingPreferenceService(
    this._prefs, {
    AccountPreferenceStore? accountPreferences,
  }) : _accountPreferences = accountPreferences {
    reloadFromStorage();
    _accountSubscription = _accountPreferences?.changes.listen(
      (_) => reloadFromStorage(),
    );
  }
  final AccountPreferenceStore? _accountPreferences;
  StreamSubscription<void>? _accountSubscription;
  Stream<void>? get changes => _accountPreferences?.changes;

  void reloadFromStorage() {
    _isAudioSharingEnabled =
        (_accountPreferences == null
                ? _prefs.getBool(prefsKey)
                : _accountPreferences.read(prefsKey))
            as bool? ??
        false;
  }

  void dispose() {
    unawaited(_accountSubscription?.cancel());
  }

  /// SharedPreferences key for the audio sharing preference
  static const String prefsKey = 'audio_sharing_enabled';

  final SharedPreferences _prefs;
  late bool _isAudioSharingEnabled;

  /// Whether the user has enabled audio sharing by default
  bool get isAudioSharingEnabled => _isAudioSharingEnabled;

  /// Set the audio sharing preference
  Future<void> setAudioSharingEnabled(bool enabled) async {
    try {
      if (_accountPreferences != null) {
        await _accountPreferences.write(prefsKey, enabled);
      } else {
        await _prefs.setBool(prefsKey, enabled);
      }
      _isAudioSharingEnabled = _accountPreferences == null
          ? enabled
          : _accountPreferences.read(prefsKey) as bool? ?? false;

      Log.debug(
        'Audio sharing preference set to: $enabled',
        name: 'AudioSharingPreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      if (_accountPreferences != null) rethrow;
      Log.error(
        'Error saving audio sharing preference: $e',
        name: 'AudioSharingPreferenceService',
        category: LogCategory.system,
      );
    }
  }
}
