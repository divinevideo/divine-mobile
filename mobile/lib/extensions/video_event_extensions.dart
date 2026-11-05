// ABOUTME: Extension methods for VideoEvent that have app-specific dependencies.
// ABOUTME: These methods require services (M3u8ResolverService) or platform
// ABOUTME: detection (dart:io) that don't belong in the pure data model.

import 'package:flutter/foundation.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:models/models.dart';
import 'package:openvine/services/bandwidth_tracker_service.dart';
import 'package:openvine/services/m3u8_resolver_service.dart';
import 'package:openvine/services/video_format_preference.dart';
import 'package:unified_logger/unified_logger.dart';

/// Extension methods for VideoEvent that require app-level dependencies.
///
/// These methods are separated from the core VideoEvent model because they
/// depend on:
/// - Platform detection (dart:io)
/// - App services (M3u8ResolverService)
///
/// The core VideoEvent model in the models package remains pure and testable.
extension VideoEventAppExtensions on VideoEvent {
  // ---------------------------------------------------------------------------
  // Platform Detection
  // ---------------------------------------------------------------------------

  /// Check if video format is supported on current platform.
  ///
  /// WebM is not supported on iOS/macOS (AVPlayer limitation).
  /// All other formats (MP4, MOV, M4V, HLS) work on all platforms.
  bool get isSupportedOnCurrentPlatform {
    // WebM only works on Android and Web, not iOS/macOS
    if (isWebM) {
      if (kIsWeb) return true;
      return defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS;
    }
    // All other formats work on all platforms
    return true;
  }

  // ---------------------------------------------------------------------------
  // Divine Server Detection
  // ---------------------------------------------------------------------------

  /// Check if video is hosted on Divine servers.
  ///
  /// Matches any *.divine.video subdomain including:
  /// - cdn.divine.video (R2 blob storage)
  /// - stream.divine.video (BunnyStream HLS)
  /// - media.divine.video (default Blossom server)
  /// - blossom.divine.video (Blossom protocol server)
  bool get isFromDivineServer {
    final url = videoUrl;
    if (url == null || url.isEmpty) return false;

    try {
      final host = Uri.parse(url).host.toLowerCase();
      return host == 'divine.video' || host.endsWith('.divine.video');
    } catch (_) {
      return false;
    }
  }

  /// Check if we should show the "Not Divine" badge.
  ///
  /// Shows badge for content that is:
  /// - NOT from Divine servers
  /// - AND does NOT have ProofMode verification (those show ProofMode badge)
  /// - AND is NOT an archive Vine funnelcake verifies (a self-applied
  ///   `platform=vine` tag does not count)
  bool get shouldShowNotDivineBadge {
    return !isFromDivineServer && !hasProofMode && !isVerifiedArchive;
  }

  // ---------------------------------------------------------------------------
  // Platform-Aware URL Selection
  // ---------------------------------------------------------------------------

  /// Divine media server base URL for HLS streaming.
  static const String _divineMediaBase = 'https://media.divine.video';

