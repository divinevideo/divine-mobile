// ABOUTME: Owns the interrupted account-deletion recovery state machine.
// ABOUTME: Coordinates loading, cancellation, polling, cleanup, and sign-out.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
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
  static const supportEscapeAfter = Duration(minutes: 15);

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
    DateTime? recoveryWatchStartedAt,
    RecoveryTimerFactory timerFactory = Timer.new,
    DateTime Function() now = DateTime.now,
  }) : _repository = repository,
       _authService = authService,
       _onAttemptResolved = onAttemptResolved,
       _onAttemptUpdated = onAttemptUpdated,
       _receiptPubkeyHex = receiptPubkeyHex,
       _receiptVanishEventId = receiptVanishEventId,
       _recoveryWatchStartedAt =
           recoveryWatchStartedAt?.toUtc() ?? now().toUtc(),
       _timerFactory = timerFactory,
       _now = now,
       super(const AccountDeletionRecoveryState());

  final AccountDeletionRecoveryRepository _repository;
  final AuthService _authService;
  final Future<void> Function() _onAttemptResolved;
  final Future<void> Function(AccountDeletionAttempt attempt)?
  _onAttemptUpdated;
  final String? _receiptPubkeyHex;
  final String? _receiptVanishEventId;
  final DateTime _recoveryWatchStartedAt;
  final RecoveryTimerFactory _timerFactory;
  final DateTime Function() _now;

  Timer? _pollTimer;
  var _generation = 0;
  var _overdueRefreshUsed = false;

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

  Future<void> completeLocalCleanup() async {
    final attempt = state.attempt;
    if (attempt?.status != AccountDeletionAttemptStatus.completed) return;
    if (state.failure == AccountDeletionRecoveryFailure.receiptClear) {
      await _retryReceiptClear(attempt!);
      return;
    }
    final generation = _beginOperation();
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
    final generation = _beginOperation();
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
        await completeLocalCleanup();
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
      ),
    );
    _schedulePoll(generation);
  }

  void _schedulePoll(int generation) {
    _pollTimer?.cancel();
    final tickIndex = state.pollTickIndex;
    final delay = AccountDeletionRecoveryPolling.delayForTick(tickIndex);
    final elapsed = _now().toUtc().difference(_recoveryWatchStartedAt);
    final nonNegativeElapsed = elapsed.isNegative ? Duration.zero : elapsed;
    if (nonNegativeElapsed + delay >
        AccountDeletionRecoveryPolling.supportEscapeAfter) {
      if (!_overdueRefreshUsed) {
        _overdueRefreshUsed = true;
        _pollTimer = _timerFactory(
          Duration.zero,
          () => _poll(generation),
        );
        return;
      }
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: state.attempt,
          failure: state.failure,
          pollTickIndex: tickIndex,
          pollingPaused: true,
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

  int _beginOperation() {
    _pollTimer?.cancel();
    _pollTimer = null;
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
