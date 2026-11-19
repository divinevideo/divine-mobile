/// The system's state for a running Live Activity.
enum LiveActivityState {
  /// The activity is on screen.
  active,

  /// The activity has ended.
  ended,

  /// The user dismissed the activity.
  dismissed,

  /// The activity is out of date.
  stale,
}
