// ABOUTME: Why a video render produced no output
// ABOUTME: Shared by the render service, editor state and the failure overlay

/// Why a render produced no output.
enum VideoRenderFailureReason {
  emptyClips('empty_clips'),
  stopMotionAssembly('stop_motion_assembly'),
  nativeRender('native_render'),

  /// The device has no room left for the export (#7125).
  ///
  /// Split from [nativeRender] because the recovery differs: a retry walks
  /// into the same wall, so the UI asks the user to free up space instead.
  insufficientStorage('insufficient_storage'),
  canceled('canceled'),

  /// The export ran past the render watchdog without settling — a native
  /// call stopped responding (#8488).
  timedOut('timed_out'),

  /// A sound on the timeline could not be fetched for muxing: every download
  /// attempt failed.
  ///
  /// The export stops here rather than shipping the video without the sound
  /// the user picked. The editor preview plays the same sound straight from
  /// the network, so a silent export used to be the only sign the download
  /// had failed — and it came after the post was already public.
  audioUnavailable('audio_unavailable');

  const VideoRenderFailureReason(this.traceValue);

  /// Stable telemetry value, independent of enum names.
  final String traceValue;
}
