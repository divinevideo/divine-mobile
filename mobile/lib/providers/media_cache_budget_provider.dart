// ABOUTME: Wires MediaCacheBudgetService to the app's video and image caches
// ABOUTME: and the device-storage channel, and labels the budget it applies.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';
import 'package:openvine/services/media_cache_budget_service.dart';
import 'package:openvine/services/media_cache_budget_telemetry.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:unified_logger/unified_logger.dart';

/// The largest budget each cache may get on this platform, which automatic
/// sizing never exceeds. Only Android's player keeps a disk cache of its own.
MediaCacheBudget appMediaCacheBudgetCeiling() => mediaCacheBudgetCeiling(
  imageBytes: openVineImageCache.mediaConfig.maxCacheSizeBytes ?? 0,
  hasPlayerCache: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// Keeps the video and image caches sized to the disk, and records coarse
/// labels of the result on analytics and crash keys: only the mode where
/// [diskSpaceMayLeaveDevice] is false.
final mediaCacheBudgetServiceProvider = Provider<MediaCacheBudgetService>((
  ref,
) {
  final setUserProperty = ref.watch(analyticsUserPropertySetterProvider);
  final crashReporting = ref.watch(crashReportingServiceProvider);
  return MediaCacheBudgetService(
    videoCache: openVineMediaCache,
    imageCache: openVineImageCache,
    prefs: ref.watch(sharedPreferencesProvider),
    readStorageSpace: const DeviceStorageService().storageSpace,
    ceiling: appMediaCacheBudgetCeiling(),
    onBudgetApplied: (storage, budget, {required automatic}) => runDetached(
      reportMediaCacheBudgetProperties(
        mediaCacheBudgetProperties(
          storage: storage,
          budget: budget,
          automatic: automatic,
          includeDiskDerived: diskSpaceMayLeaveDevice(),
        ),
        setUserProperty: setUserProperty,
        setCustomKey: crashReporting.setCustomKey,
      ),
      'record the media cache budget',
      logName: 'MediaCacheBudget',
      category: LogCategory.storage,
    ),
  );
});
