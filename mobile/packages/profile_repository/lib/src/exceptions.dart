/// Base exception for profile repository operations.
class ProfileRepositoryException implements Exception {
  /// Creates a profile repository exception with an optional [message].
  const ProfileRepositoryException([this.message]);

  /// Optional message describing the exception.
  final String? message;

  @override
  String toString() => 'ProfileRepositoryException: $message';
}

/// Thrown when a profile could not be published to Nostr relays.
class ProfilePublishFailedException extends ProfileRepositoryException {
  /// Creates a profile publish failed exception with an optional [message].
  const ProfilePublishFailedException(super.message);

  @override
  String toString() => 'ProfilePublishFailedException: $message';
}

/// Thrown before publishing when the current profile cannot safely seed a save.
///
/// This remains a [ProfilePublishFailedException] for callers that retry the
/// whole save without distinguishing which phase failed.
class ProfilePublishSeedUnavailableException
    extends ProfilePublishFailedException {
  /// Creates an exception for a save deferred during seed resolution.
  const ProfilePublishSeedUnavailableException(super.message);

  @override
  String toString() => 'ProfilePublishSeedUnavailableException: $message';
}

/// Thrown when profile publish fails because no relays are connected.
///
/// A sibling of [ProfilePublishFailedException] — both extend
/// [ProfileRepositoryException] directly. This exception signals that the
/// device has no active Nostr relay connections rather than a relay actively
/// rejecting the event. The caller can show a connectivity-specific error and
/// offer a reconnect/retry action.
class NoRelaysConnectedException extends ProfileRepositoryException {
  /// Creates a no-relays-connected exception with an optional [message].
  const NoRelaysConnectedException([super.message]);

  @override
  String toString() => 'NoRelaysConnectedException: $message';
}
