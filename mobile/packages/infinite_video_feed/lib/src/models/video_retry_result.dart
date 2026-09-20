/// The result of retrying a feed video.
///
/// [notAttempted] means initialization was skipped or lost ownership before it
/// could complete. It must not be reported as successful playback.
enum VideoRetryResult {
  /// Initialization completed without recording a playback error.
  played,

  /// Initialization completed and recorded a playback error.
  failed,

  /// Initialization did not complete, so playback was never attempted.
  notAttempted;

  /// Classifies a retry after its initialization work completes.
  static VideoRetryResult fromInitialization({
    required bool initialized,
    required bool hasError,
  }) {
    if (!initialized) return VideoRetryResult.notAttempted;
    return hasError ? VideoRetryResult.failed : VideoRetryResult.played;
  }
}
