// MPL-2.0

/// The Concord relay connection dropped, or reconnecting to it gave up.
///
/// This is an expected network condition, not a programming error.
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

  /// What the relay refused and its reason, for logs. Never shown to users.
  final String message;

  @override
  String toString() => 'RelayRejectedException: $message';
}