  /// Extract video hash from a Divine server URL.
  ///
  /// Handles URLs like:
  /// - https://media.divine.video/{hash}
  /// - https://cdn.divine.video/{hash}
  /// - https://media.divine.video/{hash}/hls/master.m3u8
  static String? _extractVideoHash(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      // Only extract from Divine servers
      if (!host.contains('divine.video')) return null;

      // Path segments: ['', 'hash'] or ['', 'hash', 'hls', 'master.m3u8']
      final segments = uri.pathSegments;
      if (segments.isEmpty) return null;

      // First segment should be the hash (64 hex characters)
      final hash = segments.first;
      if (hash.length == 64 && RegExp(r'^[a-fA-F0-9]+$').hasMatch(hash)) {
        return hash;
      }
    } catch (_) {
      // Invalid URL, return null
    }
    return null;
  }

  /// Get HLS streaming URL for Divine videos.
  ///
  /// All Divine videos are automatically transcoded to HLS format with
  /// adaptive bitrate (720p/480p). This URL provides:
  /// - Android compatibility via H.264 baseline profile
  /// - iOS/macOS native AVPlayer support
  /// - Automatic quality switching based on connection speed
  ///
  /// Returns null if:
  /// - Video is not from Divine servers
  /// - Hash cannot be extracted from URL
  String? get hlsUrl => getHlsUrl();

  /// Whether the current format selection uses HLS delivery.
  ///
  /// True when a developer override selects an HLS format. Production default
  /// (MP4) returns false. Used by [getCacheableVideoUrlForPlatform] to skip
  /// disk caching for HLS (which can't be single-file cached).
  bool get shouldPreferHlsPlayback =>
      isFromDivineServer && videoFormatPreference.isHlsFormat;

  /// Whether background file caching should be skipped for this video.
  ///
  /// Classic Vine originals already dominate the cache through feed prefetching;
  /// skip this single-file cache path so inline/background callers do not widen
  /// storage use further.
  bool get shouldSkipFileCaching => isOriginalVine;

  /// Get HLS URL with optional quality override.
  ///
  /// [quality] - null for master playlist (ABR), 'high' for 720p, 'low' for 480p
  String? getHlsUrl({String? quality}) {
    final hash = _extractVideoHash(videoUrl);
    if (hash == null) return null;

    // Quality-specific streams vs adaptive master playlist
    switch (quality) {
      case 'high':
        return '$_divineMediaBase/$hash/hls/stream_720p.m3u8';
      case 'low':
        return '$_divineMediaBase/$hash/hls/stream_480p.m3u8';
      default:
        return '$_divineMediaBase/$hash/hls/master.m3u8';
    }
  }

  /// Get the optimal video URL for initial playback.
  ///
  /// **Strategy** (first match wins):
  /// - A developer format override (Developer Options) forces that server
  ///   format on any Divine video for A/B testing, ahead of every heuristic
  ///   below.
  /// - All Divine videos default to progressive MP4 720p (faststart,
  ///   moov at front) for fastest startup with short videos (1 request, no
  ///   manifest overhead) — it is 3-8x smaller than the raw blob. This covers
  ///   raw-only uploads too: their `imeta` lists only the raw blob because it
  ///   is a publish-time snapshot taken before the derivatives transcode, but
  ///   by playback time the 720p.mp4 almost always exists. The playback ladder
  ///   falls back through HLS to the bare blob while renditions catch up.
  ///
  /// Non-Divine videos always use original (no transcoded variants exist).
  String? getOptimalVideoUrlForPlatform() {
    // Non-Divine videos: always use original (no transcoded variants)
    if (!isFromDivineServer) return videoUrl;

    final hash = _extractVideoHash(videoUrl);
    if (hash == null) return videoUrl;

    // Developer format override takes priority over every heuristic below so
    // A/B testing can force a specific server format on any Divine video,
    // including classic Vine originals and raw-only uploads. If a forced
    // derivative does not exist yet the runtime fallback chain recovers, and
    // seeing that is the point of the test switch.
    final override = videoFormatPreference.format;
    if (override != null) {
      return switch (override) {
            VideoPlaybackFormat.hlsDefault => _hlsForBandwidth(),
            VideoPlaybackFormat.raw => videoUrl,
            VideoPlaybackFormat.hlsMaster => getHlsUrl(),
            VideoPlaybackFormat.hls720p => getHlsUrl(quality: 'high'),
            VideoPlaybackFormat.hls480p => getHlsUrl(quality: 'low'),
            VideoPlaybackFormat.ts720p => '$_divineMediaBase/$hash/720p',
            VideoPlaybackFormat.ts480p => '$_divineMediaBase/$hash/480p',
            VideoPlaybackFormat.mp4_720p => '$_divineMediaBase/$hash/720p.mp4',
            VideoPlaybackFormat.mp4_480p => '$_divineMediaBase/$hash/480p.mp4',
          } ??
          videoUrl;
    }

    // Production default: progressive MP4 720p (faststart). Fastest startup
    // (1 request, moov at front), correct colors on all platforms, and 3-8x
    // smaller than the raw blob. Raw-only uploads take this path too, with the
    // bare blob retained as the final playback fallback.
    //
    // Classic Vine originals take this path as well. The transcoder caps at
    // the source resolution, so the "720p" variant of a 480x480 Vine is still
    // 480x480 — smaller than the raw blob, not an upscale.
    return '$_divineMediaBase/$hash/720p.mp4';
  }

  /// URL for the inline comment / collaborator-invite player, which assigns the
  /// URL straight to a `<video>` element (see `web_video_player_backend_web`).
  /// Older desktop Chrome (< 150) and Firefox lack native HLS, so an HLS
  /// `.m3u8` won't play there. Resolve HLS to the progressive variant — the
  /// same [getOptimalVideoUrlForPlatform] selection the feed already uses on
  /// every platform. Resolve bare Divine blobs too so previews prefer the
  /// smaller progressive derivative. Progressive URLs pass through unchanged,
  /// so the common case and its transcode readiness are never touched.
  String? get inlinePlayerVideoUrl {
    final url = videoUrl;
    if (url == null) return null;
    final isHls = url.toLowerCase().contains('.m3u8');
    final uri = Uri.tryParse(url);
    final pathSegments = uri?.pathSegments ?? const <String>[];
    final lastSegment = pathSegments.isEmpty ? '' : pathSegments.last;
    final isExtensionlessDivineBlob =
        isFromDivineServer &&
        _extractVideoHash(url) != null &&
        !lastSegment.contains('.');
    if (isHls || isExtensionlessDivineBlob) {
      return getOptimalVideoUrlForPlatform() ?? url;
    }
    return url;
  }

  /// Ordered network sources to attempt in a preview player, best rendition
  /// first.
  ///
  /// This is the feed's ladder, not a second one: [resolvePlaybackSources]
  /// expands the platform pick into its canonical alternatives and keeps the
  /// bare Divine blob last. Hand the result to [setSourceWithFallbacks] — the
  /// HLS entry is a master playlist the native player takes directly.
  List<String> get previewPlaybackSources => resolvePlaybackSources(
    this,
    urlResolver: (video) => video.getOptimalVideoUrlForPlatform(),
  );

  /// HLS URL selected by bandwidth tracker quality.
  String? _hlsForBandwidth() {
    final hlsQuality = switch (bandwidthTracker.recommendedQuality) {
      VideoQuality.high || VideoQuality.medium => 'high',
      VideoQuality.low => 'low',
    };
    return getHlsUrl(quality: hlsQuality);
  }

  /// Get the URL to use for disk caching, if any.
  ///
  /// Returns null for Divine HLS videos (can't be single-file cached).
  /// Progressive formats (ts, mp4, raw) can be cached.
  String? getCacheableVideoUrlForPlatform() {
    if (shouldSkipFileCaching) return null;
    // HLS can't be single-file cached; progressive formats can
    if (isFromDivineServer && videoFormatPreference.isHlsFormat) return null;
    return getOptimalVideoUrlForPlatform() ?? videoUrl;
  }

  // ---------------------------------------------------------------------------
  // URL Resolution (m3u8 to MP4)
  // ---------------------------------------------------------------------------

  /// Get the best playable URL for this video.
  ///
  /// This is an async convenience method that resolves m3u8 URLs to MP4.
  /// Use this when preparing to play a video.
  Future<String?> getPlayableUrl() async {
    return resolvePlayableUrl(videoUrl);
  }

  /// Resolve a video URL to its best playable format.
  ///
  /// For m3u8 (HLS) URLs, attempts to extract the underlying MP4 URL.
  /// For other URLs, returns as-is.
  ///
  /// This is useful because:
  /// - MP4 is more efficient for short videos (6 seconds)
  /// - MP4 loads faster (single file vs manifest + segments)
  /// - Some players handle MP4 better than HLS for short content
  static Future<String?> resolvePlayableUrl(String? videoUrl) async {
    if (videoUrl == null || videoUrl.isEmpty) {
      return null;
    }

    // Check if this is an m3u8 URL
    final urlLower = videoUrl.toLowerCase();
    if (!urlLower.contains('.m3u8') && !urlLower.contains('/hls/')) {
      // Not an m3u8 URL, return as-is
      return videoUrl;
    }

    Log.debug(
      '🎬 Attempting to resolve m3u8 URL to MP4: $videoUrl',
      name: 'VideoEventExtensions',
      category: LogCategory.video,
    );

    // Try to resolve to MP4
    final resolver = M3u8ResolverService();
    final resolvedUrl = await resolver.resolveM3u8ToMp4(videoUrl);

    if (resolvedUrl != null) {
      Log.debug(
        '✅ Resolved m3u8 to MP4: $resolvedUrl',
        name: 'VideoEventExtensions',
        category: LogCategory.video,
      );
      return resolvedUrl;
    } else {
      Log.warning(
        '⚠️ Failed to resolve m3u8, using original URL: $videoUrl',
        name: 'VideoEventExtensions',
        category: LogCategory.video,
      );
      return videoUrl; // Fallback to original if resolution fails
    }
  }
}
