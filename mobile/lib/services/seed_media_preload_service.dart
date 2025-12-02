// ABOUTME: Service for preloading bundled seed media files into cache directory on first app launch
// ABOUTME: Copies MP4 videos and JPG thumbnails from assets directly to files for VideoCacheManager to discover

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class SeedMediaPreloadService {
  /// Load bundled seed media files into cache if not already loaded
  ///
  /// This is a one-time operation on first app launch.
  /// If cache already populated (marker file exists), this is a no-op.
  ///
  /// Files are written directly to the cache directory with eventId-based names
  /// so VideoCacheManager can discover and use them through its normal flow.
  static Future<void> loadSeedMediaIfNeeded() async {
    try {
      // Check if cache already populated
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(
        path.join(tempDir.path, 'openvine_video_cache'),
      );
      final markerFile = File(path.join(cacheDir.path, '.seed_media_loaded'));

      if (await markerFile.exists()) {
        Log.info(
          '[SEED] Cache already populated, skipping media preload',
          name: 'SeedMediaPreload',
          category: LogCategory.system,
        );
        return;
      }

      Log.info(
        '[SEED] Cache empty, loading bundled seed media...',
        name: 'SeedMediaPreload',
        category: LogCategory.system,
      );

      // Ensure cache directory exists
      await cacheDir.create(recursive: true);

      // Load manifest.json from assets
      final manifestJson = await rootBundle.loadString(
        'assets/seed_media/manifest.json',
      );
      final manifest = jsonDecode(manifestJson) as Map<String, dynamic>;

      int videoCount = 0;
      int thumbnailCount = 0;

      // Preload videos directly to cache directory
      final videos = manifest['videos'] as List<dynamic>;
      for (final video in videos) {
        final eventId = video['eventId'] as String;
        final filename = video['filename'] as String;

        try {
          // Load video bytes from assets
          final assetPath = 'assets/seed_media/videos/$filename';
          final videoBytes = await rootBundle.load(assetPath);

          // Write directly to cache directory using eventId as filename
          // This matches VideoCacheManager's expected file naming
          final videoFile = File(path.join(cacheDir.path, eventId));
          await videoFile.writeAsBytes(videoBytes.buffer.asUint8List());

          videoCount++;
          Log.debug(
            '[SEED] ✅ Cached video $eventId (${videoFile.lengthSync()} bytes)',
            name: 'SeedMediaPreload',
            category: LogCategory.system,
          );
        } catch (e) {
          Log.error(
            '[SEED] ⚠️ Failed to preload video $eventId: $e',
            name: 'SeedMediaPreload',
            category: LogCategory.system,
          );
          // Continue with other videos - non-critical
        }
      }

      // Preload thumbnails (optional)
      final thumbnails = manifest['thumbnails'] as List<dynamic>?;
      if (thumbnails != null) {
        for (final thumbnail in thumbnails) {
          final eventId = thumbnail['eventId'] as String;
          final filename = thumbnail['filename'] as String;

          try {
            // Load thumbnail bytes from assets
            final assetPath = 'assets/seed_media/thumbnails/$filename';
            final thumbnailBytes = await rootBundle.load(assetPath);

            // Write to cache directory with thumbnail-specific naming
            final thumbnailFile = File(
              path.join(cacheDir.path, 'thumbnail_$eventId.jpg'),
            );
            await thumbnailFile.writeAsBytes(
              thumbnailBytes.buffer.asUint8List(),
            );

            thumbnailCount++;
            Log.debug(
              '[SEED] ✅ Cached thumbnail $eventId (${thumbnailFile.lengthSync()} bytes)',
              name: 'SeedMediaPreload',
              category: LogCategory.system,
            );
          } catch (e) {
            Log.error(
              '[SEED] ⚠️ Failed to preload thumbnail $eventId: $e',
              name: 'SeedMediaPreload',
              category: LogCategory.system,
            );
            // Continue - thumbnails are optional
          }
        }
      }

      // Create marker file to indicate preload complete
      await markerFile.create(recursive: true);
      await markerFile.writeAsString(
        'loaded at ${DateTime.now().toIso8601String()}',
      );

      Log.info(
        '[SEED] ✅ Media preload completed: $videoCount videos, $thumbnailCount thumbnails',
        name: 'SeedMediaPreload',
        category: LogCategory.system,
      );
    } catch (e, stack) {
      // Non-critical failure: user will download videos from network normally
      Log.error(
        '[SEED] ❌ Failed to load seed media (non-critical): $e',
        name: 'SeedMediaPreload',
        category: LogCategory.system,
      );
      Log.verbose(
        '[SEED] Stack trace: $stack',
        name: 'SeedMediaPreload',
        category: LogCategory.system,
      );
    }
  }
}
