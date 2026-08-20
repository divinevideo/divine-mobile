// ABOUTME: States for Divine authentication cubit
// ABOUTME: Tracks sign in/sign up form state and email verification

part of 'divine_auth_cubit.dart';

/// Why an email/password sign-in failed, mapped to localized copy by the UI.
///
/// Kept out of [KeycastLoginFailure] so the presentation layer never imports
/// the client package's taxonomy. Never carries a message string — the rule in
/// `state_management.md` (no error strings in state) is why this is an enum.
enum SignInFailureReason {
  /// Wrong credentials or no such account. Copy must not imply the account
  /// exists (keycast returns an identical 401 for both).
  invalidCredentials,

  /// The account's email is not yet verified.
  emailNotVerified,

  /// The submitted email was malformed.
  invalidEmail,

  /// A network/transport problem prevented a verdict.
  network,

  /// Any other unexpected failure.
  unknown,
}

/// State for Divine authentication cubit
sealed class DivineAuthState extends Equatable {
  const DivineAuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before form is ready
class DivineAuthInitial extends DivineAuthState {
  const DivineAuthInitial();
}

/// State when auth form is displayed and interactive
class DivineAuthFormState extends DivineAuthState {
  const DivineAuthFormState({
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isSignIn = false,
    this.requiresPasswordConfirmation = false,
    this.emailError,
    this.passwordError,
    this.confirmPasswordError,
    this.generalError,
    this.signInFailureReason,
    this.showInviteGateRecovery = false,
    this.inviteRecoveryCode,
    this.inviteRecoverySourceSlug,
    this.showLoginOptionsRecovery = false,
    this.obscurePassword = true,
    this.isSubmitting = false,
    this.isSkipping = false,
    this.marketingConsent = false,
  });

  /// User's email address
  final String email;

  /// User's password
  final String password;

  /// Re-entered password for sign-up typo prevention.
  final String confirmPassword;

  /// True for sign in mode, false for sign up mode
  final bool isSignIn;

  /// Whether the current form should require confirm-password validation.
  final bool requiresPasswordConfirmation;

  /// Error message for email field validation
  final String? emailError;

  /// Error message for password field validation
  final String? passwordError;

  /// Error message for confirm-password validation
  final String? confirmPasswordError;

  /// General error message (e.g., network error, auth failure)
  final String? generalError;

  /// Typed reason the last email/password sign-in failed, or null.
  ///
  /// Sign-in failures use this instead of [generalError] so the UI can map to
  /// localized copy; other auth flows still use [generalError] pending #4336.
  final SignInFailureReason? signInFailureReason;

  /// Whether the user should be sent back through the invite gate.
  final bool showInviteGateRecovery;

  /// Invite code to prefill if recovery should return to the invite gate.
  final String? inviteRecoveryCode;

  /// Creator source slug to preserve when recovery falls back to waitlist.
  final String? inviteRecoverySourceSlug;

  /// Whether the UI should route the user to sign in instead.
  final bool showLoginOptionsRecovery;

  /// Whether password is obscured in the UI
  final bool obscurePassword;

  /// Whether form is currently being submitted
  final bool isSubmitting;

  /// Whether anonymous account creation is in progress
  final bool isSkipping;

  /// Whether the user opted in to marketing communications at sign-up.
  ///
  /// Sign-up only and unchecked by default (explicit opt-in). Sent to keycast
  /// with headless registration and recorded on the account.
  final bool marketingConsent;

  /// Returns true if form has no validation errors and fields are filled
  bool get canSubmit =>
      email.isNotEmpty &&
      password.isNotEmpty &&
      (!requiresPasswordConfirmation || confirmPassword.isNotEmpty) &&
      emailError == null &&
      passwordError == null &&
      confirmPasswordError == null &&
      !isSubmitting &&
      !isSkipping;

  DivineAuthFormState copyWith({
    String? email,
    String? password,
    String? confirmPassword,
    bool? isSignIn,
    bool? requiresPasswordConfirmation,
    String? emailError,
    String? passwordError,
    String? confirmPasswordError,
    String? generalError,
    SignInFailureReason? signInFailureReason,
    bool? showInviteGateRecovery,
    String? inviteRecoveryCode,
    String? inviteRecoverySourceSlug,
    bool? showLoginOptionsRecovery,
    bool? obscurePassword,
    bool? isSubmitting,
    bool? isSkipping,
    bool? marketingConsent,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearConfirmPasswordError = false,
    bool clearGeneralError = false,
    bool clearSignInFailureReason = false,
    bool clearInviteGateRecovery = false,
  }) {
    return DivineAuthFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isSignIn: isSignIn ?? this.isSignIn,
      requiresPasswordConfirmation:
          requiresPasswordConfirmation ?? this.requiresPasswordConfirmation,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError: clearPasswordError
          ? null
          : (passwordError ?? this.passwordError),
      confirmPasswordError: clearConfirmPasswordError
          ? null
          : (confirmPasswordError ?? this.confirmPasswordError),
      generalError: clearGeneralError
          ? null
          : (generalError ?? this.generalError),
      signInFailureReason: clearSignInFailureReason
          ? null
          : (signInFailureReason ?? this.signInFailureReason),
      showInviteGateRecovery:
          !clearInviteGateRecovery &&
          (showInviteGateRecovery ?? this.showInviteGateRecovery),
      inviteRecoveryCode: clearInviteGateRecovery
          ? null
          : (inviteRecoveryCode ?? this.inviteRecoveryCode),
      inviteRecoverySourceSlug: clearInviteGateRecovery
          ? null
          : (inviteRecoverySourceSlug ?? this.inviteRecoverySourceSlug),
      showLoginOptionsRecovery:
          showLoginOptionsRecovery ?? this.showLoginOptionsRecovery,
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSkipping: isSkipping ?? this.isSkipping,
      marketingConsent: marketingConsent ?? this.marketingConsent,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    confirmPassword,
    isSignIn,
    requiresPasswordConfirmation,
    emailError,
    passwordError,
    confirmPasswordError,
    generalError,
    signInFailureReason,
    showInviteGateRecovery,
    inviteRecoveryCode,
    inviteRecoverySourceSlug,
    showLoginOptionsRecovery,
    obscurePassword,
    isSubmitting,
    isSkipping,
    marketingConsent,
  ];
}

/// State when email verification is required after registration
class DivineAuthEmailVerification extends DivineAuthState {
  const DivineAuthEmailVerification({
    required this.email,
    required this.deviceCode,
    required this.verifier,
  });

  /// Email address that needs verification
  final String email;

  /// Device code for polling verification status
  final String deviceCode;

  /// PKCE verifier for code exchange
  final String verifier;

  @override
  List<Object?> get props => [email, deviceCode, verifier];
}

/// State after successful authentication
class DivineAuthSuccess extends DivineAuthState {
  const DivineAuthSuccess();
}
