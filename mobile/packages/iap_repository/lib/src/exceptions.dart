// ABOUTME: Typed exceptions thrown by EntitlementValidator implementations.
// ABOUTME: Sealed so callers can exhaustively switch on purchase outcomes.

/// Base class for all errors thrown by an EntitlementValidator.
sealed class EntitlementException implements Exception {
  /// Creates an entitlement exception with a human-readable [message].
  const EntitlementException(this.message, this.kind);

  /// Free-form message describing the failure.
  final String message;

  /// Stable identifier for the exception subtype, safe for production logs.
  final String kind;

  @override
  String toString() => '$kind: $message';
}

/// The store is unavailable on this device or build (e.g. unsupported platform,
/// store not connected). Purchases cannot be attempted.
final class StoreUnavailableException extends EntitlementException {
  /// Creates a [StoreUnavailableException].
  const StoreUnavailableException([String message = 'Store is unavailable.'])
    : super(message, 'StoreUnavailableException');
}

/// A purchase was attempted and the store reported a failure (user cancelled,
/// network error during purchase, declined payment, etc.).
final class PurchaseFailedException extends EntitlementException {
  /// Creates a [PurchaseFailedException] with the store's [responseCode] when
  /// available (e.g. `billingResponse` / StoreKit error code).
  const PurchaseFailedException(this.responseCode, String message)
    : super(message, 'PurchaseFailedException');

  /// Store-specific error code, or null when the store did not provide one.
  final String? responseCode;
}

/// The store already holds an unfinished purchase of the product, so it did
/// not start another one. The entitlement is not yet active.
///
/// Callers treat this as "no new purchase exists", so a purchase that is only
/// waiting on the store (parental approval or payment settlement) must not
/// use it; that wait is reported through lifecycle updates instead.
final class PurchasePendingException extends EntitlementException {
  /// Creates a [PurchasePendingException].
  const PurchasePendingException([String message = 'Purchase is pending.'])
    : super(message, 'PurchasePendingException');
}

/// Restoring previous purchases did not yield an active supporter entitlement.
final class RestoreFailedException extends EntitlementException {
  /// Creates a [RestoreFailedException].
  const RestoreFailedException([
    String message = 'No supporter subscription was found to restore.',
  ]) : super(message, 'RestoreFailedException');
}
