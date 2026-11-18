// ABOUTME: Model for the recorder state mirrored on a remote control
// ABOUTME: Sent to the Apple Watch so its shutter and clip budget stay in sync

/// What a remote control needs to mirror the recorder it triggers.
///
/// Carries when the take in progress started rather than how long it has
/// run, so the remote keeps counting on its own between updates.
class RemoteRecorderState {
  /// Creates the state of an open recorder.
  const RemoteRecorderState({
    required this.recorded,
    required this.budget,
    required this.modeName,
    required this.isShutterActive,
    this.activeTakeStartedAt,
  });

  /// Combined length of the clips already recorded.
  final Duration recorded;

  /// When the take in progress started, or `null` while none is running.
  final DateTime? activeTakeStartedAt;

  /// Clip length the remote fills its progress against.
  final Duration budget;

  /// Name of the recorder mode in use, as the recorder shows it.
  final String modeName;

  /// Whether the next shutter press stops what is running: a take, its
  /// countdown, or stop-motion capturing on its interval.
  ///
  /// Separate from [activeTakeStartedAt] because a countdown and stop-motion
  /// run without adding recorded time.
  final bool isShutterActive;

  /// Converts the state to the map sent over the method channel.
  Map<String, Object?> toMap() => {
    'recordedMs': recorded.inMilliseconds,
    'activeTakeStartedAtMs': activeTakeStartedAt?.millisecondsSinceEpoch,
    'budgetMs': budget.inMilliseconds,
    'modeName': modeName,
    'shutterActive': isShutterActive,
  };
}
