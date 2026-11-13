// ABOUTME: Wires MediaCacheBudgetService to the app's video and image caches
// ABOUTME: and the device-storage channel.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';
import 'package:openvine/services/media_cache_budget_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';

/// Today's fixed cache sizes on this platform, which automatic sizing never
/// exceeds. Only Android's player keeps a disk cache of its own.
MediaCacheBudget appMediaCacheBudgetCeiling() => mediaCacheBudgetCeiling(
  imageBytes: openVineImageCache.mediaConfig.maxCacheSizeBytes ?? 0,
  hasPlayerCache: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// Keeps the video and image caches sized to the disk.
final mediaCacheBudgetServiceProvider = Provider<MediaCacheBudgetService>(
  (ref) => MediaCacheBudgetService(
    videoCache: openVineMediaCache,
    imageCache: openVineImageCache,
    prefs: ref.watch(sharedPreferencesProvider),
    readStorageSpace: const DeviceStorageService().storageSpace,
    ceiling: appMediaCacheBudgetCeiling(),
  ),
);
