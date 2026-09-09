// ABOUTME: Reusable video prefetch mixin for PageView-based video feeds
// ABOUTME: Warms the disk cache for videos around the current index.

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:media_cache/media_cache.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/extensions/video_event_extensions.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:unified_logger/unified_logger.dart';

/// Mixin that provides video prefetching logic for PageView-based feeds.
///
/// Warms the disk cache for videos before and after the current index so
/// playback starts instantly when the user scrolls.
///
/// Usage:
/// ```dart
/// class _MyFeedState extends State<MyFeed> with VideoPrefetchMixin {
///   @override
///   MediaCacheManager get videoCacheManager => openVineMediaCache;
///
///   PageView.builder(
///     onPageChanged: (index) {
///       checkForPrefetch(
///         currentIndex: index,
///         videos: myVideos,
///       );
///     },
///   );
/// }
/// ```
mixin VideoPrefetchMixin {
  DateTime? _lastPrefetchCall;

  /// Override this to provide the cache manager instance.
  /// Default uses the global singleton.
  MediaCacheManager get videoCacheManager => openVineMediaCache;

  /// Override this to customize throttle duration (useful for testing).
  int get prefetchThrottleSeconds => 2;

  /// Check if videos should be prefetched and trigger prefetch if appropriate.
  ///
  /// - [currentIndex]: Current video index in the feed
  /// - [videos]: Full list of videos in the feed
  void checkForPrefetch({
    required int currentIndex,
    required List<VideoEvent> videos,
  }) {
    // Skip if no videos.
    if (videos.isEmpty) {
      return;
    }

    // Skip prefetch on web platform - file caching not supported.
    if (kIsWeb) {
      return;
    }

    // Throttle prefetch calls to avoid excessive network activity.
    final now = clock.now();
    if (_lastPrefetchCall != null &&
        now.difference(_lastPrefetchCall!).inSeconds <
            prefetchThrottleSeconds) {
      Log.debug(
        'Prefetch: Skipping - too soon since last call (index=$currentIndex)',
        name: 'VideoPrefetchMixin',
        category: LogCategory.video,
      );
      return;
    }

    _lastPrefetchCall = now;

    // Calculate prefetch range using app constants.
    final startIndex = (currentIndex - AppConstants.preloadBefore).clamp(
      0,
      videos.length - 1,
    );
    final endIndex = (currentIndex + AppConstants.preloadAfter + 1).clamp(
      0,
      videos.length,
    );

    final prefetchItems = <({String url, String key})>[];
    for (int i = startIndex; i < endIndex; i++) {
      // Skip current video and videos without URLs.
      if (i == currentIndex || i < 0 || i >= videos.length) {
        continue;
      }
      final video = videos[i];
      if (video.videoUrl == null || video.videoUrl!.isEmpty) {
        continue;
      }
      // Only single-file assets are cacheable; HLS manifests are skipped.
      final cacheUrl = video.getCacheableVideoUrlForPlatform();
      if (cacheUrl == null) {
        continue;
      }
      prefetchItems.add((url: cacheUrl, key: video.id));
    }

    if (prefetchItems.isEmpty) {
      return;
    }

    Log.info(
      '🎬 Prefetching ${prefetchItems.length} videos around index '
      '$currentIndex (before=${AppConstants.preloadBefore}, '
      'after=${AppConstants.preloadAfter})',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );

    // Fire and forget - don't block on prefetch.
    try {
      videoCacheManager.preCacheFiles(prefetchItems).catchError((error) {
        Log.error(
          '❌ Error prefetching videos: $error',
          name: 'VideoPrefetchMixin',
          category: LogCategory.video,
        );
      });
    } catch (error) {
      Log.error(
        '❌ Error prefetching videos: $error',
        name: 'VideoPrefetchMixin',
        category: LogCategory.video,
      );
    }
  }

  /// Reset prefetch throttle (useful after feed refresh or context change).
  void resetPrefetch() {
    _lastPrefetchCall = null;
    Log.debug(
      'Prefetch: Reset throttle',
      name: 'VideoPrefetchMixin',
      category: LogCategory.video,
    );
  }
}
