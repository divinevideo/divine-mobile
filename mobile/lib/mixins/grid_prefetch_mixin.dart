// ABOUTME: Mixin that provides proactive video prefetching for grid views
// ABOUTME: Pre-caches video files based on grid position and bandwidth

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:unified_logger/unified_logger.dart';

/// Mixin for grid views to prefetch video files for faster playback.
///
/// Provides two methods:
/// - [prefetchGridVideos] prefetches visible grid items (first N videos)
/// - [prefetchAroundIndex] prefetches videos adjacent to a tapped index
///
/// Uses bandwidth-aware prefetching: only prefetches when the connection
/// quality is medium or high (skips on low/480p connections).
mixin GridPrefetchMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  static const _logName = 'GridPrefetch';

  /// Prefetch the first [AppConstants.gridPrefetchLimit] videos from a list.
  ///
  /// Call this when grid content loads or changes to warm the cache for
  /// the initially visible thumbnails/videos.
  void prefetchGridVideos(List<VideoEvent> videos) {
    if (!_shouldPrefetch) return;

    final limit = AppConstants.gridPrefetchLimit.clamp(0, videos.length);
    final items = <({String url, String key})>[];

    for (var i = 0; i < limit; i++) {
      final url = videos[i].videoUrl;
      if (url != null && url.isNotEmpty) {
        items.add((url: url, key: videos[i].id));
      }
    }

    if (items.isEmpty) return;

    Log.debug(
      'Prefetching ${items.length} grid videos',
      name: _logName,
      category: LogCategory.video,
    );

    openVineMediaCache.preCacheFiles(items);
  }

  /// Prefetch videos adjacent to the given [index].
  ///
  /// Uses [AppConstants.preloadBefore] and [AppConstants.preloadAfter]
  /// to determine the prefetch window around the tapped video. Skips
  /// the tapped video itself (the player will load it directly).
  void prefetchAroundIndex(int index, List<VideoEvent> videos) {
    if (!_shouldPrefetch) return;

    final start = (index - AppConstants.preloadBefore).clamp(0, videos.length);
    final end = (index + AppConstants.preloadAfter + 1).clamp(0, videos.length);

    final items = <({String url, String key})>[];

    for (var i = start; i < end; i++) {
      if (i == index) continue; // Skip current — player will load it
      final url = videos[i].videoUrl;
      if (url != null && url.isNotEmpty) {
        items.add((url: url, key: videos[i].id));
      }
    }

    if (items.isEmpty) return;

    Log.debug(
      'Prefetching ${items.length} adjacent videos around index $index',
      name: _logName,
      category: LogCategory.video,
    );

    openVineMediaCache.preCacheFiles(items);
  }

  bool get _shouldPrefetch =>
      !kIsWeb &&
      BandwidthTrackerService.instance.shouldUseHighQuality &&
      !InfiniteVideoFeed.isSupported;
}
