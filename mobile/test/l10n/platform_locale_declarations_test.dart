// ABOUTME: Verifies platform locale declarations stay aligned with app l10n.
// ABOUTME: Keeps Android/iOS language pickers in sync with shipped locales.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';

void main() {
  group('platform locale declarations', () {
    final appLocaleCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();

    test('includes Bulgarian in app-supported locales', () {
      expect(appLocaleCodes, contains('bg'));
    });

    test('includes Amharic in app-supported locales', () {
      expect(appLocaleCodes, contains('am'));
    });

    test('includes Vietnamese in app-supported locales', () {
      expect(appLocaleCodes, contains('vi'));
    });

    test('includes Urdu in app-supported locales', () {
      expect(appLocaleCodes, contains('ur'));
    });

    test('includes Chinese in app-supported locales', () {
      expect(appLocaleCodes, contains('zh'));
    });

    test('includes Malay in app-supported locales', () {
      expect(appLocaleCodes, contains('ms'));
    });

    test('includes Telugu in app-supported locales', () {
      expect(appLocaleCodes, contains('te'));
    });

    test('Android per-app language config includes all app locales', () {
      final androidConfig = File(
        'android/app/src/main/res/xml/locales_config.xml',
      ).readAsStringSync();

      for (final localeCode in appLocaleCodes) {
        expect(
          androidConfig,
          contains('android:name="$localeCode"'),
          reason: 'Android locale config is missing $localeCode',
        );
      }
    });

    test('iOS Info.plist declares all app locales', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

      for (final localeCode in appLocaleCodes) {
        expect(
          infoPlist,
          contains('<string>$localeCode</string>'),
          reason: 'CFBundleLocalizations is missing $localeCode',
        );
      }
    });

    test('Xcode knownRegions includes all app locales', () {
      final projectFile = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();

      for (final localeCode in appLocaleCodes) {
        expect(
          projectFile,
          contains(RegExp('\\b${RegExp.escape(localeCode)},')),
          reason: 'Xcode knownRegions is missing $localeCode',
        );
      }
    });
  });
}
