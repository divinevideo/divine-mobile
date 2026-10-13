// ABOUTME: Typed exceptions thrown by VerifierClient.

/// Base class for all errors thrown by the verifier client.
sealed class VerifierClientException implements Exception {
  /// Creates a verifier exception with a human-readable [message].
  const VerifierClientException(this.message, this.kind);

  /// Free-form message describing the failure.
  final String message;

  /// Stable identifier for the exception subtype, safe for production logs.
  final String kind;

  @override
  String toString() => '$kind: $message';
}

/// HTTP non-2xx response from the verifier.
final class VerifierApiException extends VerifierClientException {
  /// Creates a [VerifierApiException] with the response [statusCode].
  const VerifierApiException(this.statusCode, String message)
    : super(message, 'VerifierApiException');

  /// The HTTP status code returned by the verifier.
  final int statusCode;
}

/// Request did not complete within the configured timeout.
final class VerifierTimeoutException extends VerifierClientException {
  /// Creates a [VerifierTimeoutException] with [message].
  const VerifierTimeoutException(String message)
    : super(message, 'VerifierTimeoutException');
}

/// Network or transport error before a response could be read.
final class VerifierNetworkException extends VerifierClientException {
  /// Creates a [VerifierNetworkException] with [message].
  const VerifierNetworkException(String message)
    : super(message, 'VerifierNetworkException');
}

/// Why the verifier refused to confirm a sign-in.
enum SignInRefusal {
  /// Expired, or not visible to the verifier yet; worth a brief retry.
  notFound,

  /// Already confirmed with a different event.
  used,

  /// Signed by a different account than the one that started the sign-in.
  wrongAccount,

  /// Started by a different client.
  notYours,

  /// The signed list doesn't carry this sign-in's claim.
  claimMismatch,

  /// The confirmation wasn't a signed linked-accounts list.
  invalidEvent,

  /// Anything else.
  other;

  /// Reads the verifier's `code`.
  static SignInRefusal fromCode(Object? code) => switch (code) {
    'signin_not_found' => notFound,
    'signin_used' => used,
    'signin_wrong_account' => wrongAccount,
    'signin_not_yours' => notYours,
    'signin_claim_mismatch' => claimMismatch,
    'invalid_event' => invalidEvent,
    _ => other,
  };
}

/// The verifier refused to confirm a sign-in.
final class SignInConfirmException extends VerifierClientException {
  /// Creates a [SignInConfirmException]. The message never carries the code
  /// or secret sent.
  SignInConfirmException(this.statusCode, this.refusal)
    : super(
        'verifier refused the confirmation ($statusCode, ${refusal.name})',
        'SignInConfirmException',
      );

  /// The HTTP status code.
  final int statusCode;

  /// Why it was refused.
  final SignInRefusal refusal;
}
