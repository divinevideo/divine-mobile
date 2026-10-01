// ABOUTME: Web builds: every locale but English is a deferred library, fetched
// ABOUTME: on demand and cached here so later lookups are synchronous.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';

/// Localizations fetched so far, keyed by language code.
///
/// English is compiled into the main bundle rather than deferred: it is the
/// fallback a context-less lookup needs before any other locale has loaded,
/// and the most common UI language, so most visitors fetch no extra file.
final Map<String, AppLocalizations> _loaded = {'en': AppLocalizationsEn()};

/// Downloads in flight, keyed by language code, so concurrent requests for one
/// locale share a single fetch.
final Map<String, Future<void>> _pending = {};

/// Fetches a locale's deferred library; the generated lookup does exactly that.
@visibleForTesting
Future<AppLocalizations> Function(Locale locale) loadDeferredAppLocalizations =
    lookupAppLocalizations;

/// The localizations for [locale] once they are loaded, or `null` while its
/// deferred library has not been fetched yet.
AppLocalizations? loadedAppLocalizations(Locale locale) =>
    _loaded[locale.languageCode];

/// Fetches [locale]'s deferred library unless it is already loaded, so that
/// [loadedAppLocalizations] returns it from then on.
///
/// Throws whatever the fetch throws; a failed fetch is not cached, so the next
/// call retries it.
Future<void> ensureAppLocalizationsLoaded(Locale locale) {
  final languageCode = locale.languageCode;
  if (_loaded.containsKey(languageCode)) return SynchronousFuture<void>(null);
  return _pending[languageCode] ??= loadDeferredAppLocalizations(locale)
      .then<void>((localizations) => _loaded[languageCode] = localizations)
      // A block body, not `=> _pending.remove(...)`: that returns this very
      // future, and whenComplete would then wait for itself forever.
      .whenComplete(() {
        _pending.remove(languageCode);
      });
}

/// Forgets every fetched locale except English.
@visibleForTesting
void resetLoadedAppLocalizations() {
  _loaded.removeWhere((languageCode, _) => languageCode != 'en');
  _pending.clear();
  loadDeferredAppLocalizations = lookupAppLocalizations;
}
