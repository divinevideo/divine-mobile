// ABOUTME: Reusable helper for building video feed providers with common logic
// ABOUTME: Encapsulates debouncing and listener setup patterns for progressive feeds

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';
import 'package:unified_logger/unified_logger.dart';

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
  VoidCallback? _listener;
  int _lastKnownCount = 0;

  /// Build a feed with the provided configuration
  /// Subscribes and returns immediately with whatever videos are available.
  /// Progressive updates arrive via [setupContinuousListener].
  Future<VideoFeedState> buildFeed({required VideoFeedConfig config}) async {
    Log.debug(
      'VideoFeedBuilder: Building feed for ${config.subscriptionType}',
      name: 'VideoFeedBuilder',
      category: LogCategory.video,
    );

    // Start the subscription in the background so callers can render from
    // retained, cached, or empty state immediately.
    unawaited(
      config.subscribe(_service).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        Log.error(
          'VideoFeedBuilder: Background subscribe failed for ${config.subscriptionType}: $error',
          name: 'VideoFeedBuilder',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );

    // Return immediately with whatever videos are available
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
      isInitialLoad: sortedVideos.isEmpty,
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

  /// Clean up listeners and timers
  void cleanup() {
    _debounceTimer?.cancel();
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
