// ABOUTME: Applies the disk-aware media-cache budget to the video and image
// ABOUTME: caches, keeping a video-cache size the user fixed in Settings.

import 'dart:async';

import 'package:media_cache/media_cache.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Hears each budget a refresh applies, with the disk reading it came from
/// (null when the disk could not be read).
typedef MediaCacheBudgetListener = void Function(
  DeviceStorageSpace? storage,
  MediaCacheBudget budget, {
  required bool automatic,
});

/// Keeps the video and image caches sized to the disk they live on.
///
/// In automatic mode — the default, meaning the user never picked a size in
/// Settings → Storage — both caches follow [automaticMediaCacheBudget]. Once
/// the user picks a fixed video-cache size, the video cache keeps exactly
/// that and only the image cache keeps following the disk.
///
/// A budget that shrinks trims the cache straight away. One that grows only
/// raises the ceiling; the cache fills back up as videos are watched.
class MediaCacheBudgetService {
  /// Creates a service over the given caches.
  ///
  /// [ceiling] is the largest budget each cache may get: today's fixed
  /// sizes, with a zero player budget where the platform has no player cache.
  /// [onBudgetApplied] hears every budget applied, for telemetry.
  MediaCacheBudgetService({
    required MediaCacheManager videoCache,
    required MediaCacheManager imageCache,
    required SharedPreferences prefs,
    required Future<DeviceStorageSpace?> Function() readStorageSpace,
    required MediaCacheBudget ceiling,
    DateTime Function()? now,
    MediaCacheBudgetListener? onBudgetApplied,
  }) : _videoCache = videoCache,
       _imageCache = imageCache,
       _prefs = prefs,
       _readStorageSpace = readStorageSpace,
       _ceiling = ceiling,
       _now = now ?? DateTime.now,
       _onBudgetApplied = onBudgetApplied;

  /// How long a refresh stays current for [refreshIfStale].
  static const Duration staleAfter = Duration(minutes: 5);

  static const String _logName = 'MediaCacheBudgetService';

  final MediaCacheManager _videoCache;
  final MediaCacheManager _imageCache;
  final SharedPreferences _prefs;
  final Future<DeviceStorageSpace?> Function() _readStorageSpace;
  final MediaCacheBudget _ceiling;
  final DateTime Function() _now;
  final MediaCacheBudgetListener? _onBudgetApplied;

  Future<MediaCacheBudget>? _inFlight;
  DateTime? _lastRefreshedAt;
  MediaCacheBudget? _appliedBudget;

  /// Whether the video cache follows the disk rather than a size the user
  /// picked.
  bool get isAutomatic => !_prefs.containsKey(kCacheLimitPrefKey);

  /// The budget the last [refresh] applied, or null before the first.
  MediaCacheBudget? get appliedBudget => _appliedBudget;

  /// Re-reads the disk and applies the resulting budget. Overlapping calls
  /// share one reading.
  Future<MediaCacheBudget> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  /// [refresh]es unless the last one finished less than [staleAfter] ago.
  Future<void> refreshIfStale() async {
    final last = _lastRefreshedAt;
    if (last != null && _now().difference(last) < staleAfter) return;
    await refresh();
  }

  Future<MediaCacheBudget> _refresh() async {
    final storage = await _readStorageSpace();
    final automatic = storage == null
        ? _ceiling
        : automaticMediaCacheBudget(
            storage: storage,
            cacheUsageBytes:
                _videoCache.knownCacheBytes + _imageCache.knownCacheBytes,
            ceiling: _ceiling,
          );
    final budget = MediaCacheBudget(
      videoBytes: _prefs.getInt(kCacheLimitPrefKey) ?? automatic.videoBytes,
      imageBytes: automatic.imageBytes,
      playerBytes: automatic.playerBytes,
    );

    await Future.wait([
      _apply(_videoCache, budget.videoBytes),
      _apply(_imageCache, budget.imageBytes),
    ]);
    _appliedBudget = budget;
    _lastRefreshedAt = _now();
    // Logs reach crash reports, and iOS forbids sending disk space or
    // anything derived from it — the budget included — off the device.
    Log.info(
      'Media cache budget applied (automatic=$isAutomatic)',
      name: _logName,
      category: LogCategory.storage,
    );
    _onBudgetApplied?.call(storage, budget, automatic: isAutomatic);
    return budget;
  }

  Future<void> _apply(MediaCacheManager cache, int bytes) async {
    final previous = cache.maxCacheSizeBytes;
    cache.maxCacheSizeBytes = bytes;
    if (previous == null || bytes < previous) {
      await cache.enforceCacheLimits(force: true);
    }
  }
}
