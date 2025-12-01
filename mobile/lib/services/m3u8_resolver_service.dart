// ABOUTME: Service for resolving m3u8 playlist URLs to direct MP4 URLs
// ABOUTME: Parses HLS playlists and extracts the best video variant for short-form content

import 'package:dio/dio.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Represents a video variant in an m3u8 playlist
class M3u8Variant {
  final String url;
  final int bandwidth;
  final String? resolution;

  const M3u8Variant({
    required this.url,
    required this.bandwidth,
    this.resolution,
  });
}

/// Service for resolving m3u8 playlists to direct MP4 URLs
class M3u8ResolverService {
  final Dio dio;

  M3u8ResolverService({Dio? dio}) : dio = dio ?? Dio();

  /// Parse m3u8 playlist content and extract video variants
  List<M3u8Variant> parsePlaylist(String content) {
    final variants = <M3u8Variant>[];
    final lines = content.split('\n');

    int? currentBandwidth;
    String? currentResolution;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Parse stream info line
      if (line.startsWith('#EXT-X-STREAM-INF:')) {
        final attributes = line.substring('#EXT-X-STREAM-INF:'.length);

        // Extract bandwidth
        final bandwidthMatch = RegExp(
          r'BANDWIDTH=(\d+)',
        ).firstMatch(attributes);
        if (bandwidthMatch != null) {
          currentBandwidth = int.tryParse(bandwidthMatch.group(1)!);
        }

        // Extract resolution (optional)
        final resolutionMatch = RegExp(
          r'RESOLUTION=([^\s,]+)',
        ).firstMatch(attributes);
        if (resolutionMatch != null) {
          currentResolution = resolutionMatch.group(1);
        }

        // Next line should be the URL
        if (i + 1 < lines.length && currentBandwidth != null) {
          final urlLine = lines[i + 1].trim();
          if (urlLine.isNotEmpty && !urlLine.startsWith('#')) {
            variants.add(
              M3u8Variant(
                url: urlLine,
                bandwidth: currentBandwidth,
                resolution: currentResolution,
              ),
            );

            // Reset for next variant
            currentBandwidth = null;
            currentResolution = null;
          }
        }
      }
    }

    return variants;
  }

  /// Resolve relative URL to absolute URL based on base m3u8 URL
  String resolveUrl(String baseUrl, String relativeUrl) {
    // If already absolute, return as-is
    if (relativeUrl.startsWith('http://') ||
        relativeUrl.startsWith('https://')) {
      return relativeUrl;
    }

    // Parse base URL to get directory
    final uri = Uri.parse(baseUrl);
    final pathSegments = uri.pathSegments.toList();

    // Remove the playlist filename (last segment)
    if (pathSegments.isNotEmpty) {
      pathSegments.removeLast();
    }

    // Add the relative URL
    pathSegments.add(relativeUrl);

    // Reconstruct the URL
    final resolvedUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      pathSegments: pathSegments,
    );

    return resolvedUri.toString();
  }

  /// Select the variant with the lowest bandwidth (best for short videos)
  M3u8Variant? selectLowestBandwidth(List<M3u8Variant> variants) {
    if (variants.isEmpty) return null;

    return variants.reduce((a, b) => a.bandwidth < b.bandwidth ? a : b);
  }

  /// Resolve m3u8 URL to direct MP4 URL
  ///
  /// Fetches the playlist, parses it, and returns the lowest bandwidth variant
  /// Returns null if resolution fails
  Future<String?> resolveM3u8ToMp4(String m3u8Url) async {
    try {
      Log.info(
        '🔍 Resolving m3u8 URL to MP4: $m3u8Url',
        name: 'M3u8ResolverService',
        category: LogCategory.video,
      );

      // Fetch the playlist
      final response = await dio.get(m3u8Url);

      if (response.statusCode != 200) {
        Log.error(
          '❌ Failed to fetch m3u8 playlist: ${response.statusCode}',
          name: 'M3u8ResolverService',
          category: LogCategory.video,
        );
        return null;
      }

      final playlistContent = response.data as String;

      // Parse variants
      final variants = parsePlaylist(playlistContent);

      if (variants.isEmpty) {
        Log.warning(
          '⚠️ No variants found in m3u8 playlist',
          name: 'M3u8ResolverService',
          category: LogCategory.video,
        );
        return null;
      }

      Log.info(
        '📋 Found ${variants.length} variants in playlist',
        name: 'M3u8ResolverService',
        category: LogCategory.video,
      );

      // Select lowest bandwidth for short videos
      final selectedVariant = selectLowestBandwidth(variants);

      if (selectedVariant == null) {
        return null;
      }

      // Resolve to absolute URL
      final resolvedUrl = resolveUrl(m3u8Url, selectedVariant.url);

      Log.info(
        '✅ Resolved m3u8 to MP4: $resolvedUrl (bandwidth: ${selectedVariant.bandwidth})',
        name: 'M3u8ResolverService',
        category: LogCategory.video,
      );

      return resolvedUrl;
    } on DioException catch (e) {
      Log.error(
        '🌐 Network error resolving m3u8: ${e.message}',
        name: 'M3u8ResolverService',
        category: LogCategory.video,
      );
      return null;
    } catch (e) {
      Log.error(
        '💥 Unexpected error resolving m3u8: $e',
        name: 'M3u8ResolverService',
        category: LogCategory.video,
      );
      return null;
    }
  }
}
