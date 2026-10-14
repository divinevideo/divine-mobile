// ABOUTME: Persists whether new camera recordings are backed up to the gallery
// ABOUTME: A device setting, off by default, read when a recording is signed

import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for the "Back up recordings to your gallery" setting (#10067).
///
/// When on, a copy of every new camera recording goes to the device gallery
/// once its capture signing settled, so the phone's own backup keeps it and
/// the gallery import can bring it back. Off by default: clips are private
/// until posted, and a copy in the gallery is visible to other apps with
/// media access and to cloud photo backups.
///
/// This is a device preference, not account data: the gallery is the
/// device's, so it is declared [deviceScopedPrefsKeys] and the
/// account-cleanup sweep leaves it in place across an identity change.
class RecordingGalleryBackupPreferenceService {
  RecordingGalleryBackupPreferenceService(this._prefs);

  /// SharedPreferences key for the setting.
  static const String prefsKey = 'back_up_recordings_to_gallery';

  /// Device-scoped, not account data. Declared beside the key so the
  /// preference-key guard can classify it.
  static const List<String> deviceScopedPrefsKeys = [prefsKey];

  final SharedPreferences _prefs;

  /// Whether new recordings are backed up to the gallery.
  bool get isEnabled => _prefs.getBool(prefsKey) ?? false;

  /// Turns backing up new recordings on or off.
  ///
  /// Recordings taken before it was turned on are not backed up, and turning
  /// it off also stops copies still waiting for their recording to be signed.
  Future<void> setEnabled(bool enabled) async {
    try {
      await _prefs.setBool(prefsKey, enabled);
      Log.debug(
        'Recording gallery backup set to: $enabled',
        name: 'RecordingGalleryBackupPreferenceService',
        category: LogCategory.system,
      );
    } catch (e, stackTrace) {
      Log.error(
        'Error saving the recording gallery backup preference: $e',
        name: 'RecordingGalleryBackupPreferenceService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}
