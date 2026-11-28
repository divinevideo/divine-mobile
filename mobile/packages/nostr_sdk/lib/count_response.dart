// ABOUTME: Data model for NIP-45 COUNT responses from relays.
// ABOUTME: Carries the count, whether it is approximate and whether it is complete.

/// Response from a NIP-45 COUNT query
class CountResponse {
  /// The count of matching events
  final int count;

  /// Whether this count is approximate (probabilistic)
  final bool approximate;

  /// Whether every relay asked for this count settled it.
  ///
  /// `false` when at least one relay that could hold matching events timed
  /// out, refused the COUNT with CLOSED, or could not be sent it, while
  /// another relay answered. [count] is then the largest answer that did
  /// arrive, so the true count may be higher. A relay that replied it does
  /// not know COUNT ([CountCommandUnknownException]) cannot contribute and
  /// does not make a count incomplete.
  final bool isComplete;

  const CountResponse({
    required this.count,
    required this.isComplete,
    this.approximate = false,
  });

  @override
  String toString() =>
      'CountResponse(count: $count, approximate: $approximate, '
      'isComplete: $isComplete)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountResponse &&
          count == other.count &&
          approximate == other.approximate &&
          isComplete == other.isComplete;

  @override
  int get hashCode => Object.hash(count, approximate, isComplete);
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

/// Completes a relay's pending COUNT when the relay answered that it does not
/// know the COUNT command, as strfry before 1.1 and memlay do.
///
/// That relay cannot count at all, so its silence costs a count nothing:
/// unlike a CLOSED refusal or a timeout, it does not make the count
/// incomplete.
class CountCommandUnknownException extends CountNotSupportedException {
  CountCommandUnknownException(super.reason);

  @override
  String toString() => 'CountCommandUnknownException: $reason';
}
