// ABOUTME: Centralized video visibility manager that ensures videos ONLY play when actually visible
// ABOUTME: Single source of truth for video playback state based on real visibility detection

import 'dart:async';
import 'package:openvine/utils/unified_logger.dart';

/// Visibility info for a video widget
class VideoVisibilityInfo {
  VideoVisibilityInfo({
    required this.videoId,
    required this.visibilityFraction,
    required this.isVisible,
    required this.lastUpdate,
  });
  final String videoId;
  final double visibilityFraction;
  final bool isVisible;
  final DateTime lastUpdate;
}

/// Centralized manager for video visibility and playback control
///
/// This service is the SINGLE SOURCE OF TRUTH for which videos should be playing.
/// It uses actual visibility detection (not index-based assumptions) to ensure
/// videos NEVER play when not visible on screen.
///
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoVisibilityManager {
  /// Minimum visibility fraction required for a video to play (50%)
  static const double minVisibilityThreshold = 0.5;

  /// Map of video IDs to their visibility info
  final Map<String, VideoVisibilityInfo> _visibilityMap = {};

  /// Set of video IDs that are allowed to play
  final Set<String> _playableVideos = {};

  /// Track if user is actively scrolling/playing videos (auto-play mode)
  bool _autoPlayEnabled = false;

  /// The last video that was playing (for auto-play continuation)
  String? _lastPlayingVideo;

  /// Stream controller for visibility changes
  final _visibilityStreamController =
      StreamController<VideoVisibilityInfo>.broadcast();

  /// Get stream of visibility changes
  Stream<VideoVisibilityInfo> get visibilityStream =>
      _visibilityStreamController.stream;

  /// Get all currently visible videos
  List<String> get visibleVideos => _visibilityMap.entries
      .where((e) => e.value.isVisible)
      .map((e) => e.key)
      .toList();

  /// Get all videos allowed to play (visible above threshold)
  Set<String> get playableVideos => Set.unmodifiable(_playableVideos);

  /// Check if a specific video should be playing
  bool shouldVideoPlay(String videoId) => _playableVideos.contains(videoId);

  /// Check if auto-play is enabled
  bool get isAutoPlayEnabled => _autoPlayEnabled;

  /// Get the currently actively playing video (for auto-play)
  String? get activelyPlayingVideo => _lastPlayingVideo;

  /// Update visibility for a video
  ///
  /// This is called by VisibilityDetector widgets wrapping each video.
  /// The manager decides if the video should play based on visibility.
  void updateVideoVisibility(String videoId, double visibilityFraction) {
    final wasPlayable = _playableVideos.contains(videoId);
    final isNowVisible = visibilityFraction > 0;
    final isNowPlayable = visibilityFraction >= minVisibilityThreshold;

    // Update visibility info
    final info = VideoVisibilityInfo(
      videoId: videoId,
      visibilityFraction: visibilityFraction,
      isVisible: isNowVisible,
      lastUpdate: DateTime.now(),
    );

    _visibilityMap[videoId] = info;

    // Update playable set
    if (isNowPlayable && !wasPlayable) {
      _playableVideos.add(videoId);

      // Auto-play logic: if auto-play is enabled and this is a new visible video,
      // make it the actively playing one
      if (_autoPlayEnabled) {
        // When setting a new actively playing video, ensure only one can play
        _setActivelyPlaying(videoId);
      }

      Log.info(
        '✅ Video $videoId is now playable (visibility: ${(visibilityFraction * 100).toStringAsFixed(1)}%)',
        name: 'VideoVisibilityManager',
        category: LogCategory.video,
      );
    } else if (!isNowPlayable && wasPlayable) {
      _playableVideos.remove(videoId);

      // If this was the actively playing video, update auto-play state
      if (_lastPlayingVideo == videoId) {
        _lastPlayingVideo = null;
        // If auto-play is enabled, find the next most visible video
        if (_autoPlayEnabled && _playableVideos.isNotEmpty) {
          // Get the most visible video from the remaining playable ones
          String? nextVideo;
          double maxVisibility = 0;
          for (final id in _playableVideos) {
            final info = _visibilityMap[id];
            if (info != null && info.visibilityFraction > maxVisibility) {
              maxVisibility = info.visibilityFraction;
              nextVideo = id;
            }
          }
          if (nextVideo != null) {
            _setActivelyPlaying(nextVideo);
          }
        }
      }

      Log.info(
        '⏸️ Video $videoId is no longer playable (visibility: ${(visibilityFraction * 100).toStringAsFixed(1)}%)',
        name: 'VideoVisibilityManager',
        category: LogCategory.video,
      );
    }

    // Emit visibility change
    _visibilityStreamController.add(info);

    // Notify listeners if playability changed
    if (wasPlayable != isNowPlayable) {}
  }

  /// Remove a video from tracking (e.g., when widget is disposed)
  void removeVideo(String videoId) {
    _visibilityMap.remove(videoId);
    _playableVideos.remove(videoId);
    Log.debug(
      'Removed video $videoId from visibility tracking',
      name: 'VideoVisibilityManager',
      category: LogCategory.video,
    );
  }

  /// Pause all videos (e.g., when app goes to background)
  void pauseAllVideos() {
    _playableVideos.clear();
    _visibilityMap
        .clear(); // Clear visibility map to prevent stale videos from resuming
    _autoPlayEnabled = false; // Disable auto-play when backgrounding
    _lastPlayingVideo = null; // Clear last playing video
    Log.info(
      '⏸️ Paused all videos and cleared visibility state',
      name: 'VideoVisibilityManager',
      category: LogCategory.video,
    );
  }

  /// Resume visibility-based playback
  void resumeVisibilityBasedPlayback() {
    // Re-evaluate which videos should play based on current visibility
    _playableVideos.clear();

    for (final entry in _visibilityMap.entries) {
      if (entry.value.visibilityFraction >= minVisibilityThreshold) {
        _playableVideos.add(entry.key);
      }
    }

    Log.info(
      '▶️ Resumed visibility-based playback (${_playableVideos.length} videos playable)',
      name: 'VideoVisibilityManager',
      category: LogCategory.video,
    );
  }

  /// Mark a video as actively playing (enables auto-play mode)
  ///
  /// This should be called when a user explicitly starts playing a video.
  /// It enables auto-play so the next visible video will automatically play.
  void setActivelyPlaying(String videoId) {
    if (_playableVideos.contains(videoId)) {
      _setActivelyPlaying(videoId);
    }
  }

  /// Internal method to set actively playing video
  void _setActivelyPlaying(String videoId) {
    // If there was a previous video playing, ensure it's no longer in playable set
    if (_lastPlayingVideo != null && _lastPlayingVideo != videoId) {
      _playableVideos.remove(_lastPlayingVideo);
      Log.info(
        '⏸️ Removing previous video from playable: $_lastPlayingVideo',
        name: 'VideoVisibilityManager',
        category: LogCategory.video,
      );
    }

    _autoPlayEnabled = true;
    _lastPlayingVideo = videoId;
    Log.info(
      '🎬 Auto-play enabled - actively playing: $videoId',
      name: 'VideoVisibilityManager',
      category: LogCategory.video,
    );
  }

  /// Disable auto-play (user paused or stopped video)
  void disableAutoPlay() {
    _autoPlayEnabled = false;
    _lastPlayingVideo = null;
    Log.info(
      '⏹️ Auto-play disabled',
      name: 'VideoVisibilityManager',
      category: LogCategory.video,
    );
  }

  /// Check if a specific video should auto-play when visible
  ///
  /// Returns true if:
  /// - Auto-play is enabled
  /// - Video is visible above threshold
  /// - No other video is currently the designated active one, OR this video becomes visible first
  bool shouldAutoPlay(String videoId) {
    if (!_autoPlayEnabled || !_playableVideos.contains(videoId)) {
      return false;
    }

    // If no actively playing video, this one can auto-play
    if (_lastPlayingVideo == null) {
      return true;
    }

    // If the actively playing video is no longer playable, this one can take over
    if (!_playableVideos.contains(_lastPlayingVideo)) {
      return true;
    }

    // This is the actively playing video
    return _lastPlayingVideo == videoId;
  }

  /// Get visibility info for a specific video
  VideoVisibilityInfo? getVisibilityInfo(String videoId) =>
      _visibilityMap[videoId];

  /// Debug info about current visibility state
  Map<String, dynamic> get debugInfo => {
    'totalTracked': _visibilityMap.length,
    'visibleCount': visibleVideos.length,
    'playableCount': _playableVideos.length,
    'threshold': '${(minVisibilityThreshold * 100).toStringAsFixed(0)}%',
    'autoPlayEnabled': _autoPlayEnabled,
    'activelyPlaying': _lastPlayingVideo,
    'videos': _visibilityMap.map(
      (id, info) => MapEntry(id, {
        'visibility': '${(info.visibilityFraction * 100).toStringAsFixed(1)}%',
        'playable': _playableVideos.contains(id),
        'shouldAutoPlay': shouldAutoPlay(id),
        'lastUpdate': info.lastUpdate.toIso8601String(),
      }),
    ),
  };

  void dispose() {
    _visibilityStreamController.close();
  }
}
