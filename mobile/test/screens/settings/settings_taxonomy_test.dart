// ABOUTME: Widget tests for the Settings information architecture.
// ABOUTME: Verifies General Settings and Content & Safety replace split content/moderation rows.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/content_filters_screen.dart';
import 'package:openvine/screens/safety_settings_screen.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/scroll.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockAppUpdateBloc extends MockBloc<AppUpdateEvent, AppUpdateState>
    implements AppUpdateBloc {}

class _MockAudioSharingPreferenceService extends Mock
    implements AudioSharingPreferenceService {}

class _MockLanguagePreferenceService extends Mock
    implements LanguagePreferenceService {}

class _MockAccountLabelService extends Mock implements AccountLabelService {}

class _MockAgeVerificationService extends Mock
    implements AgeVerificationService {}

class _MockContentFilterService extends Mock implements ContentFilterService {}

class _MockModerationLabelService extends Mock
    implements ModerationLabelService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {
  @override
  Set<String> get runtimeBlockedUsers => const {};

  @override
  Stream<ContentPolicyState> get stateStream =>
      const Stream<ContentPolicyState>.empty();
}

class _MockVideoEventService extends Mock implements VideoEventService {
  @override
  int filterAdultContentFromExistingVideos() => 0;
}

void main() {
  late SharedPreferences sharedPreferences;
  late _MockAuthService authService;
  late _MockLocaleCubit localeCubit;
  late _MockAppUpdateBloc appUpdateBloc;
  late _MockAudioSharingPreferenceService audioSharingService;
  late _MockLanguagePreferenceService languageService;
  late _MockAccountLabelService accountLabelService;
  late _MockAgeVerificationService ageVerificationService;
  late _MockContentFilterService contentFilterService;
  late _MockModerationLabelService moderationLabelService;
  late _MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late _MockVideoEventService videoEventService;
  late DivineHostFilterService divineHostFilterService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    localeCubit = _MockLocaleCubit();
    appUpdateBloc = _MockAppUpdateBloc();
    audioSharingService = _MockAudioSharingPreferenceService();
    languageService = _MockLanguagePreferenceService();
    accountLabelService = _MockAccountLabelService();
    ageVerificationService = _MockAgeVerificationService();
    contentFilterService = _MockContentFilterService();
    moderationLabelService = _MockModerationLabelService();
    followRepository = _MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    videoEventService = _MockVideoEventService();
    divineHostFilterService = DivineHostFilterService(sharedPreferences);

    when(() => localeCubit.state).thenReturn(const LocaleState());
    when(() => appUpdateBloc.state).thenReturn(
      const AppUpdateState(
        status: AppUpdateStatus.resolved,
        latestVersion: '1.0.22',
        downloadUrl: DownloadUrls.appStore,
      ),
    );
    when(() => authService.isAuthenticated).thenReturn(false);
    when(() => authService.isRegistered).thenReturn(false);
    when(() => authService.isAnonymous).thenReturn(false);
    when(
      () => authService.authenticationSource,
    ).thenReturn(AuthenticationSource.automatic);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.getKnownAccounts()).thenAnswer((_) async => []);
    when(() => authService.currentPublicKeyHex).thenReturn(null);

    when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
    when(
      () => audioSharingService.setAudioSharingEnabled(any()),
    ).thenAnswer((_) async {});
    when(() => languageService.contentLanguage).thenReturn('en');
    when(() => languageService.isCustomLanguageSet).thenReturn(false);
    when(() => accountLabelService.accountLabels).thenReturn(<ContentLabel>{});
    when(() => accountLabelService.initialized).thenAnswer((_) async {});
    when(() => ageVerificationService.initialize()).thenAnswer((_) async {});
    when(() => ageVerificationService.isAdultContentVerified).thenReturn(false);
    when(() => contentFilterService.initialize()).thenAnswer((_) async {});
    for (final label in ContentLabel.values) {
      when(
        () => contentFilterService.getPreference(label),
      ).thenReturn(ContentFilterPreference.warn);
    }
    when(
      () => contentFilterService.lockAdultCategories(),
    ).thenAnswer((_) async {});
    when(
      () => moderationLabelService.isDivineLabelerSubscribed,
    ).thenReturn(true);
    when(() => moderationLabelService.ensureLoaded()).thenAnswer((_) async {});
    when(
      () => moderationLabelService.isFollowingModerationEnabled,
    ).thenReturn(false);
    when(() => moderationLabelService.customLabelers).thenReturn(<String>{});
    when(
      () => moderationLabelService.setFollowingModerationEnabled(
        any(),
        followedPubkeys: any(named: 'followedPubkeys'),
      ),
    ).thenAnswer((_) async {});
    when(() => followRepository.followingPubkeys).thenReturn(<String>[]);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
  });

  List<dynamic> baseOverrides() => [
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    authServiceProvider.overrideWithValue(authService),
    currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
    audioSharingPreferenceServiceProvider.overrideWithValue(
      audioSharingService,
    ),
    languagePreferenceServiceProvider.overrideWithValue(languageService),
    accountLabelServiceProvider.overrideWithValue(accountLabelService),
    ageVerificationServiceProvider.overrideWithValue(ageVerificationService),
    contentFilterServiceProvider.overrideWithValue(contentFilterService),
    moderationLabelServiceProvider.overrideWithValue(moderationLabelService),
    followRepositoryProvider.overrideWithValue(followRepository),
    contentBlocklistRepositoryProvider.overrideWithValue(blocklistRepository),
    videoEventServiceProvider.overrideWithValue(videoEventService),
    divineHostFilterServiceProvider.overrideWithValue(divineHostFilterService),
    feedAspectRatioPreferenceServiceProvider.overrideWithValue(
      FeedAspectRatioPreferenceService(sharedPreferences),
    ),
  ];

  Widget wrap(
    Widget child, {
    Locale? locale,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [...baseOverrides(), ...overrides],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<LocaleCubit>.value(value: localeCubit),
            BlocProvider<AppUpdateBloc>.value(value: appUpdateBloc),
          ],
          child: child,
        ),
      ),
    );
  }

  Future<void> setStandardSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group(SettingsScreen, () {
    testWidgets('Settings hub uses General Settings and Content & Safety', (
      tester,
    ) async {
      await setStandardSurface(tester);
      await tester.pumpWidget(
        wrap(
          const SettingsScreen(),
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.blueskyPublishing,
            ).overrideWithValue(true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General Settings'), findsOneWidget);
      expect(find.text('Content & Safety'), findsOneWidget);
      expect(find.text('Content Preferences'), findsNothing);
      expect(find.text('Moderation Controls'), findsNothing);
      expect(find.text('Bluesky Publishing'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Update available'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Update available'), findsOneWidget);
    });
  });

  group('localization', () {
    testWidgets('localizes settings taxonomy for Amharic', (tester) async {
      await setStandardSurface(tester);
      await tester.pumpWidget(
        wrap(const SettingsScreen(), locale: const Locale('am')),
      );
      await tester.pumpAndSettle();

      expect(find.text('አጠቃላይ ቅንብሮች'), findsOneWidget);
      expect(find.text('ይዘት እና ደህንነት'), findsOneWidget);
      expect(find.text('General Settings'), findsNothing);
      expect(find.text('Content & Safety'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(
        wrap(
          const GeneralSettingsScreen(),
          locale: const Locale('am'),
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.blueskyPublishing,
            ).overrideWithValue(true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('አጠቃላይ ቅንብሮች'), findsOneWidget);
      expect(find.text('ውህደቶች'), findsOneWidget);
      expect(find.text('የተዘጉ መግለጫዎች'), findsOneWidget);
      expect(find.text('ካሬ ቪዲዮዎች ብቻ'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      await tester.pumpWidget(
        wrap(const SafetySettingsScreen(), locale: const Locale('am')),
      );
      await tester.pumpAndSettle();

      expect(find.text('ይዘት እና ደህንነት'), findsOneWidget);
      expect(find.text('የሚያዩት'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('የሚያትሙት'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('የሚያትሙት'), findsOneWidget);
    });
  });

  group(GeneralSettingsScreen, () {
    testWidgets('General Settings contains integrations and viewing defaults', (
      tester,
    ) async {
      await setStandardSurface(tester);
      await tester.pumpWidget(
        wrap(
          const GeneralSettingsScreen(),
          overrides: [
            isFeatureEnabledProvider(
              FeatureFlag.blueskyPublishing,
            ).overrideWithValue(true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General Settings'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Bluesky Publishing'),
        120,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Bluesky Publishing'), findsOneWidget);
      expect(find.text('Closed Captions'), findsOneWidget);
      expect(find.text('Square videos only'), findsOneWidget);
      expect(find.text('App Language'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Make my audio available for reuse'),
        120,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Make my audio available for reuse'), findsOneWidget);
      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.scrollUntilVisible(
        find.text(l10n.generalSettingsHoldToRecord),
        120,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(l10n.generalSettingsHoldToRecord), findsOneWidget);

      final captionsToggle = find.byWidgetPredicate(
        (widget) =>
            widget is DivineSwitchTile && widget.title == 'Closed Captions',
      );
      expect(captionsToggle, findsOneWidget);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(GeneralSettingsScreen)),
        ).read(subtitleVisibilityProvider),
        isTrue,
      );

      // The scroll above targeted a different row, so bring the toggle itself
      // back into view — and pump — before reading its centre.
      await scrollUntilTappable(
        tester,
        captionsToggle,
        120,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(captionsToggle);
      await tester.pumpAndSettle();

      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(GeneralSettingsScreen)),
        ).read(subtitleVisibilityProvider),
        isFalse,
      );
    });

    testWidgets('General Settings always shows Appearance', (tester) async {
      await setStandardSurface(tester);
      // No override: the row used to be gated on FeatureFlag.lightMode. It is
      // unconditional now, so pumping with the default provider set must still
      // find it.
      await tester.pumpWidget(wrap(const GeneralSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Appearance'),
        120,
        scrollable: find.byType(Scrollable),
      );

      expect(find.text('Appearance'), findsOneWidget);
      expect(
        find.text('Choose how Divine looks on this device'),
        findsOneWidget,
      );
    });
  });

  group('Content & Safety', () {
    testWidgets('Content & Safety exposes content filters and account labels', (
      tester,
    ) async {
      await setStandardSurface(tester);
      await tester.pumpWidget(wrap(const SafetySettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Content & Safety'), findsOneWidget);
      expect(find.text('Content Filters'), findsOneWidget);
      expect(find.text('Only show Divine-hosted videos'), findsOneWidget);
      expect(find.text('Divine'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Account Labels'), findsOneWidget);
    });

    testWidgets(
      'Content Filters constrains menu content width on wide screens',
      (tester) async {
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(wrap(const ContentFiltersScreen()));
        await tester.pumpAndSettle();

        final listViewWidth = tester.getSize(find.byType(ListView).first).width;
        expect(listViewWidth, moreOrLessEquals(600));
      },
    );
  });
}
