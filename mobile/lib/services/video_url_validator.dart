// ABOUTME: Service for validating video URLs and filtering out problematic ones to improve loading performance
// ABOUTME: Tracks failed URLs and provides fallback strategies to avoid repeated loading failures

import 'package:openvine/utils/unified_logger.dart';

class VideoUrlValidator {
  static final VideoUrlValidator _instance = VideoUrlValidator._internal();
  factory VideoUrlValidator() => _instance;
  VideoUrlValidator._internal();

  // Track URLs that have consistently failed
  final Set<String> _blacklistedUrls = {};
  final Map<String, int> _failureCount = {};
  static const int maxFailures = 3;

  /// Check if a video URL is likely to work
  bool isUrlValid(String? url) {
    if (url == null || url.isEmpty) return false;

    // Check against known problematic patterns
    if (url.contains('cdn.divine.video')) {
      // Many cdn.divine.video URLs are returning 404
      Log.warning(
        '⚠️ Skipping potentially problematic cdn.divine.video URL: $url',
        name: 'VideoUrlValidator',
        category: LogCategory.video,
      );
      return false;
    }

    // Check if URL has been blacklisted due to repeated failures
    if (_blacklistedUrls.contains(url)) {
      Log.debug(
        '🚫 URL is blacklisted due to repeated failures: $url',
        name: 'VideoUrlValidator',
        category: LogCategory.video,
      );
      return false;
    }

    return true;
  }

  /// Report a URL failure to track problematic URLs
  void reportFailure(String url, String error) {
    final currentCount = _failureCount[url] ?? 0;
    _failureCount[url] = currentCount + 1;

    Log.warning(
      '❌ URL failure #${currentCount + 1} for $url: $error',
      name: 'VideoUrlValidator',
      category: LogCategory.video,
    );

    if (_failureCount[url]! >= maxFailures) {
      _blacklistedUrls.add(url);
      Log.warning(
        '🚫 Blacklisting URL after $maxFailures failures: $url',
        name: 'VideoUrlValidator',
        category: LogCategory.video,
      );
    }
  }

  /// Get stats about tracked URLs
  Map<String, dynamic> getStats() {
    return {
      'blacklistedUrls': _blacklistedUrls.length,
      'trackedFailures': _failureCount.length,
      'maxFailures': maxFailures,
    };
  }

  /// Clear blacklist (useful for testing or resetting state)
  void clearBlacklist() {
    Log.info(
      '🔄 Clearing URL blacklist (${_blacklistedUrls.length} URLs)',
      name: 'VideoUrlValidator',
      category: LogCategory.video,
    );
    _blacklistedUrls.clear();
    _failureCount.clear();
  }

  /// Get alternative video URL if original is problematic
  String? getAlternativeUrl(String originalUrl) {
    // Try to fix common URL issues
    if (originalUrl.contains('apt.openvine.co')) {
      final fixedUrl = originalUrl.replaceAll(
        'apt.openvine.co',
        'api.openvine.co',
      );
      Log.info(
        '🔧 Fixed apt.openvine.co URL: $fixedUrl',
        name: 'VideoUrlValidator',
        category: LogCategory.video,
      );
      return fixedUrl;
    }

    // For cdn.divine.video URLs, suggest api.openvine.co as fallback
    if (originalUrl.contains('cdn.divine.video')) {
      // Extract hash if available and construct api.openvine.co URL
      final hashMatch = RegExp(
        r'cdn\.divine\.video/([a-f0-9]+)',
      ).firstMatch(originalUrl);
      if (hashMatch != null) {
        final hash = hashMatch.group(1);
        final fallbackUrl = 'https://api.openvine.co/media/$hash';
        Log.info(
          '🔄 Suggesting api.openvine.co fallback for cdn.divine.video: $fallbackUrl',
          name: 'VideoUrlValidator',
          category: LogCategory.video,
        );
        return fallbackUrl;
      }
    }

    return null;
  }
}
