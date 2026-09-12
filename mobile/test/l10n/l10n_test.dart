import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';

void main() {
  group('AppLocalizations', () {
    testWidgets('provides English localizations by default', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.appTitle, equals('Divine'));
      expect(l10n.settingsTitle, equals('Settings'));
    });

    testWidgets('supports Spanish locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Ajustes'));
    });

    testWidgets('supports Bulgarian locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('bg'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Настройки'));
      expect(l10n.settingsAppLanguageTitle, equals('Език на приложението'));
    });

    testWidgets('supports Telugu locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('te'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('సెట్టింగ్‌లు'));
      expect(l10n.settingsAppLanguageTitle, equals('యాప్ భాష'));
    });

    testWidgets('supports Amharic locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('am'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('ቅንብሮች'));
      expect(l10n.settingsAppLanguageTitle, equals('የመተግበሪያ ቋንቋ'));
    });

    testWidgets('supports Vietnamese locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('vi'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Cài đặt'));
      expect(l10n.settingsAppLanguageTitle, equals('Ngôn ngữ ứng dụng'));
    });

    testWidgets('supports Urdu locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ur'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('ترتیبات'));
      expect(l10n.settingsAppLanguageTitle, equals('ایپ کی زبان'));
    });

    testWidgets('supports Chinese locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('设置'));
      expect(l10n.settingsAppLanguageTitle, equals('应用语言'));
    });

    testWidgets('supports Malay locale', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ms'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Tetapan'));
      expect(l10n.settingsAppLanguageTitle, equals('Bahasa aplikasi'));
    });

    testWidgets('falls back to English for unsupported locale', (tester) async {
      late AppLocalizations l10n;

      // Russian is not a supported locale. We force the resolution
      // callback to return English, verifying the app gracefully
      // falls back to the English ARB strings.
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsTitle, equals('Settings'));
    });

    testWidgets('parameterized string works for version', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.settingsVersion('1.0.0+42'), equals('Version 1.0.0+42'));
    });

    testWidgets('plural string works for drafts message', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final singleDraft = l10n.settingsUnsavedDraftsMessage(1);
      expect(singleDraft, contains('1 unsaved draft'));
      expect(singleDraft, contains('it'));

      final multipleDrafts = l10n.settingsUnsavedDraftsMessage(3);
      expect(multipleDrafts, contains('3 unsaved drafts'));
      expect(multipleDrafts, contains('them'));
    });

    testWidgets('plural string works for developer mode taps remaining', (
      tester,
    ) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        l10n.settingsDeveloperModeTapsRemaining(3),
        equals('3 more taps to enable developer mode'),
      );
    });

    testWidgets('plural string works for done count', (tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          localeListResolutionCallback: resolveAppUiLocale,
          home: Builder(
            builder: (context) {
              l10n = context.l10n;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(l10n.contentPreferencesDoneCount(2), equals('Done (2 selected)'));
    });

    test('people-list screen user-facing strings use l10n keys', () {
      final source = File(
        'lib/screens/user_list_people_screen.dart',
      ).readAsStringSync();

      for (final hardcodedString in [
        "'People list'",
        "'List not found'",
        "'This list may have been deleted.'",
        "'No people in this list'",
        "'Add some people to get started'",
        "'No videos yet'",
        "'Videos from list members will appear here'",
        "'No videos available'",
        "'Failed to load videos'",
        "'Video not available'",
        "'Back to grid'",
        "'Error loading videos'",
      ]) {
        expect(
          source,
          isNot(contains(hardcodedString)),
          reason: '$hardcodedString should be read from context.l10n.',
        );
      }
    });
  });
}
