// ABOUTME: Resolves AppLocalizations outside of a BuildContext.
// ABOUTME: Used by services constructed via Riverpod providers / factories.

import 'dart:ui';

import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Returns [AppLocalizations] for the user's current preferred locale,
/// or for the device default falling back through [resolveAppUiLocale].
///
/// Mirrors the locale that `MaterialApp.router` ends up using at runtime
/// (via `LocaleCubit` + `localeListResolutionCallback: resolveAppUiLocale`)
/// without requiring a [BuildContext]. Use this from services that are
/// constructed inside Riverpod factories or other context-less call sites
/// — e.g. `CollaboratorInviteService` built by `VideoPublishService`.
AppLocalizations currentAppL10n(SharedPreferences prefs) =>
    lookupAppLocalizations(currentAppUiLocale(prefs));

/// Returns the [Locale] the app UI is currently rendering in, without a
/// [BuildContext].
///
/// Mirrors what `MaterialApp.router` resolves at runtime: the user's saved
/// preference (`LocaleCubit`) when set, otherwise the device locales,
/// resolved through [resolveAppUiLocale] (which can fall back to
/// English). This is the resolved value, not the raw device language.
Locale currentAppUiLocale(SharedPreferences prefs) {
  final override = appUiLocaleOverride(prefs);
  return resolveAppUiLocale(
    override == null ? PlatformDispatcher.instance.locales : [override],
    AppLocalizations.supportedLocales,
  );
}

/// The saved Settings language, or null when following the device.
Locale? appUiLocaleOverride(SharedPreferences prefs) {
  final saved = prefs.getString(LocalePreferenceService.prefsKey);
  return saved == null ? null : Locale(saved);
}
