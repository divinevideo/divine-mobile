// ABOUTME: Reusable helper for building video feed providers with common logic
// ABOUTME: Encapsulates debouncing, stability waiting, and listener setup patterns

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Configuration for building a video feed
class VideoFeedConfig {
  const VideoFeedConfig({
    required this.subscriptionType,
    required this.subscribe,
    required this.getVideos,
    required this.sortVideos,
    this.filterVideos,
  });

  /// The subscription type for this feed
  final SubscriptionType subscriptionType;

  /// Function to subscribe to the feed (calls appropriate VideoEventService method)
  final Future<void> Function(VideoEventService service) subscribe;

  /// Function to get videos from the service
  final List<VideoEvent> Function(VideoEventService service) getVideos;

  /// Function to sort videos for this feed
  final List<VideoEvent> Function(List<VideoEvent> videos) sortVideos;

  /// Optional function to filter videos for this feed (e.g., filter out WebM on iOS/macOS)
  final List<VideoEvent> Function(List<VideoEvent> videos)? filterVideos;
}

/// Reusable builder for video feed providers
/// Encapsulates common logic: subscription, stability waiting, debouncing, listener setup
class VideoFeedBuilder {
  VideoFeedBuilder(this._service);

  final VideoEventService _service;
  Timer? _debounceTimer;
  Timer? _stabilityTimer;
  VoidCallback? _listener;
  int _lastKnownCount = 0;

  /// Build a feed with the provided configuration
  /// Handles subscription, waiting for stability, and sorting
  Future<VideoFeedState> buildFeed({required VideoFeedConfig config}) async {
    Log.debug(
      'VideoFeedBuilder: Building feed for ${config.subscriptionType}',
      name: 'VideoFeedBuilder',
      category: LogCategory.video,
    );

    // Subscribe to the feed
    await config.subscribe(_service);

    // Wait for initial batch of videos to arrive
    await _waitForStability(config);

    // Get, filter, and sort videos
    var videos = config.getVideos(_service);
    if (config.filterVideos != null) {
      videos = config.filterVideos!(videos);
    }
    final sortedVideos = config.sortVideos(videos);

    Log.info(
      'VideoFeedBuilder: Feed built with ${sortedVideos.length} videos for ${config.subscriptionType}',
      name: 'VideoFeedBuilder',
      category: LogCategory.video,
    );

    return VideoFeedState(
      videos: sortedVideos,
      hasMoreContent: sortedVideos.length >= 10,
      isLoadingMore: false,
      error: null,
      lastUpdated: DateTime.now(),
    );
  }

  /// Set up continuous listener for feed updates with debouncing
  void setupContinuousListener({
    required VideoFeedConfig config,
    required void Function(VideoFeedState state) onUpdate,
  }) {
    _lastKnownCount = config.getVideos(_service).length;

    _listener = () {
      final currentCount = config.getVideos(_service).length;

      // Only update if video count actually changed
      if (currentCount != _lastKnownCount) {
        Log.warning(
          '🔔 VideoFeedBuilder: Video count changed for ${config.subscriptionType}: $_lastKnownCount -> $currentCount',
          name: 'VideoFeedBuilder',
          category: LogCategory.video,
        );
        _lastKnownCount = currentCount;

        // Debounce updates to avoid excessive rebuilds
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 500), () {
          var videos = config.getVideos(_service);
          if (config.filterVideos != null) {
            videos = config.filterVideos!(videos);
          }
          final sortedVideos = config.sortVideos(videos);

          Log.info(
            '📊 VideoFeedBuilder: Emitting state update for ${config.subscriptionType} with ${sortedVideos.length} videos',
            name: 'VideoFeedBuilder',
            category: LogCategory.video,
          );

          final state = VideoFeedState(
            videos: sortedVideos,
            hasMoreContent: sortedVideos.length >= 10,
            isLoadingMore: false,
            error: null,
            lastUpdated: DateTime.now(),
          );

          onUpdate(state);
        });
      }
    };

    _service.addListener(_listener!);

    Log.debug(
      'VideoFeedBuilder: Continuous listener set up for ${config.subscriptionType}',
      name: 'VideoFeedBuilder',
      category: LogCategory.video,
    );
  }

  /// Wait for video count to stabilize before returning
  /// Prevents returning too early while videos are still streaming in
  Future<void> _waitForStability(VideoFeedConfig config) async {
    final completer = Completer<void>();
    int stableCount = 0;

    void checkStability() {
      final currentCount = config.getVideos(_service).length;
      if (currentCount != stableCount) {
        // Count changed, reset stability timer
        stableCount = currentCount;
        _stabilityTimer?.cancel();
        _stabilityTimer = Timer(const Duration(milliseconds: 300), () {
          // Count stable for 300ms, we're done
          if (!completer.isCompleted) {
            completer.complete();
          }
        });
      }
    }

    _service.addListener(checkStability);

    // Maximum wait time of 3 seconds
    Timer(const Duration(seconds: 3), () {
      if (!completer.isCompleted) {
        Log.debug(
          'VideoFeedBuilder: Timeout reached (3s) with $stableCount videos for ${config.subscriptionType}',
          name: 'VideoFeedBuilder',
          category: LogCategory.video,
        );
        completer.complete();
      }
    });

    // Trigger initial check
    checkStability();

    await completer.future;

    // Clean up stability listener
    _service.removeListener(checkStability);
    _stabilityTimer?.cancel();

    Log.debug(
      'VideoFeedBuilder: Stability reached with $stableCount videos for ${config.subscriptionType}',
      name: 'VideoFeedBuilder',
      category: LogCategory.video,
    );
  }

  /// Clean up listeners and timers
  void cleanup() {
    _debounceTimer?.cancel();
    _stabilityTimer?.cancel();
    if (_listener != null) {
      _service.removeListener(_listener!);
      _listener = null;
    }

    Log.debug(
      'VideoFeedBuilder: Cleaned up',
      name: 'VideoFeedBuilder',
      category: LogCategory.video,
    );
  }
}
