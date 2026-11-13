// ABOUTME: Applies the disk-aware media-cache budget to the video and image
// ABOUTME: caches, keeping a video-cache size the user fixed in Settings.

import 'dart:async';
import 'dart:math' as math;

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
/// raises the ceiling; the cache fills back up as videos are watched. A
/// reading taken before both caches have been measured only ever grows them
/// (see [MediaCacheManager.hasMeasuredCacheBytes]).
class MediaCacheBudgetService {
  /// Creates a service over the given caches.
  ///
  /// [ceiling] is the largest budget each cache may get, with a zero player
  /// budget where the platform has no player cache.
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
  Future<MediaCacheBudget>? _followUp;
  DateTime? _lastRefreshedAt;

  /// Whether the video cache follows the disk rather than a size the user
  /// picked.
  bool get isAutomatic => !_prefs.containsKey(kCacheLimitPrefKey);

  /// Re-reads the disk and applies the resulting budget.
  ///
  /// A call made while a refresh is running gets a fresh one once that
  /// finishes, so it sees whatever the caller changed first, such as a fixed
  /// size it just removed. Calls made in that window share the follow-up.
  Future<MediaCacheBudget> refresh() {
    final running = _inFlight;
    if (running == null) return _start();
    return _followUp ??= _runAfter(running);
  }

  Future<MediaCacheBudget> _start() =>
      _inFlight = _refresh().whenComplete(() => _inFlight = null);

  Future<MediaCacheBudget> _runAfter(Future<MediaCacheBudget> running) async {
    try {
      await running;
    } on Object {
      // The running refresh's own caller hears its failure; this one still
      // re-reads the disk.
    }
    _followUp = null;
    // A refresh started since then began after this caller's change.
    return _inFlight ?? _start();
  }

  /// [refresh]es unless the last one finished less than [staleAfter] ago.
  Future<void> refreshIfStale() async {
    final last = _lastRefreshedAt;
    if (last != null && _now().difference(last) < staleAfter) return;
    await refresh();
  }

  Future<MediaCacheBudget> _refresh() async {
    final storage = await _readStorageSpace();
    final diskBudget = storage == null
        ? _ceiling
        : automaticMediaCacheBudget(
            storage: storage,
            cacheUsageBytes:
                _videoCache.knownCacheBytes + _imageCache.knownCacheBytes,
            ceiling: _ceiling,
          );
    // Read once, so the log and the listener label the budget with the mode
    // it was computed under even if the user switches during the trims.
    final fixedVideoBytes = _prefs.getInt(kCacheLimitPrefKey);
    final automatic = fixedVideoBytes == null;
    // Until both caches have been walked, their sizes cover only this
    // session's downloads, so the reading undercounts what they may keep.
    // Such a reading can grow the automatic budgets but never shrink them,
    // and it leaves the next refresh free to run.
    final provisional =
        storage != null &&
        !(_videoCache.hasMeasuredCacheBytes &&
            _imageCache.hasMeasuredCacheBytes);
    final budget = MediaCacheBudget(
      videoBytes:
          fixedVideoBytes ??
          _automaticBytes(
            _videoCache,
            diskBudget.videoBytes,
            ceiling: _ceiling.videoBytes,
            provisional: provisional,
          ),
      imageBytes: _automaticBytes(
        _imageCache,
        diskBudget.imageBytes,
        ceiling: _ceiling.imageBytes,
        provisional: provisional,
      ),
      playerBytes: diskBudget.playerBytes,
    );

    await Future.wait([
      _apply(_videoCache, budget.videoBytes),
      _apply(_imageCache, budget.imageBytes),
    ]);
    if (!provisional) _lastRefreshedAt = _now();
    // Logs travel with bug reports, and on iOS E174.1 forbids sending disk
    // space or anything derived from it — the budget included — off the
    // device.
    Log.info(
      'Media cache budget applied (automatic=$automatic)',
      name: _logName,
      category: LogCategory.storage,
    );
    _onBudgetApplied?.call(storage, budget, automatic: automatic);
    return budget;
  }

  int _automaticBytes(
    MediaCacheManager cache,
    int bytes, {
    required int ceiling,
    required bool provisional,
  }) {
    final current = cache.maxCacheSizeBytes;
    if (!provisional || current == null) return bytes;
    return math.min(math.max(bytes, current), ceiling);
  }

  Future<void> _apply(MediaCacheManager cache, int bytes) async {
    final previous = cache.maxCacheSizeBytes;
    cache.maxCacheSizeBytes = bytes;
    if (previous == null || bytes < previous) {
      await cache.enforceCacheLimits(force: true);
    }
  }
}
