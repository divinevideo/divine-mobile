// ABOUTME: Real-router test for the account-deletion gate after `processing`.
// ABOUTME: Pins that the settings screen is unreachable once deletion commits.

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/account_deletion_recovery_screen.dart';
import 'package:openvine/screens/settings/nostr_settings_screen.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart'
    show AuthService, AuthState;
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAnalyticsService extends Mock implements AnalyticsService {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _otherPubkey =
    'b1c2d3e4f5a6b1c2d3e4f5a6b1c2d3e4f5a6b1c2d3e4f5a6b1c2d3e4f5a6b1c2';

const _processing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.processing,
);

const _recoverable = AccountDeletionAttempt(
  id: 'recoverable-attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
);

void main() {
  group('Account deletion gate after the coordinator accepts', () {
    late _MockAuthService authService;
    late _MockProfileRepository profileRepository;
    late _MockDeletionRepository deletionRepository;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      authService = _MockAuthService();
      profileRepository = _MockProfileRepository();
      deletionRepository = _MockDeletionRepository();

      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => Stream.value(AuthState.authenticated));
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkey);
      when(() => authService.hasExistingProfile).thenReturn(true);
      when(() => authService.signerReadiness).thenReturn(SignerReadiness.ready);
      when(() => authService.userRelays).thenReturn(const []);
      when(authService.getKnownAccounts).thenAnswer((_) async => []);
      when(
        authService.getSessionRecoveryAnchorNpub,
      ).thenAnswer((_) async => null);
      when(authService.signOut).thenAnswer((_) async {});

      final profile = UserProfile(
        pubkey: _pubkey,
        displayName: 'Test User',
        rawData: const {'display_name': 'Test User'},
        createdAt: DateTime(2024),
        eventId:
            'event123456789012345678901234567890123456789012345678901234567890',
      );
      when(
        () => profileRepository.getCachedProfile(pubkey: _pubkey),
      ).thenAnswer((_) async => profile);
      when(
        () => profileRepository.fetchFreshProfile(pubkey: _pubkey),
      ).thenAnswer((_) async => profile);

      // Before the deletion the signer is alive and there is no attempt.
      when(deletionRepository.fetchCurrent).thenAnswer((_) async => null);
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(authService),
          appVersionProvider.overrideWithValue('test'),
          analyticsServiceProvider.overrideWithValue(_MockAnalyticsService()),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          isDeveloperModeEnabledProvider.overrideWithValue(false),
          isFeatureEnabledProvider(
            FeatureFlag.advancedRelaySettings,
          ).overrideWith((ref) => false),
          currentMinorAccountReviewStatusProvider.overrideWith(
            (ref) async => MinorAccountReviewStatus.active(),
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            deletionRepository,
          ),
          profileRepositoryProvider.overrideWithValue(profileRepository),
          profileReadRepositoryProvider.overrideWithValue(profileRepository),
          blossomUploadServiceProvider.overrideWithValue(
            _MockBlossomUploadService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets(
      "resolving the active account does not clear another account's receipt",
      (tester) async {
        when(() => authService.currentPublicKeyHex).thenReturn(_otherPubkey);
        when(deletionRepository.fetchCurrent).thenAnswer(
          (_) async => const AccountDeletionAttempt(
            id: 'other-attempt-id',
            status: AccountDeletionAttemptStatus.cancelled,
          ),
        );
        final container = buildContainer();
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: _pubkey,
              attempt: _processing,
              vanishEventId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            );
        final router = GoRouter(
          initialLocation: AccountDeletionRecoveryScreen.path,
          routes: [
            GoRoute(
              path: AccountDeletionRecoveryScreen.path,
              builder: (_, _) => const AccountDeletionRecoveryScreen(),
            ),
            GoRoute(
              path: '/home/0',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          container.read(submittedAccountDeletionAttemptProvider)?.pubkeyHex,
          _pubkey,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );

    testWidgets(
      'an in-process submission keeps the recovery screen passive',
      (tester) async {
        final container = buildContainer();
        await container.read(currentMinorAccountReviewStatusProvider.future);
        await container.read(currentAccountDeletionAttemptProvider.future);
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: _pubkey,
              attempt: _recoverable,
              vanishEventId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
              submissionOwnedLocally: true,
            );
        container.invalidate(currentAccountDeletionAttemptProvider);
        await container.read(currentAccountDeletionAttemptProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(AccountDeletionRecoveryScreen), findsOneWidget);
        expect(find.text(l10n.accountDeletionFinishingBody), findsOneWidget);
        expect(find.text(l10n.accountDeletionRestoreUsername), findsNothing);
        expect(find.text(l10n.accountDeletionSignOut), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );

    testWidgets('cold-start recovery resumes the attempt shown by the router', (
      tester,
    ) async {
      when(
        deletionRepository.fetchCurrent,
      ).thenAnswer((_) async => _recoverable);
      final container = buildContainer();
      await container.read(currentAccountDeletionAttemptProvider.future);
      final router = GoRouter(
        initialLocation: AccountDeletionRecoveryScreen.path,
        routes: [
          GoRoute(
            path: AccountDeletionRecoveryScreen.path,
            builder: (_, _) => const AccountDeletionRecoveryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.accountDeletionRestoreUsername), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    testWidgets('unavailable signer reaches the real recovery screen', (
      tester,
    ) async {
      when(
        () => authService.signerReadiness,
      ).thenReturn(SignerReadiness.unavailable);
      final container = buildContainer();
      final router = GoRouter(
        initialLocation: AccountDeletionRecoveryScreen.path,
        routes: [
          GoRoute(
            path: AccountDeletionRecoveryScreen.path,
            builder: (_, _) => const AccountDeletionRecoveryScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.authSessionExpired), findsOneWidget);
      expect(
        find.text(l10n.minorAccountReviewCheckingStatusTitle),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    testWidgets(
      'a processing answer moves the user off Nostr settings onto the '
      'recovery screen and keeps settings unreachable',
      (tester) async {
        final container = buildContainer();
        await container.read(currentMinorAccountReviewStatusProvider.future);
        await container.read(currentAccountDeletionAttemptProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final router = container.read(goRouterProvider);
        router.go(NostrSettingsScreen.path);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(NostrSettingsScreen), findsOneWidget);

        // From here every lookup fails the way it does in production once
        // the coordinator has deleted the Keycast user: the NIP-98 token
        // cannot be signed. Nothing below may depend on this call succeeding.
        when(deletionRepository.fetchCurrent).thenThrow(
          const AccountDeletionRecoveryException(
            'Could not authorize deletion attempt request',
          ),
        );
        // What `startAccountDeletionFlow` does when `submit` answers
        // `processing`: record the attempt the coordinator handed back, then
        // invalidate the lookup. Awaiting the value here under real time is
        // what proves the record fed it: the lookup above throws, and a
        // provider that reached it would retry for seconds and then fail.
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: _pubkey,
              attempt: _processing,
              vanishEventId: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            );
        container.invalidate(currentAccountDeletionAttemptProvider);
        await tester.runAsync(
          () => container.read(currentAccountDeletionAttemptProvider.future),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          container.read(currentAccountDeletionAttemptProvider).value,
          same(_processing),
        );

        expect(
          router.routeInformationProvider.value.uri.toString(),
          AccountDeletionRecoveryScreen.path,
        );
        expect(find.byType(AccountDeletionRecoveryScreen), findsOneWidget);
        expect(find.byType(NostrSettingsScreen), findsNothing);

        router.go(NostrSettingsScreen.path);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          router.routeInformationProvider.value.uri.toString(),
          AccountDeletionRecoveryScreen.path,
        );
        expect(find.byType(NostrSettingsScreen), findsNothing);
        expect(find.byType(AccountDeletionRecoveryScreen), findsOneWidget);

        clearInteractions(deletionRepository);
        await tester.pump(const Duration(seconds: 3));
        verify(deletionRepository.fetchCurrent).called(1);

        // Once signed out, another account may use Welcome while the deleting
        // identity remains protected by the durable receipt.
        when(
          () => authService.authState,
        ).thenReturn(AuthState.unauthenticated);
        router.go('/welcome');
        await tester.pump();
        expect(
          router.routeInformationProvider.value.uri.toString(),
          '/welcome',
        );

        // UncontrolledProviderScope does not own its container, so dispose it
        // explicitly to cancel the router-owned recovery poll timer.
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
      },
    );
  });
}
