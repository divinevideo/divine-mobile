// ABOUTME: Utilities for detecting and classifying Nostr relay errors
// ABOUTME: Distinguishes retriable errors (network/timeout) from permanent client errors (4xx)

/// Utilities for analyzing Nostr relay errors and determining retry strategies
class NostrErrorUtils {
  /// Determines if an error is retriable (network/timeout/server issues)
  ///
  /// Retriable errors include:
  /// - Timeout errors
  /// - Connection/socket/network errors
  /// - DNS resolution failures
  /// - 5xx server errors (temporary server issues)
  ///
  /// Returns true if the operation should be retried, false otherwise
  static bool isRetriableError(dynamic error) {
    if (error == null) return false;

    final errorStr = error.toString().toLowerCase();

    // Timeout errors
    if (errorStr.contains('timeout')) return true;
    if (errorStr.contains('timed out')) return true;

    // Connection errors
    if (errorStr.contains('connection')) return true;
    if (errorStr.contains('socket')) return true;
    if (errorStr.contains('network')) return true;

    // DNS errors
    if (errorStr.contains('failed host lookup')) return true;

    // 5xx server errors (retriable - temporary server issues)
    if (errorStr.contains('500')) return true; // Internal Server Error
    if (errorStr.contains('502')) return true; // Bad Gateway
    if (errorStr.contains('503')) return true; // Service Unavailable
    if (errorStr.contains('504')) return true; // Gateway Timeout

    return false;
  }

  /// Determines if an error is a client error (not retriable)
  ///
  /// Client errors include:
  /// - 4xx HTTP errors (bad request, unauthorized, not found, etc)
  /// - File not found errors
  ///
  /// Returns true if the error is permanent and should not be retried
  static bool isClientError(dynamic error) {
    if (error == null) return false;

    final errorStr = error.toString().toLowerCase();

    // 4xx client errors (not retriable - problem with the request itself)
    if (errorStr.contains('400')) return true; // Bad Request
    if (errorStr.contains('401')) return true; // Unauthorized
    if (errorStr.contains('403')) return true; // Forbidden
    if (errorStr.contains('404')) return true; // Not Found

    // File errors
    if (errorStr.contains('file not found')) return true;
    if (errorStr.contains('no such file')) return true;

    return false;
  }
}
