// ABOUTME: Tests currentAppUiLocale, the context-less mirror of the UI locale
// ABOUTME: Covers the Settings preference winning over device resolution

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/current_app_l10n.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('currentAppUiLocale', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);
    tearDown(SharedPreferences.resetStatic);

    test('uses the language the user picked in Settings', () async {
      // The bug report's `locale` field is only worth routing by if it names
      // the language the user was actually reading, which for a Settings
      // choice is the saved preference rather than the device language.
      SharedPreferences.setMockInitialValues({
        LocalePreferenceService.prefsKey: 'de',
      });
      final prefs = await SharedPreferences.getInstance();

      expect(currentAppUiLocale(prefs).languageCode, 'de');
      expect(appUiLocaleOverride(prefs)?.languageCode, 'de');
    });

    test('resolves a stale Settings language like MaterialApp', () async {
      // LocaleCubit still supplies the saved locale to MaterialApp. Resolve
      // that preference, rather than selecting a different device language.
      SharedPreferences.setMockInitialValues({
        LocalePreferenceService.prefsKey: 'cs',
      });
      final prefs = await SharedPreferences.getInstance();

      final resolved = currentAppUiLocale(prefs);

      expect(resolved.languageCode, 'en');
      expect(currentAppL10n(prefs).localeName, 'en');
      expect(appUiLocaleOverride(prefs)?.languageCode, 'cs');
      expect(
        AppLocalizations.supportedLocales.map((l) => l.languageCode),
        contains(resolved.languageCode),
      );
    });

    test('has no override when Settings follows the device', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(appUiLocaleOverride(prefs), isNull);
    });
  });
}
