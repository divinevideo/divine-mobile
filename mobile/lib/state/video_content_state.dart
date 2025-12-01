// ABOUTME: Lightweight video content state for single-controller architecture
// ABOUTME: Stores video metadata and thumbnails without heavy VideoPlayerController instances

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter/foundation.dart';

part 'video_content_state.freezed.dart';

/// Loading state for video content
enum ContentLoadingState {
  idle,
  loadingMetadata,
  loadingThumbnail,
  ready,
  failed,
}

/// Priority for content preloading
enum PreloadPriority {
  current, // Currently visible video
  next, // Next video in feed
  nearby, // Within 2-3 videos of current
  background, // Background preloading
}

/// Lightweight video metadata without VideoPlayerController
@freezed
sealed class VideoMetadata with _$VideoMetadata {
  const factory VideoMetadata({
    required Duration duration,
    required double width,
    required double height,
    required double aspectRatio,
    int? bitrate,
    String? format,
  }) = _VideoMetadata;
}

/// Lightweight video content representation
/// This replaces the heavy VideoPlayerController-based approach
@freezed
sealed class VideoContent with _$VideoContent {
  const factory VideoContent({
    required String videoId,
    required String url,
    required ContentLoadingState loadingState,
    required DateTime createdAt,
    VideoMetadata? metadata,
    Uint8List? thumbnailData,
    String? errorMessage,
    DateTime? lastAccessedAt,
    @Default(PreloadPriority.background) PreloadPriority priority,
  }) = _VideoContent;

  const VideoContent._();

  /// Check if content is ready for display
  bool get isReady => loadingState == ContentLoadingState.ready;

  /// Check if content is currently loading
  bool get isLoading =>
      loadingState == ContentLoadingState.loadingMetadata ||
      loadingState == ContentLoadingState.loadingThumbnail;

  /// Check if content has failed to load
  bool get hasFailed => loadingState == ContentLoadingState.failed;

  /// Check if content has thumbnail ready
  bool get hasThumbnail => thumbnailData != null;

  /// Get aspect ratio from metadata or default
  double get aspectRatio => metadata?.aspectRatio ?? (16.0 / 9.0);

  /// Update access time for LRU cache management
  VideoContent accessed() {
    return copyWith(lastAccessedAt: DateTime.now());
  }

  /// Update loading state
  VideoContent withState(ContentLoadingState newState) {
    return copyWith(loadingState: newState);
  }

  /// Add error information
  VideoContent withError(String error) {
    return copyWith(
      loadingState: ContentLoadingState.failed,
      errorMessage: error,
    );
  }
}

/// State for the single video controller
enum VideoControllerState {
  idle, // No video loaded
  loading, // Switching to new video
  ready, // Video ready and can play
  playing, // Video is currently playing
  paused, // Video is paused
  error, // Video failed to load/play
}

/// Single video controller state
@freezed
sealed class SingleVideoState with _$SingleVideoState {
  const factory SingleVideoState({
    @Default(VideoControllerState.idle) VideoControllerState state,
    String? currentVideoId,
    String? previousVideoId,
    String? errorMessage,
    @Default(false) bool isInBackground,
    DateTime? lastStateChange,
  }) = _SingleVideoState;

  const SingleVideoState._();

  /// Check if video is playing
  bool get isPlaying => state == VideoControllerState.playing;

  /// Check if video is ready
  bool get isReady => state == VideoControllerState.ready;

  /// Check if there's an error
  bool get hasError => state == VideoControllerState.error;

  /// Check if controller is idle
  bool get isIdle => state == VideoControllerState.idle;

  /// Update state with timestamp
  SingleVideoState withState(VideoControllerState newState) {
    return copyWith(state: newState, lastStateChange: DateTime.now());
  }
}

/// Content buffer state for managing preloaded video content
@freezed
sealed class VideoContentBufferState with _$VideoContentBufferState {
  const factory VideoContentBufferState({
    @Default({}) Map<String, VideoContent> content,
    @Default(0) int totalSize,
    @Default(0.0) double estimatedMemoryMB,
    DateTime? lastCleanup,
  }) = _VideoContentBufferState;

  const VideoContentBufferState._();

  /// Get content by video ID
  VideoContent? getContent(String videoId) => content[videoId];

  /// Check if content exists
  bool hasContent(String videoId) => content.containsKey(videoId);

  /// Get ready content
  List<VideoContent> get readyContent =>
      content.values.where((c) => c.isReady).toList();

  /// Get loading content
  List<VideoContent> get loadingContent =>
      content.values.where((c) => c.isLoading).toList();

  /// Get failed content
  List<VideoContent> get failedContent =>
      content.values.where((c) => c.hasFailed).toList();

  /// Check if memory cleanup is needed
  bool get needsCleanup => content.length > 50 || estimatedMemoryMB > 200;

  /// Get content sorted by last access (for LRU cleanup)
  List<VideoContent> get contentForCleanup {
    final candidates = content.values
        .where((c) => c.priority != PreloadPriority.current)
        .toList();

    candidates.sort((a, b) {
      // Sort by priority first (background gets cleaned first)
      final priorityCompare = a.priority.index.compareTo(b.priority.index);
      if (priorityCompare != 0) return -priorityCompare;

      // Then by age (oldest first)
      return a.createdAt.compareTo(b.createdAt);
    });

    return candidates;
  }
}
