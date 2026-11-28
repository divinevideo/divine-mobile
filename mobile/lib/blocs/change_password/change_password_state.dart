// ABOUTME: State for the change-password form, held as a status enum plus
// ABOUTME: validation/refusal enums so no localized string lives in state.

part of 'change_password_cubit.dart';

/// Where the change-password form is in its lifecycle.
enum ChangePasswordStatus { editing, submitting, success, failure }

/// Why Keycast refused a password change, mapped to localized copy by the UI.
///
/// Kept separate from [ChangePasswordFailure] so the presentation layer never
/// imports the client package's taxonomy — the same split `SignInFailureReason`
/// makes for sign-in.
enum ChangePasswordFailureReason {
  /// The submitted current password is not the one on file. Recoverable in
  /// place: the user retypes it without leaving the screen.
  wrongCurrentPassword,

  /// Keycast rejected the new password. The form applies the same minimum
  /// length first, so this only appears when the server's rule is stricter.
  weakPassword,

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

class ChangePasswordState extends Equatable {
  const ChangePasswordState({
    this.currentPassword = '',
    this.newPassword = '',
    this.confirmPassword = '',
    this.status = ChangePasswordStatus.editing,
    this.currentPasswordMissing = false,
    this.newPasswordError,
    this.confirmPasswordError,
    this.failureReason,
  });

  final String currentPassword;
  final String newPassword;
  final String confirmPassword;

  final ChangePasswordStatus status;

  /// The current-password field is only checked for emptiness: it is verified
  /// by Keycast, and an account whose password predates today's minimum length
  /// must still be able to type it.
  final bool currentPasswordMissing;

  final PasswordValidationError? newPasswordError;
  final ConfirmPasswordValidationError? confirmPasswordError;

  /// Set only while [status] is [ChangePasswordStatus.failure].
  final ChangePasswordFailureReason? failureReason;

  /// The three password fields have to be in [props] for equality, but they
  /// must never be rendered. Equatable stringifies props by default in debug
  /// builds, which would put plaintext passwords into anything that prints a
  /// state — `DivineBlocObserver`'s `bloc.lastState` crash key above all.
  @override
  bool? get stringify => false;

  bool get isSubmitting => status == ChangePasswordStatus.submitting;

  /// True once every field has something in it. Correctness is checked on
  /// submit, so the button reports "there is something to send", not "this
  /// will succeed".
  bool get canSubmit =>
      !isSubmitting &&
      currentPassword.isNotEmpty &&
      newPassword.isNotEmpty &&
      confirmPassword.isNotEmpty;

  ChangePasswordState copyWith({
    String? currentPassword,
    String? newPassword,
    String? confirmPassword,
    ChangePasswordStatus? status,
    bool? currentPasswordMissing,
    PasswordValidationError? newPasswordError,
    ConfirmPasswordValidationError? confirmPasswordError,
    ChangePasswordFailureReason? failureReason,
    bool clearNewPasswordError = false,
    bool clearConfirmPasswordError = false,
    bool clearFailureReason = false,
  }) {
    return ChangePasswordState(
      currentPassword: currentPassword ?? this.currentPassword,
      newPassword: newPassword ?? this.newPassword,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      status: status ?? this.status,
      currentPasswordMissing:
          currentPasswordMissing ?? this.currentPasswordMissing,
      newPasswordError: clearNewPasswordError
          ? null
          : newPasswordError ?? this.newPasswordError,
      confirmPasswordError: clearConfirmPasswordError
          ? null
          : confirmPasswordError ?? this.confirmPasswordError,
      failureReason: clearFailureReason
          ? null
          : failureReason ?? this.failureReason,
    );
  }

  @override
  List<Object?> get props => [
    currentPassword,
    newPassword,
    confirmPassword,
    status,
    currentPasswordMissing,
    newPasswordError,
    confirmPasswordError,
    failureReason,
  ];
}
