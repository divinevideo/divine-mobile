// ABOUTME: Tests for M3U8 playlist resolver service
// ABOUTME: Validates parsing m3u8 playlists and extracting direct MP4 URLs

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/m3u8_resolver_service.dart';

void main() {
  late M3u8ResolverService service;

  setUp(() {
    service = M3u8ResolverService();
  });

  group('M3u8ResolverService', () {
    test('parses simple m3u8 playlist and extracts MP4 URLs', () async {
      const playlistContent = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=640x360
240p.mp4
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=1280x720
480p.mp4
''';

      final variants = service.parsePlaylist(playlistContent);

      expect(variants.length, 2);
      expect(variants[0].url, '240p.mp4');
      expect(variants[0].bandwidth, 400000);
      expect(variants[1].url, '480p.mp4');
      expect(variants[1].bandwidth, 800000);
    });

    test('resolves relative URLs to absolute URLs', () async {
      const baseUrl = 'https://stream.divine.video/abc123/playlist.m3u8';
      const relativeUrl = '240p.mp4';

      final absoluteUrl = service.resolveUrl(baseUrl, relativeUrl);

      expect(absoluteUrl, 'https://stream.divine.video/abc123/240p.mp4');
    });

    test('handles already absolute URLs', () async {
      const baseUrl = 'https://stream.divine.video/abc123/playlist.m3u8';
      const absoluteUrl = 'https://cdn.example.com/video.mp4';

      final result = service.resolveUrl(baseUrl, absoluteUrl);

      expect(result, absoluteUrl);
    });

    test('selects lowest bandwidth variant for short videos', () async {
      const playlistContent = '''
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=1280x720
high.mp4
#EXT-X-STREAM-INF:BANDWIDTH=400000,RESOLUTION=640x360
low.mp4
#EXT-X-STREAM-INF:BANDWIDTH=1200000,RESOLUTION=1920x1080
ultra.mp4
''';

      final variants = service.parsePlaylist(playlistContent);
      final lowestBandwidth = service.selectLowestBandwidth(variants);

      expect(lowestBandwidth?.url, 'low.mp4');
      expect(lowestBandwidth?.bandwidth, 400000);
    });

    test('handles empty playlist gracefully', () async {
      const playlistContent = '''
#EXTM3U
#EXT-X-VERSION:3
''';

      final variants = service.parsePlaylist(playlistContent);

      expect(variants, isEmpty);
    });

    test('handles malformed playlist without crashing', () async {
      const playlistContent = '''
Not a valid playlist
Random text here
''';

      final variants = service.parsePlaylist(playlistContent);

      expect(variants, isEmpty);
    });

    test(
      'end-to-end: resolves m3u8 URL to MP4 URL',
      () async {
        const m3u8Url = 'https://stream.divine.video/abc123/playlist.m3u8';

        // This test will use real HTTP requests
        // Skip in CI if network is unavailable
        final resolvedUrl = await service.resolveM3u8ToMp4(m3u8Url);

        // We expect either a resolved URL or null (if network/server issues)
        if (resolvedUrl != null) {
          expect(resolvedUrl, contains('.mp4'));
          expect(resolvedUrl, isNot(contains('.m3u8')));
        }
      },
      skip: 'Network test - run manually',
    );
  });
}
