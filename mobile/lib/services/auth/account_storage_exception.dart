// ABOUTME: Expected failures while persisting or verifying account evidence.
// ABOUTME: Keeps recoverable native storage failures out of programming errors.

/// Account storage could not be read, written, or verified safely.
///
/// Callers retain uncertain evidence and surface recovery or retry. This is an
/// operational failure, not proof of a programming invariant violation.
class AccountStorageException implements Exception {
  const AccountStorageException(this.message);

  final String message;

  @override
  String toString() => 'AccountStorageException: $message';
}
