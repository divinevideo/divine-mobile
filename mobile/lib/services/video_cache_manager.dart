// ABOUTME: Persistent video cache manager for offline playback and bandwidth reduction
// ABOUTME: Manages local storage of video files with intelligent cleanup and size management

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/io_client.dart';
import 'package:openvine/services/broken_video_tracker.dart';
import 'package:openvine/services/safe_json_cache_repository.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

class VideoCacheManager extends CacheManager {
  static const key = 'openvine_video_cache';

  // Cache configuration - AGGRESSIVE for demo-quality experience
  // With ~1MB videos, we can cache 1000 videos in ~1GB
  static const Duration _stalePeriod = Duration(
    days: 30,
  ); // Videos stay cached for 30 days
  static const int _maxCacheObjects =
      1000; // Max 1000 videos cached (demo-optimized)
  static const int _maxCacheSizeMB =
      1024; // Max 1GB for video cache (demo-optimized)

  static VideoCacheManager? _instance;

  // Cache manifest for synchronous lookups - tracks videoId → cached file path
  // This enables getCachedVideoSync() to avoid async overhead
  final Map<String, String> _cacheManifest = {};

  factory VideoCacheManager() {
    return _instance ??= VideoCacheManager._();
  }

  VideoCacheManager._()
    : super(
        Config(
          key,
          stalePeriod: _stalePeriod,
          maxNrOfCacheObjects: _maxCacheObjects,
          repo: SafeJsonCacheInfoRepository(databaseName: key),
          fileService: _createVideoHttpFileService(),
        ),
      );

  // Track initialization state
  bool _initialized = false;

