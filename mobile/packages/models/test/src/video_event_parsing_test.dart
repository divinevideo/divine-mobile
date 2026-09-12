// ABOUTME: Tests for VideoEvent parsing from Nostr events
// ABOUTME: Verifies divine.video schema and open protocol URL validation
// ignore_for_file: lines_longer_than_80_chars

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

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

    test('uses received relay source when no relay hint tag exists', () {
      final nostrEvent =
          Event(
              '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
              34236,
              [
                ['url', 'https://example.com/source-relay.mp4'],
              ],
              'Test video',
              createdAt: 1757385263,
            )
            ..sources.addAll([
              'wss://relay.staging.dvines.org',
              'wss://relay.divine.video',
            ]);

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.sourceRelay, 'wss://relay.staging.dvines.org');
    });

    test('keeps explicit relay hint over received relay source', () {
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['r', 'wss://relay.hint.example'],
          ['url', 'https://example.com/source-relay.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      )..sources.add('wss://relay.staging.dvines.org');

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.sourceRelay, 'wss://relay.hint.example');
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
      expect(videoEvent1.addressableDTag, equals('vine-id-from-d-tag'));
      expect(videoEvent1.hasAddressableDTag, isTrue);
      expect(
        videoEvent1.addressableId,
        equals(
          '34236:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef:vine-id-from-d-tag',
        ),
      );

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
      expect(videoEvent2.addressableDTag, isNull);
      expect(videoEvent2.hasAddressableDTag, isFalse);
      expect(videoEvent2.addressableId, isNull);
    });

    test(
      'preserves missing d tag state while keeping stable vineId fallback',
      () {
        final eventWithoutDTag = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(eventWithoutDTag);

        expect(videoEvent.vineId, equals(eventWithoutDTag.id));
        expect(videoEvent.addressableDTag, isNull);
        expect(videoEvent.hasAddressableDTag, isFalse);
        expect(videoEvent.addressableId, isNull);
      },
    );

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
        expect(videoEvent.thumbnailUrl, isNull);
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

    test('uses a live alternate thumbnail after a dead media thumbnail', () {
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://media.divine.video/video.mp4'],
          [
            'thumb',
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
          ],
          ['image', 'https://media.divine.video/fa4a90a3-thumbnail.jpg'],
          ['blurhash', 'L9AAEz-o?^TK4.%gVs-o009F9E9F'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(
        videoEvent.thumbnailUrl,
        equals('https://media.divine.video/fa4a90a3-thumbnail.jpg'),
      );
      expect(videoEvent.blurhash, equals('L9AAEz-o?^TK4.%gVs-o009F9E9F'));
    });

    test('drops a dead media thumbnail while keeping blurhash fallback', () {
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://media.divine.video/video.mp4'],
          [
            'thumb',
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
          ],
          ['blurhash', 'L9AAEz-o?^TK4.%gVs-o009F9E9F'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.thumbnailUrl, isNull);
      expect(videoEvent.blurhash, equals('L9AAEz-o?^TK4.%gVs-o009F9E9F'));
    });

    test('drops dead media thumbnails restored from persisted JSON', () {
      final videoEvent = VideoEvent.fromJson(const {
        'id':
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        'pubkey':
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        'createdAt': 1757385263,
        'content': 'Test video',
        'videoUrl': 'https://media.divine.video/video.mp4',
        'thumbnailUrl':
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
        'blurhash': 'L9AAEz-o?^TK4.%gVs-o009F9E9F',
      });

      expect(videoEvent.thumbnailUrl, isNull);
      expect(videoEvent.blurhash, equals('L9AAEz-o?^TK4.%gVs-o009F9E9F'));
    });

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

    test('should ignore invalid thumbnail URLs from typed r tags', () {
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['r', 'https:///missing-host.jpg', 'thumbnail'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.videoUrl, equals('https://example.com/video.mp4'));
      expect(videoEvent.thumbnailUrl, isNull);
    });

    test('should ignore invalid thumbnail URLs from top-level tags', () {
      final invalidThumbnailTags = [
        ['thumb', 'https:///missing-host.jpg'],
        ['image', 'https:///missing-host.jpg'],
      ];

      for (final thumbnailTag in invalidThumbnailTags) {
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
            thumbnailTag,
          ],
          'Test video',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(
          videoEvent.thumbnailUrl,
          isNull,
          reason: 'Expected ${thumbnailTag.first} to reject malformed URLs',
        );
      }
    });

    test('should ignore invalid thumbnail URLs from imeta tags', () {
      final invalidImetaTags = [
        ['imeta', 'thumb https:///missing-host.jpg'],
        ['imeta', 'image https:///missing-host.jpg'],
      ];

      for (final imetaTag in invalidImetaTags) {
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
            imetaTag,
          ],
          'Test video',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.thumbnailUrl, isNull);
      }
    });

    test('should accept valid thumbnail URLs from typed r tags', () {
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['r', 'https://example.com/thumb.jpg', 'thumbnail'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.thumbnailUrl, equals('https://example.com/thumb.jpg'));
    });
  });

  group('VideoEvent collaborator parsing', () {
    const authorPubkey =
        'aaaa567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const collabPubkey1 =
        'bbbb567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const collabPubkey2 =
        'cccc567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    test('should parse p-tags as collaborators when different from author', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', collabPubkey1, 'wss://relay.divine.video', 'collaborator'],
          ['p', collabPubkey2, 'wss://relay.divine.video', 'collaborator'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, hasLength(2));
      expect(videoEvent.collaboratorPubkeys, contains(collabPubkey1));
      expect(videoEvent.collaboratorPubkeys, contains(collabPubkey2));
      expect(videoEvent.hasCollaborators, isTrue);
    });

    test('should not include author pubkey as collaborator', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'p',
            authorPubkey,
            'wss://relay.divine.video',
            'collaborator',
          ], // Author self-tag
          ['p', collabPubkey1, 'wss://relay.divine.video', 'collaborator'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, hasLength(1));
      expect(videoEvent.collaboratorPubkeys, contains(collabPubkey1));
      expect(videoEvent.collaboratorPubkeys, isNot(contains(authorPubkey)));
    });

    test('should deduplicate collaborator pubkeys', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', collabPubkey1, 'wss://relay.divine.video', 'collaborator'],
          [
            'p',
            collabPubkey1,
            'wss://relay.divine.video',
            'collaborator',
          ], // Duplicate
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, hasLength(1));
    });

    test('should only include collaborator-marked p-tags', () {
      const strayMentionPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', collabPubkey1, 'wss://relay.divine.video', 'collaborator'],
          ['p', strayMentionPubkey, 'wss://relay.divine.video', 'mention'],
          ['p', collabPubkey2, 'wss://relay.divine.video'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, equals([collabPubkey1]));
    });

    test(
      'should expose generic mention p-tags separately from collaborators',
      () {
        const mentionPubkey =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        final nostrEvent = Event(
          authorPubkey,
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
            ['p', collabPubkey1, 'wss://relay.divine.video', 'collaborator'],
            ['p', mentionPubkey, 'wss://relay.divine.video', 'mention'],
          ],
          '@shutupphia FOLLOW HER',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.collaboratorPubkeys, equals([collabPubkey1]));
        expect(videoEvent.mentionedPubkeys, equals([mentionPubkey]));
      },
    );

    test('should accept historical capitalized collaborator markers', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', collabPubkey1, 'wss://relay.divine.video', 'Collaborator'],
          ['p', collabPubkey2, 'wss://relay.divine.video', 'COLLABORATOR'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(
        videoEvent.collaboratorPubkeys,
        equals([collabPubkey1, collabPubkey2]),
      );
    });

    test('should normalize uppercase collaborator pubkeys', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'p',
            collabPubkey1.toUpperCase(),
            'wss://relay.divine.video',
            'collaborator',
          ],
          [
            'p',
            authorPubkey.toUpperCase(),
            'wss://relay.divine.video',
            'collaborator',
          ],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, equals([collabPubkey1]));
    });

    test('should return empty collaborators when no p-tags', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, isEmpty);
      expect(videoEvent.hasCollaborators, isFalse);
    });

    test('should skip empty p-tag values', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', '', 'wss://relay.divine.video'], // Empty pubkey
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, isEmpty);
    });
  });

  group('VideoEvent Inspired By parsing', () {
    const authorPubkey =
        'aaaa567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const creatorPubkey =
        'dddd567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    test('collects every inspired-by p-tag, not just the first', () {
      // The NIP-27 content line can only name one creator, so the p-tags are
      // what carry the rest — parsing only the first would silently drop
      // everyone the author credited after the first.
      const secondCreator =
          'eeee567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', creatorPubkey, 'wss://relay.divine.video', 'inspired-by'],
          ['p', secondCreator, 'wss://relay.divine.video', 'inspired-by'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(
        videoEvent.inspiredByPubkeys,
        equals([creatorPubkey, secondCreator]),
      );
      expect(videoEvent.hasInspiredBy, isTrue);
      expect(videoEvent.inspiredByCreatorPubkey, equals(creatorPubkey));
    });

    test(
      'does not treat collaborator or clip-source p-tags as inspired by',
      () {
        const collaborator =
            'eeee567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
        final nostrEvent = Event(
          authorPubkey,
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
            ['p', collaborator, 'wss://relay.divine.video', 'collaborator'],
            ['p', creatorPubkey, 'wss://relay.divine.video', 'clip-source'],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.inspiredByPubkeys, isEmpty);
        expect(videoEvent.collaboratorPubkeys, equals([collaborator]));
      },
    );

    test('deduplicates a repeated inspired-by p-tag', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', creatorPubkey, 'wss://relay.divine.video', 'inspired-by'],
          ['p', creatorPubkey, 'wss://relay.divine.video', 'inspired-by'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      expect(
        VideoEvent.fromNostrEvent(nostrEvent).inspiredByPubkeys,
        equals([creatorPubkey]),
      );
    });

    test('should parse a-tag as inspiredByVideo for Kind 34236 references', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'a',
            '34236:$creatorPubkey:test-d-tag',
            'wss://relay.divine.video',
            'mention',
          ],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNotNull);
      expect(
        videoEvent.inspiredByVideo!.addressableId,
        equals('34236:$creatorPubkey:test-d-tag'),
      );
      expect(
        videoEvent.inspiredByVideo!.relayUrl,
        equals('wss://relay.divine.video'),
      );
      expect(videoEvent.inspiredByVideo!.creatorPubkey, equals(creatorPubkey));
      expect(videoEvent.inspiredByVideo!.dTag, equals('test-d-tag'));
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test('parses clip-source a-tags as factual clip credits', () {
      const secondCreatorPubkey =
          'eeee567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'a',
            '34236:$creatorPubkey:test-d-tag',
            'wss://relay.divine.video',
            clipSourceCreditTagMarker,
          ],
          [
            'a',
            '34236:$secondCreatorPubkey:second-d-tag',
            'wss://relay-two.divine.video',
            clipSourceCreditTagMarker,
          ],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNull);
      expect(videoEvent.clipSourceCredits, hasLength(2));
      expect(videoEvent.clipSourceCredits[0].authorPubkey, creatorPubkey);
      expect(
        videoEvent.clipSourceCredits[0].addressableId,
        '34236:$creatorPubkey:test-d-tag',
      );
      expect(videoEvent.clipSourceCredits[1].authorPubkey, secondCreatorPubkey);
      expect(
        videoEvent.clipSourceCredits[1].relayUrl,
        'wss://relay-two.divine.video',
      );
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test(
      'parses author-only clip-source p-tags without duplicating a-tags',
      () {
        final nostrEvent = Event(
          authorPubkey,
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
            [
              'a',
              '34236:$creatorPubkey:test-d-tag',
              'wss://relay.divine.video',
              clipSourceCreditTagMarker,
            ],
            [
              'p',
              creatorPubkey,
              'wss://relay.divine.video',
              clipSourceCreditTagMarker,
            ],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.clipSourceCredits, hasLength(1));
        expect(videoEvent.clipSourceCredits.single.authorPubkey, creatorPubkey);
        expect(
          videoEvent.clipSourceCredits.single.addressableId,
          '34236:$creatorPubkey:test-d-tag',
        );
      },
    );

    test('should ignore a-tag that does not start with 34236:', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['a', '30023:$creatorPubkey:some-article', 'wss://relay.example.com'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNull);
    });

    test('should parse NIP-27 nostr:npub in content as inspiredByNpub', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Great idea!\n\nInspired by nostr:npub1abc123def456ghi789',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByNpub, equals('npub1abc123def456ghi789'));
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test('should not set inspiredByNpub when no nostr:npub in content', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Just a regular description with no mentions',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByNpub, isNull);
    });

    test('should not treat an inline nostr:npub mention as inspiredByNpub', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Shoutout to nostr:npub1notattribution for the tip!',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByNpub, isNull);
    });

    test(
      'should not treat a trailing mid-sentence mention as inspiredByNpub',
      () {
        // The strip regex in the edit form requires a blank line (or start of
        // content) before the attribution phrase. Parsing must be equally
        // strict, or prose like this would set inspiredByNpub without ever
        // being strippable — duplicating the line and p-tagging the mentioned
        // person on the next edit-save.
        final nostrEvent = Event(
          authorPubkey,
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          'my remix. Inspired by nostr:npub1prosecreator',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.inspiredByNpub, isNull);
      },
    );

    test('should not treat a single-newline-prefixed attribution as '
        'inspiredByNpub', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'my caption\nInspired by nostr:npub1singlenewline',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByNpub, isNull);
    });

    test('should resolve the trailing attribution npub when an inline mention '
        'appears earlier in content', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Shoutout to nostr:npub1notattribution for the tip!'
        '\n\nInspired by nostr:npub1realattribution',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByNpub, equals('npub1realattribution'));
    });

    test(
      'should parse inspiredByNpub when attribution is the whole content',
      () {
        // Empty-description publishes trim the leading newlines, so the
        // attribution line is the entire content.
        final nostrEvent = Event(
          authorPubkey,
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          'Inspired by nostr:npub1onlyattribution',
          createdAt: 1757385263,
        );

        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        expect(videoEvent.inspiredByNpub, equals('npub1onlyattribution'));
      },
    );

    test('should parse both a-tag and npub content together', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['a', '34236:$creatorPubkey:test-d-tag', 'wss://relay.divine.video'],
        ],
        'Inspired by nostr:npub1xyz789abc',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNotNull);
      expect(videoEvent.inspiredByNpub, equals('npub1xyz789abc'));
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test(
      'should prefer explicit inspired-by creator over factual clip credits',
      () {
        const clipCreator =
            'eeee567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
        final videoEvent = VideoEvent(
          id: 'video-id',
          pubkey: authorPubkey,
          createdAt: 1757385263,
          content: 'Test video',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1757385263000),
          videoUrl: 'https://example.com/video.mp4',
          inspiredByVideo: const InspiredByInfo(
            addressableId: '34236:$creatorPubkey:test-d-tag',
          ),
          clipSourceCredits: const [
            ClipSourceCredit(
              authorPubkey: clipCreator,
              addressableId: '34236:$clipCreator:clip-source',
            ),
          ],
        );

        expect(videoEvent.hasInspiredBy, isTrue);
        expect(videoEvent.inspiredByCreatorPubkey, creatorPubkey);
      },
    );

    test('should not have inspiredBy when no a-tag or npub', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'No inspiration here',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNull);
      expect(videoEvent.inspiredByNpub, isNull);
      expect(videoEvent.hasInspiredBy, isFalse);
    });
  });

  group(InspiredByInfo, () {
    test('should parse creatorPubkey from addressableId', () {
      const info = InspiredByInfo(addressableId: '34236:abc123:my-video');

      expect(info.creatorPubkey, equals('abc123'));
    });

    test('should parse dTag from addressableId', () {
      const info = InspiredByInfo(addressableId: '34236:abc123:my-video');

      expect(info.dTag, equals('my-video'));
    });

    test('should handle addressableId with missing segments', () {
      const infoNoSegments = InspiredByInfo(addressableId: '34236');

      expect(infoNoSegments.creatorPubkey, isEmpty);
      expect(infoNoSegments.dTag, isEmpty);
    });

    test('should round-trip through JSON serialization', () {
      const original = InspiredByInfo(
        addressableId: '34236:abc123:my-video',
        relayUrl: 'wss://relay.divine.video',
      );

      final json = original.toJson();
      final restored = InspiredByInfo.fromJson(json);

      expect(restored.addressableId, equals(original.addressableId));
      expect(restored.relayUrl, equals(original.relayUrl));
      expect(restored, equals(original));
    });

    test('should serialize without relayUrl when null', () {
      const info = InspiredByInfo(addressableId: '34236:abc:vid');

      final json = info.toJson();

      expect(json.containsKey('relayUrl'), isFalse);
      expect(json['addressableId'], equals('34236:abc:vid'));
    });

    test('should implement equality based on addressableId', () {
      const info1 = InspiredByInfo(
        addressableId: '34236:abc:vid',
        relayUrl: 'wss://relay1.com',
      );
      const info2 = InspiredByInfo(
        addressableId: '34236:abc:vid',
        relayUrl: 'wss://relay2.com', // Different relay, same ID
      );
      const info3 = InspiredByInfo(addressableId: '34236:different:vid');

      expect(info1, equals(info2));
      expect(info1, isNot(equals(info3)));
    });
  });

  group('VideoEvent.imetaVideoUrls', () {
    const hash =
        'e770667c1a62cc394602fc07462fa0d7ba83441002d9aac662fb88d0cc575338';

    VideoEvent eventWithTags(List<List<String>> tags) {
      final event = Event(
        'e2fef811cf3a5e0ff69f645d8207ee7cff36d64c81a7f2a8d0c8ff8ceecd6b0f',
        34236,
        tags,
        '',
        createdAt: 1234567890,
      );
      return VideoEvent.fromNostrEvent(event);
    }

    test('extracts the single url from space-separated imeta', () {
      final video = eventWithTags([
        [
          'imeta',
          'url https://media.divine.video/$hash',
          'm video/mp4',
          'x $hash',
        ],
      ]);

      expect(
        video.imetaVideoUrls,
        equals(['https://media.divine.video/$hash']),
      );
    });

    test('extracts and dedups urls from positional imeta', () {
      final video = eventWithTags([
        [
          'imeta',
          'url',
          'https://media.divine.video/$hash/720p.mp4',
          'url',
          'https://media.divine.video/$hash',
          'm',
          'video/mp4',
        ],
      ]);

      expect(
        video.imetaVideoUrls,
        equals([
          'https://media.divine.video/$hash/720p.mp4',
          'https://media.divine.video/$hash',
        ]),
      );
    });

    test('ignores thumbnail and non-url imeta keys', () {
      final video = eventWithTags([
        [
          'imeta',
          'url https://media.divine.video/$hash',
          'image https://media.divine.video/$hash/thumb.jpg',
          'thumb https://media.divine.video/$hash/thumb.jpg',
        ],
      ]);

      expect(
        video.imetaVideoUrls,
        equals(['https://media.divine.video/$hash']),
      );
    });

    test('returns empty list when there is no imeta tag', () {
      final video = eventWithTags([
        ['url', 'https://media.divine.video/$hash'],
      ]);

      expect(video.imetaVideoUrls, isEmpty);
    });

    group('nostrCreatedAt', () {
      test('keeps the event created_at when published_at overrides '
          'createdAt', () {
        // An edit mints a new event under the same `d` tag but re-emits the
        // original published_at, so createdAt reports the first publication.
        final republishedEdit = Event(
          '0f1e20e4f53b27b62a3eb4fe7eb454c6a4d1040abfa279e7bb4a5222723541c9',
          34236,
          [
            ['d', 'clip-1'],
            ['url', 'https://cdn.divine.video/clip.mp4'],
            ['published_at', '1000'],
          ],
          'an edited clip',
          createdAt: 3000,
        );

        final video = VideoEvent.fromNostrEvent(republishedEdit);

        expect(video.createdAt, 1000, reason: 'display timestamp');
        expect(video.nostrCreatedAt, 3000, reason: 'deletion-ordering');
      });

      test('falls back to createdAt when the raw timestamp is unknown', () {
        final video = VideoEvent(
          id: 'id',
          pubkey: 'pubkey',
          createdAt: 1000,
          content: 'no raw timestamp',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000),
        );

        expect(video.nostrCreatedAt, 1000);
      });
    });
  });
}
