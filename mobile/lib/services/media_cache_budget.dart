// ABOUTME: Sizes the media caches against how full the disk is, so Divine
// ABOUTME: keeps 15% of the device free while staying usable on a full one.

import 'dart:math' as math;

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
/// reserve is smaller than the floor, the floor wins: Divine keeps working,
/// and what filled the disk was something else.
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
