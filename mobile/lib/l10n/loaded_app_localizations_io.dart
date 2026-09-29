// ABOUTME: Native and test builds: every locale is compiled in, so the app
// ABOUTME: localizations resolve synchronously, exactly as before deferral.

import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_am.dart';
import 'package:openvine/l10n/generated/app_localizations_ar.dart';
import 'package:openvine/l10n/generated/app_localizations_bg.dart';
import 'package:openvine/l10n/generated/app_localizations_de.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/generated/app_localizations_es.dart';
import 'package:openvine/l10n/generated/app_localizations_fil.dart';
import 'package:openvine/l10n/generated/app_localizations_fr.dart';
import 'package:openvine/l10n/generated/app_localizations_id.dart';
import 'package:openvine/l10n/generated/app_localizations_it.dart';
import 'package:openvine/l10n/generated/app_localizations_ja.dart';
import 'package:openvine/l10n/generated/app_localizations_ko.dart';
import 'package:openvine/l10n/generated/app_localizations_ms.dart';
import 'package:openvine/l10n/generated/app_localizations_nl.dart';
import 'package:openvine/l10n/generated/app_localizations_pl.dart';
import 'package:openvine/l10n/generated/app_localizations_pt.dart';
import 'package:openvine/l10n/generated/app_localizations_ro.dart';
import 'package:openvine/l10n/generated/app_localizations_sv.dart';
import 'package:openvine/l10n/generated/app_localizations_te.dart';
import 'package:openvine/l10n/generated/app_localizations_tr.dart';
import 'package:openvine/l10n/generated/app_localizations_ur.dart';
import 'package:openvine/l10n/generated/app_localizations_vi.dart';
import 'package:openvine/l10n/generated/app_localizations_zh.dart';

/// The localizations for [locale], built without waiting. Never `null` here;
/// the nullable type matches the web implementation, where a locale may not
/// have loaded yet.
///
/// Native builds gain nothing from deferring a locale — they ship every one in
/// the binary — so they keep resolving synchronously: a
/// `Localizations` widget then paints translated text in its first frame, and
/// a context-less caller can read a string straight away.
///
/// Mirrors the language-code switch in the generated `lookupAppLocalizations`,
/// which a test pins locale by locale.
///
/// Throws a [FlutterError] for a locale the app does not support.
AppLocalizations? loadedAppLocalizations(Locale locale) =>
    switch (locale.languageCode) {
      'am' => AppLocalizationsAm(),
      'ar' => AppLocalizationsAr(),
      'bg' => AppLocalizationsBg(),
      'de' => AppLocalizationsDe(),
      'en' => AppLocalizationsEn(),
      'es' => AppLocalizationsEs(),
      'fil' => AppLocalizationsFil(),
      'fr' => AppLocalizationsFr(),
      'id' => AppLocalizationsId(),
      'it' => AppLocalizationsIt(),
      'ja' => AppLocalizationsJa(),
      'ko' => AppLocalizationsKo(),
      'ms' => AppLocalizationsMs(),
      'nl' => AppLocalizationsNl(),
      'pl' => AppLocalizationsPl(),
      'pt' => AppLocalizationsPt(),
      'ro' => AppLocalizationsRo(),
      'sv' => AppLocalizationsSv(),
      'te' => AppLocalizationsTe(),
      'tr' => AppLocalizationsTr(),
      'ur' => AppLocalizationsUr(),
      'vi' => AppLocalizationsVi(),
      'zh' => AppLocalizationsZh(),
      _ => throw FlutterError(
        'AppLocalizations does not support the locale "$locale".',
      ),
    };

/// Records localizations fetched asynchronously for [locale].
void rememberLoadedAppLocalizations(
  Locale locale,
  AppLocalizations localizations,
) {
  // Intentional no-op: native builds never load a locale asynchronously, so
  // there is nothing to remember.
}
