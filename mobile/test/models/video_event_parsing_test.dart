// ABOUTME: Tests for VideoEvent parsing from Nostr events, including streaming formats
// ABOUTME: Verifies support for divine.video schema and open protocol URL validation

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  group('VideoEvent parsing from Nostr events', () {
    test('should parse streaming tag with HLS URL', () {
      // Arrange - create a Nostr event with streaming tag
      final nostrEvent = Event(
        '0f1e20e4f53b27b62a3eb4fe7eb454c6a4d1040abfa279e7bb4a5222723541c9',
        34236,
        [
          ['d', '5gITeYOlL7g'],
          ['title', 'A low quality edit with high quality content. ✨'],
          [
            'streaming',
            'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/manifest/video.m3u8',
            'hls',
          ],
          [
            'thumb',
            'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/thumbnails/thumbnail.jpg',
          ],
          [
            'preview',
            'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/thumbnails/thumbnail.gif',
          ],
          ['vine_id', '5gITeYOlL7g'],
          ['loops', '13565'],
          ['likes', '732'],
        ],
        'A low quality edit with high quality content. ✨',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(
        videoEvent.videoUrl,
        equals(
          'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/manifest/video.m3u8',
        ),
      );
      expect(
        videoEvent.title,
        equals('A low quality edit with high quality content. ✨'),
      );
      expect(videoEvent.vineId, equals('5gITeYOlL7g'));
      expect(videoEvent.originalLoops, equals(13565));
      expect(videoEvent.originalLikes, equals(732));
    });

    test(
      'should NOT use preview GIF as thumbnail (uses static thumb instead)',
      () {
        // Arrange
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['thumb', 'https://example.com/static-thumbnail.jpg'],
            ['preview', 'https://example.com/animated-preview.gif'],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert - Should use static thumbnail, not GIF
        expect(
          videoEvent.thumbnailUrl,
          equals('https://example.com/static-thumbnail.jpg'),
        );
      },
    );

    test('should accept video URLs from any domain (open protocol)', () {
      // Arrange - test various domains that should all be accepted
      final domains = [
        'https://my-personal-server.com/video.mp4',
        'https://cdn.divine.video/path/video.m3u8',
        'https://random-cdn.xyz/stream.mpd',
        'https://192.168.1.100/local-video.webm',
        'https://example.onion/tor-video.mp4',
      ];

      for (final url in domains) {
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', url],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(
          videoEvent.videoUrl,
          equals(url),
          reason: 'Should accept video from $url (open protocol)',
        );
      }
    });

    test('should handle both d tag and vine_id tag for Vine ID', () {
      // Test with 'd' tag
      final eventWithDTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['d', 'vine-id-from-d-tag'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent1 = VideoEvent.fromNostrEvent(eventWithDTag);
      expect(videoEvent1.vineId, equals('vine-id-from-d-tag'));

      // Test with 'vine_id' tag
      final eventWithVineIdTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['vine_id', 'vine-id-from-vine-id-tag'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent2 = VideoEvent.fromNostrEvent(eventWithVineIdTag);
      expect(videoEvent2.vineId, equals('vine-id-from-vine-id-tag'));
    });

    test(
      'should parse imeta tag with blurhash from divine.video events (OLD FORMAT - space-separated)',
      () {
        // Arrange
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', 'https://cdn.divine.video/test/video.m3u8'],
            [
              'imeta',
              'url https://cdn.divine.video/test/video.mp4',
              'm video/mp4',
              'dim 480x480',
              'duration 6',
              'blurhash U~L;mea|M{t7WBj[j[ay~qoft7j[%MWBayj[',
              'image https://cdn.divine.video/test/thumbnail.jpg',
            ],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(
          videoEvent.blurhash,
          equals('U~L;mea|M{t7WBj[j[ay~qoft7j[%MWBayj['),
        );
        expect(videoEvent.dimensions, equals('480x480'));
        expect(videoEvent.duration, equals(6));
        expect(
          videoEvent.thumbnailUrl,
          equals('https://cdn.divine.video/test/thumbnail.jpg'),
        );
      },
    );

    test(
      'should parse imeta tag with blurhash (NEW FORMAT - positional key-value pairs)',
      () {
        // Arrange - This is the format used by newer divine.video events
        final nostrEvent = Event(
          '62054c6897d4971d03979196c0d7b6f54d501fed44cda0ce9d2bb88ff67992ba',
          34236,
          [
            ['d', 'iOr5DLaPr79'],
            [
              'imeta',
              'url',
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/play_240p.mp4',
              'm',
              'video/mp4',
              'image',
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
              'blurhash',
              'L9AAEz-o?^TK4.%gVs-o009F9E9F',
              'dim',
              '720x720',
              'x',
              '70c84853646e2e8f64ef07ebd5e5267329d21d194af1138a790cdb4463d1f0b7',
            ],
            ['title', 'jordan'],
          ],
          'jordan',
          createdAt: 1761378640,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(videoEvent.blurhash, equals('L9AAEz-o?^TK4.%gVs-o009F9E9F'));
        expect(videoEvent.dimensions, equals('720x720'));
        expect(
          videoEvent.thumbnailUrl,
          equals(
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
          ),
        );
        expect(
          videoEvent.videoUrl,
          equals(
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/play_240p.mp4',
          ),
        );
        expect(
          videoEvent.sha256,
          equals(
            '70c84853646e2e8f64ef07ebd5e5267329d21d194af1138a790cdb4463d1f0b7',
          ),
        );
        expect(videoEvent.mimeType, equals('video/mp4'));
      },
    );

    test('should not require specific file extensions for video URLs', () {
      // Arrange - URL without typical video extension
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://api.example.com/stream/12345'], // No file extension
        ],
        'Test video',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(
        videoEvent.videoUrl,
        equals('https://api.example.com/stream/12345'),
      );
    });

    test('should reject non-HTTP/HTTPS URLs', () {
      // Arrange
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'ftp://example.com/video.mp4'], // FTP protocol
        ],
        'Test video',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(videoEvent.videoUrl, isNull);
    });
  });
}
