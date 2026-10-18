/// A relay read ended before the requested badge data could be completed.
///
/// This is a retryable network/read outcome, not a programming invariant.
class BadgeReadIncompleteException implements Exception {
  /// Creates an incomplete-read failure with a diagnostic [message].
  const BadgeReadIncompleteException(this.message);

  /// The badge data that could not be completely read.
  final String message;

  @override
  String toString() => 'BadgeReadIncompleteException: $message';
}
