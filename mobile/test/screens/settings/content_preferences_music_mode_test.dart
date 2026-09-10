// ABOUTME: Tests the Music mode toggle in content preferences (#7796).
// ABOUTME: Covers the iOS/Android gate and that a tap reaches the preference.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/content_preferences_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/music_mode_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

class _MockLanguagePreferenceService extends Mock
    implements LanguagePreferenceService {}

class _MockAccountLabelService extends Mock implements AccountLabelService {}

class _MockMusicModePreferenceService extends Mock
    implements MusicModePreferenceService {}

void main() {
  group('ContentPreferencesScreen Music mode toggle', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    late _MockAudioSharingPreferenceService audioSharingService;
    late _MockLanguagePreferenceService languageService;
    late _MockAccountLabelService accountLabelService;
    late _MockMusicModePreferenceService musicModeService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      audioSharingService = _MockAudioSharingPreferenceService();
      languageService = _MockLanguagePreferenceService();
      accountLabelService = _MockAccountLabelService();
      musicModeService = _MockMusicModePreferenceService();

      when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
      when(
        () => audioSharingService.setAudioSharingEnabled(any()),
      ).thenAnswer((_) async {});
      when(() => languageService.initialize()).thenAnswer((_) async {});
      when(() => languageService.contentLanguage).thenReturn('en');
      when(() => languageService.isCustomLanguageSet).thenReturn(false);
      when(() => accountLabelService.accountLabels).thenReturn({});
      when(() => accountLabelService.initialized).thenAnswer((_) async {});
      when(() => musicModeService.isMusicModeEnabled).thenReturn(false);
      when(
        () => musicModeService.setMusicModeEnabled(any()),
      ).thenAnswer((_) async {});
    });

    // testWidgets asserts every foundation debug var is unset when the body
    // returns, before tearDown runs — hence the in-body reset in `disposeTree`.
    // This tearDown only catches bodies that threw before reaching it.
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          audioSharingPreferenceServiceProvider.overrideWithValue(
            audioSharingService,
          ),
          languagePreferenceServiceProvider.overrideWithValue(languageService),
          accountLabelServiceProvider.overrideWithValue(accountLabelService),
          musicModePreferenceServiceProvider.overrideWithValue(
            musicModeService,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: const ContentPreferencesScreen(),
        ),
      );
    }

    Future<void> disposeTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    }

    Finder musicModeTile() => find.byWidgetPredicate(
      (widget) =>
          widget is DivineSwitchTile &&
          widget.title == l10n.contentPreferencesMusicMode,
    );

    test('an iOS override cannot determine the process-cached app themes', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final cachedDarkPlatform = VineTheme.theme.platform;
      final cachedLightPlatform = VineTheme.lightTheme.platform;
      debugDefaultTargetPlatformOverride = null;

      expect(cachedDarkPlatform, TargetPlatform.android);
      expect(cachedLightPlatform, TargetPlatform.android);
    });

    testWidgets('shows the toggle on iOS with its trade-off subtitle', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(musicModeTile(), findsOneWidget);
      expect(
        find.text(l10n.contentPreferencesMusicModeSubtitle),
        findsOneWidget,
      );

      await disposeTree(tester);
    });

    testWidgets('shows the toggle on Android too', (tester) async {
      // Android honours the preference when it resolves the recording audio
      // source (#8079), so the switch has to be reachable there as well —
      // until it was, the setting could not be turned on at all on Android.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(musicModeTile(), findsOneWidget);

      await disposeTree(tester);
    });

    testWidgets('hides the toggle where nothing acts on it', (tester) async {
      // macOS captures through its own controller, which never reads the
      // flag, so a switch there would be a control that does nothing.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(musicModeTile(), findsNothing);

      await disposeTree(tester);
    });

    testWidgets('reflects the persisted preference', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      when(() => musicModeService.isMusicModeEnabled).thenReturn(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final tile = tester.widget<DivineSwitchTile>(musicModeTile());
      expect(tile.value, isTrue);

      await disposeTree(tester);
    });

    testWidgets('tapping the toggle writes the preference', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(musicModeTile());
      await tester.pumpAndSettle();

      verify(() => musicModeService.setMusicModeEnabled(true)).called(1);

      await disposeTree(tester);
    });
  });
}
