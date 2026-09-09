// ABOUTME: Utility for detecting device memory and determining safe image resolutions
// ABOUTME: Used to prevent OOM crashes when rendering large images on low-memory devices

import 'dart:ui' show Size;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:unified_logger/unified_logger.dart';

/// Device memory tier for determining safe rendering resolutions
enum MemoryTier {
  /// Low memory devices (< 3GB RAM) - iPhones 6s/7/8, older Androids
  /// Max overlay resolution: 720p
  low,

  /// Medium memory devices (3-4GB RAM) - iPhone X/11, mid-range Androids
  /// Max overlay resolution: 1080p
  medium,

  /// High memory devices (> 4GB RAM) - iPhone 12+, flagship Androids
  /// Max overlay resolution: native video resolution
  high,
}

/// Utility for detecting device memory and determining safe resolutions
class DeviceMemoryUtil {
  DeviceMemoryUtil._();

  static MemoryTier? _cachedTier;
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Get the memory tier for the current device
  /// Results are cached for performance
  static Future<MemoryTier> getMemoryTier() async {
    if (_cachedTier != null) {
      return _cachedTier!;
    }

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        _cachedTier = await _getIOSMemoryTier();
      } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _cachedTier = await _getAndroidMemoryTier();
      } else {
        // Default to medium for other platforms
        _cachedTier = MemoryTier.medium;
      }
    } catch (e) {
      Log.warning(
        'Failed to detect memory tier, defaulting to medium: $e',
        name: 'DeviceMemoryUtil',
        category: LogCategory.system,
      );
      _cachedTier = MemoryTier.medium;
    }

    Log.info(
      'Device memory tier: ${_cachedTier!.name}',
      name: 'DeviceMemoryUtil',
      category: LogCategory.system,
    );

    return _cachedTier!;
  }

  /// Get memory tier for iOS devices based on device model
  static Future<MemoryTier> _getIOSMemoryTier() async {
    final iosInfo = await _deviceInfo.iosInfo;
    final model = iosInfo.utsname.machine;

    Log.debug(
      'iOS device model: $model',
      name: 'DeviceMemoryUtil',
      category: LogCategory.system,
    );

    // iPhone model identifiers and their RAM:
    // iPhone 6s/7/8: 2GB - low
    // iPhone X/XS/XR/11: 3-4GB - medium
    // iPhone 12/13/14/15/16: 4-6GB - high
    //
    // Format: iPhone[major],[minor]
    // e.g., iPhone14,2 = iPhone 13 Pro

    if (model.startsWith('iPhone')) {
      final versionPart = model.replaceFirst('iPhone', '');
      final parts = versionPart.split(',');
      if (parts.isNotEmpty) {
        final major = int.tryParse(parts[0]) ?? 0;

        // iPhone 14,x and later = iPhone 13+ (high memory, 4-6GB)
        if (major >= 14) {
          return MemoryTier.high;
        }
        // iPhone 11,x to 13,x = iPhone X to 12 (medium memory, 3-4GB)
        if (major >= 11) {
          return MemoryTier.medium;
        }
        // iPhone 10,x and earlier = iPhone 8 and earlier (low memory, 2-3GB)
        return MemoryTier.low;
      }
    }

    // iPad models generally have more RAM
    if (model.startsWith('iPad')) {
      return MemoryTier.high;
    }

    // Default to medium for unknown models
    return MemoryTier.medium;
  }

  /// Get memory tier for Android devices
  /// Note: Android doesn't expose total RAM via device_info_plus,
  /// so we use a heuristic based on SDK version and whether it's 64-bit
  static Future<MemoryTier> _getAndroidMemoryTier() async {
    final androidInfo = await _deviceInfo.androidInfo;

    Log.debug(
      'Android device: ${androidInfo.model}, SDK: ${androidInfo.version.sdkInt}, 64-bit: ${androidInfo.supported64BitAbis.isNotEmpty}',
      name: 'DeviceMemoryUtil',
      category: LogCategory.system,
    );

    // Modern 64-bit devices with Android 10+ typically have 4GB+ RAM
    if (androidInfo.version.sdkInt >= 29 &&
        androidInfo.supported64BitAbis.isNotEmpty) {
      return MemoryTier.high;
    }

    // 64-bit devices with Android 8+ typically have 3-4GB RAM
    if (androidInfo.version.sdkInt >= 26 &&
        androidInfo.supported64BitAbis.isNotEmpty) {
      return MemoryTier.medium;
    }

    // Older or 32-bit devices likely have less RAM
    return MemoryTier.low;
  }

  /// Get the maximum safe overlay resolution for the current device
  /// Returns a Size that should be used instead of native video resolution
  static Future<Size> getMaxOverlayResolution(Size videoSize) async {
    final tier = await getMemoryTier();

    switch (tier) {
      case MemoryTier.low:
        // Cap at 720p (1280x720 landscape, 720x1280 portrait)
        return _scaleToMax(videoSize, 1280, 720);

      case MemoryTier.medium:
        // Cap at 1080p (1920x1080 landscape, 1080x1920 portrait)
        return _scaleToMax(videoSize, 1920, 1080);

      case MemoryTier.high:
        // Use native resolution, but cap at 4K to be safe
        return _scaleToMax(videoSize, 3840, 2160);
    }
  }

  /// Scale a size to fit within max dimensions while preserving aspect ratio
  static Size _scaleToMax(Size size, double maxWidth, double maxHeight) {
    // Determine if portrait or landscape
    final isPortrait = size.height > size.width;

    // For portrait videos, swap max dimensions
    final effectiveMaxWidth = isPortrait ? maxHeight : maxWidth;
    final effectiveMaxHeight = isPortrait ? maxWidth : maxHeight;

    // Check if already within bounds
    if (size.width <= effectiveMaxWidth && size.height <= effectiveMaxHeight) {
      return size;
    }

    // Calculate scale factor to fit within bounds
    final scaleX = effectiveMaxWidth / size.width;
    final scaleY = effectiveMaxHeight / size.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    return Size(
      (size.width * scale).roundToDouble(),
      (size.height * scale).roundToDouble(),
    );
  }

  /// Check if the device is considered low memory
  static Future<bool> isLowMemoryDevice() async {
    final tier = await getMemoryTier();
    return tier == MemoryTier.low;
  }

  /// Reset cached tier (useful for testing)
  @visibleForTesting
  static void resetCache() {
    _cachedTier = null;
  }
}
