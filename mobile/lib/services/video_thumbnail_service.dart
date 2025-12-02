// ABOUTME: Service for extracting thumbnails from video files
// ABOUTME: Generates preview frames for video posts to include in NIP-71 events

import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';

/// Service for extracting thumbnail images from video files
class VideoThumbnailService {
  static const int _thumbnailQuality = 75;
  static const int _maxWidth = 640;
  static const int _maxHeight = 640;

  /// Extract a thumbnail using FFmpeg (fallback method for all platforms)
  static Future<String?> _extractThumbnailWithFFmpeg({
    required String videoPath,
    required String destPath,
    int timeMs = 100,
  }) async {
    try {
      Log.debug(
        'Using FFmpeg to extract thumbnail',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Convert milliseconds to seconds for FFmpeg
      final timeSeconds = (timeMs / 1000).toStringAsFixed(3);

      // FFmpeg command to extract a single frame at specified timestamp
      // -ss: seek to position (faster before -i)
      // -i: input file
      // -vframes 1: extract 1 frame
      // -vf scale: resize maintaining aspect ratio
      // -q:v: quality (2-5 is good, lower = better)
      final command =
          '-ss $timeSeconds -i "$videoPath" -vframes 1 '
          '-vf "scale=$_maxWidth:$_maxHeight:force_original_aspect_ratio=decrease" '
          '-q:v 2 "$destPath"';

      Log.debug(
        'FFmpeg command: ffmpeg $command',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final file = File(destPath);
        if (file.existsSync()) {
          final size = await file.length();
          Log.info(
            'FFmpeg thumbnail generated: ${(size / 1024).toStringAsFixed(2)}KB',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
          return destPath;
        }
      }

      final output = await session.getOutput();
      Log.error(
        'FFmpeg failed: $output',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    } catch (e) {
      Log.error(
        'FFmpeg extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Extract a thumbnail from a video file at a specific timestamp
  ///
  /// [videoPath] - Path to the video file
  /// [timeMs] - Timestamp in milliseconds to extract thumbnail from (default: 100ms)
  /// [quality] - JPEG quality (1-100, default: 75)
  ///
  /// Returns the path to the generated thumbnail file
  static Future<String?> extractThumbnail({
    required String videoPath,
    int timeMs = 100, // Extract frame at 100ms by default
    int quality = _thumbnailQuality,
  }) async {
    try {
      Log.debug(
        'Extracting thumbnail from video: $videoPath',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      Log.debug(
        '⏱️ Timestamp: ${timeMs}ms, Quality: $quality%',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Verify video file exists
      final videoFile = File(videoPath);
      if (!videoFile.existsSync()) {
        Log.error(
          'Video file not found: $videoPath',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return null;
      }

      final destPath =
          '${(await getTemporaryDirectory()).path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Try fc_native_video_thumbnail first (faster, native performance)
      try {
        Log.debug(
          'Trying fc_native_video_thumbnail plugin',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );

        final plugin = FcNativeVideoThumbnail();
        final thumbnailGenerated = await plugin.getVideoThumbnail(
          srcFile: videoPath,
          destFile: destPath,
          width: _maxWidth,
          height: _maxHeight,
          format: 'jpeg',
          quality: quality,
        );

        if (thumbnailGenerated && File(destPath).existsSync()) {
          final thumbnailSize = await File(destPath).length();
          Log.info(
            'Thumbnail generated with fc_native_video_thumbnail:',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
          Log.debug(
            '  📸 Path: $destPath',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
          Log.debug(
            '  📦 Size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
          return destPath;
        }
      } catch (pluginError) {
        Log.warning(
          'fc_native_video_thumbnail failed, falling back to FFmpeg: $pluginError',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
      }

      // Fallback to FFmpeg (works on ALL platforms)
      Log.debug(
        'Falling back to FFmpeg for thumbnail extraction',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      final thumbnailPath = await _extractThumbnailWithFFmpeg(
        videoPath: videoPath,
        destPath: destPath,
        timeMs: timeMs,
      );

      if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
        final thumbnailSize = await File(thumbnailPath).length();
        Log.info(
          'Thumbnail generated successfully with FFmpeg:',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        Log.debug(
          '  📸 Path: $thumbnailPath',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        Log.debug(
          '  📦 Size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return thumbnailPath;
      }

      Log.error(
        'Both fc_native_video_thumbnail and FFmpeg failed to generate thumbnail',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    } catch (e, stackTrace) {
      Log.error(
        'Thumbnail extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      Log.verbose(
        '📱 Stack trace: $stackTrace',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Extract thumbnail as bytes (for direct upload without file)
  static Future<Uint8List?> extractThumbnailBytes({
    required String videoPath,
    int timeMs = 100,
    int quality = _thumbnailQuality,
  }) async {
    try {
      Log.debug(
        'Extracting thumbnail bytes from video: $videoPath',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );

      // Generate thumbnail file first
      final thumbnailPath = await extractThumbnail(
        videoPath: videoPath,
        timeMs: timeMs,
        quality: quality,
      );

      if (thumbnailPath == null) {
        Log.error(
          'Failed to generate thumbnail file',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
        return null;
      }

      // Read bytes from file
      final file = File(thumbnailPath);
      final uint8list = await file.readAsBytes();

      // Clean up temporary file
      await file.delete();

      Log.info(
        'Thumbnail bytes generated: ${(uint8list.length / 1024).toStringAsFixed(2)}KB',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return uint8list;
    } catch (e) {
      Log.error(
        'Thumbnail bytes extraction error: $e',
        name: 'VideoThumbnailService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Generate multiple thumbnails at different timestamps
  /// Useful for selecting the best frame
  static Future<List<String>> extractMultipleThumbnails({
    required String videoPath,
    List<int>? timestamps,
    int quality = _thumbnailQuality,
  }) async {
    // Default to extracting at 0ms, 500ms, and 1000ms
    final timesToExtract = timestamps ?? [0, 500, 1000];
    final thumbnails = <String>[];

    for (final timeMs in timesToExtract) {
      final thumbnail = await extractThumbnail(
        videoPath: videoPath,
        timeMs: timeMs,
        quality: quality,
      );

      if (thumbnail != null) {
        thumbnails.add(thumbnail);
      }
    }

    Log.debug(
      '📱 Generated ${thumbnails.length} thumbnails',
      name: 'VideoThumbnailService',
      category: LogCategory.video,
    );
    return thumbnails;
  }

  /// Clean up temporary thumbnail files
  static Future<void> cleanupThumbnails(List<String> thumbnailPaths) async {
    for (final path in thumbnailPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          await file.delete();
          Log.debug(
            '📱️ Deleted thumbnail: $path',
            name: 'VideoThumbnailService',
            category: LogCategory.video,
          );
        }
      } catch (e) {
        Log.error(
          'Failed to delete thumbnail: $e',
          name: 'VideoThumbnailService',
          category: LogCategory.video,
        );
      }
    }
  }

  /// Get optimal thumbnail timestamp based on video duration
  static int getOptimalTimestamp(Duration videoDuration) {
    // Extract thumbnail from 10% into the video
    // This usually avoids black frames at the start
    final tenPercent = (videoDuration.inMilliseconds * 0.1).round();

    // But ensure it's at least 100ms and not more than 1 second
    return tenPercent.clamp(100, 1000);
  }
}
