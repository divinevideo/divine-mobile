// ABOUTME: Widget tests for the account-switch confirmation in Settings.
// ABOUTME: Covers the in-flight-upload warning that supersedes the drafts one.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:keycast_flutter/keycast_flutter.dart'
    show SessionExpiredException;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/device_scope.dart';
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
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

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

/// Unstubbed on purpose: reading `switchController` throws inside the tile's
/// try/catch, so the tap exercises the parking loop and the "couldn't switch"
/// path without a real container swap.
class _MockDeviceScope extends Mock implements DeviceScope {}

void main() {
  const currentPubkey =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  const otherPubkey =
      'b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3';

  late SharedPreferences sharedPreferences;
  late _MockAuthService authService;
  late _MockLocaleCubit localeCubit;
  late _MockInviteStatusCubit inviteStatusCubit;
  late _MockBackgroundPublishBloc publishBloc;
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
  late DivineHostFilterService divineHostFilterService;
  late _MockDeviceScope deviceScope;

  DivineVideoDraft draftWithId(String id) => DivineVideoDraft.create(
    clips: const [],
    title: id,
    description: '',
    hashtags: const {},
    selectedApproach: 'test',
  ).copyWith(id: id);

  /// The account picker renders each tile with a generated display name, since
  /// `profileRepositoryProvider` is null in these tests. The settings header
  /// shows the current account under the same name, so take the match inside
  /// the picker — it is pushed last.
  Finder accountTile(String pubkeyHex) =>
      find.text(models.UserProfile.defaultDisplayNameFor(pubkeyHex)).last;

  void expectNothingParked() => verifyNever(() => publishBloc.parkInFlight());

  void seedPublishState(BackgroundPublishState state) {
    whenListen(
      publishBloc,
      const Stream<BackgroundPublishState>.empty(),
      initialState: state,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPreferences = await SharedPreferences.getInstance();
    authService = _MockAuthService();
    localeCubit = _MockLocaleCubit();
    inviteStatusCubit = _MockInviteStatusCubit();
    publishBloc = _MockBackgroundPublishBloc();
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
    divineHostFilterService = DivineHostFilterService(sharedPreferences);
    deviceScope = _MockDeviceScope();

    when(() => localeCubit.state).thenReturn(const LocaleState());
    whenListen(
      inviteStatusCubit,
      const Stream<InviteStatusState>.empty(),
      initialState: const InviteStatusState(),
    );
    when(() => inviteStatusCubit.load()).thenAnswer((_) async {});
    when(() => publishBloc.parkInFlight()).thenAnswer((_) async {});
    seedPublishState(const BackgroundPublishState());

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
        KnownAccount(
          pubkeyHex: otherPubkey,
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

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        authServiceProvider.overrideWithValue(authService),
        deviceScopeProvider.overrideWithValue(deviceScope),
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        // Null repository keeps profile reads offline, so the account header
        // renders from fallbacks without any network.
        profileRepositoryProvider.overrideWithValue(null),
        profileReadRepositoryProvider.overrideWithValue(null),
        draftStorageServiceProvider.overrideWithValue(draftStorageService),
        isFeatureEnabledProvider(
          FeatureFlag.accountSwitching,
        ).overrideWithValue(true),
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<LocaleCubit>.value(value: localeCubit),
            BlocProvider<InviteStatusCubit>.value(value: inviteStatusCubit),
            BlocProvider<BackgroundPublishBloc>.value(value: publishBloc),
          ],
          child: child,
        ),
      ),
    );
  }

  Future<AppLocalizations> pumpAndTapSwitch(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(SettingsScreen)),
    );
    await tester.tap(find.text(l10n.settingsSwitchAccount));
    await tester.pumpAndSettle();
    return l10n;
  }

  group('switching to another account', () {
    testWidgets('exposes the account switch action to automation', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrap(const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsIdentifier(SemanticIds.settingsAccountSwitchAction),
        findsOneWidget,
      );
      expect(
        find.bySemanticsIdentifier(SemanticIds.settingsExperimentalFeaturesRow),
        findsOneWidget,
      );
    });

    testWidgets('warns about an in-flight upload before switching', (
      tester,
    ) async {
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);

      expect(find.text(l10n.settingsUploadInProgressTitle), findsOneWidget);
      expect(
        find.text(l10n.settingsUploadInProgressMessage(1)),
        findsOneWidget,
      );
    });

    testWidgets('cancelling the warning leaves the upload untouched', (
      tester,
    ) async {
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsCancel));
      await tester.pumpAndSettle();

      expectNothingParked();
      expect(find.text(l10n.settingsUploadInProgressTitle), findsNothing);
    });

    testWidgets('picking another account parks the in-flight uploads', (
      tester,
    ) async {
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
            BackgroundUpload(
              draft: draftWithId('d2'),
              result: null,
              progress: 0,
            ),
            // Already finished — must not be counted in the warning.
            BackgroundUpload(
              draft: draftWithId('d3'),
              result: const PublishError(PublishErrorKind.generic),
              progress: 1,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      expect(
        find.text(l10n.settingsUploadInProgressMessage(2)),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();
      await tester.tap(accountTile(otherPubkey));
      await tester.pumpAndSettle();

      // Which uploads parking covers is pinned on the bloc.
      verify(() => publishBloc.parkInFlight()).called(1);
    });

    testWidgets('waits for the park to land before swapping the account', (
      tester,
    ) async {
      final parked = Completer<void>();
      when(() => publishBloc.parkInFlight()).thenAnswer((_) => parked.future);
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();
      await tester.tap(accountTile(otherPubkey));
      await tester.pumpAndSettle();

      // `swapAccount` disposes the container the publish bloc lives in, so it
      // must not start while the park write is still outstanding.
      verifyNever(() => deviceScope.switchController);

      parked.complete();
      await tester.pumpAndSettle();

      verify(() => deviceScope.switchController).called(1);
    });

    testWidgets('failed parking aborts the account switch with feedback', (
      tester,
    ) async {
      when(
        () => publishBloc.parkInFlight(),
      ).thenAnswer((_) async => throw Exception('database locked'));
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();
      await tester.tap(accountTile(otherPubkey));
      await tester.pumpAndSettle();

      verifyNever(() => deviceScope.switchController);
      expect(find.text(l10n.settingsAccountSwitchFailed), findsOneWidget);
    });
  });

  // Both failures take the re-auth route, but missing local keys are not a
  // session expiry and should not reuse session-expired copy.
  final unusableSessionFailures =
      <String, (Object, String Function(AppLocalizations))>{
        'SessionExpiredException': (
          SessionExpiredException(),
          (l10n) => l10n.settingsSessionExpiredSwitchMessage,
        ),
        'AccountRestoreFailedException': (
          const AccountRestoreFailedException(
            otherPubkey,
            AuthState.unauthenticated,
          ),
          (l10n) => l10n.settingsAccountRestoreFailedSwitchMessage,
        ),
      };

  group('switching hits an unusable session', () {
    for (final entry in unusableSessionFailures.entries) {
      testWidgets('offers a fresh sign-in on ${entry.key}', (tester) async {
        // Same seam as the `_MockDeviceScope` note above: reading
        // `switchController` throws inside the tile's try, standing in for a
        // swap that dies on the target account's unusable credentials.
        when(() => deviceScope.switchController).thenThrow(entry.value.$1);
        when(() => authService.signOut()).thenAnswer((_) async {});

        final l10n = await pumpAndTapSwitch(tester);
        await tester.tap(accountTile(otherPubkey));
        await tester.pumpAndSettle();

        // Recoverable by signing in again, so the user gets that offer instead
        // of the dead-end "couldn't switch" snackbar — and the copy says what
        // confirming costs, since it signs the working account out.
        expect(find.text(entry.value.$2(l10n)), findsOneWidget);
        expect(find.text(l10n.settingsAccountSwitchFailed), findsNothing);

        await tester.tap(find.text(l10n.authSignInTitle));
        await tester.pumpAndSettle();

        // Signing out lands on the welcome screen, where the pending pubkey
        // pre-selects the account the user was trying to reach.
        verify(
          () => authService.pendingAccountSwitchPubkey = otherPubkey,
        ).called(1);
        verify(() => authService.signOut()).called(1);
      });
    }

    testWidgets('declining the fresh sign-in keeps the current account', (
      tester,
    ) async {
      when(
        () => deviceScope.switchController,
      ).thenThrow(SessionExpiredException());
      when(() => authService.signOut()).thenAnswer((_) async {});

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(accountTile(otherPubkey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsCancel));
      await tester.pumpAndSettle();

      verifyNever(() => authService.signOut());
      // Nothing is remembered for the welcome screen either — backing out has to
      // leave the session exactly as it was, not stage a switch for later.
      verifyNever(() => authService.pendingAccountSwitchPubkey = any());
    });
  });

  group('the account picker', () {
    testWidgets('adding an account parks the in-flight uploads', (
      tester,
    ) async {
      // `addNewAccount` signs out to reach the sign-in flow, ending the session
      // the upload runs in just as the switch does — so this tile has to park
      // too, or the copy is stranded at `publishing` and shows up in neither the
      // queue nor the drafts library.
      when(() => authService.signOut()).thenAnswer((_) async {});
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsAddAnotherAccount).last);
      await tester.pumpAndSettle();

      verify(() => publishBloc.parkInFlight()).called(1);
    });

    testWidgets('failed parking aborts adding an account with feedback', (
      tester,
    ) async {
      when(
        () => publishBloc.parkInFlight(),
      ).thenAnswer((_) async => throw Exception('database locked'));
      when(() => authService.signOut()).thenAnswer((_) async {});
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.settingsAddAnotherAccount).last);
      await tester.pumpAndSettle();

      verifyNever(() => authService.signOut());
      expect(find.text(l10n.settingsAccountSwitchFailed), findsOneWidget);
    });

    testWidgets('confirming the warning alone parks nothing', (tester) async {
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();

      // The account picker is open but nothing has been chosen yet — backing out
      // here must leave the upload running, not tear it down for nothing.
      expectNothingParked();
    });

    testWidgets('dismissing the account picker leaves the upload running', (
      tester,
    ) async {
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();

      Navigator.of(
        tester.element(find.byType(SettingsScreen)),
        rootNavigator: true,
      ).pop();
      await tester.pumpAndSettle();

      expectNothingParked();
    });

    testWidgets('re-picking the current account parks nothing', (tester) async {
      seedPublishState(
        BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draftWithId('d1'),
              result: null,
              progress: 0,
            ),
          ],
        ),
      );

      final l10n = await pumpAndTapSwitch(tester);
      await tester.tap(find.text(l10n.settingsSwitchAnyway));
      await tester.pumpAndSettle();
      await tester.tap(accountTile(currentPubkey));
      await tester.pumpAndSettle();

      expectNothingParked();
    });
  });

  group('falls back to the drafts warning', () {
    testWidgets('falls back to the drafts warning when nothing is uploading', (
      tester,
    ) async {
      when(
        () => draftStorageService.getDraftCount(),
      ).thenAnswer((_) async => 2);

      final l10n = await pumpAndTapSwitch(tester);

      expect(find.text(l10n.settingsUnsavedDraftsTitle), findsOneWidget);
      expect(find.text(l10n.settingsUploadInProgressTitle), findsNothing);
    });
  });
}
