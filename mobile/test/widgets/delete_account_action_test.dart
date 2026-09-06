// ABOUTME: Tests the shared account-deletion entry point end to end.
// ABOUTME: Pins that a coordinator-accepted deletion feeds the recovery gate.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/owned_divine_username_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/delete_account_action.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockAuthService extends Mock implements AuthService {}

class _MockRecoveryCubit extends Mock implements AccountDeletionRecoveryCubit {}

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

const _recoverable = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
);

const _processing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.processing,
);

void main() {
  group('startAccountDeletionFlow', () {
    late _MockAccountDeletionService deletionService;
    late _MockAuthService authService;
    late _MockDeletionRepository repository;

    setUp(() {
      deletionService = _MockAccountDeletionService();
      authService = _MockAuthService();
      repository = _MockDeletionRepository();
      when(() => authService.currentPublicKeyHex).thenReturn(_pubkeyHex);
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(() => authService.signerReadiness).thenReturn(SignerReadiness.ready);
      when(
        authService.checkAccountDeletionReadiness,
      ).thenAnswer((_) async => AccountDeletionReadiness.ready);
      when(repository.prepare).thenAnswer((_) async => _recoverable);
      when(repository.fetchCurrent).thenAnswer((_) async => _processing);
      when(
        () => repository.submit(
          attemptId: any(named: 'attemptId'),
          vanishEventId: any(named: 'vanishEventId'),
        ),
      ).thenAnswer((_) async => _processing);
      when(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      ).thenAnswer((_) async => DeleteAccountResult.createSuccess('event-id'));
      when(authService.signOut).thenAnswer((_) async {});
    });

    testWidgets(
      'a processing answer records the attempt the recovery gate reads',
      (tester) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final sharedPreferences = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.rpcReady,
            ),
            accountDeletionServiceProvider.overrideWithValue(deletionService),
            accountDeletionRecoveryRepositoryProvider.overrideWithValue(
              repository,
            ),
            ownedDivineUsernameProvider.overrideWith(
              (ref) async => const DivineUsernameNotFound(),
            ),
            fetchUserProfileProvider(
              _pubkeyHex,
            ).overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);

        // The confirmation sheet closes through GoRouter, so the host needs one.
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    key: const Key('delete'),
                    onPressed: () => startAccountDeletionFlow(
                      context: context,
                      ref: ref,
                      screenName: 'Test',
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );

        await tester.tap(find.byKey(const Key('delete')));
        await tester.pumpAndSettle();
        // No handle in the profile, so the sheet asks for the DELETE token.
        await tester.enterText(find.byType(TextField), 'DELETE');
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.widgetWithText(
            DivineButton,
            l10n.deleteAccountDeleteAllContentButton,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final receipt = container.read(
          submittedAccountDeletionAttemptProvider,
        );
        expect(receipt?.pubkeyHex, _pubkeyHex);
        expect(receipt?.attempt, same(_processing));
        expect(receipt?.vanishEventId, 'event-id');
        // The signer is gone the moment the coordinator accepts: the gate must
        // be fed by the record, never by a lookup. Read under real time so a
        // provider that reached the lookup fails here instead of hanging on
        // its retry timers.
        when(repository.fetchCurrent).thenThrow(
          const AccountDeletionRecoveryException(
            'Could not authorize deletion attempt request',
          ),
        );
        final current = await tester.runAsync(
          () => container.read(currentAccountDeletionAttemptProvider.future),
        );
        expect(current, same(_processing));
        verifyNever(repository.fetchCurrent);
        verify(authService.signOut).called(1);
        await container.read(submittedAccountDeletionMonitorProvider)?.close();
      },
    );

    testWidgets('a pending receipt blocks deletion for another account', (
      tester,
    ) async {
      final recoveryCubit = _MockRecoveryCubit();
      when(() => recoveryCubit.state).thenReturn(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.processing,
          attempt: _processing,
          pollingPaused: true,
        ),
      );
      when(() => recoveryCubit.resume(_processing)).thenAnswer((_) async {});
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          accountDeletionServiceProvider.overrideWithValue(deletionService),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
          submittedAccountDeletionMonitorProvider.overrideWithValue(
            recoveryCubit,
          ),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: 'different-account-pubkey',
            attempt: _processing,
            vanishEventId: 'other-vanish-event-id',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  key: const Key('delete'),
                  onPressed: () => startAccountDeletionFlow(
                    context: context,
                    ref: ref,
                    screenName: 'Test',
                  ),
                  child: const Text('Delete'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('delete')));
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(l10n.accountDeletionOtherAccountPending),
        findsOneWidget,
      );
      expect(find.text(l10n.supportContactSupport), findsOneWidget);
      verify(() => recoveryCubit.resume(_processing)).called(1);
      verifyNever(repository.prepare);
      verifyNever(
        () => deletionService.deleteAccount(
          onProgress: any(named: 'onProgress'),
          expectedPubkey: any(named: 'expectedPubkey'),
        ),
      );
    });
  });
}
