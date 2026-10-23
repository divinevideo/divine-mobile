// ABOUTME: Stores the viewer's subtitle translation preferences: the target
// ABOUTME: language to translate into, and which source languages stay original.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/services/account_preference_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Manages how the viewer wants subtitle languages handled.
///
/// Two preferences:
/// - **Target language** — the language subtitles are translated into. `null`
///   means "follow the app locale".
/// - **Keep original** — source languages the viewer reads as-is, so they are
///   never translated.
///
/// All values are normalized to the bare BCP-47 primary subtag (`de-CH` ->
/// `de`), matching the language the publish path writes onto `text-track` tags.
class SubtitleLanguagePreferenceService implements Listenable {
  SubtitleLanguagePreferenceService({
    AccountPreferenceStore? accountPreferences,
  }) : _accountPreferences = accountPreferences {
    _accountSubscription = _accountPreferences?.changes.listen(
      (_) => _reloadAccountPreferences(),
    );
  }
  final AccountPreferenceStore? _accountPreferences;
  StreamSubscription<void>? _accountSubscription;
  void _reloadAccountPreferences() {
    // Account reads are synchronous; no old storage load can win over them.
    unawaited(reloadFromStorage());
  }

  final Set<VoidCallback> _listeners = {};

  @override
  void addListener(VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(listener);

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  /// Reloads this account-scoped instance and refreshes active subtitle tracks.
  Future<void> reloadFromStorage() async {
    await initialize();
    _targetLanguage = null;
    _keepOriginalLanguages = {};
    _initializeFuture = _load();
    await _initializeFuture;
    _notifyListeners();
  }

  /// SharedPreferences key for the target language.
  static const String targetLanguageStorageKey = 'subtitle_target_language';

  /// SharedPreferences key for the set of languages shown in the original.
  static const String keepOriginalLanguagesStorageKey =
      'subtitle_keep_original_languages';

  /// Language codes that do not identify a real source language.
  static const Set<String> _unknownLanguageCodes = {'und', 'auto'};

  String? _targetLanguage;
  Set<String> _keepOriginalLanguages = <String>{};
  Future<void>? _initializeFuture;

  /// The explicit target language, or `null` to follow the app locale.
  String? get targetLanguage => _targetLanguage;

  /// Source languages the viewer wants shown in the original.
  Set<String> get keepOriginalLanguages =>
      Set<String>.unmodifiable(_keepOriginalLanguages);

  /// Loads persisted preferences once; safe to call repeatedly.
  Future<void> initialize() async {
    _initializeFuture ??= _load();
    await _initializeFuture;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _targetLanguage = _normalize(
        (_accountPreferences == null
                ? prefs.getString(targetLanguageStorageKey)
                : _accountPreferences.read(targetLanguageStorageKey))
            as String?,
      );
      _keepOriginalLanguages = _normalizeAll(
        ((_accountPreferences == null
                        ? prefs.getStringList(keepOriginalLanguagesStorageKey)
                        : _accountPreferences.read(
                            keepOriginalLanguagesStorageKey,
                          ))
                    as List?)
                ?.cast<String>() ??
            const [],
      );
    } catch (e) {
      Log.error(
        'Error loading subtitle language preferences: $e',
        name: 'SubtitleLanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Sets the target language; pass `null` to follow the app locale.
  Future<void> setTargetLanguage(String? languageCode) async {
    await initialize();
    final normalized = _normalize(languageCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accountPreferences != null) {
        await _accountPreferences.write(targetLanguageStorageKey, normalized);
      } else if (normalized == null) {
        await prefs.remove(targetLanguageStorageKey);
      } else {
        await prefs.setString(targetLanguageStorageKey, normalized);
      }
      _targetLanguage = _accountPreferences == null
          ? normalized
          : _accountPreferences.read(targetLanguageStorageKey) as String?;
      _notifyListeners();
    } catch (e) {
      if (_accountPreferences != null) rethrow;
      Log.error(
        'Error saving subtitle target language: $e',
        name: 'SubtitleLanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  /// Replaces the set of source languages to show in the original.
  Future<void> setKeepOriginalLanguages(Set<String> languages) async {
    await initialize();
    final normalized = _normalizeAll(languages);

    try {
      final prefs = await SharedPreferences.getInstance();
      final sorted = normalized.toList()..sort();
      if (_accountPreferences != null) {
        await _accountPreferences.write(
          keepOriginalLanguagesStorageKey,
          sorted,
        );
      } else {
        await prefs.setStringList(keepOriginalLanguagesStorageKey, sorted);
      }
      _keepOriginalLanguages = _accountPreferences == null
          ? normalized
          : ((_accountPreferences.read(
                  keepOriginalLanguagesStorageKey,
                ) as List?)?.cast<String>().toSet() ??
                {});
      _notifyListeners();
    } catch (e) {
      if (_accountPreferences != null) rethrow;
      Log.error(
        'Error saving subtitle keep-original languages: $e',
        name: 'SubtitleLanguagePreferenceService',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {
    unawaited(_accountSubscription?.cancel());
    _listeners.clear();
  }

  /// The language to translate into: the explicit target, else [appLocaleCode].
  String effectiveTargetLanguage(String appLocaleCode) =>
      _targetLanguage ?? _normalize(appLocaleCode) ?? appLocaleCode;

  /// Whether a track in [sourceLanguage] should be translated for a viewer
  /// whose app locale is [appLocaleCode].
  ///
  /// Returns `false` — show the original — when the source is missing or
  /// unknown, already the target language, or listed under keep-original.
  bool shouldTranslate({
    required String? sourceLanguage,
    required String appLocaleCode,
  }) {
    final source = _normalize(sourceLanguage);
    if (source == null || _unknownLanguageCodes.contains(source)) return false;
    if (source == effectiveTargetLanguage(appLocaleCode)) return false;
    if (_keepOriginalLanguages.contains(source)) return false;
    return true;
  }

  static String? _normalize(String? code) {
    final trimmed = code?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split('-').first;
  }

  static Set<String> _normalizeAll(Iterable<String> codes) {
    final result = <String>{};
    for (final code in codes) {
      final normalized = _normalize(code);
      if (normalized != null) result.add(normalized);
    }
    return result;
  }
}
