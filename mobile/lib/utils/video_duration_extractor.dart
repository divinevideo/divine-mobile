// ABOUTME: Utility for extracting video duration from video files
// ABOUTME: Provides fallback when VideoPlayerController hasn't loaded metadata

import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Extract video duration from a video file
///
/// Creates a temporary video player controller, initializes it,
/// and extracts the duration. Handles errors and disposes properly.
///
/// Returns null if duration cannot be extracted.
Future<Duration?> extractVideoDuration(File videoFile) async {
  if (!videoFile.existsSync()) {
    Log.error(
      'Video file does not exist: ${videoFile.path}',
      name: 'VideoDurationExtractor',
      category: LogCategory.video,
    );
    return null;
  }

  VideoPlayerController? tempController;
  try {
    Log.debug(
      'Extracting duration from video file: ${videoFile.path}',
      name: 'VideoDurationExtractor',
      category: LogCategory.video,
    );

    // Create temporary controller to read video metadata
    tempController = VideoPlayerController.file(videoFile);

    // Initialize with timeout to prevent hanging
    await tempController.initialize().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw TimeoutException(
          'Video duration extraction timed out after 5 seconds',
        );
      },
    );

    final duration = tempController.value.duration;

    if (duration == Duration.zero) {
      Log.warning(
        'Video player returned zero duration',
        name: 'VideoDurationExtractor',
        category: LogCategory.video,
      );
      return null;
    }

    Log.info(
      'Extracted video duration: ${duration.inMilliseconds}ms',
      name: 'VideoDurationExtractor',
      category: LogCategory.video,
    );
    return duration;
  } catch (e) {
    Log.error(
      'Failed to extract video duration: $e',
      name: 'VideoDurationExtractor',
      category: LogCategory.video,
    );
    return null;
  } finally {
    // Always dispose the temporary controller
    await tempController?.dispose();
  }
}

class TimeoutException implements Exception {
  TimeoutException(this.message);
  final String message;

  @override
  String toString() => 'TimeoutException: $message';
}
