// ABOUTME: Whether the signed-in user holds Divine Confirmation, as far as
// ABOUTME: the verifier can tell the app.

/// Whether the user holds Divine Confirmation.
///
/// [unknown] means the answer could not be had (offline, an older verifier, a
/// failed lookup). Callers treat it like [has]: the app never shows an upsell
/// or a refusal on a guess.
enum ConfirmationAccess {
  /// The user has Divine Confirmation.
  has,

  /// The verifier says the user does not have Divine Confirmation.
  hasNot,

  /// The answer is not known.
  unknown,
}
