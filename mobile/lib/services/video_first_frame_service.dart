// ABOUTME: Service for extracting first frame from videos as fallback thumbnail
// ABOUTME: Uses video_player to extract frame at position 0 for missing thumbnails

import 'dart:async';
import 'dart:typed_data';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Service for extracting first frames from videos to use as thumbnails
class VideoFirstFrameService {
  static final VideoFirstFrameService _instance =
      VideoFirstFrameService._internal();
  factory VideoFirstFrameService() => _instance;
  VideoFirstFrameService._internal();

  // Cache of extracted frames to avoid re-extraction
  final Map<String, Uint8List?> _frameCache = {};

  // Track ongoing extractions to avoid duplicates
  final Map<String, Completer<Uint8List?>> _pendingExtractions = {};

  /// Extract the first frame from a video URL
  /// Returns null if extraction fails or is not supported on the platform
  Future<Uint8List?> extractFirstFrame(String videoUrl) async {
    // Check cache first
    if (_frameCache.containsKey(videoUrl)) {
      return _frameCache[videoUrl];
    }

    // Check if extraction is already in progress
    if (_pendingExtractions.containsKey(videoUrl)) {
      return _pendingExtractions[videoUrl]!.future;
    }

    // Start new extraction
    final completer = Completer<Uint8List?>();
    _pendingExtractions[videoUrl] = completer;

    try {
      Log.info(
        '🎬 Extracting first frame from video: ${videoUrl.substring(0, 50)}...',
        name: 'VideoFirstFrameService',
        category: LogCategory.video,
      );

      // Create a temporary video player controller
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      // Initialize the controller
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Video initialization timed out');
        },
      );

      // Seek to the first frame (position 0)
      await controller.seekTo(Duration.zero);

      // Wait a bit for the frame to be ready
      await Future.delayed(const Duration(milliseconds: 100));

      // Get video dimensions
      final videoWidth = controller.value.size.width;
      final videoHeight = controller.value.size.height;

      if (videoWidth == 0 || videoHeight == 0) {
        throw Exception('Invalid video dimensions');
      }

      // Extract frame using platform-specific method
      Uint8List? frameData;

      // For web, we need a different approach since captureFrame isn't available
      // We'll return null and let the video player show naturally
      // On mobile platforms, we could use platform channels or plugins

      // Clean up the controller
      await controller.dispose();

      // For now, on web we'll return null and rely on the video player showing
      // On mobile platforms, we could implement platform-specific frame capture
      Log.info(
        '⚠️ First frame extraction not fully implemented for this platform',
        name: 'VideoFirstFrameService',
        category: LogCategory.video,
      );

      frameData = null;

      // Cache the result (even if null)
      _frameCache[videoUrl] = frameData;

      // Complete and clean up pending extraction
      completer.complete(frameData);
      _pendingExtractions.remove(videoUrl);

      return frameData;
    } catch (e) {
      Log.error(
        'Failed to extract first frame: $e',
        name: 'VideoFirstFrameService',
        category: LogCategory.video,
      );

      // Cache the failure
      _frameCache[videoUrl] = null;

      // Complete and clean up pending extraction
      completer.complete(null);
      _pendingExtractions.remove(videoUrl);

      return null;
    }
  }

  /// Clear the frame cache to free memory
  void clearCache() {
    _frameCache.clear();
  }

  /// Clear a specific URL from cache
  void clearCacheForUrl(String videoUrl) {
    _frameCache.remove(videoUrl);
  }
}
