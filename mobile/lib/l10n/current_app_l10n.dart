// ABOUTME: Resolves AppLocalizations outside of a BuildContext.
// ABOUTME: Used by services constructed via Riverpod providers / factories.

import 'dart:ui';

import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/loaded_app_localizations.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Returns [AppLocalizations] for the user's current preferred locale,
/// or for the device default falling back through [resolveAppUiLocale].
///
/// Mirrors the locale that `MaterialApp.router` ends up using at runtime
/// (via `LocaleCubit` + `localeListResolutionCallback: resolveAppUiLocale`)
/// without requiring a [BuildContext]. Use this from services that are
/// constructed inside Riverpod factories or other context-less call sites
/// — e.g. `CollaboratorInviteService` built by `VideoPublishService`.
///
/// On the web that locale has to have been downloaded first, or this returns
/// English: startup does it with [preloadAppUiLocalizations] before any such
/// service exists, and `LocaleCubit` before it switches the language.
AppLocalizations currentAppL10n(SharedPreferences prefs) =>
    lookupAppLocalizations(currentAppUiLocale(prefs));

/// Downloads the language the app UI renders in, so [currentAppL10n] returns
/// it rather than the English fallback.
///
/// Only the web defers languages; on native builds this completes at once.
/// Call it before anything reads [currentAppL10n] — context-less services
/// capture their strings when they are built, so one built while the
/// download is still running would keep English for its lifetime.
///
/// A failed download is logged, not thrown: the UI's own localization
/// delegate retries it, and the app is usable in English meanwhile.
Future<void> preloadAppUiLocalizations(SharedPreferences prefs) =>
    preloadAppUiLocalizationsFor(appUiLocaleOverride(prefs));

/// [preloadAppUiLocalizations] for a language [override] the user is
/// switching to, or for the device language when [override] is null.
Future<void> preloadAppUiLocalizationsFor(Locale? override) async {
  final locale = _resolveAppUiLocale(override);
  try {
    await ensureAppLocalizationsLoaded(locale);
  } on Object catch (error, stackTrace) {
    Log.warning(
      'Could not download the $locale UI language; context-free strings '
      'fall back to English until it loads',
      name: 'AppLocalizations',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Returns the [Locale] the app UI is currently rendering in, without a
/// [BuildContext].
///
/// Mirrors what `MaterialApp.router` resolves at runtime: the user's saved
/// preference (`LocaleCubit`) when set, otherwise the device locales,
/// resolved through [resolveAppUiLocale] (which can fall back to
/// English). This is the resolved value, not the raw device language.
Locale currentAppUiLocale(SharedPreferences prefs) =>
    _resolveAppUiLocale(appUiLocaleOverride(prefs));

Locale _resolveAppUiLocale(Locale? override) => resolveAppUiLocale(
  override == null ? PlatformDispatcher.instance.locales : [override],
  AppLocalizations.supportedLocales,
);

/// The saved Settings language, or null when following the device.
Locale? appUiLocaleOverride(SharedPreferences prefs) {
  final saved = prefs.getString(LocalePreferenceService.prefsKey);
  return saved == null ? null : Locale(saved);
}
