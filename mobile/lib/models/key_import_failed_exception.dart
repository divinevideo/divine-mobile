// ABOUTME: Describes a valid private key the app could not store or sign in with.
// ABOUTME: Reported to crash reporting with the key already cut out of the text.

/// A private key passed validation but the import still failed.
///
/// Built to be reported off the device, so it never holds the key itself.
class KeyImportFailedException implements Exception {
  /// Wraps [error] with every one of [secrets] cut out of its text.
  factory KeyImportFailedException.redacting(
    Object error,
    Iterable<String> secrets,
  ) {
    var message = error.toString();
    for (final secret in secrets) {
      message = message.replaceAll(secret, '[redacted]');
    }
    return KeyImportFailedException._(message);
  }

  const KeyImportFailedException._(this.message);

  final String message;

  @override
  String toString() => 'KeyImportFailedException: $message';
}
