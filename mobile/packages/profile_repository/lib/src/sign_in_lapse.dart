// ABOUTME: Why the verifier stopped counting a sign-in link, read from the
// ABOUTME: reason code on its verdict.

/// Why the verifier stopped counting a claim linked by signing in.
///
/// Signing in again renews the link in place, so the dashboard offers that
/// only for a claim carrying one of these.
enum SignInLapse {
  /// The sign-in is past the lifetime the verifier gives it.
  expired,

  /// The handle now points to a different account than the one that signed
  /// in.
  accountChanged,
}

/// Reads the verifier's reason code on a verdict as a [SignInLapse].
///
/// Returns null for no code, or for any code that is not about a sign-in,
/// so a verifier that predates these codes, or adds new ones, never reads as
/// a lapsed sign-in.
SignInLapse? signInLapseFromCode(String? code) => switch (code) {
  'signin_expired' => SignInLapse.expired,
  'signin_account_changed' => SignInLapse.accountChanged,
  _ => null,
};
