// MPL-2.0

/// The Concord relay could not be reached, or the connection dropped before
/// the relay answered.
///
/// This is an expected network condition, not a programming error: callers
/// show it as a connection problem and let the user retry, which reconnects.
class RelayConnectionException implements Exception {
  const RelayConnectionException(this.message);

  /// What failed, for logs. Never shown to users.
  final String message;

  @override
  String toString() => 'RelayConnectionException: $message';
}

/// The Concord relay answered but refused the request: it rejected an event,
/// sent a notice that failed pending publications, or closed a subscription.
///
/// Like a 4xx response this is an expected relay decision, not a programming
/// error. [message] carries the relay's own reason.
class RelayRejectedException implements Exception {
  const RelayRejectedException(this.message);

  /// The relay's reason, for logs. Never shown to users.
  final String message;

  @override
  String toString() => 'RelayRejectedException: $message';
}
