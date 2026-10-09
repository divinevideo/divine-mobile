// ABOUTME: Tests the subtitle translation setting in content preferences.
// ABOUTME: Covers the default target, a kept source language, and the picker.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SubtitleTranslationSetting', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Widget buildSetting() {
      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const Scaffold(body: SubtitleTranslationSetting()),
        ),
      );
    }

    testWidgets('shows the target and keep-original rows with defaults', (
      tester,
    ) async {
      await tester.pumpWidget(buildSetting());
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.contentPreferencesSubtitleLanguage),
        findsOneWidget,
      );
      expect(
        find.text(l10n.contentPreferencesSubtitleKeepOriginal),
        findsOneWidget,
      );
      expect(
        find.text(l10n.contentPreferencesSubtitleLanguageFollowApp),
        findsOneWidget,
      );
      expect(
        find.text(l10n.contentPreferencesSubtitleKeepOriginalNone),
        findsOneWidget,
      );
    });

    testWidgets('shows a persisted kept source language by name', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'subtitle_keep_original_languages': ['ja'],
      });
      prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(buildSetting());
      await tester.pumpAndSettle();

      expect(find.text('Japanese'), findsOneWidget);
    });
  });
}
