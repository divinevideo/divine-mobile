// ABOUTME: Tests the account-deletion recovery providers used by routing.
// ABOUTME: Verifies lookup readiness remains fail-closed until signing works.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _vanishEventId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

class _AuthStateProbe extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.authenticated;

  void set(AuthState next) => state = next;
}

final _authStateProbe = NotifierProvider<_AuthStateProbe, AuthState>(
  _AuthStateProbe.new,
);

class _TestNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: _pubkeyA);
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  group('currentAccountDeletionAttemptProvider', () {
    test(
      'lookup starts when signing is ready without waiting for relays',
      () async {
        final repository = _MockDeletionRepository();
        final authService = _MockAuthService();
        when(repository.fetchCurrent).thenAnswer((_) async => null);
        when(
          () => authService.signerReadiness,
        ).thenReturn(SignerReadiness.ready);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.unavailable,
            ),
            nostrSessionProvider.overrideWith(_TestNostrSession.new),
            accountDeletionRecoveryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          currentAccountDeletionAttemptProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await container.read(currentAccountDeletionAttemptProvider.future);

        expect(
          container.read(currentAccountDeletionAttemptProvider).value,
          isNull,
        );
        verify(repository.fetchCurrent).called(1);
      },
    );

    test('lookup settles without a receipt while signing warms up', () async {
      final repository = _MockDeletionRepository();
      final authService = _MockAuthService();
      when(
        () => authService.signerReadiness,
      ).thenReturn(SignerReadiness.pending);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.upgrading,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        currentAccountDeletionAttemptProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.read(currentAccountDeletionAttemptProvider.future);

      expect(
        container.read(currentAccountDeletionAttemptProvider).value,
        isNull,
      );
      verifyNever(repository.fetchCurrent);
    });

    test('permanent signer failure settles as a typed error', () async {
      final repository = _MockDeletionRepository();
      final authService = _MockAuthService();
      when(
        () => authService.signerReadiness,
      ).thenReturn(SignerReadiness.unavailable);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final settled = Completer<AsyncValue<AccountDeletionAttempt?>>();
      final subscription = container.listen(
        currentAccountDeletionAttemptProvider,
        (_, next) {
          if (next.hasError && !next.isLoading && !settled.isCompleted) {
            settled.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final result = await settled.future;
      expect(result.isLoading, isFalse);
      expect(result.error, isA<AccountDeletionStatusUnavailable>());
      verifyNever(repository.fetchCurrent);
    });
  });

  group('submittedAccountDeletionAttemptProvider', () {
    const pubkey = _pubkeyA;
    const processing = AccountDeletionAttempt(
      id: 'attempt-id',
      status: AccountDeletionAttemptStatus.processing,
    );

    late _MockDeletionRepository repository;
    late _MockAuthService authService;
    late ProviderContainer container;

    setUp(() {
      repository = _MockDeletionRepository();
      authService = _MockAuthService();
      when(repository.fetchCurrent).thenAnswer((_) async => null);
      when(() => authService.signerReadiness).thenReturn(SignerReadiness.ready);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    // Listened after the record is written, the way the router listens
    // from app start: the lookup must never have been needed.
    void keepAlive() {
      final subscription = container.listen(
        currentAccountDeletionAttemptProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
    }

    group('recovery watch anchor', () {
      /// A container whose clock the test drives, so "later" is exact.
      ProviderContainer containerAt(DateTime now) {
        final made = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.rpcReady,
            ),
            accountDeletionRecoveryRepositoryProvider.overrideWithValue(
              repository,
            ),
            accountDeletionRecoveryClockProvider.overrideWithValue(() => now),
          ],
        );
        addTearDown(made.dispose);
        return made;
      }

      test('is stamped when the receipt is first recorded', () async {
        final at = DateTime.utc(2026, 3, 4, 5);
        final scoped = containerAt(at);
        await scoped
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: _vanishEventId,
            );

        expect(
          scoped
              .read(submittedAccountDeletionAttemptProvider)!
              .recoveryWatchStartedAt,
          at,
        );
      });

      test(
        're-recording the same attempt keeps the original anchor, so the '
        'support budget cannot be pushed out by a status refresh',
        () async {
          final first = DateTime.utc(2026, 3, 4, 5);
          final scoped = containerAt(first);
          final notifier = scoped.read(
            submittedAccountDeletionAttemptProvider.notifier,
          );
          await notifier.record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: _vanishEventId,
          );

          // Same attempt id, recorded again half an hour later.
          final later = containerAt(first.add(const Duration(minutes: 30)));
          await later
              .read(submittedAccountDeletionAttemptProvider.notifier)
              .record(
                pubkeyHex: pubkey,
                attempt: processing,
                vanishEventId: _vanishEventId,
              );

          expect(
            later
                .read(submittedAccountDeletionAttemptProvider)!
                .recoveryWatchStartedAt,
            first,
          );
        },
      );

      test('updateAttempt does not restamp the anchor', () async {
        final first = DateTime.utc(2026, 3, 4, 5);
        final scoped = containerAt(first);
        await scoped
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: _vanishEventId,
            );

        final later = containerAt(first.add(const Duration(minutes: 30)));
        await later
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .updateAttempt(
              const AccountDeletionAttempt(
                id: 'attempt-id',
                status: AccountDeletionAttemptStatus.completed,
              ),
            );

        final receipt = later.read(submittedAccountDeletionAttemptProvider)!;
        expect(receipt.recoveryWatchStartedAt, first);
        expect(receipt.attempt.status, AccountDeletionAttemptStatus.completed);
      });

      test(
        'a legacy receipt is stamped once on adoption and that stamp sticks, '
        'so the budget is not re-anchored on every read',
        () async {
          // A receipt written before the field existed.
          SharedPreferences.setMockInitialValues({
            'account_deletion_receipt_v1': jsonEncode({
              'pubkey_hex': pubkey,
              'vanish_event_id': _vanishEventId,
              'attempt': processing.toJson(),
            }),
          });
          final legacyPrefs = await SharedPreferences.getInstance();

          ProviderContainer adoptAt(DateTime now) {
            final made = ProviderContainer(
              overrides: [
                sharedPreferencesProvider.overrideWithValue(legacyPrefs),
                authServiceProvider.overrideWithValue(authService),
                currentAuthStateProvider.overrideWithValue(
                  AuthState.authenticated,
                ),
                currentAuthRpcCapabilityProvider.overrideWithValue(
                  AuthRpcCapability.rpcReady,
                ),
                accountDeletionRecoveryRepositoryProvider.overrideWithValue(
                  repository,
                ),
                accountDeletionRecoveryClockProvider.overrideWithValue(
                  () => now,
                ),
              ],
            );
            addTearDown(made.dispose);
            return made;
          }

          final adopted = DateTime.utc(2026, 3, 4, 5);
          final first = adoptAt(adopted);
          expect(
            first
                .read(submittedAccountDeletionAttemptProvider)!
                .recoveryWatchStartedAt,
            adopted,
          );
          // Settle the unawaited backfill write rather than sleeping on it.
          await pumpEventQueue();

          final later = adoptAt(adopted.add(const Duration(hours: 1)));
          expect(
            later
                .read(submittedAccountDeletionAttemptProvider)!
                .recoveryWatchStartedAt,
            adopted,
            reason: 'the adoption stamp was persisted, not recomputed',
          );
        },
      );
    });

    test(
      'a recorded attempt is the current attempt without a lookup',
      () async {
        // The signer the deletion just killed: every lookup fails, exactly
        // as it does once the coordinator has deleted the Keycast user
        // (#8583).
        when(repository.fetchCurrent).thenThrow(
          const AccountDeletionRecoveryException(
            'Could not authorize deletion attempt request',
          ),
        );
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: _vanishEventId,
            );
        keepAlive();

        expect(
          await container.read(currentAccountDeletionAttemptProvider.future),
          same(processing),
        );
        verifyNever(repository.fetchCurrent);
      },
    );

    test('a recorded attempt survives a new provider container', () async {
      await container
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: _vanishEventId,
          );
      final restarted = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(restarted.dispose);

      final receipt = restarted.read(submittedAccountDeletionAttemptProvider);
      expect(receipt?.pubkeyHex, pubkey);
      expect(receipt?.attempt.id, processing.id);
      expect(receipt?.attempt.status, processing.status);
      expect(receipt?.vanishEventId, _vanishEventId);
      expect(
        await restarted.read(currentAccountDeletionAttemptProvider.future),
        isNotNull,
      );
      verifyNever(repository.fetchCurrent);
    });

    test(
      'submitted monitor finishes cleanup after another account signs in',
      () async {
        final otherPubkey = 'b' * 64;
        when(() => authService.currentPublicKeyHex).thenReturn(otherPubkey);
        when(
          () => authService.deleteLocalAccount(pubkey),
        ).thenAnswer((_) async {});
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: 'c' * 64,
            );
        final subscription = container.listen(
          submittedAccountDeletionMonitorProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        final cubit = subscription.read()!;

        expect(
          container.read(currentSubmittedAccountDeletionAttemptProvider),
          isNull,
        );
        await cubit.resume(
          const AccountDeletionAttempt(
            id: 'attempt-id',
            status: AccountDeletionAttemptStatus.completed,
          ),
        );

        verify(() => authService.deleteLocalAccount(pubkey)).called(1);
        expect(
          container.read(submittedAccountDeletionAttemptProvider),
          isNull,
        );
        expect(
          cubit.state.status,
          anyOf(
            AccountDeletionRecoveryStatus.completed,
            AccountDeletionRecoveryStatus.resolved,
          ),
        );
      },
    );

    test(
      'submitted monitor waits for the deletion flow to release its receipt',
      () async {
        const recoverable = AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.recoverable,
        );
        when(
          () => repository.submit(
            attemptId: recoverable.id,
            vanishEventId: _vanishEventId,
          ),
        ).thenAnswer((_) async => processing);
        when(() => authService.signOut()).thenAnswer((_) async {});
        final subscription = container.listen(
          submittedAccountDeletionMonitorProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: recoverable,
              vanishEventId: _vanishEventId,
              submissionOwnedLocally: true,
            );
        await Future<void>.delayed(Duration.zero);

        expect(subscription.read(), isNull);
        verifyNever(
          () => repository.submit(
            attemptId: any(named: 'attemptId'),
            vanishEventId: any(named: 'vanishEventId'),
          ),
        );

        container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .releaseSubmissionOwnership();
        await untilCalled(
          () => repository.submit(
            attemptId: recoverable.id,
            vanishEventId: _vanishEventId,
          ),
        );

        verify(
          () => repository.submit(
            attemptId: recoverable.id,
            vanishEventId: _vanishEventId,
          ),
        ).called(1);
      },
    );

    for (final cleanupFailsBeforeSignIn in [false, true]) {
      test(
        'submitted monitor ${cleanupFailsBeforeSignIn ? 'retries' : 'resolves'} '
        'cleanup completed before another account signs in',
        () async {
          String? activePubkey;
          var cleanupCalls = 0;
          when(
            () => authService.currentPublicKeyHex,
          ).thenAnswer((_) => activePubkey);
          when(() => authService.deleteLocalAccount(pubkey)).thenAnswer((
            _,
          ) async {
            cleanupCalls++;
            if (cleanupFailsBeforeSignIn && cleanupCalls == 1) {
              throw StateError('keychain unavailable');
            }
          });
          final probe = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              authServiceProvider.overrideWithValue(authService),
              currentAuthStateProvider.overrideWith(
                (ref) => ref.watch(_authStateProbe),
              ),
              accountDeletionRecoveryRepositoryProvider.overrideWithValue(
                repository,
              ),
            ],
          );
          addTearDown(probe.dispose);
          probe.read(_authStateProbe.notifier).set(AuthState.unauthenticated);
          await probe
              .read(submittedAccountDeletionAttemptProvider.notifier)
              .record(
                pubkeyHex: pubkey,
                attempt: processing,
                vanishEventId: _vanishEventId,
              );
          final monitorSubscription = probe.listen(
            submittedAccountDeletionMonitorProvider,
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(monitorSubscription.close);
          final cubit = monitorSubscription.read()!;
          await cubit.resume(
            const AccountDeletionAttempt(
              id: 'attempt-id',
              status: AccountDeletionAttemptStatus.completed,
            ),
          );
          expect(
            cubit.state.status,
            cleanupFailsBeforeSignIn
                ? AccountDeletionRecoveryStatus.cleanupFailed
                : AccountDeletionRecoveryStatus.completed,
          );
          final resolved = Completer<void>();
          final receiptSubscription = probe.listen(
            submittedAccountDeletionAttemptProvider,
            (_, next) {
              if (next == null && !resolved.isCompleted) resolved.complete();
            },
          );
          addTearDown(receiptSubscription.close);

          activePubkey = _pubkeyB;
          probe.read(_authStateProbe.notifier).set(AuthState.authenticated);
          await resolved.future;

          expect(cleanupCalls, cleanupFailsBeforeSignIn ? 2 : 1);
          expect(
            probe.read(submittedAccountDeletionAttemptProvider),
            isNull,
          );
        },
      );
    }

    test('a durable record gates before authentication is restored', () async {
      final preAuth = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(preAuth.dispose);
      await preAuth
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: _pubkeyB,
            attempt: processing,
            vanishEventId: _vanishEventId,
          );

      expect(
        await preAuth.read(currentAccountDeletionAttemptProvider.future),
        same(processing),
      );
      verifyNever(repository.fetchCurrent);
    });

    test('a different authenticated account ignores the receipt', () async {
      when(
        () => authService.currentPublicKeyHex,
      ).thenReturn(_pubkeyB);
      await container
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: _vanishEventId,
          );
      keepAlive();

      expect(
        await container.read(currentAccountDeletionAttemptProvider.future),
        isNull,
      );
      expect(
        container.read(currentSubmittedAccountDeletionAttemptProvider),
        isNull,
      );
      verify(repository.fetchCurrent).called(1);
    });

    test(
      'a different account is not gated by a retained receipt after lookup '
      'failure',
      () async {
        final probe = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWith(
              (ref) => ref.watch(_authStateProbe),
            ),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.rpcReady,
            ),
            accountDeletionRecoveryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(probe.dispose);
        probe.read(_authStateProbe.notifier).set(AuthState.unauthenticated);
        await probe
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: _vanishEventId,
            );
        final subscription = probe.listen(
          currentAccountDeletionAttemptProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        expect(
          await probe.read(currentAccountDeletionAttemptProvider.future),
          same(processing),
        );

        when(
          () => authService.currentPublicKeyHex,
        ).thenReturn(_pubkeyB);
        when(repository.fetchCurrent).thenThrow(
          const AccountDeletionStatusUnavailable(),
        );
        probe.read(_authStateProbe.notifier).set(AuthState.authenticated);
        await expectLater(
          probe.read(currentAccountDeletionAttemptProvider.future),
          throwsA(isA<AccountDeletionStatusUnavailable>()),
        );

        final retained = probe.read(currentAccountDeletionAttemptProvider);
        expect(retained.hasError, isTrue);
        expect(retained.value, same(processing));
        expect(
          probe.read(currentSubmittedAccountDeletionAttemptProvider),
          isNull,
        );
        expect(
          accountDeletionRecoveryGateActive(
            retained,
            submittedAttempt: probe.read(
              submittedAccountDeletionAttemptProvider,
            ),
            authState: AuthState.authenticated,
            currentPubkeyHex: _pubkeyB,
          ),
          isFalse,
        );
      },
    );

    test('a second account cannot overwrite the pending receipt', () async {
      final notifier = container.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      await notifier.record(
        pubkeyHex: pubkey,
        attempt: processing,
        vanishEventId: _vanishEventId,
      );

      await expectLater(
        notifier.record(
          pubkeyHex: _pubkeyB,
          attempt: processing,
          vanishEventId: 'other-vanish-event-id',
        ),
        throwsStateError,
      );
      expect(notifier.state?.pubkeyHex, pubkey);
    });

    test('signing out preserves the record', () async {
      final probe = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(
            (ref) => ref.watch(_authStateProbe),
          ),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(probe.dispose);
      final subscription = probe.listen(
        submittedAccountDeletionAttemptProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await probe
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: _vanishEventId,
          );

      probe.read(_authStateProbe.notifier).set(AuthState.unauthenticated);
      await Future<void>.delayed(Duration.zero);

      expect(
        probe.read(submittedAccountDeletionAttemptProvider)?.attempt,
        same(processing),
      );
    });

    test('clearing the record hands the lookup back to the signer', () async {
      final notifier = container.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      await notifier.record(
        pubkeyHex: pubkey,
        attempt: processing,
        vanishEventId: _vanishEventId,
      );
      keepAlive();
      await container.read(currentAccountDeletionAttemptProvider.future);

      await notifier.clear(expectedPubkeyHex: pubkey);

      expect(
        await container.read(currentAccountDeletionAttemptProvider.future),
        isNull,
      );
      verify(repository.fetchCurrent).called(1);
    });

    test('a different account cannot clear the durable receipt', () async {
      final notifier = container.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      await notifier.record(
        pubkeyHex: pubkey,
        attempt: processing,
        vanishEventId: _vanishEventId,
      );

      await notifier.clear(expectedPubkeyHex: 'b' * 64);

      expect(
        container.read(submittedAccountDeletionAttemptProvider)?.pubkeyHex,
        pubkey,
      );
      expect(
        preferences.getString('account_deletion_receipt_v1'),
        isNotNull,
      );
    });

    test('a corrupt durable receipt is discarded explicitly', () async {
      await preferences.setString(
        'account_deletion_receipt_v1',
        '{"pubkey_hex":"$pubkey","attempt":"invalid"}',
      );

      expect(
        container.read(submittedAccountDeletionAttemptProvider),
        isNull,
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        preferences.containsKey('account_deletion_receipt_v1'),
        isFalse,
      );
    });
  });
}
