// ABOUTME: Sizes Flutter's decoded-image cache by the device's physical RAM,
// ABOUTME: so its GPU cost stays a similar share of memory on every device.

import 'package:flutter/painting.dart';
import 'package:openvine/constants/app_constants.dart';

const int _bytesPerGib = 1 << 30;

/// Decoded-image cache budget for a device with [physicalMemoryBytes] of RAM.
///
/// RAM divided by [AppConstants.imageCacheRamDivisor], clamped to
/// [AppConstants.imageCacheMinBytes]–[AppConstants.imageCacheMaxBytes]:
/// 12 GB gets 256 MB, 8 GB 170 MB, 6 GB 128 MB and 4 GB or less 96 MB.
/// Unknown RAM gets [AppConstants.imageCacheFallbackBytes].
///
/// The OS reports a little less than the installed RAM (a 12 GB Galaxy S26
/// reports 11.4 GiB), so the reading is rounded up to whole GiB first.
int imageCacheBudgetBytes(int? physicalMemoryBytes) {
  if (physicalMemoryBytes == null || physicalMemoryBytes <= 0) {
    return AppConstants.imageCacheFallbackBytes;
  }
  final installedGib = (physicalMemoryBytes + _bytesPerGib - 1) ~/ _bytesPerGib;
  final budget =
      installedGib * _bytesPerGib ~/ AppConstants.imageCacheRamDivisor;
  return budget.clamp(
    AppConstants.imageCacheMinBytes,
    AppConstants.imageCacheMaxBytes,
  );
}

/// Sets [cache]'s byte budget from the RAM [readPhysicalMemoryBytes] reports.
///
/// Returns the budget it set.
Future<int> configureImageCacheBudget({
  required ImageCache cache,
  required Future<int?> Function() readPhysicalMemoryBytes,
}) async {
  final budget = imageCacheBudgetBytes(await readPhysicalMemoryBytes());
  cache.maximumSizeBytes = budget;
  return budget;
}
