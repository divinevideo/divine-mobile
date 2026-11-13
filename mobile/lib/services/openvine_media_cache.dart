// ABOUTME: Video file cache singleton using media_cache package
// ABOUTME: Replaces video_cache_manager.dart with cleaner abstraction

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'openvine_media_cache.g.dart';

/// OpenVine video file cache singleton using media_cache package.
///
/// Configured for video caching with:
/// - 30 day stale period
/// - 1000 max cached objects
/// - Sync manifest for instant cache lookups
///
/// This singleton is used directly in main() for early initialization,
/// and exposed via [mediaCacheProvider] for dependency injection in
/// Riverpod contexts.
///
/// Usage:
/// ```dart
/// // Direct access (in main.dart or non-Riverpod code)
/// await openVineMediaCache.initialize();
/// final cachedFile = openVineMediaCache.getCachedFileSync(videoId);
///
/// // Via provider (in widgets/providers - preferred for testability)
/// final cache = ref.read(mediaCacheProvider);
/// final cachedFile = cache.getCachedFileSync(videoId);
/// ```
// TODO(any): move declaration to provider or inject in packages in the future
final openVineMediaCache = MediaCacheManager(
  config: const MediaCacheConfig.video(cacheKey: kVideoCacheDirectoryName),
);

/// Provider exposing the media cache singleton for dependency injection.
///
/// Use this in Riverpod contexts for testability - can be overridden in tests.
/// The underlying singleton is initialized in main.dart before Riverpod.
@Riverpod(keepAlive: true)
MediaCacheManager mediaCache(Ref ref) => openVineMediaCache;

/// Initialize video file cache on app startup.
///
/// Loads the in-memory manifest for synchronous cache lookups and applies the
/// user's configured byte budget (if any). The startup sequence then sweeps
/// the cache and sizes it to the disk in the background, so neither blocks
/// startup (see `sweepThenBudgetMediaCaches`).
/// Call this in main.dart after WidgetsFlutterBinding.ensureInitialized().
/// Skipped on web where file-based caching is not available.
Future<void> initializeMediaCache() async {
  if (kIsWeb) return;
  await openVineMediaCache.initialize();
  final prefs = await SharedPreferences.getInstance();
  final storedLimit = prefs.getInt(kCacheLimitPrefKey);
  if (storedLimit != null) {
    openVineMediaCache.maxCacheSizeBytes = storedLimit;
  }
}
