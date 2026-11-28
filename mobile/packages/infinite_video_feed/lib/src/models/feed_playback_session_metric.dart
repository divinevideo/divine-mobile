import 'package:infinite_video_feed/src/models/feed_playback_telemetry.dart';

/// How a fullscreen-feed activation turned out by the time it ended.
enum FeedPlaybackSessionOutcome {
  /// The video rendered a first frame while it was the active video.
  played,

  /// The viewer left before a first frame, and no error was shown.
  abandoned,

  /// The video showed an error and never rendered a first frame.
  failed,
}

/// What ended a fullscreen-feed activation.
enum FeedPlaybackSessionEnd {
  /// Another video became active: a swipe, an auto-advance or a jump.
  swipe,

  /// The feed stopped being visible: backgrounded, covered or a tab switch.
  hidden,

  /// The feed was closed.
  closed,

  /// The feed's video list changed under the active video.
  replaced,
}

/// One fullscreen-feed activation, measured from the moment its video became
/// active until it ended.
///
/// Carries no video, URL or account identifier.
class FeedPlaybackSessionMetric {
  /// Creates a completed activation measurement.
  const FeedPlaybackSessionMetric({
    required this.index,
    required this.outcome,
    required this.end,
    required this.loadedFromCache,
    required this.active,
    this.error,
    this.timeToFirstFrame,
    this.controllerInitializedAt,
    this.sourceReadyAt,
    this.playbackRequestedAt,
    this.watched,
    this.stallCount,
    this.stalled,
  });

  /// Index occupied by the video when it became active.
  final int index;

  /// How the activation turned out.
  final FeedPlaybackSessionOutcome outcome;

  /// What ended the activation.
  final FeedPlaybackSessionEnd end;

  /// Whether the player opened a file from the local media cache.
  final bool loadedFromCache;

  /// Time from activation until it ended.
  final Duration active;

  /// The last error category shown, for [FeedPlaybackSessionOutcome.failed].
  final FeedPlaybackError? error;

  /// Time from activation until the first frame rendered, when it did.
  final Duration? timeToFirstFrame;

  /// Time from activation until the native controller was initialized.
  final Duration? controllerInitializedAt;

  /// Time from activation until the media source was ready.
  final Duration? sourceReadyAt;

  /// Time from activation until playback was requested.
  final Duration? playbackRequestedAt;

  /// Time the player reported playing after the first frame, when it played.
  final Duration? watched;

  /// Buffering episodes after playback started, or `null` where the player
  /// does not report a wait for data as buffering.
  final int? stallCount;

  /// Time spent in those episodes, `null` where [stallCount] is.
  final Duration? stalled;
}
