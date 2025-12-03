// ABOUTME: Test multiple imeta tag parsing and URL selection following Postel's Law
// ABOUTME: Ensures best video URL is selected from events with multiple imeta tags

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('VideoEvent Multiple Imeta Parsing (Postel\'s Law)', () {
    test('selects best URL from multiple imeta tags with broken and working URLs', () {
      // Real-world example: Event with two imeta tags
      // First has working MP4 and HLS, second has broken manifest URL
      final event = Event.fromJson({
        'id':
            '8bd52c7beac0e08691178089750de8cba8666b7ca1b40267bd8d17546f00064a',
        'pubkey':
            'f877b0f7850c752d0aabd3083f1b2db3177334efd087302bc2116d988759d919',
        'created_at': 1760376721,
        'kind': 34236,
        'content': '161015 bundang fansign ✧ YOONGI FOCUS',
        'sig':
            'fa9390f525b7be8f18c2f7e1f9cf2e179b7b8756714089423969ab584d4428c7f356ce77706b15b9699bc7af9f77648118184fcbe84fa349f9b09b6ae01a8dca',
        'tags': [
          ['d', '5dBOuO66YtA'],
          // First imeta - has working MP4 and HLS URLs
          [
            'imeta',
            'url',
            'https://cdn.divine.video/4b38e80d2567d290f91268202e9a9d89f29fdae29b89aec9df3b7c8ac9e290b2.mp4',
            'm',
            'video/mp4',
            'x',
            '4b38e80d2567d290f91268202e9a9d89f29fdae29b89aec9df3b7c8ac9e290b2',
            'image',
            'https://stream.divine.video/9f507ce3-fc05-4e1f-a6b7-5d5270769420/thumbnail.jpg',
            'hls',
            'https://stream.divine.video/9f507ce3-fc05-4e1f-a6b7-5d5270769420/playlist.m3u8',
          ],
          // Second imeta - has BROKEN manifest URL
          [
            'imeta',
            'url',
            'https://cdn.divine.video/47e3747a511237274cc8d7a634970c37/manifest/video.m3u8',
            'm',
            'application/vnd.apple.mpegurl',
            'image',
            'https://stream.divine.video/9f507ce3-fc05-4e1f-a6b7-5d5270769420/thumbnail.jpg',
            'hls',
            'https://stream.divine.video/9f507ce3-fc05-4e1f-a6b7-5d5270769420/playlist.m3u8',
          ],
          ['title', '161015 bundang fansign ✧ YOONGI FOCUS'],
        ],
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Should select the MP4 from first imeta (highest score: 115)
      // NOT the broken manifest URL from second imeta (score: 5)
      expect(videoEvent.videoUrl, isNotNull);
      expect(videoEvent.videoUrl, contains('.mp4'));
      expect(videoEvent.videoUrl, contains('cdn.divine.video'));
      expect(videoEvent.videoUrl, isNot(contains('/manifest/')));
    });

    test('extracts hls URL from imeta as fallback candidate', () {
      // Event with only HLS URLs, no MP4
      final event = Event.fromJson({
        'id': 'test123',
        'pubkey': 'pubkey123',
        'created_at': 1700000000,
        'kind': 34236,
        'content': 'Test video',
        'sig': 'sig123',
        'tags': [
          ['d', 'test-d-tag'],
          [
            'imeta',
            'url',
            'https://cdn.divine.video/broken/manifest/video.m3u8', // Broken
            'm', 'application/vnd.apple.mpegurl',
            'hls',
            'https://stream.divine.video/working/playlist.m3u8', // Working
          ],
        ],
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Should prefer stream.divine.video HLS (score 105) over cdn.divine.video manifest (score 5)
      expect(videoEvent.videoUrl, isNotNull);
      expect(videoEvent.videoUrl, contains('stream.divine.video'));
    });

    test('handles old space-separated imeta format with hls', () {
      final event = Event.fromJson({
        'id': 'test456',
        'pubkey': 'pubkey456',
        'created_at': 1700000000,
        'kind': 34236,
        'content': 'Old format video',
        'sig': 'sig456',
        'tags': [
          ['d', 'test-d-tag'],
          [
            'imeta',
            'url https://example.com/video.mp4',
            'm video/mp4',
            'hls https://example.com/playlist.m3u8',
          ],
        ],
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Should parse both url and hls from old format
      expect(videoEvent.videoUrl, isNotNull);
      // MP4 should win due to higher score
      expect(videoEvent.videoUrl, contains('.mp4'));
    });

    test('deprioritizes cdn.divine.video manifest URLs', () {
      final event = Event.fromJson({
        'id': 'test789',
        'pubkey': 'pubkey789',
        'created_at': 1700000000,
        'kind': 34236,
        'content': 'Manifest test',
        'sig': 'sig789',
        'tags': [
          ['d', 'test-d-tag'],
          // Only broken manifest URL available
          [
            'imeta',
            'url',
            'https://cdn.divine.video/someid/manifest/video.m3u8',
            'm',
            'application/vnd.apple.mpegurl',
          ],
          // But also a regular URL tag with working video
          ['url', 'https://other-cdn.com/video.mp4'],
        ],
      });

      final videoEvent = VideoEvent.fromNostrEvent(event);

      // Should prefer the other-cdn.com MP4 over the broken manifest
      expect(videoEvent.videoUrl, isNotNull);
      expect(videoEvent.videoUrl, contains('other-cdn.com'));
    });

    test(
      'collects URLs from streaming, fallback, mp4, video keys in imeta',
      () {
        final event = Event.fromJson({
          'id': 'test-postels',
          'pubkey': 'pubkey-postels',
          'created_at': 1700000000,
          'kind': 34236,
          'content': 'Postel test',
          'sig': 'sig-postels',
          'tags': [
            ['d', 'test-d-tag'],
            [
              'imeta',
              'streaming',
              'https://stream.example.com/live.m3u8',
              'fallback',
              'https://fallback.example.com/video.mp4',
              'mp4',
              'https://mp4.example.com/video.mp4',
              'video',
              'https://video.example.com/play.webm',
            ],
          ],
        });

        final videoEvent = VideoEvent.fromNostrEvent(event);

        // Should have picked one of the URLs (MP4 preferred)
        expect(videoEvent.videoUrl, isNotNull);
        expect(videoEvent.videoUrl, contains('.mp4'));
      },
    );
  });
}
