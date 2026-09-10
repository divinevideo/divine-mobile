// ABOUTME: Owns the interrupted account-deletion recovery state machine.
// ABOUTME: Coordinates loading, cancellation, polling, cleanup, and sign-out.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_poll_budget.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

part 'account_deletion_recovery_state.dart';

abstract class AccountDeletionRecoveryPolling {
  static const schedule = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
    Duration(seconds: 21),
  ];
  static const cap = Duration(seconds: 30);
  static const sessionBound = Duration(minutes: 15);

  static Duration delayForTick(int tickIndex) =>
      tickIndex < schedule.length ? schedule[tickIndex] : cap;
}

typedef RecoveryTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

class AccountDeletionRecoveryCubit extends Cubit<AccountDeletionRecoveryState>
    with CloseGuardedEmit<AccountDeletionRecoveryState> {
  AccountDeletionRecoveryCubit({
    required AccountDeletionRecoveryRepository repository,
    required AuthService authService,
    required Future<void> Function() onAttemptResolved,
    Future<void> Function(AccountDeletionAttempt attempt)? onAttemptUpdated,
    String? receiptPubkeyHex,
    String? receiptVanishEventId,
    RecoveryTimerFactory timerFactory = Timer.new,
    AccountDeletionRecoveryPollBudgetStore? pollBudgetStore,
    DateTime Function() clock = DateTime.now,
  }) : _repository = repository,
       _authService = authService,
       _onAttemptResolved = onAttemptResolved,
       _onAttemptUpdated = onAttemptUpdated,
       _receiptPubkeyHex = receiptPubkeyHex,
       _receiptVanishEventId = receiptVanishEventId,
       _timerFactory = timerFactory,
       _pollBudgetStore =
           pollBudgetStore ?? InMemoryAccountDeletionRecoveryPollBudgetStore(),
       _clock = clock,
       super(const AccountDeletionRecoveryState());

  final AccountDeletionRecoveryRepository _repository;
  final AuthService _authService;
  final Future<void> Function() _onAttemptResolved;
  final Future<void> Function(AccountDeletionAttempt attempt)?
  _onAttemptUpdated;
  final String? _receiptPubkeyHex;
  final String? _receiptVanishEventId;
  final RecoveryTimerFactory _timerFactory;
  final AccountDeletionRecoveryPollBudgetStore _pollBudgetStore;
  final DateTime Function() _clock;

  Timer? _pollTimer;
  var _generation = 0;

  /// Wall-clock start of this attempt's polling budget, cached from
  /// [_pollBudgetStore]. Null until an attempt that polls has been handled.
  DateTime? _pollBudgetStartedAt;

  /// How much of [AccountDeletionRecoveryPolling.sessionBound] this attempt
  /// has spent, measured in elapsed time rather than in timer delays this
  /// process happened to run. That distinction is the fix: the old
  /// accumulator only advanced while the app was foregrounded and alive, so
  /// backgrounding — the natural thing to do while waiting on a server — reset
  /// the budget on every launch and the "contact support" message was
  /// unreachable no matter how long the wait actually was.
  Duration get _pollingSpent {
    final startedAt = _pollBudgetStartedAt;
    if (startedAt == null) return Duration.zero;
    final spent = _clock().difference(startedAt);
    return spent.isNegative ? Duration.zero : spent;
  }

  Future<void> load() async {
    final generation = _beginOperation();
    emit(
      const AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.loading,
      ),
    );
    try {
      final attempt = await _repository.fetchCurrent();
      if (!_isCurrent(generation)) return;
      await _handleAttempt(attempt, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loadFailed,
          failure: AccountDeletionRecoveryFailure.statusLookup,
        ),
      );
    }
  }

  Future<void> retry() async {
    // An explicit retry is the user asking for another round, so it restarts
    // the budget. A relaunch is not — that path goes through [load], which
    // re-reads the same attempt's persisted start and keeps counting.
    await _restartPollBudget();
    if (_authService.signerReadiness == SignerReadiness.unavailable) {
      final attempt = state.attempt;
      final generation = _beginOperation();
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loading,
          attempt: attempt,
        ),
      );
      final refreshed = await _authService.tryRefreshExpiredSession();
      if (!_isCurrent(generation)) return;
      if (refreshed) {
        await load();
      } else {
        await signerUnavailable(attempt: attempt);
      }
      return;
    }
    return load();
  }

  /// Adopts an attempt this process already holds without a status lookup.
  ///
  /// After `submit` answers `processing` the coordinator deletes the Keycast
  /// user, so the lookup [load] starts with cannot be signed. Polling still
  /// runs from here; a failed poll keeps the known state rather than
  /// replacing it with a lookup failure.
  Future<void> resume(AccountDeletionAttempt attempt) async {
    final generation = _beginOperation();
    if (attempt.status == AccountDeletionAttemptStatus.recoverable &&
        _receiptVanishEventId != null) {
      await _confirmSubmission(attempt, generation: generation);
      return;
    }
    await _handleAttempt(attempt, generation: generation);
  }

  /// Reports that the signer is permanently unavailable.
  ///
  /// With no [attempt], or one the user could still cancel after signing in
  /// again, this holds the session-expired copy with retry and sign-out. A
  /// `processing` attempt cannot be cancelled and its Keycast account is what
  /// the signer just lost, so the local session ends while the durable receipt
  /// continues checking the coordinator (#8583).
  /// Terminal states need no signer and are handled as if fetched.
  Future<void> signerUnavailable({AccountDeletionAttempt? attempt}) async {
    switch (attempt?.status) {
      case null:
      case AccountDeletionAttemptStatus.preparing:
      case AccountDeletionAttemptStatus.recoverable:
        _beginOperation();
        emitIfOpen(
          const AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.loadFailed,
            failure: AccountDeletionRecoveryFailure.signerUnavailable,
          ),
        );
      case AccountDeletionAttemptStatus.processing:
        await _signOutForProcessing(attempt!);
      case AccountDeletionAttemptStatus.completed:
      case AccountDeletionAttemptStatus.cancelled:
      case AccountDeletionAttemptStatus.terminalFailure:
        await resume(attempt!);
    }
  }

  Future<void> cancel() async {
    final attempt = state.attempt;
    if (attempt == null ||
        state.status != AccountDeletionRecoveryStatus.restorable) {
      return;
    }
    final generation = _beginOperation();
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.cancelInFlight,
        attempt: attempt,
      ),
    );
    try {
      final ready = await _prepareForCancellation(attempt);
      if (!_isCurrent(generation)) return;
      final result = await _repository.cancel(attemptId: ready.id);
      if (!_isCurrent(generation)) return;
      await _handleAttempt(result, generation: generation);
    } on AccountDeletionRecoveryException catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      if (_requiresStatusRefresh(error.code)) {
        await _reloadAfterConflict(generation);
        return;
      }
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.restorable,
          attempt: attempt,
          failure: attempt.username == null
              ? AccountDeletionRecoveryFailure.statusLookup
              : AccountDeletionRecoveryFailure.usernameRestore,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.restorable,
          attempt: attempt,
          failure: attempt.username == null
              ? AccountDeletionRecoveryFailure.statusLookup
              : AccountDeletionRecoveryFailure.usernameRestore,
        ),
      );
    }
  }

  Future<void> completeLocalCleanup({
    bool preservePollingProgress = false,
  }) async {
    final attempt = state.attempt;
    if (attempt?.status != AccountDeletionAttemptStatus.completed) return;
    if (state.failure == AccountDeletionRecoveryFailure.receiptClear) {
      await _retryReceiptClear(attempt!);
      return;
    }
    final generation = _beginOperation(
      resetPollingProgress: !preservePollingProgress,
    );
    final pollTickIndex = state.pollTickIndex;
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.completingLocally,
        attempt: attempt,
        pollTickIndex: pollTickIndex,
      ),
    );
    try {
      final receiptPubkeyHex = _receiptPubkeyHex;
      final activePubkeyHex = _authService.currentPublicKeyHex;
      final deletingInactiveAccount =
          receiptPubkeyHex != null &&
          activePubkeyHex != null &&
          activePubkeyHex != receiptPubkeyHex;
      if (receiptPubkeyHex != null && activePubkeyHex != receiptPubkeyHex) {
        await _authService.deleteLocalAccount(receiptPubkeyHex);
      } else {
        await _authService.signOut(deleteKeys: true, deleteLocalUserData: true);
      }
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.completed,
          attempt: attempt,
          pollTickIndex: pollTickIndex,
        ),
      );
      if (deletingInactiveAccount) await _resolve();
    } on SecureKeyStorageException catch (error, stackTrace) {
      addError(error, stackTrace);
      _emitCleanupFailure(
        generation,
        attempt!,
        AccountDeletionRecoveryFailure.keychainCleanup,
      );
    } on UserDataCleanupException catch (error, stackTrace) {
      addError(error, stackTrace);
      _emitCleanupFailure(
        generation,
        attempt!,
        AccountDeletionRecoveryFailure.localDataCleanup,
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      _emitCleanupFailure(
        generation,
        attempt!,
        AccountDeletionRecoveryFailure.localDataCleanup,
      );
    }
  }

  Future<void> signOut() async {
    if (state.status == AccountDeletionRecoveryStatus.signingOut) return;
    final attempt = state.attempt;
    final generation = _beginOperation();
    emit(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.signingOut,
        attempt: attempt,
      ),
    );
    try {
      await _authService.signOut();
      if (!_isCurrent(generation)) return;
      await _resolve();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.signOutFailed,
          attempt: attempt,
          failure: AccountDeletionRecoveryFailure.signOut,
        ),
      );
    }
  }

  Future<void> acknowledgeCompletion() async {
    if (state.status != AccountDeletionRecoveryStatus.completed) return;
    await _retryReceiptClear(state.attempt!);
  }

  Future<void> _retryReceiptClear(AccountDeletionAttempt attempt) async {
    final generation = _beginOperation(resetPollingProgress: false);
    final pollTickIndex = state.pollTickIndex;
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.completingLocally,
        attempt: attempt,
        pollTickIndex: pollTickIndex,
      ),
    );
    try {
      await _resolve();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.cleanupFailed,
          attempt: attempt,
          failure: AccountDeletionRecoveryFailure.receiptClear,
          pollTickIndex: pollTickIndex,
        ),
      );
      if (_receiptPubkeyHex != null) _schedulePoll(generation);
    }
  }

  Future<bool> switchAccount() async {
    final attempt = state.attempt;
    if (attempt == null) return false;
    final generation = _beginOperation();
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.signingOut,
        attempt: attempt,
      ),
    );
    try {
      await _authService.signOut();
      if (!_isCurrent(generation)) return false;
      _emitPollingState(
        AccountDeletionRecoveryStatus.processing,
        attempt,
        generation,
      );
      return true;
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return false;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.signOutFailed,
          attempt: attempt,
          failure: AccountDeletionRecoveryFailure.signOut,
        ),
      );
      return false;
    }
  }

  Future<void> _signOutForProcessing(AccountDeletionAttempt attempt) async {
    final generation = _beginOperation();
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.signingOut,
        attempt: attempt,
      ),
    );
    try {
      await _authService.signOut();
      if (!_isCurrent(generation)) return;
      _emitPollingState(
        AccountDeletionRecoveryStatus.processing,
        attempt,
        generation,
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.signOutFailed,
          attempt: attempt,
          failure: AccountDeletionRecoveryFailure.signOut,
        ),
      );
    }
  }

  Future<void> _confirmSubmission(
    AccountDeletionAttempt attempt, {
    required int generation,
  }) async {
    final vanishEventId = _receiptVanishEventId;
    if (vanishEventId == null) return;
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.confirmingSubmission,
        attempt: attempt,
        pollTickIndex: state.pollTickIndex,
      ),
    );
    try {
      final submitted = await _repository.submit(
        attemptId: attempt.id,
        vanishEventId: vanishEventId,
      );
      if (!_isCurrent(generation)) return;
      await _onAttemptUpdated?.call(submitted);
      if (!_isCurrent(generation)) return;
      if (submitted.status == AccountDeletionAttemptStatus.processing) {
        await _signOutForProcessing(submitted);
        return;
      }
      await _handleAttempt(submitted, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      _schedulePoll(generation);
    }
  }

  Future<AccountDeletionAttempt> _prepareForCancellation(
    AccountDeletionAttempt attempt,
  ) async {
    if (attempt.status == AccountDeletionAttemptStatus.preparing &&
        !attempt.isCancellationInFlight &&
        attempt.username != null) {
      return _repository.resumePreparation(attempt);
    }
    return attempt;
  }

  Future<void> _reloadAfterConflict(int generation) async {
    try {
      final current = await _repository.fetchCurrent();
      if (!_isCurrent(generation)) return;
      await _handleAttempt(current, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loadFailed,
          failure: AccountDeletionRecoveryFailure.statusLookup,
        ),
      );
    }
  }

  bool _requiresStatusRefresh(String? code) => const {
    'cancellation_after_commit',
    'illegal_transition',
    'attempt_not_found',
  }.contains(code);

  Future<void> _handleAttempt(
    AccountDeletionAttempt? attempt, {
    required int generation,
  }) async {
    if (!_isCurrent(generation)) return;
    if (attempt == null ||
        attempt.status == AccountDeletionAttemptStatus.cancelled) {
      await _resolve();
      return;
    }
    switch (attempt.status) {
      case AccountDeletionAttemptStatus.preparing:
        if (attempt.isCancellationInFlight) {
          await _loadPollBudget(attempt.id);
          if (!_isCurrent(generation)) return;
          _emitPollingState(
            AccountDeletionRecoveryStatus.cancelInFlight,
            attempt,
            generation,
          );
        } else {
          emitIfOpen(
            AccountDeletionRecoveryState(
              status: AccountDeletionRecoveryStatus.restorable,
              attempt: attempt,
            ),
          );
        }
      case AccountDeletionAttemptStatus.recoverable:
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.restorable,
            attempt: attempt,
          ),
        );
      case AccountDeletionAttemptStatus.processing:
        await _loadPollBudget(attempt.id);
        if (!_isCurrent(generation)) return;
        if (!await _updateAttemptOrRetry(attempt, generation)) return;
        _emitPollingState(
          AccountDeletionRecoveryStatus.processing,
          attempt,
          generation,
        );
      case AccountDeletionAttemptStatus.completed:
        if (state.failure == AccountDeletionRecoveryFailure.receiptClear) {
          await _retryReceiptClear(attempt);
          return;
        }
        if (!await _updateAttemptOrRetry(attempt, generation)) return;
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.completingLocally,
            attempt: attempt,
            pollTickIndex: state.pollTickIndex,
          ),
        );
        await completeLocalCleanup(preservePollingProgress: true);
      case AccountDeletionAttemptStatus.terminalFailure:
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.terminalFailure,
            attempt: attempt,
          ),
        );
      case AccountDeletionAttemptStatus.cancelled:
        await _resolve();
    }
  }

  Future<bool> _updateAttemptOrRetry(
    AccountDeletionAttempt attempt,
    int generation,
  ) async {
    try {
      await _onAttemptUpdated?.call(attempt);
      return _isCurrent(generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (_isCurrent(generation)) {
        _emitPollingState(
          AccountDeletionRecoveryStatus.processing,
          attempt,
          generation,
        );
      }
      return false;
    }
  }

  /// Forgets this attempt's polling budget so the next poll starts a new one.
  Future<void> _restartPollBudget() async {
    final attemptId = state.attempt?.id;
    if (attemptId != null) await _pollBudgetStore.clear(attemptId);
    _pollBudgetStartedAt = null;
  }

  /// Reads this attempt's polling start, beginning one on first sight.
  ///
  /// Keyed by attempt id, so a relaunch against the same attempt continues the
  /// budget it already spent while a genuinely new attempt starts fresh.
  Future<void> _loadPollBudget(String attemptId) async {
    await _pollBudgetStore.recordStartIfAbsent(attemptId, _clock());
    // Always take the store's value, never the cache: [_schedulePoll] can seed
    // the cache with `now` on a path that reached it before this ran, and the
    // store is the one that knows when a previous launch started. Earliest
    // wins, which is what `recordStartIfAbsent` guarantees.
    _pollBudgetStartedAt = await _pollBudgetStore.startedAt(attemptId);
  }

  void _emitPollingState(
    AccountDeletionRecoveryStatus status,
    AccountDeletionAttempt attempt,
    int generation,
  ) {
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: status,
        attempt: attempt,
        failure: state.failure,
        pollTickIndex: state.pollTickIndex,
        pollingElapsed: _pollingSpent,
      ),
    );
    _schedulePoll(generation);
  }

  void _schedulePoll(int generation) {
    _pollTimer?.cancel();
    // Polling is also scheduled from paths that never went through the
    // `processing` branch of [_handleAttempt] — a failed submission confirm,
    // a cleanup failure — so the budget has to start here too. Without this
    // the budget on those paths would read as zero forever and the bound
    // would never be reached, which is the same trap in a different place.
    if (_pollBudgetStartedAt == null) {
      final startedAt = _clock();
      _pollBudgetStartedAt = startedAt;
      final attemptId = state.attempt?.id;
      if (attemptId != null) {
        unawaited(
          _pollBudgetStore.recordStartIfAbsent(attemptId, startedAt),
        );
      }
    }
    final tickIndex = state.pollTickIndex;
    final delay = AccountDeletionRecoveryPolling.delayForTick(tickIndex);
    final spent = _pollingSpent;
    if (spent + delay > AccountDeletionRecoveryPolling.sessionBound) {
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: state.attempt,
          failure: state.failure,
          pollTickIndex: tickIndex,
          pollingPaused: true,
          pollingElapsed: spent,
        ),
      );
      return;
    }
    _pollTimer = _timerFactory(delay, () => _poll(generation));
  }

  Future<void> _poll(int generation) async {
    if (!_isCurrent(generation)) return;
    final expectedAttemptId = state.attempt?.id;
    final tickIndex = state.pollTickIndex + 1;
    try {
      final receiptPubkeyHex = _receiptPubkeyHex;
      final canUseAuthenticatedLookup =
          receiptPubkeyHex == null ||
          (_authService.signerReadiness == SignerReadiness.ready &&
              _authService.currentPublicKeyHex == receiptPubkeyHex);
      final current = canUseAuthenticatedLookup
          ? await _repository.fetchCurrent()
          : await _repository.fetchStatus(
              attemptId: expectedAttemptId!,
              pubkeyHex: receiptPubkeyHex,
            );
      if (!_isCurrent(generation)) return;
      if (current == null) {
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: state.status,
            attempt: state.attempt,
            failure: state.failure,
            pollTickIndex: tickIndex,
          ),
        );
        _schedulePoll(generation);
        return;
      }
      if (current.id != expectedAttemptId) {
        emitIfOpen(
          const AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.loadFailed,
            failure: AccountDeletionRecoveryFailure.statusLookup,
          ),
        );
        return;
      }
      if (current.status == AccountDeletionAttemptStatus.recoverable &&
          _receiptVanishEventId != null) {
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: state.status,
            attempt: current,
            failure: state.failure,
            pollTickIndex: tickIndex,
          ),
        );
        await _confirmSubmission(current, generation: generation);
        return;
      }
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: current,
          failure: state.failure,
          pollTickIndex: tickIndex,
        ),
      );
      await _handleAttempt(current, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: state.attempt,
          failure: state.failure,
          pollTickIndex: tickIndex,
        ),
      );
      _schedulePoll(generation);
    }
  }

  int _beginOperation({bool resetPollingProgress = true}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    // Drops the CACHE, not the record. A reload re-reads the same attempt's
    // persisted start, so only a different attempt gets a fresh budget.
    if (resetPollingProgress) _pollBudgetStartedAt = null;
    return ++_generation;
  }

  bool _isCurrent(int generation) => !isClosed && generation == _generation;

  void _emitCleanupFailure(
    int generation,
    AccountDeletionAttempt attempt,
    AccountDeletionRecoveryFailure failure,
  ) {
    if (!_isCurrent(generation)) return;
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.cleanupFailed,
        attempt: attempt,
        failure: failure,
        pollTickIndex: state.pollTickIndex,
      ),
    );
    if (_receiptPubkeyHex != null) _schedulePoll(generation);
  }

  Future<void> _resolve() async {
    _pollTimer?.cancel();
    final resolvedAttemptId = state.attempt?.id;
    if (resolvedAttemptId != null) {
      await _pollBudgetStore.clear(resolvedAttemptId);
    }
    _pollBudgetStartedAt = null;
    await _onAttemptResolved();
    if (isClosed) return;
    emitIfOpen(
      const AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.resolved,
      ),
    );
  }

  @override
  Future<void> close() {
    _generation++;
    _pollTimer?.cancel();
    return super.close();
  }
}
