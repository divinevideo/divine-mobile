// ABOUTME: VideoState model for tracking video loading and lifecycle states
// ABOUTME: Immutable model with state transitions following TDD principles

import 'package:flutter/foundation.dart';
import 'package:openvine/models/video_event.dart';

/// Enum representing the different loading states of a video
enum VideoLoadingState {
  /// Video has not started loading yet
  notLoaded,

  /// Video is currently being loaded/initialized
  loading,

  /// Video is ready for playback
  ready,

  /// Video failed to load but can be retried
  failed,

  /// Video failed permanently and should not be retried
  permanentlyFailed,

  /// Video has been disposed and resources cleaned up
  disposed,
}

/// Immutable state model for video lifecycle management
///
/// Tracks the loading state, error conditions, and retry attempts
/// for a video event. Provides controlled state transitions and
/// validation to ensure data integrity.
@immutable
class VideoState {
  /// Creates a new VideoState instance
  ///
  /// [event] - The video event (required)
  /// [loadingState] - Current state (defaults to notLoaded)
  /// [errorMessage] - Error description if any
  /// [retryCount] - Number of retries (defaults to 0)
  /// [lastUpdated] - When state was updated (defaults to now)
  factory VideoState({
    required VideoEvent event,
    VideoLoadingState loadingState = VideoLoadingState.notLoaded,
    String? errorMessage,
    int retryCount = 0,
    DateTime? lastUpdated,
  }) {
    assert(retryCount >= 0, 'Retry count cannot be negative');
    return VideoState._internal(
      event: event,
      loadingState: loadingState,
      errorMessage: errorMessage,
      retryCount: retryCount,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  /// Internal constructor for immutable state creation
  const VideoState._internal({
    required this.event,
    required this.loadingState,
    required this.retryCount,
    required this.lastUpdated,
    this.errorMessage,
  });

  /// Maximum number of retry attempts before marking as permanently failed
  static const int maxRetryCount = 3;

  /// The video event this state represents
  final VideoEvent event;

  /// Current loading state
  final VideoLoadingState loadingState;

  /// Error message if the video failed to load
  final String? errorMessage;

  /// Number of retry attempts made
  final int retryCount;

  /// Timestamp when this state was last updated
  final DateTime lastUpdated;

  // State transition methods

  /// Transition to loading state
  VideoState toLoading() {
    _validateTransition([
      VideoLoadingState.notLoaded,
      VideoLoadingState.failed,
      VideoLoadingState.ready,
    ]);

    return VideoState._internal(
      event: event,
      loadingState: VideoLoadingState.loading,
      errorMessage: null, // Clear error when starting new load
      retryCount: retryCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Transition to ready state
  VideoState toReady() {
    _validateTransition([VideoLoadingState.loading]);

    return VideoState._internal(
      event: event,
      loadingState: VideoLoadingState.ready,
      errorMessage: null,
      retryCount: retryCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Transition to failed state with error message
  VideoState toFailed(String errorMessage) {
    // Can fail from any state except disposed and permanently failed
    if (loadingState == VideoLoadingState.disposed) {
      throw StateError('Cannot transition to failed from disposed state');
    }
    if (loadingState == VideoLoadingState.permanentlyFailed) {
      throw StateError(
        'Cannot transition to failed from permanently failed state',
      );
    }

    final newRetryCount = retryCount + 1;

    // Check if we should transition to permanently failed instead
    if (newRetryCount > maxRetryCount) {
      return toPermanentlyFailed(errorMessage);
    }

    return VideoState._internal(
      event: event,
      loadingState: VideoLoadingState.failed,
      errorMessage: errorMessage,
      retryCount: newRetryCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Transition to permanently failed state
  VideoState toPermanentlyFailed(String errorMessage) {
    if (loadingState == VideoLoadingState.disposed) {
      throw StateError(
        'Cannot transition to permanently failed from disposed state',
      );
    }

    return VideoState._internal(
      event: event,
      loadingState: VideoLoadingState.permanentlyFailed,
      errorMessage: errorMessage,
      retryCount: retryCount,
      lastUpdated: DateTime.now(),
    );
  }

  /// Transition to disposed state
  VideoState toDisposed() {
    if (loadingState == VideoLoadingState.disposed) {
      throw StateError('Video is already disposed');
    }

    return VideoState._internal(
      event: event,
      loadingState: VideoLoadingState.disposed,
      errorMessage: errorMessage,
      retryCount: retryCount,
      lastUpdated: DateTime.now(),
    );
  }

  // Convenience getters

  /// Whether the video is currently loading
  bool get isLoading => loadingState == VideoLoadingState.loading;

  /// Whether the video is ready for playback
  bool get isReady => loadingState == VideoLoadingState.ready;

  /// Whether the video has failed to load
  bool get hasFailed =>
      loadingState == VideoLoadingState.failed ||
      loadingState == VideoLoadingState.permanentlyFailed;

  /// Whether the video can be retried
  bool get canRetry =>
      loadingState == VideoLoadingState.failed && retryCount < maxRetryCount;

  /// Whether the video has been disposed
  bool get isDisposed => loadingState == VideoLoadingState.disposed;

  /// Validates that the current state can transition to one of the allowed states
  void _validateTransition(List<VideoLoadingState> allowedFromStates) {
    if (loadingState == VideoLoadingState.disposed) {
      throw StateError('Cannot transition from disposed state');
    }
    if (loadingState == VideoLoadingState.permanentlyFailed) {
      throw StateError('Cannot transition from permanently failed state');
    }
    if (!allowedFromStates.contains(loadingState)) {
      throw StateError('Invalid transition from $loadingState');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoState &&
        other.event == event &&
        other.loadingState == loadingState &&
        other.errorMessage == errorMessage &&
        other.retryCount == retryCount;
  }

  @override
  int get hashCode =>
      Object.hash(event, loadingState, errorMessage, retryCount);

  @override
  String toString() =>
      'VideoState('
      'event: ${event.id}, '
      'state: $loadingState, '
      'error: $errorMessage, '
      'retries: $retryCount, '
      'updated: $lastUpdated'
      ')';
}