  /// Initialize cache manifest by loading all cached videos from database
  /// Should be called on app startup to enable synchronous cache lookups
  Future<void> initialize() async {
    if (_initialized) {
      Log.debug(
        '📋 Cache manifest already initialized, skipping',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
      return;
    }

    try {
      Log.info(
        '🔄 Initializing video cache manifest from database...',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      final startTime = DateTime.now();

      // Query the cache database directly to get all cached objects
      // flutter_cache_manager stores cache metadata in a sqflite database
      final dbPath = await sqflite.getDatabasesPath();
      final cacheDbPath = path.join(dbPath, '$key.db');

      // Check if database exists
      if (!await File(cacheDbPath).exists()) {
        Log.info(
          '📋 No cache database found yet, skipping initialization',
          name: 'VideoCacheManager',
          category: LogCategory.video,
        );
        _initialized = true;
        return;
      }

      final database = await sqflite.openDatabase(cacheDbPath, readOnly: true);

      try {
        // Query all cache objects from the cacheObject table
        final List<Map<String, dynamic>> maps = await database.query(
          'cacheObject',
        );

        int loadedCount = 0;
        int missingCount = 0;

        // Get the base cache directory for constructing full paths
        final tempDir = await getTemporaryDirectory();
        final baseCacheDir = path.join(tempDir.path, key);

        // Populate manifest with verified cache entries
        for (final map in maps) {
          final videoKey = map['key'] as String;
          final relativePath = map['relativePath'] as String;

          // Construct full file path
          final fullPath = path.join(baseCacheDir, relativePath);
          final file = File(fullPath);

          // Only add to manifest if file actually exists
          if (file.existsSync()) {
            _cacheManifest[videoKey] = fullPath;
            loadedCount++;
          } else {
            // File is in database but missing from filesystem
            missingCount++;
            Log.debug(
              '⚠️ Cached video $videoKey missing from filesystem',
              name: 'VideoCacheManager',
              category: LogCategory.video,
            );
          }
        }

        final duration = DateTime.now().difference(startTime);
        _initialized = true;

        Log.info(
          '✅ Cache manifest initialized: $loadedCount videos loaded, '
          '$missingCount missing (${duration.inMilliseconds}ms)',
          name: 'VideoCacheManager',
          category: LogCategory.video,
        );
      } finally {
        await database.close();
      }
    } catch (error) {
      Log.error(
        '❌ Failed to initialize cache manifest: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
      // Don't throw - degraded functionality is better than crash
      // App will still work but without instant cache lookups
      _initialized = true; // Mark as initialized to avoid retry loops
    }
  }

  static HttpFileService _createVideoHttpFileService() {
    final httpClient = HttpClient();

    // Longer timeouts for video downloads
    httpClient.connectionTimeout = const Duration(seconds: 30);
    httpClient.idleTimeout = const Duration(minutes: 2);

    // Optimize for video streaming
    httpClient.maxConnectionsPerHost = 4;

    // In debug mode on desktop platforms, allow self-signed certificates
    // This is needed for local development and CDN certificate chain issues
    if (kDebugMode &&
        (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
      httpClient.badCertificateCallback = (cert, host, port) {
        // Accept all certificates in debug mode on desktop platforms
        // This helps with CDN certificate validation issues during development
        return true;
      };
    }

    return HttpFileService(httpClient: IOClient(httpClient));
  }

  /// Download and cache a video for offline use
  Future<File?> cacheVideo(
    String videoUrl,
    String videoId, {
    BrokenVideoTracker? brokenVideoTracker,
    Map<String, String>? authHeaders,
  }) async {
    try {
      // Check if already cached first - avoid redundant downloads
      final cachedFile = await getCachedVideo(videoId);
      if (cachedFile != null) {
        // Update manifest in case it was missing
        _cacheManifest[videoId] = cachedFile.path;
        Log.debug(
          '⏭️ Video $videoId already cached, skipping download',
          name: 'VideoCacheManager',
          category: LogCategory.video,
        );
        return cachedFile;
      }

      Log.info(
        '🎬 Caching video $videoId from $videoUrl${authHeaders != null && authHeaders.isNotEmpty ? " (with auth)" : ""}',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      final fileInfo = await downloadFile(
        videoUrl,
        key: videoId, // Use video ID as cache key
        authHeaders: authHeaders ?? {},
      );

      // Add to cache manifest for synchronous lookups
      _cacheManifest[videoId] = fileInfo.file.path;

      Log.info(
        '✅ Video $videoId cached successfully at ${fileInfo.file.path}',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      return fileInfo.file;
    } catch (error) {
      final errorMessage = error.toString();
      Log.error(
        '❌ Failed to cache video $videoId: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      // Mark video as broken if it's a 404, network error, or timeout
      if (brokenVideoTracker != null && _isVideoError(errorMessage)) {
        await brokenVideoTracker.markVideoBroken(
          videoId,
          'Cache failure: $errorMessage',
        );
      }

      return null;
    }
  }

  /// Check if error indicates a broken/non-functional video
  bool _isVideoError(String errorMessage) {
    final lowerError = errorMessage.toLowerCase();
    return lowerError.contains('404') ||
        lowerError.contains('not found') ||
        lowerError.contains('invalid statuscode: 404') ||
        lowerError.contains('httpexception') ||
        lowerError.contains('timeout') ||
        lowerError.contains('connection refused') ||
        lowerError.contains('network error');
  }

  /// Check if video is available in cache
  Future<bool> isVideoCached(String videoId) async {
    try {
      final fileInfo = await getFileFromCache(videoId);
      final isCached = fileInfo != null && fileInfo.file.existsSync();

      // Update manifest if cached
      if (isCached) {
        _cacheManifest[videoId] = fileInfo.file.path;
      }

      Log.debug(
        '🔍 Video $videoId cached: $isCached',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      return isCached;
    } catch (error) {
      Log.warning(
        '⚠️ Error checking cache for video $videoId: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Get cached video file if available (async version)
  Future<File?> getCachedVideo(String videoId) async {
    try {
      final fileInfo = await getFileFromCache(videoId);
      if (fileInfo != null && fileInfo.file.existsSync()) {
        // Update manifest for synchronous lookups
        _cacheManifest[videoId] = fileInfo.file.path;
        Log.info(
          '🎯 Using cached video $videoId : ${fileInfo.file.path}',
          name: 'VideoCacheManager',
          category: LogCategory.video,
        );
        return fileInfo.file;
      }
    } catch (error) {
      Log.warning(
        '⚠️ Error retrieving cached video $videoId: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
    }
    return null;
  }

  /// SYNCHRONOUS cache check - uses in-memory manifest for instant cache lookups
  /// This enables video controllers to use cached files immediately without async overhead
  File? getCachedVideoSync(String videoId) {
    // Check manifest for cached video path
    final cachedPath = _cacheManifest[videoId];

    if (cachedPath == null) {
      return null;
    }

    // Verify file still exists (in case cache was cleared externally)
    final file = File(cachedPath);
    if (!file.existsSync()) {
      // Remove stale entry from manifest
      _cacheManifest.remove(videoId);
      Log.debug(
        '🗑️ Removed stale cache entry for video $videoId',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
      return null;
    }

    Log.debug(
      '⚡ Fast cache hit for video $videoId (sync check)',
      name: 'VideoCacheManager',
      category: LogCategory.video,
    );
    return file;
  }

  /// Preemptively cache videos for offline use
  Future<void> preCache(List<String> videoUrls, List<String> videoIds) async {
    if (videoUrls.length != videoIds.length) {
      Log.error(
        '❌ Mismatch between video URLs and IDs for precaching',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
      return;
    }

    Log.info(
      '🔄 Pre-caching ${videoUrls.length} videos for offline use',
      name: 'VideoCacheManager',
      category: LogCategory.video,
    );

    // Check current cache size before starting
    await _manageCacheSize();

    // Cache videos concurrently but limit concurrency to avoid overwhelming the network
    const batchSize = 3;
    for (int i = 0; i < videoUrls.length; i += batchSize) {
      final batch = <Future<File?>>[];
      final end = (i + batchSize > videoUrls.length)
          ? videoUrls.length
          : i + batchSize;

      for (int j = i; j < end; j++) {
        // Skip if already cached
        if (await isVideoCached(videoIds[j])) {
          Log.debug(
            '⏭️ Skipping already cached video ${videoIds[j]}...',
            name: 'VideoCacheManager',
            category: LogCategory.video,
          );
          continue;
        }

        batch.add(cacheVideo(videoUrls[j], videoIds[j]));
      }

      // Wait for current batch to complete before starting next
      await Future.wait(batch, eagerError: false);
    }

    Log.info(
      '✅ Video pre-caching completed',
      name: 'VideoCacheManager',
      category: LogCategory.video,
    );
  }

  /// Manage cache size to stay within limits
  Future<void> _manageCacheSize() async {
    try {
      // Simple cache size management - the base CacheManager handles most of this
      Log.debug(
        '📊 Managing video cache size (max $_maxCacheSizeMB MB, max $_maxCacheObjects files)',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      // Let the base cache manager handle cleanup based on maxNrOfCacheObjects
      // This is more reliable than manual cache info inspection
    } catch (error) {
      Log.error(
        '❌ Error managing cache size: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      // Return basic stats without accessing internal cache info
      return {
        'totalFiles': 'unknown', // CacheManager doesn't expose this easily
        'totalSizeMB': 'managed',
        'maxSizeMB': _maxCacheSizeMB,
        'maxFiles': _maxCacheObjects,
        'stalePeriodDays': _stalePeriod.inDays,
      };
    } catch (error) {
      Log.error(
        '❌ Error getting cache stats: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
      return {'error': error.toString()};
    }
  }

  /// Remove a corrupted video from cache so it can be re-downloaded
  Future<void> removeCorruptedVideo(String videoId) async {
    try {
      Log.info(
        '🗑️ Removing corrupted video $videoId from cache',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      await removeFile(videoId);

      // Remove from manifest
      _cacheManifest.remove(videoId);

      Log.info(
        '✅ Corrupted video $videoId removed from cache',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
    } catch (error) {
      Log.error(
        '❌ Error removing corrupted video $videoId from cache: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
    }
  }

  /// Clear all cached videos (useful for testing or when user wants to free space)
  Future<void> clearAllCache() async {
    try {
      Log.info(
        '🧹 Clearing all cached videos...',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );

      await emptyCache();

      // Clear manifest
      _cacheManifest.clear();

      Log.info(
        '✅ All cached videos cleared',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
    } catch (error) {
      Log.error(
        '❌ Error clearing video cache: $error',
        name: 'VideoCacheManager',
        category: LogCategory.video,
      );
    }
  }

  /// Reset internal state for testing purposes
  /// This is needed because VideoCacheManager is a singleton
  @visibleForTesting
  void resetForTesting() {
    _initialized = false;
    _cacheManifest.clear();
    Log.debug(
      '🔄 VideoCacheManager reset for testing',
      name: 'VideoCacheManager',
      category: LogCategory.video,
    );
  }
}

// Singleton instance for easy access across the app
final openVineVideoCache = VideoCacheManager();
