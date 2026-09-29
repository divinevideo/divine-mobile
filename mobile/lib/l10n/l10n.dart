import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart' as framework;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;
import 'package:openvine/l10n/generated/app_localizations.dart' as generated;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/loaded_app_localizations.dart';

export 'package:openvine/l10n/generated/app_localizations.dart'
    hide lookupAppLocalizations;

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// The localizations for [locale], without waiting.
///
/// `flutter gen-l10n` runs with `use-deferred-loading`, so its own
/// `lookupAppLocalizations` returns a `Future` even where nothing is deferred.
/// This one does not: native builds and tests compile every locale in and
/// resolve it immediately.
///
/// On the web a locale other than English is fetched the first time the app
/// renders in it. Until then this returns English, the fallback the app shows
/// for any unsupported locale too; that only affects a context-less caller
/// running before the UI has loaded its locale.
AppLocalizations lookupAppLocalizations(Locale locale) =>
    loadedAppLocalizations(locale) ??
    loadedAppLocalizations(const Locale('en'))!;

/// Every delegate an app-root widget in this app registers.
///
/// Two departures from the generated [AppLocalizations.localizationsDelegates]:
///
/// * The app's own strings load through a delegate that resolves synchronously
///   wherever the locale is already compiled in, instead of the generated one,
///   which always waits for a deferred library. Only the web defers, so native
///   builds and tests still paint translated text in their first frame.
/// * `flutter gen-l10n` has no notion of `material_ui` and always emits
///   `flutter_localizations`' `Global*Localizations`. Those satisfy the
///   framework's `MaterialLocalizations`, which since #8916 is a different
///   type from the one `material_ui` widgets look up. On its own, that list
///   leaves non-English locales without a supported `material_ui`
///   `MaterialLocalizations` delegate. Widgets such as `DiVineAppBar` read
///   `MaterialLocalizations.backButtonTooltip` unconditionally, so those
///   locales would throw when rendering navigation semantics. The appended
///   delegates provide the corresponding `material_ui` types.
///
/// The framework delegates are the generated list's own, in its order; a test
/// pins that.
const List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates =
    <LocalizationsDelegate<dynamic>>[
      _AppLocalizationsLoader(),
      framework.GlobalMaterialLocalizations.delegate,
      framework.GlobalCupertinoLocalizations.delegate,
      framework.GlobalWidgetsLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ];

/// Loads [AppLocalizations] synchronously when the locale is already
/// available, and from its deferred library otherwise.
class _AppLocalizationsLoader extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsLoader();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.delegate.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) {
    final loaded = loadedAppLocalizations(locale);
    if (loaded != null) return SynchronousFuture(loaded);
    return generated.lookupAppLocalizations(locale).then((localizations) {
      rememberLoadedAppLocalizations(locale, localizations);
      return localizations;
    });
  }

  @override
  bool shouldReload(_AppLocalizationsLoader old) => false;
}
