// ABOUTME: Widget test for settings hub screen
// ABOUTME: Verifies account header, auth-state tiles, and navigation structure

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/invite_availability/invite_availability_cubit.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/locale/locale_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/feature_flags/screens/feature_flag_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/invite_availability.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/account_enforcement_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/badges/badges_screen.dart';
import 'package:openvine/screens/developer_options_screen.dart';
import 'package:openvine/screens/settings/account_status_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/environment_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/go_router.dart';
import '../helpers/invite_availability_harness.dart';
import '../helpers/scroll.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _FakeDraft extends Fake implements DivineVideoDraft {
  @override
  String get id => 'settings-fake-draft';
}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

class _MockLocaleCubit extends MockCubit<LocaleState> implements LocaleCubit {}

_MockInviteStatusCubit _createMockInviteCubit() {
  final cubit = _MockInviteStatusCubit();
  when(() => cubit.state).thenReturn(const InviteStatusState());
  when(cubit.load).thenAnswer((_) async {});
  return cubit;
}

_MockBackgroundPublishBloc _stubbedPublishBloc() {
  final bloc = _MockBackgroundPublishBloc();
  when(() => bloc.state).thenReturn(const BackgroundPublishState());
  whenListen(
    bloc,
    const Stream<BackgroundPublishState>.empty(),
    initialState: const BackgroundPublishState(),
  );
  return bloc;
}

