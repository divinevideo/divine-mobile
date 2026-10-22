// ABOUTME: Persists whether front camera recordings are saved mirrored
// ABOUTME: A device setting, off by default, read when the camera opens

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for the "Mirror front camera" setting.
///
/// The front camera preview is always shown mirrored, like looking into a
/// mirror. Recordings are saved the way others see you, so a clip can look
/// flipped next to what the preview showed. When on, front camera clips and
/// stills are saved mirrored, exactly as previewed. Off by default: a
/// mirrored clip shows any text in the shot backwards.
///
/// This is a device preference, not account data: it describes how this
/// device's camera records, so it is declared [deviceScopedPrefsKeys] and
/// the account-cleanup sweep leaves it in place across an identity change.
class FrontCameraMirrorPreferenceService {
  FrontCameraMirrorPreferenceService(this._prefs);

  /// SharedPreferences key for the setting.
  static const String prefsKey = 'mirror_front_camera';

  /// Device-scoped, not account data. Declared beside the key so the
  /// preference-key guard can classify it.
  static const List<String> deviceScopedPrefsKeys = [prefsKey];

  final SharedPreferences _prefs;

  /// Whether front camera recordings are saved mirrored.
  bool get isEnabled => _prefs.getBool(prefsKey) ?? false;

  /// Turns mirrored front camera recordings on or off.
  ///
  /// Takes effect the next time the camera opens; the camera reads it once
  /// when it sets up its outputs.
  Future<void> setEnabled(bool enabled) async {
    try {
      await _prefs.setBool(prefsKey, enabled);
      Log.debug(
        'Front camera mirror set to: $enabled',
        name: 'FrontCameraMirrorPreferenceService',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Error saving the front camera mirror preference: $e',
        name: 'FrontCameraMirrorPreferenceService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
