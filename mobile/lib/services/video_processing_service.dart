// ABOUTME: Background service for polling video processing completion from Blossom servers
// ABOUTME: Handles asynchronous video processing states and completion detection for Cloudflare Stream

import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result from video processing completion polling
class VideoProcessingResult {
  final bool success;
  final String? videoId;
  final String? cdnUrl;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final String? errorMessage;

  const VideoProcessingResult({
    required this.success,
    this.videoId,
    this.cdnUrl,
    this.hlsUrl,
    this.thumbnailUrl,
    this.errorMessage,
  });
}

/// Service for polling video processing completion on Blossom servers
class VideoProcessingService {
  final Dio dio;

  VideoProcessingService({Dio? dio}) : dio = dio ?? Dio();

  /// Poll the Blossom server until video processing is complete
  ///
  /// Returns [VideoProcessingResult] with completion status and metadata
  Future<VideoProcessingResult> pollForProcessingCompletion({
    required String serverUrl,
    required String fileHash,
    required String videoId,
    int maxAttempts = 20,
    Duration pollInterval = const Duration(seconds: 5),
    void Function(double)? onProgress,
  }) async {
    Log.info(
      '🔄 Starting video processing poll for $videoId',
      name: 'VideoProcessingService',
      category: LogCategory.video,
    );

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        Log.info(
          '📡 Poll attempt $attempt/$maxAttempts for $fileHash',
          name: 'VideoProcessingService',
          category: LogCategory.video,
        );

        // Report progress (90% to 99% during polling, 100% on completion)
        final progressValue = 0.9 + (attempt / maxAttempts) * 0.09;
        onProgress?.call(progressValue);

        final response = await dio.get(
          '$serverUrl/$fileHash',
          options: Options(
            validateStatus: (status) => status != null && status < 500,
          ),
        );

        if (response.statusCode == 200) {
          // Processing complete!
          final blobData = response.data;

          if (blobData is Map) {
            // final sha256 = blobData['sha256'] as String?; // TODO: Use if needed for integrity verification
            final mediaUrl = blobData['url'] as String?;
            final hlsUrl = blobData['hls'] as String?;
            final thumbnailUrl = blobData['thumbnail'] as String?;

            Log.info(
              '✅ Video processing complete: $mediaUrl',
              name: 'VideoProcessingService',
              category: LogCategory.video,
            );
            Log.info(
              '  HLS: $hlsUrl',
              name: 'VideoProcessingService',
              category: LogCategory.video,
            );
            Log.info(
              '  Thumbnail: $thumbnailUrl',
              name: 'VideoProcessingService',
              category: LogCategory.video,
            );

            onProgress?.call(1.0); // 100% complete

            return VideoProcessingResult(
              success: true,
              videoId: videoId,
              cdnUrl: mediaUrl,
              hlsUrl: hlsUrl,
              thumbnailUrl: thumbnailUrl,
            );
          } else {
            Log.error(
              '❌ Invalid blob descriptor format from Blossom server',
              name: 'VideoProcessingService',
              category: LogCategory.video,
            );
            return VideoProcessingResult(
              success: false,
              errorMessage: 'Invalid blob descriptor format from server',
            );
          }
        } else if (response.statusCode == 202) {
          // Still processing, continue polling
          Log.info(
            '⏳ Video still processing (HTTP 202), attempt $attempt/$maxAttempts',
            name: 'VideoProcessingService',
            category: LogCategory.video,
          );

          if (attempt < maxAttempts) {
            // Wait before next attempt with exponential backoff
            final delay = Duration(
              milliseconds:
                  pollInterval.inMilliseconds +
                  (Random().nextInt(1000)), // Add jitter
            );
            await Future.delayed(delay);
          }
        } else {
          Log.error(
            '❌ Unexpected response: ${response.statusCode} - ${response.data}',
            name: 'VideoProcessingService',
            category: LogCategory.video,
          );
          return VideoProcessingResult(
            success: false,
            errorMessage:
                'Processing failed: ${response.statusCode} - ${response.data}',
          );
        }
      } on DioException catch (e) {
        Log.error(
          '🌐 Network error during polling attempt $attempt: ${e.message}',
          name: 'VideoProcessingService',
          category: LogCategory.video,
        );

        if (attempt == maxAttempts) {
          return VideoProcessingResult(
            success: false,
            errorMessage:
                'Network error after $maxAttempts attempts: ${e.message}',
          );
        }

        // Wait before retry on network error
        await Future.delayed(pollInterval);
      } catch (e) {
        Log.error(
          '💥 Unexpected error during polling attempt $attempt: $e',
          name: 'VideoProcessingService',
          category: LogCategory.video,
        );
        return VideoProcessingResult(
          success: false,
          errorMessage: 'Unexpected error during processing: $e',
        );
      }
    }

    Log.error(
      '⏱️ Video processing timeout after $maxAttempts attempts',
      name: 'VideoProcessingService',
      category: LogCategory.video,
    );
    return VideoProcessingResult(
      success: false,
      errorMessage: 'Processing timeout after $maxAttempts attempts',
    );
  }
}
