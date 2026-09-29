// ABOUTME: Web builds: every locale but English is a deferred library, fetched
// ABOUTME: on first use and cached here so later lookups are synchronous.

import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';

/// Localizations fetched so far, keyed by language code.
///
/// English is compiled into the main bundle rather than deferred: it is the
/// fallback a context-less lookup needs before any other locale has loaded,
/// and the most common UI language, so most visitors fetch no extra file.
final Map<String, AppLocalizations> _loaded = {'en': AppLocalizationsEn()};

/// The localizations for [locale] once they are loaded, or `null` while its
/// deferred library has not been fetched yet.
AppLocalizations? loadedAppLocalizations(Locale locale) =>
    _loaded[locale.languageCode];

/// Records localizations fetched asynchronously for [locale], so the next
/// lookup for it resolves synchronously.
void rememberLoadedAppLocalizations(
  Locale locale,
  AppLocalizations localizations,
) {
  _loaded[locale.languageCode] = localizations;
}
