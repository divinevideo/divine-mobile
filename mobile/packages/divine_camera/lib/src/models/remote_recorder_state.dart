// ABOUTME: Model for the recorder state mirrored on a remote control
// ABOUTME: Sent to watch remotes to keep their shutter and clip budget in sync

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
    this.isShutterEnabled = true,
    this.activeTakeStartedAt,
    this.stillShutterCount = 0,
  });

  /// Combined length of the clips already recorded. In stop motion, the clip
  /// time the stills taken so far are held for.
  final Duration recorded;

  /// When the take in progress started, or `null` while none is running.
  final DateTime? activeTakeStartedAt;

  /// Clip length the remote fills its progress against. In stop motion, the
  /// clip time of the most stills the session fits.
  final Duration budget;

  /// Name of the recorder mode in use, as the recorder shows it.
  final String modeName;

  /// Whether the next shutter press stops what is running: a take, its
  /// countdown, or stop-motion capturing on its interval.
  ///
  /// Separate from [activeTakeStartedAt] because a countdown and stop-motion
  /// run without adding recorded time.
  final bool isShutterActive;

  /// Whether a shutter press can act on the recorder's current state.
  final bool isShutterEnabled;

  /// How many single-frame capture attempts have finished in stop-motion mode.
  ///
  /// A still leaves [isShutterActive] unchanged, so this count is what tells
  /// a remote that its press was handled.
  final int stillShutterCount;

  /// Converts the state to the map sent over the method channel.
  Map<String, Object?> toMap() => {
    'recordedMs': recorded.inMilliseconds,
    'activeTakeStartedAtMs': activeTakeStartedAt?.millisecondsSinceEpoch,
    'budgetMs': budget.inMilliseconds,
    'modeName': modeName,
    'shutterActive': isShutterActive,
    'shutterEnabled': isShutterEnabled,
    'stillShutterCount': stillShutterCount,
  };
}
