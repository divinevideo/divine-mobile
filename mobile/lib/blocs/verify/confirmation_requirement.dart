// ABOUTME: The pure rule for when Divine Confirmation gates a sign-in link,
// ABOUTME: and when the app offers the upsell for it.

import 'package:profile_repository/profile_repository.dart';
import 'package:verifier_client/verifier_client.dart';

/// Reads whether the signed-in user holds Divine Confirmation.
///
/// [refresh] skips any cached answer, for a re-check after a purchase or a
/// refusal.
typedef ConfirmationAccessReader = Future<ConfirmationAccess> Function({
  bool refresh,
});

/// Whether linking [platform] by signing in requires Divine Confirmation.
///
/// Holds only when every one of these does:
/// - [flagOn]: the internal `confirmationSignIn` flag is on;
/// - the verifier reports `signin_requires: "confirmation"` for [platform];
/// - sign-in is offered for [platform] at all (the verifier has it on and the
///   app can start it);
/// - [oauthUsable]: sign-in is usable on this device, so nobody is upsold on
///   a path that is hidden (iOS below 17.4).
///
/// Whether the user can buy Confirmation is deliberately not a condition: the
/// requirement exists whether or not a purchase does.
bool confirmationSignInRequired({
  required bool flagOn,
  required VerifierPlatform platform,
  required bool oauthUsable,
}) {
  return flagOn &&
      oauthUsable &&
      platform.supportsOAuth &&
      platform.signinRequires == SigninRequirement.confirmation;
}

/// Whether to show the Confirmation upsell.
///
/// Only when the requirement applies and the verifier says the user lacks
/// Confirmation. [ConfirmationAccess.unknown] behaves like
/// [ConfirmationAccess.has]: no upsell on a guess.
bool showsConfirmationUpsell({
  required bool required,
  required ConfirmationAccess access,
}) {
  return required && access == ConfirmationAccess.hasNot;
}

/// [platform] as the verifier reports it while its Confirmation requirement
/// is on, for the developer setting that simulates that requirement against a
/// verifier with it off.
///
/// Like the verifier, it marks only a platform whose sign-in is on. Only the
/// app's view changes: the verifier still approves a sign-in without
/// Confirmation, so a refusal at confirm can't be simulated this way.
VerifierPlatform withSimulatedConfirmationRequirement(
  VerifierPlatform platform,
) {
  if (platform.oauth != true) return platform;
  return VerifierPlatform(
    key: platform.key,
    label: platform.label,
    supported: platform.supported,
    oauth: platform.oauth,
    signinExpiresAfterDays: platform.signinExpiresAfterDays,
    signinRequires: SigninRequirement.confirmation,
  );
}
