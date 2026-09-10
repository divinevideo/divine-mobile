// ABOUTME: Pumps real settings screens under VineTheme.lightTheme and proves
// ABOUTME: they paint light tokens instead of silently resolving the dark fallback.
import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/appearance/bloc/appearance_cubit.dart';
import 'package:openvine/features/appearance/repositories/appearance_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/crossposting_repository.dart';
import 'package:openvine/screens/settings/appearance_settings_screen.dart';
import 'package:openvine/screens/settings/crossposting_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crossposting_api_client.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

class _MockCrosspostingRepository extends Mock
    implements CrosspostingRepository {}

void main() {
  group('settings screens in light mode', () {
    late _MockAuthService authService;
    late _MockLocaleCubit localeCubit;
    late _MockAudioSharingPreferenceService audioSharingService;
    late _MockCrosspostingRepository crosspostingRepository;
    late SharedPreferences preferences;

    setUp(() async {
      // The dark fallback is silent by design, so a light-mode leak is only
      // observable through this counter — reset it around every pump.
      VineThemeColors.debugFallbackCount = 0;
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      authService = _MockAuthService();
      localeCubit = _MockLocaleCubit();
      audioSharingService = _MockAudioSharingPreferenceService();
      crosspostingRepository = _MockCrosspostingRepository();
      when(() => localeCubit.state).thenReturn(const LocaleState());
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => authService.isAnonymous).thenReturn(false);
      when(() => authService.hasExpiredOAuthSession).thenReturn(false);
      when(
        () => authService.authenticationSource,
      ).thenReturn(AuthenticationSource.automatic);
      when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
      when(
        () => audioSharingService.setAudioSharingEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        crosspostingRepository.loadSettings,
      ).thenAnswer((_) async => _crosspostingEntries);
    });

    tearDown(() => VineThemeColors.debugFallbackCount = 0);

    testWidgets('SettingsScreen paints the light palette', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          ],
          child: MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<LocaleCubit>.value(
              value: localeCubit,
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, VineTheme.lightColors.surface);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, VineTheme.lightColors.nav);

      expect(
        VineThemeColors.debugFallbackCount,
        0,
        reason:
            'A widget resolved context.vineColors from a context without the '
            'VineThemeColors extension and rendered dark tokens on a light '
            'page. Check for a nested Theme/MaterialApp that drops extensions.',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('AppearanceSettingsScreen paints the light palette', (
      tester,
    ) async {
      final cubit = AppearanceCubit(AppearanceRepository(preferences));
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.lightTheme,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final title = tester.widget<Text>(
        find.text(l10n.appearanceSettingsLight),
      );
      expect(title.style?.color, VineTheme.lightColors.onSurface);
      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('GeneralSettingsScreen paints the light palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            audioSharingPreferenceServiceProvider.overrideWithValue(
              audioSharingService,
            ),
            feedAspectRatioPreferenceServiceProvider.overrideWithValue(
              FeedAspectRatioPreferenceService(preferences),
            ),
            crosspostingEligibleProvider.overrideWithValue(true),
          ],
          child: MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<LocaleCubit>.value(
              value: localeCubit,
              child: const GeneralSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, VineTheme.lightColors.background);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, VineTheme.lightColors.nav);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final title = tester.widget<Text>(
        find.text(l10n.settingsCrosspostingTitle),
      );
      expect(title.style?.color, VineTheme.lightColors.primaryText);

      final subtitle = tester.widget<Text>(
        find.text(l10n.settingsCrosspostingSubtitle),
      );
      expect(subtitle.style?.color, VineTheme.lightColors.mutedText);

      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('CrosspostingSettingsScreen paints the light palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            crosspostingEligibleProvider.overrideWithValue(true),
            crosspostingRepositoryProvider.overrideWithValue(
              crosspostingRepository,
            ),
          ],
          child: MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CrosspostingSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, VineTheme.lightColors.background);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, VineTheme.lightColors.nav);

      final l10n = lookupAppLocalizations(const Locale('en'));
      final platformTitle = tester.widget<Text>(find.text('Instagram'));
      expect(platformTitle.style?.color, VineTheme.lightColors.primaryText);

      final identity = tester.widget<Text>(find.text('divine.creator'));
      expect(identity.style?.color, VineTheme.lightColors.secondaryText);

      final disconnectedStatus = tester.widget<Text>(
        find.text(l10n.crosspostingNotConnected),
      );
      expect(disconnectedStatus.style?.color, VineTheme.lightColors.mutedText);

      final modeSubtitle = tester.widget<Text>(
        find.text(l10n.crosspostingModeManualSubtitle),
      );
      expect(modeSubtitle.style?.color, VineTheme.lightColors.mutedText);

      final divider = tester.widget<Divider>(find.byType(Divider).first);
      expect(divider.color, VineTheme.lightColors.outlineMuted);

      final reconnect = tester.widget<Text>(
        find.text(l10n.crosspostingNeedsReconnect),
      );
      expect(reconnect.style?.color, VineTheme.lightColors.accentWarning);

      // One per platform row, in `entries` order: connected, disconnected,
      // needs-reauth. Typed on the icon name so the app bar's own icons — a
      // plain `find.byType(DivineIcon).first` picks up the back arrow — stay
      // out of it.
      final platformIcons = tester
          .widgetList<DivineIcon>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is DivineIcon &&
                  widget.icon == DivineIconName.shareNetwork,
            ),
          )
          .toList();
      expect(platformIcons, hasLength(3));
      expect(platformIcons.first.color, VineTheme.lightColors.accentPositive);
      expect(platformIcons[1].color, VineTheme.lightColors.mutedText);
      expect(platformIcons.last.color, VineTheme.lightColors.accentWarning);

      final refresh = tester.widget<RefreshIndicator>(
        find.byType(RefreshIndicator),
      );
      expect(refresh.color, VineTheme.lightColors.accentPositive);

      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('the signed-out crossposting copy paints the light palette', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            crosspostingEligibleProvider.overrideWithValue(false),
          ],
          child: MaterialApp(
            theme: VineTheme.lightTheme,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CrosspostingSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      final copy = tester.widget<Text>(
        find.text(l10n.crosspostingSignInRequired),
      );
      expect(copy.style?.color, VineTheme.lightColors.mutedText);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        VineTheme.lightColors.background,
      );
      expect(VineThemeColors.debugFallbackCount, 0);
    });

    testWidgets('the dark fallback stays reachable without the extension', (
      tester,
    ) async {
      // Guards the counter itself: if this stopped incrementing, the two
      // assertions above would pass for the wrong reason.
      final cubit = AppearanceCubit(AppearanceRepository(preferences));
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const AppearanceSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(VineThemeColors.debugFallbackCount, greaterThan(0));
    });
  });
}

