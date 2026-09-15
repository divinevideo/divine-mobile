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
  timedOut('timed_out');

  const VideoRenderFailureReason(this.traceValue);

  /// Stable telemetry value, independent of enum names.
  final String traceValue;
}
