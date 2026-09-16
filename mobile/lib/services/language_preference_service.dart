// ABOUTME: Service for managing the user's preferred content language
// ABOUTME: Stores ISO-639-1 language code used for NIP-32 labeling on video events

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for managing the user's preferred content language.
///
/// The language code is used to tag published video events with NIP-32
/// self-labeling (`L`/`l` tags with ISO-639-1 namespace).
///
/// When no custom language is set, the device's OS language is used.
class LanguagePreferenceService {
  /// SharedPreferences key for the content language preference
  static const String prefsKey = 'content_language';

  String? _customLanguage;
  Future<void>? _initializeFuture;
  final Set<VoidCallback> _listeners = {};

  /// Whether the user has overridden the default device language.
  bool get isCustomLanguageSet => _customLanguage != null;

  /// The language the user explicitly chose, or `null` if they never chose.
  ///
  /// Unlike [contentLanguage] this never falls back to the OS locale. Use it
  /// when *claiming* what language a piece of content is in — a phone set to
  /// German is not evidence that the video is German.
  String? get declaredContentLanguage => _customLanguage;

  /// Returns the content language code (ISO-639-1).
  ///
  /// If the user has set a custom language, returns that.
  /// Otherwise returns the device's OS language code.
  String get contentLanguage =>
      _customLanguage ?? PlatformDispatcher.instance.locale.languageCode;

  /// Initialize the service by loading the saved preference.
  Future<void> initialize() async {
    _initializeFuture ??= _loadPreference();
    await _initializeFuture;
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _customLanguage = prefs.getString(prefsKey);
    } catch (e) {
      Log.error(
        'Error loading language preference: $e',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Set the content language preference.
  ///
  /// [languageCode] must be an ISO-639-1 code (e.g. `'en'`, `'es'`, `'pt'`).
  Future<void> setContentLanguage(String languageCode) async {
    try {
      await initialize();
      if (_customLanguage == languageCode) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, languageCode);
      _customLanguage = languageCode;
      _notifyListeners();

      Log.debug(
        'Content language set to: $languageCode',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error saving language preference: $e',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Clear the custom language preference, reverting to device default.
  Future<void> clearContentLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
      _customLanguage = null;
      _notifyListeners();

      Log.debug(
        'Content language cleared, using device default',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error clearing language preference: $e',
        name: 'LanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Map of common ISO-639-1 language codes to display names.
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'am': 'Amharic',
    'bg': 'Bulgarian',
    'es': 'Spanish',
    'pt': 'Portuguese',
    'ja': 'Japanese',
    'fr': 'French',
    'de': 'German',
    'zh': 'Chinese',
    'ko': 'Korean',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'it': 'Italian',
    'ru': 'Russian',
    'tr': 'Turkish',
    'nl': 'Dutch',
    'pl': 'Polish',
    'sv': 'Swedish',
    'te': 'Telugu',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'id': 'Indonesian',
    'uk': 'Ukrainian',
    'ur': 'Urdu',
    'ms': 'Malay',
  };

  /// Returns the display name for a language code, or the code itself
  /// if not found in the supported languages map.
  static String displayNameFor(String languageCode) {
    return supportedLanguages[languageCode] ?? languageCode.toUpperCase();
  }

  /// Register a listener for content-language preference changes.
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener previously registered with [addListener].
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Release registered listeners when the provider is disposed.
  void dispose() {
    _listeners.clear();
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      try {
        listener();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'language preference service',
            context: ErrorDescription(
              'while dispatching content-language preference notifications',
            ),
          ),
        );
      }
    }
  }
}
