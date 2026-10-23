import 'package:models/models.dart' show AudioEvent;

/// Where the render places [track] on the exported video: its timeline
/// window, or the whole video (both `null`, as `VideoAudioTrack` reads them)
/// when the window is missing or inverted.
///
/// A persisted track can carry an invalid window — e.g. a sound added before
/// its duration was known ends up with endTime=0 (see _openMusicLibrary) — and
/// still has to render instead of being dropped as a zero-length range. The
/// voice-over measurement for ducking places the takes through this too, so
/// they are measured where they play.
({Duration? startTime, Duration? endTime}) renderWindowOf(AudioEvent track) {
  final endTime = track.endTime;
  final hasWindow = endTime != null && endTime > track.startTime;
  return (
    startTime: hasWindow ? track.startTime : null,
    endTime: hasWindow ? endTime : null,
  );
}
