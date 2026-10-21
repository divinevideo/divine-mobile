/// Whether a follow changed state and reached the network.
enum FollowOutcome {
  /// The updated contact list was successfully published.
  published,

  /// The follow is local and awaiting an offline sync or a safe publish retry.
  queued,

  /// The account was already followed or the request targeted the current user.
  unchanged,
}
