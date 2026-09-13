// ABOUTME: State-machine tests for interrupted account-deletion recovery.
// ABOUTME: Pins coordinator transitions, polling, cleanup, and close safety.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_poll_budget.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

class _MockRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _ManualTimer implements Timer {
  _ManualTimer(this.delay, this._callback);

  final Duration delay;
  final void Function() _callback;
  var _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

class _ManualTimers {
  _ManualTimers(this._advance);

  final void Function(Duration duration) _advance;
  final timers = <_ManualTimer>[];

  Timer create(Duration delay, void Function() callback) {
    final timer = _ManualTimer(delay, callback);
    timers.add(timer);
    return timer;
  }

  Future<void> fireNext() async {
    final timer = timers.firstWhere((timer) => timer.isActive);
    _advance(timer.delay);
    timer.fire();
    await Future<void>.delayed(Duration.zero);
  }
}

const _preparing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.preparing,
  username: 'alice',
);
const _preparingWithoutUsername = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.preparing,
);
const _recoverable = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
);
const _cancelling = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.preparing,
  operation: AccountDeletionAttemptOperation.cancelling,
  username: 'alice',
);
const _processing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.processing,
);
const _completed = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.completed,
);
const _cancelled = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.cancelled,
);

void main() {
  late _MockRepository repository;
  late _MockAuthService authService;
  late _ManualTimers timers;
  late int resolvedCalls;
  late DateTime now;

  AccountDeletionRecoveryCubit buildCubit({
    bool withReceipt = false,
    AccountDeletionRecoveryPollBudgetStore? pollBudgetStore,
    Future<void> Function()? onAttemptResolved,
    Future<void> Function(AccountDeletionAttempt)? onAttemptUpdated,
  }) => AccountDeletionRecoveryCubit(
    pollBudgetStore:
        pollBudgetStore ?? InMemoryAccountDeletionRecoveryPollBudgetStore(),
    repository: repository,
    authService: authService,
    onAttemptResolved: onAttemptResolved ?? () async => resolvedCalls++,
    onAttemptUpdated: onAttemptUpdated,
    receiptPubkeyHex: withReceipt ? 'a' * 64 : null,
    receiptVanishEventId: withReceipt ? 'b' * 64 : null,
    timerFactory: timers.create,
    now: () => now,
  );

  setUpAll(() {
    registerFallbackValue(_preparing);
  });

  setUp(() {
    repository = _MockRepository();
    authService = _MockAuthService();
    now = DateTime.utc(2026, 9, 10, 12);
    timers = _ManualTimers((duration) => now = now.add(duration));
    resolvedCalls = 0;
    when(() => authService.signerReadiness).thenReturn(SignerReadiness.ready);
    when(() => authService.currentPublicKeyHex).thenReturn(null);
    when(() => authService.deleteLocalAccount(any())).thenAnswer((_) async {});
  });

  group('signer readiness', () {
    test('unavailable signer enters a typed load failure', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      cubit.signerUnavailable();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.loadFailed);
      expect(
        cubit.state.failure,
        AccountDeletionRecoveryFailure.signerUnavailable,
      );
      verifyNever(repository.fetchCurrent);
    });

    test(
      'retry refreshes an expired session while signer is unavailable',
      () async {
        when(
          () => authService.signerReadiness,
        ).thenReturn(SignerReadiness.unavailable);
        when(
          () => authService.tryRefreshExpiredSession(),
        ).thenAnswer((_) async => false);
        final cubit = buildCubit();
        cubit.signerUnavailable();
        addTearDown(cubit.close);

        await cubit.retry();

        verify(authService.tryRefreshExpiredSession).called(1);
        expect(
          cubit.state.failure,
          AccountDeletionRecoveryFailure.signerUnavailable,
        );
        verifyNever(repository.fetchCurrent);
      },
    );

    test(
      'unavailable signer with a cancellable attempt keeps the retry path',
      () async {
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.signerUnavailable(attempt: _recoverable);

        expect(cubit.state.status, AccountDeletionRecoveryStatus.loadFailed);
        expect(
          cubit.state.failure,
          AccountDeletionRecoveryFailure.signerUnavailable,
        );
        verifyNever(() => authService.signOut());
      },
    );

    test(
      'unavailable signer with a processing attempt ends the session',
      () async {
        when(() => authService.signOut()).thenAnswer((_) async {});
        final cubit = buildCubit();
        addTearDown(cubit.close);
        final statuses = <AccountDeletionRecoveryStatus>[];
        final subscription = cubit.stream.listen(
          (state) => statuses.add(state.status),
        );
        addTearDown(subscription.cancel);

        await cubit.signerUnavailable(attempt: _processing);
        await pumpEventQueue();

        expect(statuses, [
          AccountDeletionRecoveryStatus.signingOut,
          AccountDeletionRecoveryStatus.processing,
        ]);
        verify(() => authService.signOut()).called(1);
        verifyNever(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );
        verifyNever(repository.fetchCurrent);
        expect(resolvedCalls, 0);
      },
    );

    test('retry preserves a processing attempt when refresh fails', () async {
      when(
        () => authService.signerReadiness,
      ).thenReturn(SignerReadiness.unavailable);
      when(authService.tryRefreshExpiredSession).thenAnswer((_) async => false);
      when(authService.signOut).thenAnswer((_) async {});
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.resume(_processing);

      await cubit.retry();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      expect(cubit.state.attempt, same(_processing));
      verify(authService.tryRefreshExpiredSession).called(1);
      verify(authService.signOut).called(1);
    });

    test(
      'unavailable signer with a completed attempt finishes local cleanup',
      () async {
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {});
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.signerUnavailable(attempt: _completed);

        expect(cubit.state.status, AccountDeletionRecoveryStatus.completed);
        verify(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).called(1);
        verifyNever(repository.fetchCurrent);
      },
    );
  });

  group('resume', () {
    test('adopts a processing attempt and polls without a lookup', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.resume(_processing);

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      expect(cubit.state.attempt, same(_processing));
      verifyNever(repository.fetchCurrent);
      expect(timers.timers.where((timer) => timer.isActive), hasLength(1));
    });

    test('a failed poll keeps the known processing state', () async {
      when(repository.fetchCurrent).thenThrow(
        const AccountDeletionRecoveryException(
          'Could not authorize deletion attempt request',
        ),
      );
      final cubit = buildCubit();
      addTearDown(cubit.close);
      await cubit.resume(_processing);

      await timers.fireNext();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      expect(cubit.state.attempt, same(_processing));
      expect(cubit.state.pollTickIndex, 1);
      verify(repository.fetchCurrent).called(1);
    });

    test('a signed-out receipt polls the public status endpoint', () async {
      when(
        () => repository.fetchStatus(
          attemptId: _processing.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenAnswer((_) async => _processing);
      final cubit = buildCubit(withReceipt: true);
      addTearDown(cubit.close);

      await cubit.resume(_processing);
      await timers.fireNext();

      verify(
        () => repository.fetchStatus(
          attemptId: _processing.id,
          pubkeyHex: 'a' * 64,
        ),
      ).called(1);
      verifyNever(repository.fetchCurrent);
    });

    test('a signed-in receipt polls with the authenticated endpoint', () async {
      when(() => authService.currentPublicKeyHex).thenReturn('a' * 64);
      when(repository.fetchCurrent).thenAnswer((_) async => _processing);
      final cubit = buildCubit(withReceipt: true);
      addTearDown(cubit.close);

      await cubit.resume(_processing);
      await timers.fireNext();

      verify(repository.fetchCurrent).called(1);
      verifyNever(
        () => repository.fetchStatus(
          attemptId: any(named: 'attemptId'),
          pubkeyHex: any(named: 'pubkeyHex'),
        ),
      );
    });

    test('switching accounts preserves the processing receipt', () async {
      when(authService.signOut).thenAnswer((_) async {});
      final cubit = buildCubit(withReceipt: true);
      addTearDown(cubit.close);
      await cubit.resume(_processing);

      final switched = await cubit.switchAccount();

      expect(switched, isTrue);
      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      expect(cubit.state.attempt, same(_processing));
      expect(resolvedCalls, 0);
      verify(authService.signOut).called(1);
    });

    test('a failed account switch exposes the sign-out failure', () async {
      when(authService.signOut).thenThrow(StateError('sign out failed'));
      final cubit = buildCubit(withReceipt: true);
      addTearDown(cubit.close);
      await cubit.resume(_processing);

      final switched = await cubit.switchAccount();

      expect(switched, isFalse);
      expect(cubit.state.status, AccountDeletionRecoveryStatus.signOutFailed);
      expect(cubit.state.failure, AccountDeletionRecoveryFailure.signOut);
      expect(cubit.state.attempt, same(_processing));
    });
  });

  group('load', () {
    final cases = <(AccountDeletionAttempt, AccountDeletionRecoveryStatus)>[
      (_preparing, AccountDeletionRecoveryStatus.restorable),
      (_recoverable, AccountDeletionRecoveryStatus.restorable),
      (_cancelling, AccountDeletionRecoveryStatus.cancelInFlight),
      (_processing, AccountDeletionRecoveryStatus.processing),
      (
        const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.terminalFailure,
        ),
        AccountDeletionRecoveryStatus.terminalFailure,
      ),
    ];

    for (final (attempt, expectedStatus) in cases) {
      test('${attempt.status.name} + ${attempt.operation.name}', () async {
        when(repository.fetchCurrent).thenAnswer((_) async => attempt);
        final cubit = buildCubit();

        await cubit.load();

        expect(cubit.state.status, expectedStatus);
        expect(cubit.state.attempt, same(attempt));
        await cubit.close();
      });
    }

    test(
      'completed deletes local credentials only after server completion',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _completed);
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {});
        final cubit = buildCubit();

        await cubit.load();

        expect(cubit.state.status, AccountDeletionRecoveryStatus.completed);
        verify(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).called(1);
        expect(resolvedCalls, 0);
        await cubit.close();
      },
    );

    test(
      'absent and cancelled attempts resolve without local deletion',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => null);
        final absentCubit = buildCubit();
        await absentCubit.load();
        expect(
          absentCubit.state.status,
          AccountDeletionRecoveryStatus.resolved,
        );
        await absentCubit.close();

        when(repository.fetchCurrent).thenAnswer((_) async => _cancelled);
        final cancelledCubit = buildCubit();
        await cancelledCubit.load();
        expect(
          cancelledCubit.state.status,
          AccountDeletionRecoveryStatus.resolved,
        );
        verifyNever(
          () => authService.signOut(
            deleteKeys: any(named: 'deleteKeys'),
            deleteLocalUserData: any(named: 'deleteLocalUserData'),
          ),
        );
        await cancelledCubit.close();
      },
    );

    test('lookup error fails closed without carrying an exception', () async {
      when(repository.fetchCurrent).thenThrow(const FormatException('bad'));
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.loadFailed);
      expect(cubit.state.failure, AccountDeletionRecoveryFailure.statusLookup);
      await cubit.close();
    });
  });

  group('cancel', () {
    test('username-free preparing attempt cancels without resuming', () async {
      when(
        repository.fetchCurrent,
      ).thenAnswer((_) async => _preparingWithoutUsername);
      when(
        () => repository.cancel(attemptId: 'attempt-id'),
      ).thenAnswer((_) async => _cancelled);
      final cubit = buildCubit();
      await cubit.load();

      await cubit.cancel();

      verifyNever(() => repository.resumePreparation(any()));
      verify(() => repository.cancel(attemptId: 'attempt-id')).called(1);
      expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
      await cubit.close();
    });

    test(
      'preparing username completes handshake before 200 cancellation',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _preparing);
        when(
          () => repository.resumePreparation(_preparing),
        ).thenAnswer((_) async => _recoverable);
        when(
          () => repository.cancel(attemptId: 'attempt-id'),
        ).thenAnswer((_) async => _cancelled);
        final cubit = buildCubit();
        await cubit.load();

        await cubit.cancel();

        verify(() => repository.resumePreparation(_preparing)).called(1);
        expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
        await cubit.close();
      },
    );

    test(
      '202 cancellation enters polling and repeated cancel is ignored',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _recoverable);
        when(
          () => repository.cancel(attemptId: 'attempt-id'),
        ).thenAnswer((_) async => _cancelling);
        final cubit = buildCubit();
        await cubit.load();

        await cubit.cancel();
        await cubit.cancel();

        expect(
          cubit.state.status,
          AccountDeletionRecoveryStatus.cancelInFlight,
        );
        verify(() => repository.cancel(attemptId: 'attempt-id')).called(1);
        verifyNever(() => repository.resumePreparation(any()));
        await cubit.close();
      },
    );

    test('cancellation after commit reloads processing state', () async {
      var fetches = 0;
      when(repository.fetchCurrent).thenAnswer((_) async {
        fetches++;
        return fetches == 1 ? _recoverable : _processing;
      });
      when(() => repository.cancel(attemptId: 'attempt-id')).thenThrow(
        const AccountDeletionRecoveryException(
          'conflict',
          code: 'cancellation_after_commit',
        ),
      );
      final cubit = buildCubit();
      await cubit.load();

      await cubit.cancel();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      await cubit.close();
    });
  });

  group('polling and cleanup', () {
    test('polling retries transient failure and completes cleanup', () async {
      var fetches = 0;
      when(repository.fetchCurrent).thenAnswer((_) async {
        fetches++;
        if (fetches == 1) return _processing;
        if (fetches == 2) {
          throw const AccountDeletionRecoveryException('offline');
        }
        return _completed;
      });
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenAnswer((_) async {});
      final cubit = buildCubit();
      await cubit.load();

      await timers.fireNext();
      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      expect(cubit.state.pollTickIndex, 1);
      await timers.fireNext();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.completed);
      expect(fetches, 3);
      await cubit.close();
    });

    test('polling fails closed when the attempt identity changes', () async {
      var fetches = 0;
      when(repository.fetchCurrent).thenAnswer((_) async {
        fetches++;
        return fetches == 1
            ? _processing
            : const AccountDeletionAttempt(
                id: 'different-attempt-id',
                status: AccountDeletionAttemptStatus.processing,
              );
      });
      final cubit = buildCubit();
      await cubit.load();

      await timers.fireNext();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.loadFailed);
      expect(timers.timers.where((timer) => timer.isActive), isEmpty);

      when(authService.signOut).thenAnswer((_) async {});
      await cubit.signOut();
      expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
      expect(resolvedCalls, 1);
      await cubit.close();
    });

    test('receipt completion deletes the named signed-out account', () async {
      when(
        () => repository.fetchStatus(
          attemptId: _processing.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenAnswer((_) async => _completed);
      final cubit = buildCubit(withReceipt: true);
      await cubit.resume(_processing);

      await timers.fireNext();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.completed);
      verify(() => authService.deleteLocalAccount('a' * 64)).called(1);
      verifyNever(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      );
      await cubit.close();
    });

    test(
      'receipt completion resolves after deleting a different active account',
      () async {
        when(() => authService.currentPublicKeyHex).thenReturn('c' * 64);
        final cubit = buildCubit(withReceipt: true);

        await cubit.resume(_completed);

        verify(() => authService.deleteLocalAccount('a' * 64)).called(1);
        verifyNever(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        );
        expect(resolvedCalls, 1);
        expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
        await cubit.close();
      },
    );

    test('receipt update failure polls again before local cleanup', () async {
      var updates = 0;
      when(
        () => repository.fetchStatus(
          attemptId: _completed.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenAnswer((_) async => _completed);
      final cubit = buildCubit(
        withReceipt: true,
        onAttemptUpdated: (_) async {
          updates++;
          if (updates == 1) throw StateError('receipt write failed');
        },
      );

      await cubit.resume(_completed);

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      verifyNever(() => authService.deleteLocalAccount(any()));
      await timers.fireNext();

      expect(updates, 2);
      verify(() => authService.deleteLocalAccount('a' * 64)).called(1);
      expect(cubit.state.status, AccountDeletionRecoveryStatus.completed);
      await cubit.close();
    });

    test(
      'different active account pauses polling at the support threshold',
      () async {
        when(() => authService.currentPublicKeyHex).thenReturn('c' * 64);
        when(
          () => repository.fetchStatus(
            attemptId: _processing.id,
            pubkeyHex: 'a' * 64,
          ),
        ).thenAnswer((_) async => _processing);
        final cubit = buildCubit(withReceipt: true);
        await cubit.resume(_processing);

        while (timers.timers.any((timer) => timer.isActive)) {
          await timers.fireNext();
        }

        expect(cubit.state.pollingPaused, isTrue);
        expect(timers.timers.any((timer) => timer.isActive), isFalse);
        await cubit.close();
      },
    );

    test(
      'expired durable watch refreshes once before exposing support',
      () async {
        when(() => authService.currentPublicKeyHex).thenReturn('c' * 64);
        when(
          () => repository.fetchStatus(
            attemptId: _processing.id,
            pubkeyHex: 'a' * 64,
          ),
        ).thenAnswer((_) async => _processing);
        final store = InMemoryAccountDeletionRecoveryPollBudgetStore();
        await store.recordStartIfAbsent(
          _processing.id,
          now.subtract(const Duration(minutes: 16)),
        );
        final cubit = buildCubit(withReceipt: true, pollBudgetStore: store);

        await cubit.resume(_processing);

        expect(
          timers.timers.singleWhere((timer) => timer.isActive).delay,
          Duration.zero,
        );
        await timers.fireNext();

        expect(cubit.state.pollingPaused, isTrue);
        verify(
          () => repository.fetchStatus(
            attemptId: _processing.id,
            pubkeyHex: 'a' * 64,
          ),
        ).called(1);
        expect(timers.timers.any((timer) => timer.isActive), isFalse);
        await cubit.close();
      },
    );

    test('resume does not renew the overdue refresh allowance', () async {
      when(() => authService.currentPublicKeyHex).thenReturn('c' * 64);
      when(
        () => repository.fetchStatus(
          attemptId: _processing.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenAnswer((_) async => _processing);
      final store = InMemoryAccountDeletionRecoveryPollBudgetStore();
      await store.recordStartIfAbsent(
        _processing.id,
        now.subtract(const Duration(minutes: 16)),
      );
      final cubit = buildCubit(withReceipt: true, pollBudgetStore: store);

      await cubit.resume(_processing);
      await timers.fireNext();
      await cubit.resume(_processing);

      expect(cubit.state.pollingPaused, isTrue);
      expect(timers.timers.any((timer) => timer.isActive), isFalse);
      verify(
        () => repository.fetchStatus(
          attemptId: _processing.id,
          pubkeyHex: 'a' * 64,
        ),
      ).called(1);
      await cubit.close();
    });

    test('receipt-less relaunch keeps the same attempt budget', () async {
      when(repository.fetchCurrent).thenAnswer((_) async => _processing);
      final store = InMemoryAccountDeletionRecoveryPollBudgetStore();
      final first = buildCubit(pollBudgetStore: store);
      await first.load();
      await first.close();
      now = now.add(const Duration(minutes: 16));

      final relaunched = buildCubit(pollBudgetStore: store);
      addTearDown(relaunched.close);
      await relaunched.resume(_processing);

      expect(
        timers.timers.singleWhere((timer) => timer.isActive).delay,
        Duration.zero,
      );
    });

    test('a different attempt receives a fresh budget', () async {
      final store = InMemoryAccountDeletionRecoveryPollBudgetStore();
      await store.recordStartIfAbsent(
        _processing.id,
        now.subtract(const Duration(minutes: 16)),
      );
      const differentAttempt = AccountDeletionAttempt(
        id: 'different-attempt-id',
        status: AccountDeletionAttemptStatus.processing,
      );
      final cubit = buildCubit(pollBudgetStore: store);

      await cubit.resume(_processing);
      await cubit.resume(differentAttempt);

      expect(
        timers.timers.singleWhere((timer) => timer.isActive).delay,
        AccountDeletionRecoveryPolling.schedule.first,
      );
      await cubit.close();
    });

    test('fresh load does not perform a redundant overdue refresh', () async {
      when(repository.fetchCurrent).thenAnswer((_) async => _processing);
      final store = InMemoryAccountDeletionRecoveryPollBudgetStore();
      await store.recordStartIfAbsent(
        _processing.id,
        now.subtract(const Duration(minutes: 16)),
      );
      final cubit = buildCubit(pollBudgetStore: store);

      await cubit.load();

      expect(cubit.state.pollingPaused, isTrue);
      expect(timers.timers.any((timer) => timer.isActive), isFalse);
      verify(repository.fetchCurrent).called(1);
      await cubit.close();
    });

    test('resolution clears the durable budget for that attempt', () async {
      when(repository.fetchCurrent).thenAnswer((_) async => _cancelled);
      final store = InMemoryAccountDeletionRecoveryPollBudgetStore();
      final cubit = buildCubit(pollBudgetStore: store);

      await cubit.resume(_processing);
      expect(await store.startedAt(_processing.id), isNotNull);
      await timers.fireNext();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
      expect(await store.startedAt(_processing.id), isNull);
      await cubit.close();
    });

    test('unknown public status stays gated and pauses at the bound', () async {
      when(() => authService.currentPublicKeyHex).thenReturn('c' * 64);
      when(
        () => repository.fetchStatus(
          attemptId: _processing.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenThrow(
        const AccountDeletionRecoveryException(
          'Attempt not found',
          code: 'attempt_not_found',
          statusCode: 404,
        ),
      );
      final cubit = buildCubit(withReceipt: true);
      await cubit.resume(_processing);

      while (timers.timers.any((timer) => timer.isActive)) {
        await timers.fireNext();
      }

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      expect(cubit.state.attempt, _processing);
      expect(cubit.state.pollingPaused, isTrue);
      expect(resolvedCalls, 0);
      await cubit.close();
    });

    test(
      'unknown authenticated status stays gated and pauses at the bound',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => null);
        final cubit = buildCubit(withReceipt: true);
        await cubit.resume(_processing);

        while (timers.timers.any((timer) => timer.isActive)) {
          await timers.fireNext();
        }

        expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
        expect(cubit.state.attempt, _processing);
        expect(cubit.state.pollingPaused, isTrue);
        expect(resolvedCalls, 0);
        await cubit.close();
      },
    );

    test('durable cleanup keeps retrying after repeated failures', () async {
      var cleanupCalls = 0;
      when(() => authService.currentPublicKeyHex).thenReturn('c' * 64);
      when(() => authService.deleteLocalAccount('a' * 64)).thenAnswer((
        _,
      ) async {
        cleanupCalls++;
        if (cleanupCalls < 3) {
          throw const SecureKeyStorageException('locked');
        }
      });
      when(
        () => repository.fetchStatus(
          attemptId: _completed.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenAnswer((_) async => _completed);
      final cubit = buildCubit(withReceipt: true);

      await cubit.resume(_completed);
      expect(
        cubit.state.failure,
        AccountDeletionRecoveryFailure.keychainCleanup,
      );
      expect(
        timers.timers.firstWhere((timer) => timer.isActive).delay,
        const Duration(seconds: 2),
      );
      await timers.fireNext();
      expect(
        cubit.state.failure,
        AccountDeletionRecoveryFailure.keychainCleanup,
      );
      expect(
        timers.timers.firstWhere((timer) => timer.isActive).delay,
        const Duration(seconds: 3),
      );
      await timers.fireNext();

      expect(cleanupCalls, 3);
      expect(resolvedCalls, 1);
      expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
      await cubit.close();
    });

    test('durable receipt clear failure retries through polling', () async {
      var clearCalls = 0;
      var updateCalls = 0;
      when(() => authService.currentPublicKeyHex).thenReturn(null);
      when(
        () => repository.fetchStatus(
          attemptId: _completed.id,
          pubkeyHex: 'a' * 64,
        ),
      ).thenAnswer((_) async => _completed);
      final cubit = buildCubit(
        withReceipt: true,
        onAttemptUpdated: (_) async => updateCalls++,
        onAttemptResolved: () async {
          clearCalls++;
          if (clearCalls == 1) throw StateError('receipt clear failed');
        },
      );
      await cubit.resume(_completed);

      await cubit.acknowledgeCompletion();
      expect(cubit.state.status, AccountDeletionRecoveryStatus.cleanupFailed);
      expect(cubit.state.failure, AccountDeletionRecoveryFailure.receiptClear);
      await timers.fireNext();

      expect(clearCalls, 2);
      expect(updateCalls, 1);
      verify(() => authService.deleteLocalAccount('a' * 64)).called(1);
      expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
      await cubit.close();
    });

    test(
      'polling pauses at the support threshold and keeps manual retry',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _processing);
        final cubit = buildCubit();
        await cubit.load();

        while (timers.timers.any((timer) => timer.isActive)) {
          await timers.fireNext();
        }

        expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
        expect(cubit.state.pollingPaused, isTrue);
        final fetchesBeforeRetry = cubit.state.pollTickIndex + 1;
        await cubit.retry();
        verify(repository.fetchCurrent).called(fetchesBeforeRetry + 1);
        expect(cubit.state.pollingPaused, isFalse);
        await cubit.close();
      },
    );

    test(
      'submission confirmation exposes actions at the support threshold',
      () async {
        when(
          () => repository.submit(
            attemptId: _recoverable.id,
            vanishEventId: 'b' * 64,
          ),
        ).thenThrow(const AccountDeletionRecoveryException('offline'));
        when(
          () => repository.fetchStatus(
            attemptId: _recoverable.id,
            pubkeyHex: 'a' * 64,
          ),
        ).thenAnswer((_) async => _recoverable);
        final cubit = buildCubit(withReceipt: true);

        await cubit.resume(_recoverable);
        final firstDelay = timers.timers.single.delay;
        await timers.fireNext();
        final secondDelay = timers.timers
            .singleWhere((timer) => timer.isActive)
            .delay;
        expect(secondDelay, greaterThan(firstDelay));
        while (timers.timers.any((timer) => timer.isActive)) {
          await timers.fireNext();
        }

        expect(
          cubit.state.status,
          AccountDeletionRecoveryStatus.confirmingSubmission,
        );
        expect(cubit.state.pollingPaused, isTrue);
        await cubit.close();
      },
    );

    test(
      'completion acknowledgement can retry a receipt clear failure',
      () async {
        var attempts = 0;
        when(repository.fetchCurrent).thenAnswer((_) async => _completed);
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenAnswer((_) async {});
        final cubit = buildCubit(
          onAttemptResolved: () async {
            attempts++;
            if (attempts == 1) throw StateError('receipt clear failed');
          },
        );
        await cubit.load();

        await expectLater(cubit.acknowledgeCompletion(), completes);
        expect(cubit.state.status, AccountDeletionRecoveryStatus.cleanupFailed);
        await cubit.completeLocalCleanup();

        expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
        expect(attempts, 2);
        await cubit.close();
      },
    );

    test(
      'cleanup failure records a typed reason and remains retryable',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _completed);
        when(
          () =>
              authService.signOut(deleteKeys: true, deleteLocalUserData: true),
        ).thenThrow(const SecureKeyStorageException('locked'));
        final cubit = buildCubit();

        await cubit.load();

        expect(cubit.state.status, AccountDeletionRecoveryStatus.cleanupFailed);
        expect(
          cubit.state.failure,
          AccountDeletionRecoveryFailure.keychainCleanup,
        );
        await cubit.close();
      },
    );

    test('local data cleanup failure has a distinct typed reason', () async {
      when(repository.fetchCurrent).thenAnswer((_) async => _completed);
      when(
        () => authService.signOut(deleteKeys: true, deleteLocalUserData: true),
      ).thenThrow(const UserDataCleanupException('failed'));
      final cubit = buildCubit();

      await cubit.load();

      expect(
        cubit.state.failure,
        AccountDeletionRecoveryFailure.localDataCleanup,
      );
      await cubit.close();
    });

    test('close during an in-flight request drops the resumed emit', () async {
      final completer = Completer<AccountDeletionAttempt?>();
      when(repository.fetchCurrent).thenAnswer((_) => completer.future);
      final cubit = buildCubit();
      final load = cubit.load();
      expect(cubit.state.status, AccountDeletionRecoveryStatus.loading);

      await cubit.close();
      completer.complete(_recoverable);
      await load;

      expect(cubit.state.status, AccountDeletionRecoveryStatus.loading);
    });

    test(
      'close while waiting for signer refresh drops the resumed emit',
      () async {
        final refresh = Completer<bool>();
        when(
          () => authService.signerReadiness,
        ).thenReturn(SignerReadiness.unavailable);
        when(
          () => authService.tryRefreshExpiredSession(),
        ).thenAnswer((_) => refresh.future);
        final cubit = buildCubit();
        cubit.signerUnavailable();

        final retry = cubit.retry();
        await Future<void>.delayed(Duration.zero);
        await cubit.close();
        refresh.complete(false);
        await retry;

        expect(cubit.state.status, AccountDeletionRecoveryStatus.loading);
      },
    );
  });
}