/// One platform per rendered branch — connected (identity + mode subtitle),
/// disconnected (status line) and needs-reauth (the accent-tinted status line
/// and icon) — so every migrated token has a rendered call site.
///
/// The needs-reauth row is the one this screen shipped without: it is the only
/// branch that paints an accent on the canvas rather than a text token, and it
/// is where the raw brand orange stayed 2.48:1 in light mode.
const _crosspostingEntries = <CrosspostingPlatformSettings>[
  CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.instagram,
    supportsAutomatic: true,
    mode: CrosspostingMode.manual,
    connection: CrosspostingConnection(
      id: 'instagram-connection',
      platform: CrosspostingPlatform.instagram,
      status: CrosspostingConnectionStatus.connected,
      externalAccountName: 'divine.creator',
    ),
  ),
  CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.x,
    supportsAutomatic: false,
    mode: CrosspostingMode.disabled,
  ),
  CrosspostingPlatformSettings(
    platform: CrosspostingPlatform.tiktok,
    supportsAutomatic: true,
    mode: CrosspostingMode.manual,
    connection: CrosspostingConnection(
      id: 'tiktok-connection',
      platform: CrosspostingPlatform.tiktok,
      status: CrosspostingConnectionStatus.needsReauth,
      externalAccountName: 'divine.tiktok',
    ),
  ),
];
