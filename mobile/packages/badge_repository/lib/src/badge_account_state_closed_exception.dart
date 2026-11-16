/// The account's badge state closed while an operation on it was running.
///
/// Signing out with data erasure, or removing the account from the device,
/// closes the badge state before the identity clears, so a dashboard load or
/// a dismissal already in flight can find it gone. The operation then stops
/// rather than touch the erased state. This is the expected end of that race,
/// not a programming invariant: an operation that starts after the close
/// still throws a [StateError].
class BadgeAccountStateClosedException implements Exception {
  /// Creates the failure for an operation the close overtook.
  const BadgeAccountStateClosedException();

  @override
  String toString() =>
      'BadgeAccountStateClosedException: the account badge state closed '
      'during the operation';
}
