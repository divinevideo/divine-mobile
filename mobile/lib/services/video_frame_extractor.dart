// ABOUTME: Video frame extraction service using FFmpeg
// ABOUTME: Converts video files to individual frame images for GIF creation

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';

// Conditional imports for FFmpeg - disabled due to macOS compatibility issues
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Service for extracting frames from video files using FFmpeg
class VideoFrameExtractor {
  /// Extract frames from a video file
  ///
  /// [videoPath] - Path to the input video file
  /// [targetFrameCount] - Number of frames to extract (default: 30 for 6-second 5fps GIF)
  /// [width] - Target width for extracted frames (default: 640)
  /// [height] - Target height for extracted frames (default: 480)
  ///
  /// Returns a list of frame image data as Uint8List
  static Future<List<Uint8List>> extractFrames({
    required String videoPath,
    int targetFrameCount = 30,
    int width = 640,
    int height = 480,
  }) async {
    try {
      Log.debug(
        'Starting FFmpeg frame extraction from: $videoPath',
        name: 'VideoFrameExtractor',
        category: LogCategory.video,
      );

      // Create temporary directory for frame images
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory(
        '${tempDir.path}/frames_${DateTime.now().millisecondsSinceEpoch}',
      );
      await framesDir.create(recursive: true);

      // Calculate frame extraction rate
      // For 6-second video -> 30 frames = extract every 0.2 seconds
      final frameRate = targetFrameCount / 6.0; // frames per second to extract

      // FFmpeg command to extract frames
      final outputPattern = '${framesDir.path}/frame_%03d.png';
      final command = [
        '-i', videoPath,
        '-vf', 'fps=$frameRate,scale=$width:$height',
        '-y', // Overwrite output files
        outputPattern,
      ].join(' ');

      Log.debug(
        'FFmpeg command: ffmpeg $command',
        name: 'VideoFrameExtractor',
        category: LogCategory.video,
      );

      // FFmpeg is temporarily disabled due to macOS compatibility issues
      throw UnsupportedError(
        'FFmpeg frame extraction is currently disabled due to dependency conflicts. '
        'Use camera-based frame capture instead.',
      );
    } catch (e) {
      Log.error(
        'Video frame extraction failed: $e',
        name: 'VideoFrameExtractor',
        category: LogCategory.video,
      );
      rethrow;
    }
  }

  /// Get video information using FFprobe
  ///
  /// [videoPath] - Path to the video file
  ///
  /// Returns a map with video metadata
  static Future<Map<String, dynamic>> getVideoInfo(String videoPath) async {
    try {
      Log.debug(
        'Getting video info for: $videoPath',
        name: 'VideoFrameExtractor',
        category: LogCategory.video,
      );

      // FFprobe command to get video information in JSON format
      // Note: Command construction for future FFmpeg integration
      Log.debug(
        'Would execute FFprobe with: -v quiet -print_format json -show_format -show_streams $videoPath',
        name: 'VideoFrameExtractor',
        category: LogCategory.video,
      );

      // FFmpeg is temporarily disabled due to macOS compatibility issues
      throw UnsupportedError(
        'FFprobe video info extraction is currently disabled due to dependency conflicts.',
      );
    } catch (e) {
      Log.error(
        'Failed to get video info: $e',
        name: 'VideoFrameExtractor',
        category: LogCategory.video,
      );
      return {'success': false, 'error': e.toString()};
    }
  }
}