void main() {
  group(SettingsScreen, () {
    late _MockAuthService mockAuthService;
    late _MockDraftStorageService mockDraftStorageService;
    late _MockLocaleCubit mockLocaleCubit;
    late SharedPreferences sharedPreferences;
    final l10n = lookupAppLocalizations(const Locale('en'));
    const currentPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final twoAccounts = [
      KnownAccount(
        pubkeyHex:
            'abc123pubkeyabc123pubkeyabc123pubkeyabc123pubkeyabc123pubkeyabc1',
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      ),
      KnownAccount(
        pubkeyHex:
            'def456pubkeydef456pubkeydef456pubkeydef456pubkeydef456pubkeydef4',
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      ),
    ];

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockAuthService = _MockAuthService();
      mockDraftStorageService = _MockDraftStorageService();
      mockLocaleCubit = _MockLocaleCubit();
      when(() => mockLocaleCubit.state).thenReturn(const LocaleState());

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.isAnonymous).thenReturn(false);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(currentPubkey);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(false);
      when(
        () => mockAuthService.getKnownAccounts(),
      ).thenAnswer((_) async => []);
      when(
        () => mockDraftStorageService.getDraftCount(),
      ).thenAnswer((_) async => 0);
    });

    Widget buildSubject({
      AuthState authState = AuthState.authenticated,
      MockGoRouter? goRouter,
      List<KnownAccount> knownAccounts = const [],
      _MockInviteStatusCubit? inviteCubit,
      _MockBackgroundPublishBloc? publishBloc,
      InviteAvailabilityCubit? availabilityCubit,
      bool developerMode = false,
      AccountEnforcementKind? enforcement,
    }) {
      when(
        () => mockAuthService.getKnownAccounts(),
      ).thenAnswer((_) async => knownAccounts);

      final mockInviteCubit = inviteCubit ?? _createMockInviteCubit();

      // Default publish bloc has no uploads in progress.
      final effectivePublishBloc = publishBloc ?? _MockBackgroundPublishBloc();
      if (publishBloc == null) {
        when(
          () => effectivePublishBloc.state,
        ).thenReturn(const BackgroundPublishState());
        whenListen(
          effectivePublishBloc,
          const Stream<BackgroundPublishState>.empty(),
          initialState: const BackgroundPublishState(),
        );
      }

      final app = ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          currentAuthStateProvider.overrideWithValue(authState),
          knownAccountsProvider.overrideWith((ref) async => knownAccounts),
          isAccountEnforcedProvider.overrideWithValue(
            enforcement?.isEnforced ?? false,
          ),
          userProfileReactiveProvider.overrideWith(
            (ref, pubkey) => Stream.value(null),
          ),
          if (developerMode)
            isDeveloperModeEnabledProvider.overrideWithValue(true),
          if (enforcement != null)
            accountEnforcementStatusProvider.overrideWith(
              (ref) async => AccountEnforcementStatus(kind: enforcement),
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MultiBlocProvider(
            providers: [
              if (availabilityCubit != null)
                BlocProvider<InviteAvailabilityCubit>.value(
                  value: availabilityCubit,
                ),
              BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
              BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
              BlocProvider<BackgroundPublishBloc>.value(
                value: effectivePublishBloc,
              ),
            ],
            child: const SettingsScreen(),
          ),
        ),
      );

      if (goRouter == null) {
        return app;
      }

      return MockGoRouterProvider(goRouter: goRouter, child: app);
    }

    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('scaffold takes its background from the palette', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, equals(VineTheme.darkColors.surface));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders centered account header when authenticated', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsOneWidget);
      expect(
        find.text(NostrKeyUtils.encodePubKey(currentPubkey)),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('account header keeps the npub over the own follower count', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(mockAuthService),
            draftStorageServiceProvider.overrideWithValue(
              mockDraftStorageService,
            ),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            knownAccountsProvider.overrideWith((ref) async => const []),
            // No NIP-05, but a follower count from the REST profile. Social
            // proof must not stand in for the signed-in account's identifier.
            userProfileReactiveProvider.overrideWith(
              (ref, pubkey) => Stream.value(
                UserProfile(
                  pubkey: pubkey,
                  name: 'Jack',
                  rawData: const {'follower_count': 12},
                  createdAt: DateTime(2024),
                  eventId: 'event-$pubkey',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<InviteStatusCubit>.value(
                  value: _createMockInviteCubit(),
                ),
                BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                BlocProvider<BackgroundPublishBloc>.value(
                  value: _stubbedPublishBloc(),
                ),
              ],
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(NostrKeyUtils.encodePubKey(currentPubkey)),
        findsOneWidget,
      );
      expect(find.text(l10n.socialProofFollowerCount(12, '12')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('does not load invite status for the share action', (
      tester,
    ) async {
      final mockInviteCubit = _createMockInviteCubit();

      await tester.pumpWidget(buildSubject(inviteCubit: mockInviteCubit));
      await tester.pumpAndSettle();

      verifyNever(mockInviteCubit.load);
      expect(find.text(l10n.settingsShareDivine), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('shows share action when signup invites are disabled', (
      tester,
    ) async {
      final availabilityCubit = seededInviteAvailabilityCubit(
        serverMode: OnboardingMode.open,
      );
      addTearDown(availabilityCubit.close);

      await tester.pumpWidget(
        buildSubject(availabilityCubit: availabilityCubit),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsShareDivine), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('keeps share action when invite override forces disabled', (
      tester,
    ) async {
      final availabilityCubit = seededInviteAvailabilityCubit();
      addTearDown(availabilityCubit.close);

      await tester.pumpWidget(
        buildSubject(availabilityCubit: availabilityCubit),
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.settingsShareDivine), findsOneWidget);

      availabilityCubit.setOverride(InviteAvailabilityOverride.forceDisabled);
      expect(availabilityCubit.state.isEnabled, isFalse);
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsShareDivine), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('share action does not show an invite activity badge', (
      tester,
    ) async {
      final mockInviteCubit = _MockInviteStatusCubit();
      when(() => mockInviteCubit.state).thenReturn(
        const InviteStatusState(
          status: InviteStatusLoadingStatus.loaded,
          inviteStatus: InviteStatus(
            canInvite: true,
            remaining: 5,
            total: 5,
            codes: [],
          ),
        ),
      );

      await tester.pumpWidget(buildSubject(inviteCubit: mockInviteCubit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsShareDivine), findsOneWidget);
      expect(find.text('5'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'hides account action when multiple accounts exist and switching is disabled',
      (tester) async {
        await tester.pumpWidget(buildSubject(knownAccounts: twoAccounts));
        await tester.pumpAndSettle();

        expect(find.text('Switch account'), findsNothing);
        expect(find.text('Add another account'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('renders Switch account button when multiple accounts exist', (
      tester,
    ) async {
      await sharedPreferences.setBool('ff_accountSwitching', true);

      await tester.pumpWidget(buildSubject(knownAccounts: twoAccounts));
      await tester.pumpAndSettle();

      expect(find.text('Switch account'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'account switcher uses full npub fallback for same-name accounts',
      (tester) async {
        const firstPubkey =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const secondPubkey =
            '2222222222222222222222222222222222222222222222222222222222222222';
        final accounts = [
          KnownAccount(
            pubkeyHex: firstPubkey,
            authSource: AuthenticationSource.automatic,
            addedAt: DateTime(2024),
            lastUsedAt: DateTime(2024),
          ),
          KnownAccount(
            pubkeyHex: secondPubkey,
            authSource: AuthenticationSource.automatic,
            addedAt: DateTime(2024),
            lastUsedAt: DateTime(2024),
          ),
        ];

        await sharedPreferences.setBool('ff_accountSwitching', true);
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(firstPubkey);
        when(
          () => mockAuthService.getKnownAccounts(),
        ).thenAnswer((_) async => accounts);
        final publishBloc = _MockBackgroundPublishBloc();
        when(
          () => publishBloc.state,
        ).thenReturn(const BackgroundPublishState());
        whenListen(
          publishBloc,
          const Stream<BackgroundPublishState>.empty(),
          initialState: const BackgroundPublishState(),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              authServiceProvider.overrideWithValue(mockAuthService),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
              knownAccountsProvider.overrideWith((ref) async => accounts),
              userProfileReactiveProvider.overrideWith(
                (ref, pubkey) => Stream.value(
                  UserProfile(
                    pubkey: pubkey,
                    name: 'Jack',
                    rawData: const {},
                    createdAt: DateTime(2024),
                    eventId: 'event-$pubkey',
                  ),
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                  BlocProvider<BackgroundPublishBloc>.value(value: publishBloc),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Switch account'));
        await tester.pumpAndSettle();

        expect(find.text('Jack'), findsWidgets);
        expect(
          find.text(NostrKeyUtils.encodePubKey(firstPubkey)),
          findsWidgets,
        );
        expect(
          find.text(NostrKeyUtils.encodePubKey(secondPubkey)),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('renders navigation tiles', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);

      expect(find.text('Creator Analytics'), findsOneWidget);
      expect(find.text('Support Center'), findsOneWidget);

      // Tiles below the centered header may need scrolling
      for (final title in [
        l10n.settingsNotifications,
        l10n.settingsGeneralTitle,
        l10n.settingsContentSafetyTitle,
        l10n.settingsNostrSettings,
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          100,
          scrollable: scrollable,
        );
        expect(find.text(title), findsOneWidget);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Integration Permissions opens the permissions route', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await scrollUntilTappable(
        tester,
        find.text('Integration Permissions'),
        300,
        scrollable: scrollable,
      );
      await tester.tap(find.text('Integration Permissions'));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(AppsPermissionsScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Integrated Apps opens the directory route', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(mockAuthService),
          draftStorageServiceProvider.overrideWithValue(
            mockDraftStorageService,
          ),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          userProfileReactiveProvider.overrideWith(
            (ref, pubkey) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MockGoRouterProvider(
            goRouter: mockGoRouter,
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await scrollUntilTappable(
        tester,
        find.text(l10n.settingsIntegratedApps),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text(l10n.settingsIntegratedApps));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(AppsDirectoryScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('tapping Badges opens the badges dashboard', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable);
      await scrollUntilTappable(
        tester,
        find.text(l10n.settingsBadgesTitle),
        200,
        scrollable: scrollable,
      );
      await tester.tap(find.text(l10n.settingsBadgesTitle));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(BadgesScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Secure Your Account tile for anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsSecureAccount), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('renders Session Expired tile when session expired', (
      tester,
    ) async {
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(true);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsSessionExpired), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'shows secure account tile instead of session expired for anonymous '
      'users',
      (tester) async {
        when(() => mockAuthService.isAnonymous).thenReturn(true);
        when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(true);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              authServiceProvider.overrideWithValue(mockAuthService),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.settingsSecureAccount), findsOneWidget);
        expect(find.text(l10n.settingsSessionExpired), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('hides Secure Your Account for non-anonymous users', (
      tester,
    ) async {
      when(() => mockAuthService.isAnonymous).thenReturn(false);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsSecureAccount), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('does not render account section when unauthenticated', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(authState: AuthState.unauthenticated),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UserAvatar), findsNothing);
      expect(find.text('Switch account'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('hides Bluesky Publishing tile when feature flag is off', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Bluesky Publishing'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'keeps Bluesky Publishing off the hub when feature flag is on',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              authServiceProvider.overrideWithValue(mockAuthService),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
              userProfileReactiveProvider.overrideWith(
                (ref, pubkey) => Stream.value(null),
              ),
              isFeatureEnabledProvider(
                FeatureFlag.blueskyPublishing,
              ).overrideWith((ref) => true),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text(l10n.settingsGeneralTitle),
          200,
        );
        expect(find.text(l10n.settingsGeneralTitle), findsOneWidget);
        expect(find.text('Bluesky Publishing'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('defers nav to login-options until background upload finishes '
        'when Session Expired tile is tapped and refresh fails', (
      tester,
    ) async {
      // Regression for #4626: tapping the Session Expired tile while a
      // background upload is active must not navigate immediately.
      // Navigation is deferred until BackgroundPublishBloc.hasUploadInProgress
      // becomes false.
      final publishStreamController =
          StreamController<BackgroundPublishState>();
      addTearDown(publishStreamController.close);

      final mockPublishBloc = _MockBackgroundPublishBloc();
      final inProgressState = BackgroundPublishState(
        uploads: [
          BackgroundUpload(draft: _FakeDraft(), result: null, progress: 0.5),
        ],
      );
      when(() => mockPublishBloc.state).thenReturn(inProgressState);
      whenListen(
        mockPublishBloc,
        publishStreamController.stream,
        initialState: inProgressState,
      );

      // Session is expired, refresh will fail.
      when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(true);
      when(
        () => mockAuthService.tryRefreshExpiredSession(),
      ).thenAnswer((_) async => false);

      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.go(any())).thenReturn(null);

      await tester.pumpWidget(
        buildSubject(goRouter: mockGoRouter, publishBloc: mockPublishBloc),
      );
      await tester.pumpAndSettle();

      // Session Expired tile is present.
      expect(find.text(l10n.settingsSessionExpired), findsOneWidget);

      // Tap the tile — triggers _handleSessionExpired.
      await tester.tap(find.text(l10n.settingsSessionExpired));
      await tester.pumpAndSettle();

      // Navigation must NOT have fired yet — upload is still in progress.
      verifyNever(() => mockGoRouter.go(any()));

      // Simulate upload completing.
      publishStreamController.add(const BackgroundPublishState());
      await tester.pump();

      // Now navigation must have fired exactly once to login-options.
      verify(
        () => mockGoRouter.go(any(that: contains('login-options'))),
      ).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'navigates immediately when upload finishes before stream listener '
      'attaches — regression for check/listen race',
      (tester) async {
        // Regression for the subscribe/re-check race: the upload completes
        // between the state read and the stream.listen() call. With the old
        // code (check-then-listen), no further emission would ever arrive and
        // navigation would be silently lost. With the fix (listen-then-recheck),
        // the recheck immediately fires navigation.
        //
        // We model this by giving the bloc a state that already has no upload
        // in progress before _handleSessionExpired even runs. The stream emits
        // nothing further. Navigation must still fire exactly once.
        const emptyState = BackgroundPublishState();
        final mockPublishBloc = _MockBackgroundPublishBloc();
        when(() => mockPublishBloc.state).thenReturn(emptyState);
        // Stream produces no further emissions after subscribe — simulating
        // the race where the last upload completed just before listen().
        whenListen(
          mockPublishBloc,
          const Stream<BackgroundPublishState>.empty(),
          initialState: emptyState,
        );

        when(() => mockAuthService.hasExpiredOAuthSession).thenReturn(true);
        when(
          () => mockAuthService.tryRefreshExpiredSession(),
        ).thenAnswer((_) async => false);

        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.go(any())).thenReturn(null);

        await tester.pumpWidget(
          buildSubject(goRouter: mockGoRouter, publishBloc: mockPublishBloc),
        );
        await tester.pumpAndSettle();

        // Tap Session Expired tile — triggers _handleSessionExpired.
        await tester.tap(find.text(l10n.settingsSessionExpired));
        await tester.pumpAndSettle();

        // Navigation must have fired immediately because re-check after
        // subscribe detected no upload in progress.
        verify(
          () => mockGoRouter.go(any(that: contains('login-options'))),
        ).called(1);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('shows Experimental Features tile when developer mode is off', (
      tester,
    ) async {
      // Tall surface so the whole settings list is laid out; otherwise the
      // lazy ListView never builds the lower tiles and the absence proves
      // nothing.
      await tester.binding.setSurfaceSize(const Size(900, 2000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final mockGoRouter = MockGoRouter();
      when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsLegal), findsOneWidget);
      expect(find.text(l10n.settingsExperimentalFeatures), findsOneWidget);

      await tester.tap(find.text(l10n.settingsExperimentalFeatures));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.push(FeatureFlagScreen.path)).called(1);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'shows Experimental Features tile and opens it when developer mode is on',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(
          buildSubject(goRouter: mockGoRouter, developerMode: true),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.settingsExperimentalFeatures), findsOneWidget);

        await tester.tap(find.text(l10n.settingsExperimentalFeatures));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.push(FeatureFlagScreen.path)).called(1);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets('hides Developer Options tile when developer mode is off', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text(l10n.settingsDeveloperOptions), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets(
      'shows Developer Options tile and navigates to it when developer mode '
      'is on',
      (tester) async {
        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(
          buildSubject(goRouter: mockGoRouter, developerMode: true),
        );
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable);
        await scrollUntilTappable(
          tester,
          find.text(l10n.settingsDeveloperOptions),
          200,
          scrollable: scrollable,
        );

        expect(find.text(l10n.settingsDeveloperOptions), findsOneWidget);

        await tester.tap(find.text(l10n.settingsDeveloperOptions));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.push(DeveloperOptionsScreen.path)).called(1);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    testWidgets(
      'reveals Developer Options tile immediately when developer mode is '
      'unlocked at runtime',
      (tester) async {
        // The user's emphasis: enabling developer mode (7 taps on the version
        // tile calls EnvironmentService.enableDeveloperMode) must surface the
        // tile without leaving and re-entering the screen. This exercises the
        // real service -> notifyListeners -> isDeveloperModeEnabledProvider ->
        // rebuild path, so it fails if the hub stops watching the provider.
        final environmentService = EnvironmentService();
        await environmentService.initialize(
          sharedPreferences: sharedPreferences,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              authServiceProvider.overrideWithValue(mockAuthService),
              draftStorageServiceProvider.overrideWithValue(
                mockDraftStorageService,
              ),
              currentAuthStateProvider.overrideWithValue(
                AuthState.authenticated,
              ),
              userProfileReactiveProvider.overrideWith(
                (ref, pubkey) => Stream.value(null),
              ),
              environmentServiceProvider.overrideWithValue(environmentService),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: MultiBlocProvider(
                providers: [
                  BlocProvider<InviteStatusCubit>.value(
                    value: _createMockInviteCubit(),
                  ),
                  BlocProvider<LocaleCubit>.value(value: mockLocaleCubit),
                ],
                child: const SettingsScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.settingsDeveloperOptions), findsNothing);

        await environmentService.enableDeveloperMode();
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable);
        await tester.scrollUntilVisible(
          find.text(l10n.settingsDeveloperOptions),
          200,
          scrollable: scrollable,
        );

        expect(find.text(l10n.settingsDeveloperOptions), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );

    group('account status tile', () {
      testWidgets('is hidden when no restriction is confirmed', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            enforcement: AccountEnforcementKind.noRestrictionReported,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.accountStatusTitle), findsNothing);
        expect(
          find.text(l10n.accountStatusTileSubtitleRestricted),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });

      testWidgets('flags a restricted account on the row itself', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(enforcement: AccountEnforcementKind.suspended),
        );
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable);
        await scrollUntilTappable(
          tester,
          find.text(l10n.accountStatusTitle),
          200,
          scrollable: scrollable,
        );

        expect(
          find.text(l10n.accountStatusTileSubtitleRestricted),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });

      testWidgets('tapping it opens the account status route', (tester) async {
        final mockGoRouter = MockGoRouter();
        when(() => mockGoRouter.push(any())).thenAnswer((_) async => null);

        await tester.pumpWidget(
          buildSubject(
            goRouter: mockGoRouter,
            enforcement: AccountEnforcementKind.suspended,
          ),
        );
        await tester.pumpAndSettle();

        final scrollable = find.byType(Scrollable);
        await scrollUntilTappable(
          tester,
          find.text(l10n.accountStatusTitle),
          200,
          scrollable: scrollable,
        );
        await tester.tap(find.text(l10n.accountStatusTitle));
        await tester.pumpAndSettle();

        verify(() => mockGoRouter.push(AccountStatusScreen.path)).called(1);

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      });
    });
  });
}
