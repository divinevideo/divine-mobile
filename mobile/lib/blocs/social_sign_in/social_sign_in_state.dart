part of 'social_sign_in_cubit.dart';

/// Where a Google or Apple sign-in stands.
enum SocialSignInStatus {
  /// Nothing running; the buttons can be tapped.
  idle,

  /// The provider's sheet or the Keycast round trip is running.
  inProgress,

  /// Signed in. The router leaves the screen on its own.
  signedIn,

  /// The last attempt failed; [SocialSignInState.failureReason] says why.
  failed,
}

/// Why a Google or Apple sign-in failed, for the UI to localize.
enum SocialSignInFailureReason {
  /// The provider cannot sign in on this device or build.
  unavailable,

  /// The email belongs to an account that must be signed in with email and
  /// password.
  accountLinkRequired,

  /// The provider shared no email address.
  emailMissing,

  /// The provider has not verified the email address.
  emailNotVerified,

  /// Too many attempts for now.
  rateLimited,

  /// No connection or a timeout.
  network,

  /// The previous account's local data could not be cleared.
  accountCleanupFailed,

  /// Anything else.
  failed,
}

class SocialSignInState extends Equatable {
  const SocialSignInState({
    required this.availableProviders,
    this.status = SocialSignInStatus.idle,
    this.activeProvider,
    this.failureReason,
  });

  /// Providers to offer, in display order. Empty when the feature is off.
  final List<SocialProvider> availableProviders;
  final SocialSignInStatus status;

  /// The provider of the running or last attempt.
  final SocialProvider? activeProvider;

  /// Set only when [status] is [SocialSignInStatus.failed].
  final SocialSignInFailureReason? failureReason;

  /// Whether the buttons must stay disabled.
  bool get isBusy =>
      status == SocialSignInStatus.inProgress ||
      status == SocialSignInStatus.signedIn;

  SocialSignInState copyWith({
    SocialSignInStatus? status,
    SocialProvider? activeProvider,
    SocialSignInFailureReason? failureReason,
  }) => SocialSignInState(
    availableProviders: availableProviders,
    status: status ?? this.status,
    activeProvider: activeProvider ?? this.activeProvider,
    failureReason: failureReason,
  );

  @override
  List<Object?> get props => [
    availableProviders,
    status,
    activeProvider,
    failureReason,
  ];
}
