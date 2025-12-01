// ABOUTME: Blurhash service for generating image placeholders and smooth loading transitions
// ABOUTME: Creates compact representations of images for better UX during vine loading

import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:blurhash_dart/blurhash_dart.dart' as blurhash_dart;
import 'package:image/image.dart' as img;
import 'package:openvine/utils/unified_logger.dart';

/// Service for generating and decoding Blurhash placeholders
class BlurhashService {
  static const int defaultComponentX = 4;
  static const int defaultComponentY = 3;
  static const double defaultPunch = 1;

  /// Generate blurhash from image bytes using blurhash_dart
  static Future<String?> generateBlurhash(
    Uint8List imageBytes, {
    int componentX = defaultComponentX,
    int componentY = defaultComponentY,
  }) async {
    try {
      // Decode image to get dimensions and pixel data
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        Log.error(
          'Failed to decode image for blurhash generation',
          name: 'BlurhashService',
          category: LogCategory.system,
        );
        return null;
      }

      // Encode blurhash using blurhash_dart library
      // The library's encode method takes an Image object and returns a BlurHash
      final blurhash = blurhash_dart.BlurHash.encode(
        image,
        numCompX: componentX,
        numCompY: componentY,
      );

      final hashString = blurhash.hash;

      Log.verbose(
        'Generated blurhash: $hashString (${image.width}x${image.height}, ${componentX}x$componentY components)',
        name: 'BlurhashService',
        category: LogCategory.system,
      );

      return hashString;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to generate blurhash: $e',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      Log.verbose(
        'Stack trace: $stackTrace',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Generate blurhash from image widget
  static Future<String?> generateBlurhashFromImage(
    ui.Image image, {
    int componentX = defaultComponentX,
    int componentY = defaultComponentY,
  }) async {
    try {
      // Convert image to bytes
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      return generateBlurhash(
        bytes,
        componentX: componentX,
        componentY: componentY,
      );
    } catch (e) {
      Log.error(
        'Failed to generate blurhash from image: $e',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Decode blurhash to create placeholder widget data
  static BlurhashData? decodeBlurhash(
    String blurhash, {
    int width = 32,
    int height = 32,
    double punch = defaultPunch,
  }) {
    try {
      if (!_isValidBlurhash(blurhash)) {
        return null;
      }

      // Use real blurhash_dart library to decode
      final blurHashObject = blurhash_dart.BlurHash.decode(blurhash);
      final image = blurHashObject.toImage(width, height);

      // Convert image to RGBA pixels
      final pixels = Uint8List.fromList(
        image.getBytes(order: img.ChannelOrder.rgba),
      );

      // Extract colors from the decoded pixel data
      final colors = _extractColorsFromPixels(pixels, width, height);
      final primaryColor = colors.isNotEmpty
          ? colors.first
          : const ui.Color(0xFF888888);

      return BlurhashData(
        blurhash: blurhash,
        width: width,
        height: height,
        colors: colors,
        primaryColor: primaryColor,
        timestamp: DateTime.now(),
        pixels: pixels, // Store the actual decoded pixels
      );
    } catch (e) {
      Log.error(
        'Failed to decode blurhash: $e',
        name: 'BlurhashService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Generate a default blurhash for vine content
  static String getDefaultVineBlurhash() {
    // Purple gradient for divine branding
    return 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';
  }

  /// Get common vine blurhashes for different content types
  static String getBlurhashForContentType(VineContentType contentType) {
    switch (contentType) {
      case VineContentType.comedy:
        return 'L8Q9Kx4n00M{~qD%_3t7D%WBRjof'; // Warm yellow/orange
      case VineContentType.dance:
        return 'L6PZfxjF4nWB_3t7t7R**0o#DgR4'; // Purple/pink
      case VineContentType.nature:
        return 'L8F5?xYk^6#M@-5c,1J5@[or[Q6.'; // Green tones
      case VineContentType.food:
        return 'L8RC8w4n00M{~qD%_3t7D%WBRjof'; // Warm brown/orange
      case VineContentType.music:
        return 'L4Pj0^jE.AyE_3t7t7R**0o#DgR4'; // Blue/purple
      case VineContentType.tech:
        return 'L2P?^~00~q00~qIU9FIU_3M{t7of'; // Cool blue/gray
      case VineContentType.art:
        return 'L8RC8w4n00M{~qD%_3t7D%WBRjof'; // Rich colors
      case VineContentType.sports:
        return 'L8F5?xYk^6#M@-5c,1J5@[or[Q6.'; // Dynamic green
      case VineContentType.lifestyle:
        return 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4'; // Soft purple
      case VineContentType.meme:
        return 'L8Q9Kx4n00M{~qD%_3t7D%WBRjof'; // Bright yellow
      case VineContentType.tutorial:
        return 'L2P?^~00~q00~qIU9FIU_3M{t7of'; // Professional blue
      case VineContentType.unknown:
        return getDefaultVineBlurhash();
    }
  }

  /// Validate blurhash format
  static bool _isValidBlurhash(String blurhash) {
    if (blurhash.length < 6) return false;

    // Basic validation - should start with 'L' and contain valid base83 characters
    if (!blurhash.startsWith('L')) return false;

    final validChars = RegExp(r'^[0-9A-Za-z#$%*+,-.:;=?@\[\]^_{|}~]+$');
    return validChars.hasMatch(blurhash);
  }

  /// Extract representative colors from decoded pixel data
  static List<ui.Color> _extractColorsFromPixels(
    Uint8List pixels,
    int width,
    int height,
  ) {
    final colors = <ui.Color>[];

    if (pixels.isEmpty) return colors;

    // Sample a few pixels to get representative colors
    final sampleCount = 4; // Sample 4 colors
    final totalPixels = width * height;
    final step = totalPixels ~/ sampleCount;

    for (var i = 0; i < sampleCount && i * step * 4 < pixels.length - 3; i++) {
      final pixelIndex = i * step * 4; // 4 bytes per pixel (RGBA)

      if (pixelIndex + 3 < pixels.length) {
        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];
        final a = pixels[pixelIndex + 3];

        colors.add(ui.Color.fromARGB(a, r, g, b));
      }
    }

    // If we didn't get enough colors, add the first pixel as fallback
    if (colors.isEmpty && pixels.length >= 4) {
      colors.add(ui.Color.fromARGB(pixels[3], pixels[0], pixels[1], pixels[2]));
    }

    return colors;
  }
}

/// Content types for vine classification
enum VineContentType {
  comedy,
  dance,
  nature,
  food,
  music,
  tech,
  art,
  sports,
  lifestyle,
  meme,
  tutorial,
  unknown,
}

/// Decoded blurhash data for UI rendering
class BlurhashData {
  const BlurhashData({
    required this.blurhash,
    required this.width,
    required this.height,
    required this.colors,
    required this.primaryColor,
    required this.timestamp,
    this.pixels,
  });
  final String blurhash;
  final int width;
  final int height;
  final List<ui.Color> colors;
  final ui.Color primaryColor;
  final DateTime timestamp;
  final Uint8List? pixels; // Store actual decoded pixel data

  /// Get a gradient for placeholder background
  ui.Gradient get gradient {
    if (colors.length < 2) {
      return ui.Gradient.linear(const ui.Offset(0, 0), const ui.Offset(1, 1), [
        primaryColor,
        primaryColor.withValues(alpha: 0.7),
      ]);
    }

    return ui.Gradient.linear(
      const ui.Offset(0, 0),
      const ui.Offset(1, 1),
      colors.take(2).toList(), // Use only first 2 colors for gradient
    );
  }

  /// Check if this blurhash data is still valid (not too old)
  bool get isValid {
    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < 30; // Expire after 30 minutes
  }

  @override
  String toString() =>
      'BlurhashData(hash: ${blurhash.substring(0, 8)}..., '
      'colors: ${colors.length}, primary: #${primaryColor.r.toInt().toRadixString(16).padLeft(2, '0')}${primaryColor.g.toInt().toRadixString(16).padLeft(2, '0')}${primaryColor.b.toInt().toRadixString(16).padLeft(2, '0')})';
}

/// Exception thrown by blurhash operations
class BlurhashException implements Exception {
  const BlurhashException(this.message);
  final String message;

  @override
  String toString() => 'BlurhashException: $message';
}

/// Blurhash cache for improved performance
class BlurhashCache {
  static const int maxCacheSize = 100;
  static const Duration cacheExpiry = Duration(hours: 1);

  final Map<String, BlurhashData> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  /// Store blurhash data in cache
  void put(String key, BlurhashData data) {
    // Clean old entries if cache is full
    if (_cache.length >= maxCacheSize) {
      _cleanOldEntries();
    }

    _cache[key] = data;
    _cacheTimestamps[key] = DateTime.now();
  }

  /// Get blurhash data from cache
  BlurhashData? get(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return null;

    // Check if entry is expired
    if (DateTime.now().difference(timestamp) > cacheExpiry) {
      remove(key);
      return null;
    }

    return _cache[key];
  }

  /// Remove entry from cache
  void remove(String key) {
    _cache.remove(key);
    _cacheTimestamps.remove(key);
  }

  /// Clear all cache entries
  void clear() {
    _cache.clear();
    _cacheTimestamps.clear();
  }

  /// Clean old cache entries
  void _cleanOldEntries() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > cacheExpiry) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      remove(key);
    }

    // If still too many entries, remove oldest ones
    if (_cache.length >= maxCacheSize) {
      final sortedEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final toRemoveCount = _cache.length - (maxCacheSize ~/ 2);
      for (var i = 0; i < toRemoveCount && i < sortedEntries.length; i++) {
        remove(sortedEntries[i].key);
      }
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() => {
    'size': _cache.length,
    'maxSize': maxCacheSize,
    'oldestEntry': _cacheTimestamps.values.isEmpty
        ? null
        : _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b),
    'newestEntry': _cacheTimestamps.values.isEmpty
        ? null
        : _cacheTimestamps.values.reduce((a, b) => a.isAfter(b) ? a : b),
  };
}
