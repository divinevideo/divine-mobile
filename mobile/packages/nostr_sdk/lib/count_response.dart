// ABOUTME: Data model for NIP-45 COUNT responses from relays.
// ABOUTME: Contains the count value and whether it's approximate.

/// Response from a NIP-45 COUNT query
class CountResponse {
  /// The count of matching events
  final int count;

  /// Whether this count is approximate (probabilistic)
  final bool approximate;

  const CountResponse({required this.count, this.approximate = false});

  @override
  String toString() =>
      'CountResponse(count: $count, approximate: $approximate)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountResponse &&
          count == other.count &&
          approximate == other.approximate;

  @override
  int get hashCode => Object.hash(count, approximate);
}

/// Thrown when no relay produced a NIP-45 COUNT answer.
///
/// Despite the name, a relay without NIP-45 is only one cause: a relay that
/// refused the COUNT (CLOSED), did not answer before the deadline, or could
/// not be reached at all ends here too. [CountNotSentException] narrows it to
/// the last case.
class CountNotSupportedException implements Exception {
  final String reason;

  CountNotSupportedException(this.reason);

  @override
  String toString() => 'CountNotSupportedException: $reason';
}

/// Thrown when no relay accepted the COUNT frame, because every eligible
/// relay was disconnected or could not be written before the deadline.
///
/// Unlike a COUNT a relay accepted and did not answer, this one can be cured
/// by reconnecting and asking again.
class CountNotSentException extends CountNotSupportedException {
  CountNotSentException(super.reason);

  @override
  String toString() => 'CountNotSentException: $reason';
}
