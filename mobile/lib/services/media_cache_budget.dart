// ABOUTME: Sizes the media caches against how full the disk is, so Divine
// ABOUTME: keeps 15% of the device free while staying usable on a full one.

import 'dart:math' as math;

import 'package:divine_video_player/divine_video_player.dart'
    show kDefaultCacheMaxSizeBytes;
import 'package:equatable/equatable.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/services/device_storage_service.dart';

/// Byte budgets for the three caches that grow while someone watches.
class MediaCacheBudget extends Equatable {
  /// Creates a budget.
  const MediaCacheBudget({
    required this.videoBytes,
    required this.imageBytes,
    required this.playerBytes,
  });

  /// Downloaded feed videos.
  final int videoBytes;

  /// Thumbnails and avatars on disk.
  final int imageBytes;

  /// The Android player's streaming cache; zero where there is none.
  final int playerBytes;

  /// The three budgets together.
  int get totalBytes => videoBytes + imageBytes + playerBytes;

  @override
  List<Object?> get props => [videoBytes, imageBytes, playerBytes];
}

/// The smallest budget automatic sizing shrinks to: enough for the feed to
/// keep playing, 128 MB in total.
const MediaCacheBudget mediaCacheBudgetFloor = MediaCacheBudget(
  videoBytes: kVideoCacheFloorBytes,
  imageBytes: kImageCacheFloorBytes,
  playerBytes: kPlayerCacheFloorBytes,
);

/// The budget that keeps [kAutoCacheReservedDiskFraction] of the disk free.
///
/// [cacheUsageBytes] is what the caches already hold. It counts as space the
/// caches may keep, so a full cache on a disk with room does not shrink, and
/// a cache filled to the returned budget still leaves the reserve free.
///
/// Every cache sits between its floor ([mediaCacheBudgetFloor]) and its
/// [ceiling], at the same fraction of the way up. When the space above the
/// reserve is smaller than the floor, the floor wins so Divine keeps working.
MediaCacheBudget automaticMediaCacheBudget({
  required DeviceStorageSpace storage,
  required int cacheUsageBytes,
  required MediaCacheBudget ceiling,
}) {
  final floor = MediaCacheBudget(
    videoBytes: math.min(mediaCacheBudgetFloor.videoBytes, ceiling.videoBytes),
    imageBytes: math.min(mediaCacheBudgetFloor.imageBytes, ceiling.imageBytes),
    playerBytes: math.min(
      mediaCacheBudgetFloor.playerBytes,
      ceiling.playerBytes,
    ),
  );
  final growthRoom = ceiling.totalBytes - floor.totalBytes;
  if (growthRoom <= 0) return ceiling;

  final reserve = (storage.totalBytes * kAutoCacheReservedDiskFraction).ceil();
  final spendable = storage.freeBytes + cacheUsageBytes - reserve;
  final share = ((spendable - floor.totalBytes) / growthRoom).clamp(0.0, 1.0);

  int between(int low, int high) => low + ((high - low) * share).floor();
  return MediaCacheBudget(
    videoBytes: between(floor.videoBytes, ceiling.videoBytes),
    imageBytes: between(floor.imageBytes, ceiling.imageBytes),
    playerBytes: between(floor.playerBytes, ceiling.playerBytes),
  );
}

/// The largest budget each cache may get, which automatic sizing never
/// exceeds: [kCacheLimitDefaultBytes] for video, the image cache's configured
/// [imageBytes], and [kDefaultCacheMaxSizeBytes] for the player where
/// [hasPlayerCache] (zero elsewhere: only Android's player keeps a disk cache
/// of its own).
MediaCacheBudget mediaCacheBudgetCeiling({
  required int imageBytes,
  required bool hasPlayerCache,
}) => MediaCacheBudget(
  videoBytes: kCacheLimitDefaultBytes,
  imageBytes: imageBytes,
  playerBytes: hasPlayerCache ? kDefaultCacheMaxSizeBytes : 0,
);

/// The Android player-cache budget to configure at launch.
///
/// The player cache can only be sized when it is created, before the other
/// caches have been measured, so this counts their contents as zero. That
/// errs small: a launch on a filling disk gets a smaller player cache, never
/// a larger one. Returns the ceiling when the disk cannot be read, and zero
/// without reading it where the platform has no player cache.
Future<int> startupPlayerCacheBudgetBytes({
  required Future<DeviceStorageSpace?> Function() readStorageSpace,
  required MediaCacheBudget ceiling,
}) async {
  if (ceiling.playerBytes == 0) return 0;
  final storage = await readStorageSpace();
  if (storage == null) return ceiling.playerBytes;
  return automaticMediaCacheBudget(
    storage: storage,
    cacheUsageBytes: 0,
    ceiling: ceiling,
  ).playerBytes;
}
