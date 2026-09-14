// ABOUTME: Marks a relay read that nothing answered, so its empty result
// ABOUTME: cannot be mistaken for "nothing matched the filter".

/// Thrown when a relay read came back empty because it could not be
/// completed, rather than because no event matched.
///
/// The relay layer reports a read that reached no relay, or that ran out of
/// time, as an empty list — the same value a genuinely empty answer has. A
/// caller that renders "nothing here" from that value shows a dead end for
/// what is a network failure, and never retries, because nothing failed as
/// far as it can tell.
class RelayReadUnavailableException implements Exception {
  /// Creates the exception with the [reason] the read could not answer.
  const RelayReadUnavailableException(this.reason);

  /// Why the read could not answer, in the relay layer's own terms.
  final String reason;

  @override
  String toString() => 'RelayReadUnavailableException: $reason';
}
