part of 'account_deletion_recovery_cubit.dart';

enum AccountDeletionRecoveryStatus {
  initial,
  loading,
  loadFailed,
  restorable,
  cancelInFlight,
  confirmingSubmission,
  processing,
  completingLocally,
  completed,
  cleanupFailed,
  terminalFailure,
  signingOut,
  signOutFailed,
  resolved,
}

enum AccountDeletionRecoveryFailure {
  signerUnavailable,
  statusLookup,
  usernameRestore,
  keychainCleanup,
  localDataCleanup,
  receiptClear,
  signOut,
}

final class AccountDeletionRecoveryState extends Equatable {
  const AccountDeletionRecoveryState({
    this.status = AccountDeletionRecoveryStatus.initial,
    this.attempt,
    this.failure,
    this.pollTickIndex = 0,
    this.pollingPaused = false,
    this.pollingElapsed = Duration.zero,
  });

  final AccountDeletionRecoveryStatus status;
  final AccountDeletionAttempt? attempt;
  final AccountDeletionRecoveryFailure? failure;
  final int pollTickIndex;
  final bool pollingPaused;

  /// How long this deletion attempt has been waiting on the server.
  ///
  /// Surfaced so the recovery screen can show the wait it is asking for. There
  /// is deliberately no estimate: the remaining work is server-side and has no
  /// client-visible bound, so a countdown here would be invented.
  final Duration pollingElapsed;

  @override
  List<Object?> get props => [
    status,
    attempt,
    failure,
    pollTickIndex,
    pollingPaused,
    pollingElapsed,
  ];
}
