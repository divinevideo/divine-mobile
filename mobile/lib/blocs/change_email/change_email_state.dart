// ABOUTME: State for the change-email form, held as status and reason enums so
// ABOUTME: no localized string or client-package type lives in state.

part of 'change_email_cubit.dart';

/// Where the change-email form is in its lifecycle.
///
/// [requestSent] is deliberately not called "success": Keycast has accepted the
/// request and mailed both addresses, but the address only changes once both
/// inboxes confirm.
enum ChangeEmailStatus { editing, submitting, requestSent, failure }

/// Why the new address was rejected before anything was sent.
enum NewEmailFieldError {
  /// Empty field.
  missing,

  /// Not a well-formed address.
  invalid,

  /// Already the address on the account — checked here because Keycast answers
  /// 200 for it, which would otherwise read as "check your inbox" for mail that
  /// was never sent.
  sameAsCurrent,
}

/// Why Keycast refused to start an email change, mapped to localized copy by
/// the UI. Kept separate from `ChangeEmailFailure` so the presentation layer
/// never imports the client package's taxonomy.
enum ChangeEmailFailureReason {
  /// The submitted account password is not the one on file.
  wrongPassword,

  /// Keycast rejected the address as malformed.
  invalidEmail,

  /// The session can no longer authorize the change; only signing in again
  /// clears it.
  needsSignIn,

  /// The account was created with Google or Apple and has no password yet.
  passwordNotSet,

  /// Too many attempts. Waiting is the remedy, not a retry.
  rateLimited,

  /// The request never reached a verdict.
  network,

  /// Anything else, including a fault on Keycast's side.
  unknown,
}

class ChangeEmailState extends Equatable {
  const ChangeEmailState({
    this.currentEmail,
    this.newEmail = '',
    this.password = '',
    this.status = ChangeEmailStatus.editing,
    this.newEmailError,
    this.passwordMissing = false,
    this.failureReason,
  });

  /// The address Keycast has on file, or null while it is loading or could not
  /// be read. Null never blocks the form — it only means the screen cannot show
  /// the current address or catch a no-op change before sending it.
  final String? currentEmail;

  final String newEmail;

  /// The account password, re-verified by Keycast before it mails anything.
  final String password;

  final ChangeEmailStatus status;

  final NewEmailFieldError? newEmailError;

  /// The password field is only checked for emptiness here; Keycast verifies
  /// the value itself.
  final bool passwordMissing;

  /// Set only while [status] is [ChangeEmailStatus.failure].
  final ChangeEmailFailureReason? failureReason;

  /// [password] has to be in [props] for equality, but it must never be
  /// rendered. Equatable stringifies props by default in debug builds, which
  /// would put a plaintext password into anything that prints a state —
  /// `DivineBlocObserver`'s `bloc.lastState` crash key above all.
  @override
  bool? get stringify => false;

  bool get isSubmitting => status == ChangeEmailStatus.submitting;

  bool get canSubmit =>
      !isSubmitting && newEmail.trim().isNotEmpty && password.isNotEmpty;

  ChangeEmailState copyWith({
    String? currentEmail,
    String? newEmail,
    String? password,
    ChangeEmailStatus? status,
    NewEmailFieldError? newEmailError,
    bool? passwordMissing,
    ChangeEmailFailureReason? failureReason,
    bool clearNewEmailError = false,
    bool clearFailureReason = false,
  }) {
    return ChangeEmailState(
      currentEmail: currentEmail ?? this.currentEmail,
      newEmail: newEmail ?? this.newEmail,
      password: password ?? this.password,
      status: status ?? this.status,
      newEmailError: clearNewEmailError
          ? null
          : newEmailError ?? this.newEmailError,
      passwordMissing: passwordMissing ?? this.passwordMissing,
      failureReason: clearFailureReason
          ? null
          : failureReason ?? this.failureReason,
    );
  }

  @override
  List<Object?> get props => [
    currentEmail,
    newEmail,
    password,
    status,
    newEmailError,
    passwordMissing,
    failureReason,
  ];
}
