// ABOUTME: Tests the web localizations cache: English is always available and
// ABOUTME: any other locale resolves synchronously once it has been fetched.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations_de.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/l10n/loaded_app_localizations_web.dart';

void main() {
  group('loadedAppLocalizations', () {
    test('has English before anything is fetched', () {
      expect(
        loadedAppLocalizations(const Locale('en')),
        isA<AppLocalizationsEn>(),
      );
    });

    test('has no other locale until it is remembered', () {
      expect(loadedAppLocalizations(const Locale('fr')), isNull);
    });

    test('returns a remembered locale synchronously', () {
      final german = AppLocalizationsDe();
      rememberLoadedAppLocalizations(const Locale('de'), german);

      expect(loadedAppLocalizations(const Locale('de')), same(german));
    });
  });
}
