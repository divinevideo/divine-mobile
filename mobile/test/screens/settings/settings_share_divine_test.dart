// ABOUTME: Widget tests for sharing Divine from the Settings account header.
// ABOUTME: Verifies invite availability cannot hide the anchored share action.

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/account_label_service.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/divine_host_filter_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/feed_aspect_ratio_preference_service.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/invite_availability_harness.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

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
  const currentPubkey =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

  late List<Map<Object?, Object?>> shareCalls;
  late SharedPreferences sharedPreferences;
  late _MockAuthService authService;
  late _MockLocaleCubit localeCubit;
  late _MockDraftStorageService draftStorageService;
  late _MockAudioSharingPreferenceService audioSharingService;
  late _MockLanguagePreferenceService languageService;
  late _MockAccountLabelService accountLabelService;
  late _MockAgeVerificationService ageVerificationService;
  late _MockContentFilterService contentFilterService;
  late _MockModerationLabelService moderationLabelService;
  late _MockFollowRepository followRepository;
  late _MockContentBlocklistRepository blocklistRepository;
  late _MockVideoEventService videoEventService;

  setUp(() async {
    shareCalls = <Map<Object?, Object?>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, (call) async {
          if (call.method == 'share') {
            shareCalls.add(call.arguments as Map<Object?, Object?>);
          }
          return 'com.apple.UIKit.activity.CopyToPasteboard';
        });

    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    localeCubit = _MockLocaleCubit();
    draftStorageService = _MockDraftStorageService();
    audioSharingService = _MockAudioSharingPreferenceService();
    languageService = _MockLanguagePreferenceService();
    accountLabelService = _MockAccountLabelService();
    ageVerificationService = _MockAgeVerificationService();
    contentFilterService = _MockContentFilterService();
    moderationLabelService = _MockModerationLabelService();
    followRepository = _MockFollowRepository();
    blocklistRepository = _MockContentBlocklistRepository();
    videoEventService = _MockVideoEventService();

    when(() => localeCubit.state).thenReturn(const LocaleState());
    when(() => authService.isAuthenticated).thenReturn(true);
    when(() => authService.isAnonymous).thenReturn(false);
    when(() => authService.hasExpiredOAuthSession).thenReturn(false);
    when(() => authService.currentPublicKeyHex).thenReturn(currentPubkey);
    when(() => authService.getKnownAccounts()).thenAnswer(
      (_) async => [
        KnownAccount(
          pubkeyHex: currentPubkey,
          authSource: AuthenticationSource.importedKeys,
          addedAt: DateTime(2026),
          lastUsedAt: DateTime(2026),
        ),
      ],
    );
    when(() => draftStorageService.getDraftCount()).thenAnswer((_) async => 0);
    when(() => audioSharingService.isAudioSharingEnabled).thenReturn(false);
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
      () => moderationLabelService.isDivineLabelerSubscribed,
    ).thenReturn(true);
    when(() => moderationLabelService.ensureLoaded()).thenAnswer((_) async {});
    when(
      () => moderationLabelService.isFollowingModerationEnabled,
    ).thenReturn(false);
    when(() => moderationLabelService.customLabelers).thenReturn(<String>{});
    when(() => followRepository.followingPubkeys).thenReturn(<String>[]);
    when(
      () => followRepository.followingStream,
    ).thenAnswer((_) => const Stream<List<String>>.empty());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
  });

  Widget wrap({
    required OnboardingMode onboardingMode,
    Locale locale = const Locale('en'),
    double textScaleFactor = 1,
  }) {
    final divineHostFilterService = DivineHostFilterService(sharedPreferences);
    final availabilityCubit = seededInviteAvailabilityCubit(
      serverMode: onboardingMode,
    );
    addTearDown(availabilityCubit.close);

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWithValue(authService),
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        profileRepositoryProvider.overrideWithValue(null),
        profileReadRepositoryProvider.overrideWithValue(null),
        draftStorageServiceProvider.overrideWithValue(draftStorageService),
        isFeatureEnabledProvider(
          FeatureFlag.accountSwitching,
        ).overrideWithValue(false),
        audioSharingPreferenceServiceProvider.overrideWithValue(
          audioSharingService,
        ),
        languagePreferenceServiceProvider.overrideWithValue(languageService),
        accountLabelServiceProvider.overrideWithValue(accountLabelService),
        ageVerificationServiceProvider.overrideWithValue(
          ageVerificationService,
        ),
        contentFilterServiceProvider.overrideWithValue(contentFilterService),
        moderationLabelServiceProvider.overrideWithValue(
          moderationLabelService,
        ),
        followRepositoryProvider.overrideWithValue(followRepository),
        contentBlocklistRepositoryProvider.overrideWithValue(
          blocklistRepository,
        ),
        videoEventServiceProvider.overrideWithValue(videoEventService),
        divineHostFilterServiceProvider.overrideWithValue(
          divineHostFilterService,
        ),
        feedAspectRatioPreferenceServiceProvider.overrideWithValue(
          FeedAspectRatioPreferenceService(sharedPreferences),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: VineTheme.theme,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScaleFactor,
          maxScaleFactor: textScaleFactor,
          child: child!,
        ),
        home: MultiBlocProvider(
          providers: [
            BlocProvider<LocaleCubit>.value(value: localeCubit),
            BlocProvider.value(value: availabilityCubit),
          ],
          child: const SettingsScreen(),
        ),
      ),
    );
  }

  group('interactions', () {
    for (final onboardingMode in OnboardingMode.values) {
      testWidgets('shares Divine when onboarding mode is $onboardingMode', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(wrap(onboardingMode: onboardingMode));
        await tester.pumpAndSettle();

        final label = lookupAppLocalizations(
          const Locale('en'),
        ).settingsShareDivine;
        expect(find.text(label), findsOneWidget);
        final shareAction = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(shareAction).height, greaterThanOrEqualTo(48));

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();

        expect(shareCalls, hasLength(1));
        expect(shareCalls.single['text'], AppConstants.downloadUrl);
        expect(shareCalls.single['originWidth'], isNotNull);
        expect(shareCalls.single['originHeight'], isNotNull);
      });
    }
  });

  group('renders', () {
    // The slot used to hold one word ("Invites"); the label is now a sentence,
    // so the pill has to survive a narrow phone, the longest translation, and
    // an accessibility text scale. Every case below overflowed before the
    // label was allowed to wrap.
    const layoutProbes = <({double width, Locale locale, double textScale})>[
      (width: 320, locale: Locale('fil'), textScale: 1),
      (width: 360, locale: Locale('fil'), textScale: 1),
      (width: 360, locale: Locale('en'), textScale: 1.3),
      (width: 412, locale: Locale('en'), textScale: 2),
    ];

    for (final probe in layoutProbes) {
      testWidgets(
        'share action fits ${probe.width}dp in ${probe.locale.languageCode} '
        'at text scale ${probe.textScale}',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(probe.width, 1600));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            wrap(
              onboardingMode: OnboardingMode.open,
              locale: probe.locale,
              textScaleFactor: probe.textScale,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(lookupAppLocalizations(probe.locale).settingsShareDivine),
            findsOneWidget,
          );
        },
      );
    }
  });
}
