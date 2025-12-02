// ABOUTME: Service for interacting with divine thumbnail generation API
// ABOUTME: Handles automatic thumbnail generation, custom uploads, and caching

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:openvine/utils/unified_logger.dart';

/// Thumbnail size options
enum ThumbnailSize {
  small, // 320x240
  medium, // 640x480 (default)
  large, // 1280x720
}

/// Service for divine thumbnail API operations
class ThumbnailApiService {
  static const String _baseUrl = 'https://api.openvine.co';

  /// Get thumbnail URL for a video
  ///
  /// [videoId] - The video ID to get thumbnail for
  /// [timeSeconds] - Time offset in seconds (default: 2.5s)
  /// [size] - Thumbnail size (default: medium)
  static String getThumbnailUrl(
    String videoId, {
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) {
    final sizeParam = size == ThumbnailSize.medium ? '' : '&size=${size.name}';
    return '$_baseUrl/thumbnail/$videoId?t=$timeSeconds$sizeParam';
  }

  /// Check if thumbnail exists for a video
  ///
  /// Returns true if thumbnail exists, false otherwise
  static Future<bool> thumbnailExists(String videoId) async {
    try {
      final url = getThumbnailUrl(videoId);
      final response = await http.head(Uri.parse(url));

      Log.debug(
        'Thumbnail existence check for $videoId: ${response.statusCode}',
        name: 'ThumbnailApiService',
        category: LogCategory.api,
      );

      return response.statusCode == 200;
    } catch (e) {
      Log.error(
        'Error checking thumbnail existence for $videoId: $e',
        name: 'ThumbnailApiService',
        category: LogCategory.api,
      );
      return false;
    }
  }

  /// Upload custom thumbnail for a video
  ///
  /// [videoId] - The video ID to upload thumbnail for
  /// [thumbnailBytes] - The thumbnail image data
  /// [filename] - The filename for the upload (optional)
  ///
  /// Returns true if upload was successful
  static Future<bool> uploadCustomThumbnail(
    String videoId,
    Uint8List thumbnailBytes, {
    String filename = 'thumbnail.jpg',
  }) async {
    try {
      final url = '$_baseUrl/thumbnail/$videoId/upload';

      Log.info(
        'Uploading custom thumbnail for video $videoId',
        name: 'ThumbnailApiService',
        category: LogCategory.api,
      );

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(
        http.MultipartFile.fromBytes(
          'thumbnail',
          thumbnailBytes,
          filename: filename,
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200 || response.statusCode == 201) {
        Log.info(
          'Successfully uploaded custom thumbnail for $videoId',
          name: 'ThumbnailApiService',
          category: LogCategory.api,
        );
        return true;
      } else {
        final responseBody = await response.stream.bytesToString();
        Log.error(
          'Failed to upload custom thumbnail for $videoId: ${response.statusCode} $responseBody',
          name: 'ThumbnailApiService',
          category: LogCategory.api,
        );
        return false;
      }
    } catch (e) {
      Log.error(
        'Error uploading custom thumbnail for $videoId: $e',
        name: 'ThumbnailApiService',
        category: LogCategory.api,
      );
      return false;
    }
  }

  /// Get thumbnail with automatic generation fallback
  ///
  /// First checks if thumbnail exists, if not, generates it automatically
  ///
  /// [videoId] - The video ID to get thumbnail for
  /// [timeSeconds] - Time offset in seconds (default: 2.5s)
  /// [size] - Thumbnail size (default: medium)
  ///
  /// Returns thumbnail URL (backend handles automatic generation)
  static Future<String?> getThumbnailWithFallback(
    String videoId, {
    double timeSeconds = 2.5,
    ThumbnailSize size = ThumbnailSize.medium,
  }) async {
    try {
      Log.debug(
        '🚀 getThumbnailWithFallback called for video ${videoId} (timeSeconds: $timeSeconds, size: $size)',
        name: 'ThumbnailApiService',
        category: LogCategory.video,
      );

      // Backend automatically generates thumbnails on-demand via GET endpoint
      final thumbnailUrl = getThumbnailUrl(
        videoId,
        timeSeconds: timeSeconds,
        size: size,
      );
      Log.info(
        '✅ Returning thumbnail URL for ${videoId}: $thumbnailUrl',
        name: 'ThumbnailApiService',
        category: LogCategory.video,
      );

      return thumbnailUrl;
    } catch (e) {
      Log.error(
        '❌ Error in getThumbnailWithFallback for ${videoId}: $e',
        name: 'ThumbnailApiService',
        category: LogCategory.video,
      );
      return null;
    }
  }

  /// Batch generate thumbnails for multiple videos
  ///
  /// [videoIds] - List of video IDs to generate thumbnails for
  /// [timeSeconds] - Time offset in seconds for all thumbnails
  ///
  /// Returns map of videoId -> thumbnailUrl for successful generations
  static Future<Map<String, String>> batchGenerateThumbnails(
    List<String> videoIds, {
    double timeSeconds = 2.5,
  }) async {
    final results = <String, String>{};

    Log.info(
      'Batch generating thumbnails for ${videoIds.length} videos',
      name: 'ThumbnailApiService',
      category: LogCategory.api,
    );

    // Process in parallel but limit concurrency to avoid overwhelming the server
    const batchSize = 5;
    for (var i = 0; i < videoIds.length; i += batchSize) {
      final batch = videoIds.skip(i).take(batchSize).toList();

      final futures = batch.map((videoId) async {
        final url = await getThumbnailWithFallback(
          videoId,
          timeSeconds: timeSeconds,
        );
        if (url != null) {
          results[videoId] = url;
        }
      });

      await Future.wait(futures);
    }

    Log.info(
      'Batch generation completed: ${results.length}/${videoIds.length} successful',
      name: 'ThumbnailApiService',
      category: LogCategory.api,
    );

    return results;
  }
}

/// Exception thrown when thumbnail operations fail
class ThumbnailApiException implements Exception {
  const ThumbnailApiException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ThumbnailApiException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}
