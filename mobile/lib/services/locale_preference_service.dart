// ABOUTME: Service for persisting the user's preferred app display locale
// ABOUTME: Separate from LanguagePreferenceService which handles Nostr content
// tagging

import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Persists the user's preferred app display locale to SharedPreferences.
///
/// This controls the `locale:` parameter on [MaterialApp], overriding the
/// device default when set. A `null` locale means "follow device language".
///
/// This is separate from [LanguagePreferenceService], which manages the
/// content language for NIP-32 tagging on video events.
class LocalePreferenceService {
  /// Creates a [LocalePreferenceService] backed by [sharedPreferences].
  const LocalePreferenceService({
    required SharedPreferences sharedPreferences,
    AccountPreferenceStore? accountPreferences,
  }) : _prefs = sharedPreferences,
       _accountPreferences = accountPreferences;

  final AccountPreferenceStore? _accountPreferences;
  Stream<void>? get changes => _accountPreferences?.changes;

  final SharedPreferences _prefs;

  /// SharedPreferences key for the app locale preference.
  static const String prefsKey = 'app_locale';

  /// Returns the stored locale code, or `null` if using device default.
  String? getLocale() {
    try {
      return (_accountPreferences == null
              ? _prefs.getString(prefsKey)
              : _accountPreferences.read(prefsKey))
          as String?;
    } catch (e) {
      Log.error(
        'Error reading app locale preference: $e',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Persists the selected locale code.
  ///
  /// [localeCode] must be an ISO-639-1 code (e.g. `'en'`, `'es'`, `'tr'`).
  Future<void> setLocale(String localeCode) async {
    try {
      if (_accountPreferences != null) {
        await _accountPreferences.write(prefsKey, localeCode);
      } else {
        await _prefs.setString(prefsKey, localeCode);
      }
      Log.debug(
        'App locale set to: $localeCode',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      if (_accountPreferences != null) rethrow;
      Log.error(
        'Error saving app locale preference: $e',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Clears the custom locale, reverting to device default.
  Future<void> clearLocale() async {
    try {
      if (_accountPreferences != null) {
        await _accountPreferences.write(prefsKey, null);
      } else {
        await _prefs.remove(prefsKey);
      }
      Log.debug(
        'App locale cleared, using device default',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      if (_accountPreferences != null) rethrow;
      Log.error(
        'Error clearing app locale preference: $e',
        name: 'LocalePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Map of supported locale codes to their native display names.
  ///
  /// Every locale that ships an ARB file is listed here. Users can pick
  /// any of them; untranslated keys fall back to English via
  /// `AppLocalizations` (see `l10n.yaml` / `MaterialApp.supportedLocales`).
  ///
  /// Add new entries here as translations are added.
  static const Map<String, String> supportedLocales = {
    'en': 'English',
    'am': 'አማርኛ',
    'ar': 'العربية',
    'bg': 'Български',
    'de': 'Deutsch',
    'es': 'Español',
    'fil': 'Filipino',
    'fr': 'Français',
    'id': 'Bahasa Indonesia',
    'it': 'Italiano',
    'ja': '日本語',
    'ko': '한국어',
    'ms': 'Bahasa Melayu',
    'nl': 'Nederlands',
    'pl': 'Polski',
    'pt': 'Português',
    'ro': 'Română',
    'sv': 'Svenska',
    'te': 'తెలుగు',
    'tr': 'Türkçe',
    'ur': 'اردو',
    'vi': 'Tiếng Việt',
    'zh': '简体中文',
  };

  /// Returns the native display name for a locale code, or the code
  /// uppercased if not in the supported list.
  static String nativeNameFor(String localeCode) {
    return supportedLocales[localeCode] ?? localeCode.toUpperCase();
  }
}
