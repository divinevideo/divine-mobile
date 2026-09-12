// ABOUTME: Tests for VideoStats model.
// ABOUTME: Tests JSON parsing, field handling, and VideoEvent conversion.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VideoStats', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        expect(stats.id, equals('test-id'));
        expect(stats.pubkey, equals('test-pubkey'));
        expect(stats.kind, equals(34236));
        expect(stats.title, equals('Test Video'));
        expect(stats.reactions, equals(10));
      });

      test('creates instance with optional fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          description: 'A description',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          sha256: 'abc123',
          authorName: 'Test Author',
          authorAvatar: 'https://example.com/avatar.jpg',
          blurhash: 'LEHV6nWB2yk8',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
          trendingScore: 0.85,
          loops: 1000,
        );

        expect(stats.description, equals('A description'));
        expect(stats.sha256, equals('abc123'));
        expect(stats.authorName, equals('Test Author'));
        expect(stats.blurhash, equals('LEHV6nWB2yk8'));
        expect(stats.trendingScore, equals(0.85));
        expect(stats.loops, equals(1000));
      });
    });

    group('fromJson', () {
      test('parses basic flat JSON', () {
        final json = {
          'id': 'abc123',
          'pubkey': 'pub456',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'My Video',
          'content': 'Video description',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 100,
          'comments': 20,
          'reposts': 5,
          'engagement_score': 125,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abc123'));
        expect(stats.pubkey, equals('pub456'));
        expect(stats.kind, equals(34236));
        expect(stats.dTag, equals('video-1'));
        expect(stats.title, equals('My Video'));
        expect(stats.description, equals('Video description'));
        expect(stats.reactions, equals(100));
        expect(stats.engagementScore, equals(125));
      });

      test('parses nested event/stats format', () {
        final json = {
          'event': {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'd_tag': 'nested-video',
            'title': 'Nested Title',
            'content': 'Nested description',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
          },
          'stats': {
            'reactions': 50,
            'comments': 10,
            'reposts': 3,
            'engagement_score': 63,
            'trending_score': 0.75,
          },
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('event-id'));
        expect(stats.pubkey, equals('event-pubkey'));
        expect(stats.title, equals('Nested Title'));
        expect(stats.reactions, equals(50));
        expect(stats.trendingScore, equals(0.75));
      });

      test('preserves repeated and provenance tags for editing', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'content': 'Description',
            'tags': [
              ['d', 'video-1'],
              ['imeta', 'url https://example.com/video.mp4'],
              ['t', 'first'],
              ['t', 'second'],
              ['alt', 'Accessible description'],
              ['duration', '6'],
              ['proofmode', 'proof-manifest'],
              ['c2pa_manifest_id', 'urn:c2pa:test'],
              ['verification', 'verified_mobile'],
              ['device_attestation', 'attestation'],
            ],
          },
          'stats': {
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
          },
        });

        final video = stats.toVideoEvent();

        expect(stats.eventTags, hasLength(10));
        expect(video.nostrEventTags, equals(stats.eventTags));
        expect(video.hashtags, equals(['first', 'second']));
        expect(video.altText, equals('Accessible description'));
        expect(video.duration, equals(6));
        expect(
          video.nostrEventTags,
          contains(equals(['proofmode', 'proof-manifest'])),
        );
        expect(
          video.nostrEventTags,
          contains(equals(['c2pa_manifest_id', 'urn:c2pa:test'])),
        );
        expect(
          video.nostrEventTags,
          contains(equals(['verification', 'verified_mobile'])),
        );
        expect(
          video.nostrEventTags,
          contains(equals(['device_attestation', 'attestation'])),
        );
      });

      test('standalone file size overrides imeta for metadata editing', () {
        final video = VideoStats.fromJson(const {
          'event': {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'content': 'Description',
            'tags': [
              ['d', 'video-1'],
              [
                'imeta',
                'url https://example.com/video.mp4',
                'size 480000',
              ],
              ['size', '640000'],
            ],
          },
          'stats': {
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
          },
        }).toVideoEvent();

        expect(video.fileSize, 640000);
      });

      test(
        'parses explicit addressable d tag fields from compact REST JSON',
        () {
          final stats = VideoStats.fromJson(const {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'addressable_d_tag': 'real-d-tag',
            'title': 'Compact Title',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
          });

          final videoEvent = stats.toVideoEvent();

          expect(stats.dTag, equals('real-d-tag'));
          expect(videoEvent.vineId, equals('real-d-tag'));
          expect(videoEvent.addressableDTag, equals('real-d-tag'));
          expect(
            videoEvent.addressableId,
            equals('34236:event-pubkey:real-d-tag'),
          );
        },
      );

      test('parses d tag from explicit REST addressable id', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'addressableId': '34236:event-pubkey:real-d-tag',
            'title': 'Compact Title',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
          },
          'stats': {
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
          },
        });

        expect(stats.dTag, equals('real-d-tag'));
        expect(stats.toVideoEvent().addressableDTag, equals('real-d-tag'));
      });

      test('prefers event d tag over a tag addressable references', () {
        final stats = VideoStats.fromJson(const {
          'id': 'event-id',
          'pubkey': 'event-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'tags': [
            ['a', '34236:other-pubkey:referenced-d-tag', '', 'mention'],
            ['d', 'real-d-tag'],
          ],
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        });

        expect(stats.dTag, equals('real-d-tag'));
        expect(stats.toVideoEvent().addressableDTag, equals('real-d-tag'));
      });

      test('parses published_at from tags instead of REST fields', () {
        final stats = VideoStats.fromJson(const {
          'id': 'abc123',
          'pubkey': 'pub456',
          'created_at': 1777489813,
          'published_at': 1777489813,
          'kind': 34236,
          'tags': [
            ['d', 'video-1'],
            ['published_at', '1473050841'],
          ],
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        });

        expect(stats.publishedAt, equals(1473050841));
      });

      test('reads top-level published_at when tags are omitted', () {
        final stats = VideoStats.fromJson(const {
          'id': 'abc123',
          'pubkey': 'pub456',
          'created_at': 1788200570,
          'published_at': 1784431685,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Message to the Grassroots',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        });

        expect(stats.publishedAt, equals(1784431685));
        final video = stats.toVideoEvent();
        expect(video.createdAt, equals(1784431685));
        expect(video.nostrCreatedAt, equals(1788200570));
      });

      test('ignores zero and invalid top-level published_at', () {
        final stats = VideoStats.fromJson(const {
          'id': 'abc123',
          'pubkey': 'pub456',
          'created_at': 1788200570,
          'published_at': 0,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        });

        expect(stats.publishedAt, isNull);
        expect(stats.toVideoEvent().createdAt, equals(1788200570));
      });

      test('normalizes invalid engagement counters to zero', () {
        final stats = VideoStats.fromJson(const {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'stats': {
            'reactions': -1,
            'comments': '9223372036854775807',
            'reposts': '18446744073709551615',
          },
          'engagement_score': 0,
        });

        expect(stats.reactions, equals(0));
        expect(stats.comments, equals(0));
        expect(stats.reposts, equals(0));
      });

      test('parses id as byte array (ASCII codes)', () {
        final json = {
          'id': [97, 98, 99, 49, 50, 51], // 'abc123' as ASCII codes
          'pubkey': 'pub456',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abc123'));
      });

      test('parses pubkey as byte array (ASCII codes)', () {
        final json = {
          'id': 'test-id',
          'pubkey': [112, 117, 98, 52, 53, 54], // 'pub456' as ASCII codes
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.pubkey, equals('pub456'));
      });

      test('normalizes uppercase id to lowercase', () {
        final json = {
          'id': 'ABCDEF1234567890',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abcdef1234567890'));
      });

      test('normalizes uppercase pubkey to lowercase', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'ABCDEF1234567890',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.pubkey, equals('abcdef1234567890'));
      });

      test('normalizes uppercase byte array id to lowercase', () {
        // 'ABCD' as ASCII codes: A=65, B=66, C=67, D=68
        final json = {
          'id': [65, 66, 67, 68, 69, 70],
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.id, equals('abcdef'));
      });

      test('parses created_at as Unix timestamp', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(
          stats.createdAt,
          equals(
            DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
          ),
        );
      });

      test('parses created_at as ISO string', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': '2024-01-15T12:00:00.000Z',
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.createdAt.year, equals(2024));
        expect(stats.createdAt.month, equals(1));
        expect(stats.createdAt.day, equals(15));
        expect(stats.createdAt.isUtc, isTrue);
      });

      test('falls back to UTC now when created_at string is invalid', () {
        final before = DateTime.now().toUtc();
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 'not-a-date',
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);
        final after = DateTime.now().toUtc();

        expect(stats.createdAt.isUtc, isTrue);
        expect(
          stats.createdAt.isAfter(before) ||
              stats.createdAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          stats.createdAt.isBefore(after) ||
              stats.createdAt.isAtSameMomentAs(after),
          isTrue,
        );
      });

      test('extracts fields from tags array', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'tags': [
            ['title', 'Title from tag'],
            ['thumb', 'https://example.com/thumb-from-tag.jpg'],
            ['url', 'https://example.com/video-from-tag.mp4'],
            ['d', 'dtag-from-tag'],
            ['x', 'sha256-from-tag'],
            ['blurhash', 'LEHV6nWB'],
            ['dim', '720x1280'],
            ['summary', 'Summary from tag'],
            ['loops', '5000'],
          ],
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.title, equals('Title from tag'));
        expect(
          stats.thumbnail,
          equals('https://example.com/thumb-from-tag.jpg'),
        );
        expect(
          stats.videoUrl,
          equals('https://example.com/video-from-tag.mp4'),
        );
        expect(stats.dTag, equals('dtag-from-tag'));
        expect(stats.sha256, equals('sha256-from-tag'));
        expect(stats.blurhash, equals('LEHV6nWB'));
        expect(stats.dimensions, equals('720x1280'));
        expect(stats.description, equals('Summary from tag'));
        expect(stats.loops, equals(5000));
      });

      test('ignores size tag when dim tag is absent', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'tags': [
            ['size', '480000'],
          ],
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.dimensions, isNull);
      });

      test('parses dimensions from direct REST fields', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'dimensions': '1080x1920',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.dimensions, equals('1080x1920'));
      });

      test('prefers content over summary tag for description', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'content': 'Content description',
          'tags': [
            ['summary', 'Summary description'],
          ],
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.description, equals('Content description'));
      });

      test('keeps embedded_likes out of live reactions', () {
        final jsonWithEmbeddedLikes = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'embedded_likes': 42,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(jsonWithEmbeddedLikes);

        expect(stats.reactions, equals(0));
        expect(stats.embeddedLikes, equals(42));
      });

      test('parses archival embedded_* counts separately from live counts', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1457922740,
          'kind': 34236,
          'd_tag': 'iwKm6wppIIH',
          'title': 'Classic vine',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'loops': 142678928,
          'embedded_likes': 459878,
          'embedded_comments': 15227,
          'embedded_reposts': 179996,
          'platform': 'vine',
          'reactions': 387,
          'comments': 10,
          'reposts': 42,
          'views': 3020,
          'engagement_score': 533,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.loops, equals(142678928));
        expect(stats.embeddedLikes, equals(459878));
        expect(stats.embeddedComments, equals(15227));
        expect(stats.embeddedReposts, equals(179996));
        expect(stats.reactions, equals(387));
        expect(stats.comments, equals(10));
        expect(stats.reposts, equals(42));
        expect(stats.views, equals(3020));
      });

      test(
        'prefers embedded_loops over live loops in nested stats objects',
        () {
          final json = {
            'event': {
              'id': 'test-id',
              'pubkey': 'test-pubkey',
              'created_at': 1457922740,
              'kind': 34236,
              'tags': [
                ['d', 'video-1'],
                ['url', 'https://example.com/video.mp4'],
              ],
            },
            'stats': {
              'reactions': 387,
              'comments': 10,
              'reposts': 42,
              'engagement_score': 533,
              'views': 3020,
              'loops': 1538,
              'embedded_loops': 142678928,
            },
          };

          final stats = VideoStats.fromJson(json);

          expect(stats.loops, equals(142678928));
          expect(stats.views, equals(3020));
        },
      );

      test(
        'keeps embedded_comments and embedded_reposts out of live counts',
        () {
          final json = {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'd_tag': 'video-1',
            'title': 'Test',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
            'embedded_comments': 15227,
            'embedded_reposts': 179996,
            'engagement_score': 0,
          };

          final stats = VideoStats.fromJson(json);

          expect(stats.comments, equals(0));
          expect(stats.reposts, equals(0));
          expect(stats.embeddedComments, equals(15227));
          expect(stats.embeddedReposts, equals(179996));
        },
      );

      test('handles loops in different formats', () {
        // As int
        final jsonWithIntLoops = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'loops': 1000,
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        expect(VideoStats.fromJson(jsonWithIntLoops).loops, equals(1000));

        // As string
        final jsonWithStringLoops = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'loops': '2000',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        expect(VideoStats.fromJson(jsonWithStringLoops).loops, equals(2000));
      });

      test('handles trending_score as int and double', () {
        final jsonWithIntScore = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'trending_score': 1,
        };

        expect(
          VideoStats.fromJson(jsonWithIntScore).trendingScore,
          equals(1.0),
        );

        final jsonWithDoubleScore = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'trending_score': 0.85,
        };

        expect(
          VideoStats.fromJson(jsonWithDoubleScore).trendingScore,
          equals(0.85),
        );
      });

      test('handles numeric fields as doubles from REST API', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 10.0,
          'comments': 5.0,
          'reposts': 2.0,
          'engagement_score': 125.0,
          'loops': 42.0,
          'views': 100.0,
        };

        final stats = VideoStats.fromJson(json);
        expect(stats.reactions, equals(10));
        expect(stats.comments, equals(5));
        expect(stats.reposts, equals(2));
        expect(stats.engagementScore, equals(125));
        expect(stats.loops, equals(42));
        expect(stats.views, equals(100));
      });

      test('parses total_loops and total_views field variants', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 10,
          'comments': 5,
          'reposts': 2,
          'engagement_score': 125,
          'total_loops': 42.0,
          'total_views': 100.0,
        };

        final stats = VideoStats.fromJson(json);
        expect(stats.loops, equals(42));
        expect(stats.views, equals(100));
      });

      test('normalizes empty values to null', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'content': '',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'sha256': '',
          'author_name': '',
          'author_avatar': '',
          'blurhash': '',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.description, isNull);
        expect(stats.sha256, isNull);
        expect(stats.authorName, isNull);
        expect(stats.authorAvatar, isNull);
        expect(stats.blurhash, isNull);
      });

      test('falls back to d_tag as sha256 when d_tag is 64-char hex', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag':
              'a04b70820ef370e90aae19d23e46b148'
              '2d3af0e7c9d994d1594a1384a62d3972',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(
          stats.sha256,
          equals(
            'a04b70820ef370e90aae19d23e46b1482d3af0e7c9d994d1594a1384a62d3972',
          ),
        );
      });

      test('does not use d_tag as sha256 when d_tag is not a hex hash', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'my-video-slug',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.sha256, isNull);
      });

      test('does not override explicit sha256 with d_tag', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag':
              'a04b70820ef370e90aae19d23'
              'e46b1482d3af0e7c9d994d15'
              '94a1384a62d3972',
          'sha256': 'explicit-sha256-value',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.sha256, equals('explicit-sha256-value'));
      });

      test('defaults kind to 34236 when missing', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.kind, equals(34236));
      });
    });

    group('blurhash from imeta tag', () {
      Map<String, dynamic> jsonWithImetaTag(List<dynamic> imetaTag) => {
        'event': {
          'id': 'event-id',
          'pubkey': 'event-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'tags': [imetaTag],
        },
        'reactions': 0,
        'comments': 0,
        'reposts': 0,
        'engagement_score': 0,
      };

      test('extracts blurhash from space-separated imeta format', () {
        final stats = VideoStats.fromJson(
          jsonWithImetaTag([
            'imeta',
            'url https://example.com/video.mp4',
            'blurhash LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          ]),
        );

        expect(stats.blurhash, equals('LEHV6nWB2yk8pyo0adR*.7kCMdnj'));
      });

      test('extracts dimensions from space-separated imeta format', () {
        final stats = VideoStats.fromJson(
          jsonWithImetaTag([
            'imeta',
            'url https://example.com/video.mp4',
            'dim 1080x1920',
          ]),
        );

        expect(stats.dimensions, equals('1080x1920'));
      });

      test('extracts blurhash from positional imeta format', () {
        final stats = VideoStats.fromJson(
          jsonWithImetaTag([
            'imeta',
            'url',
            'https://example.com/video.mp4',
            'blurhash',
            'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          ]),
        );

        expect(stats.blurhash, equals('LEHV6nWB2yk8pyo0adR*.7kCMdnj'));
      });

      test('extracts dimensions from positional imeta format', () {
        final stats = VideoStats.fromJson(
          jsonWithImetaTag([
            'imeta',
            'url',
            'https://example.com/video.mp4',
            'dim',
            '720x1280',
          ]),
        );

        expect(stats.dimensions, equals('720x1280'));
      });

      test('ignores empty blurhash value in imeta', () {
        final stats = VideoStats.fromJson(
          jsonWithImetaTag(['imeta', 'blurhash ']),
        );

        expect(stats.blurhash, isNull);
      });

      test('standalone blurhash tag wins over imeta when both present', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'event-id',
            'pubkey': 'event-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'd_tag': 'video-1',
            'title': 'Test',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
            'tags': [
              ['blurhash', 'STANDALONE_HASH'],
              ['imeta', 'blurhash IMETA_HASH'],
            ],
          },
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
        });

        expect(stats.blurhash, equals('STANDALONE_HASH'));
      });
    });

    group('text-track fields', () {
      test('parses text_track_ref from top-level JSON', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'text_track_ref': '39307:abc123:subtitles:video-1',
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.textTrackRef, equals('39307:abc123:subtitles:video-1'));
      });

      test('parses text_track_content from top-level JSON', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'text_track_content':
              'WEBVTT\n\n00:00:00.000 --> 00:00:04.000\nHello',
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.textTrackContent, isNotNull);
        expect(stats.textTrackContent, contains('WEBVTT'));
      });

      test('parses text-track tag from event tags', () {
        final json = {
          'event': {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'tags': [
              ['d', 'video-1'],
              ['title', 'Test'],
              ['url', 'https://example.com/video.mp4'],
              ['thumb', 'https://example.com/thumb.jpg'],
              ['text-track', '39307:abc123:subtitles:video-1'],
            ],
          },
          'stats': {
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
          },
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.textTrackRef, equals('39307:abc123:subtitles:video-1'));
      });

      test('normalizes empty text-track fields to null', () {
        final json = {
          'id': 'test-id',
          'pubkey': 'test-pubkey',
          'created_at': 1700000000,
          'kind': 34236,
          'd_tag': 'video-1',
          'title': 'Test',
          'thumbnail': 'https://example.com/thumb.jpg',
          'video_url': 'https://example.com/video.mp4',
          'reactions': 0,
          'comments': 0,
          'reposts': 0,
          'engagement_score': 0,
          'text_track_ref': '',
          'text_track_content': '',
        };

        final stats = VideoStats.fromJson(json);

        expect(stats.textTrackRef, isNull);
        expect(stats.textTrackContent, isNull);
      });

      test(
        'preserves moderation_labels from REST responses including unknowns',
        () {
          final json = {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'd_tag': 'video-1',
            'title': 'Test',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
            'moderation_labels': [
              'nudity',
              'violence',
              // Behavior change: unknown labels (including discovery metadata
              // like 'topic:music') are now preserved rather than dropped.
              // Downstream filters treat unknown labels as a conservative
              // hide signal so the relay's labeling is never silently ignored.
              'topic:music',
              'spam',
            ],
          };

          final stats = VideoStats.fromJson(json);
          final event = stats.toVideoEvent();

          expect(
            stats.moderationLabels,
            equals(['nudity', 'violence', 'topic:music', 'spam']),
          );
          // Moderation labels go to VideoEvent.moderationLabels (ML-generated),
          // NOT contentWarningLabels (which are for author self-labels only)
          expect(event.contentWarningLabels, isEmpty);
          expect(
            event.moderationLabels,
            equals(['nudity', 'violence', 'topic:music', 'spam']),
          );
        },
      );

      test('passes textTrackRef and textTrackContent to toVideoEvent', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
          textTrackRef: '39307:abc123:subtitles:test-dtag',
          textTrackContent: 'WEBVTT\n\n00:00:00.000 --> 00:00:04.000\nHello',
        );

        final event = stats.toVideoEvent();

        expect(event.textTrackRef, equals('39307:abc123:subtitles:test-dtag'));
        expect(event.textTrackContent, contains('WEBVTT'));
      });
    });

    group('moderation labels', () {
      final hexId = 'a' * 64;
      final hexPubkey = 'b' * 64;

      Map<String, dynamic> buildJson(List<String> labels) => {
        'id': hexId,
        'pubkey': hexPubkey,
        'created_at': 1700000000,
        'kind': 34236,
        'd_tag': 'video-1',
        'title': 'Test',
        'thumbnail': 'https://example.com/thumb.jpg',
        'video_url': 'https://example.com/video.mp4',
        'reactions': 0,
        'comments': 0,
        'reposts': 0,
        'engagement_score': 0,
        'moderation_labels': labels,
      };

      test('normalizes whitespace in labels to hyphens', () {
        final stats = VideoStats.fromJson(
          buildJson(['sexual content', 'graphic media']),
        );

        expect(stats.moderationLabels, contains('sexual'));
        expect(stats.moderationLabels, contains('graphic-media'));
      });

      test('preserves unknown moderation labels instead of dropping them', () {
        final stats = VideoStats.fromJson(buildJson(['some-new-server-label']));

        expect(stats.moderationLabels, equals(['some-new-server-label']));
      });

      test('still applies known aliases', () {
        final stats = VideoStats.fromJson(
          buildJson(['pornography', 'nsfw', 'gore']),
        );

        expect(stats.moderationLabels, contains('porn'));
        expect(stats.moderationLabels, contains('nudity'));
        expect(stats.moderationLabels, contains('graphic-media'));
      });

      test('maps sexual-content alias to canonical sexual label', () {
        final stats = VideoStats.fromJson(buildJson(['sexual-content']));

        expect(stats.moderationLabels, equals(['sexual']));
      });

      test('drops empty strings', () {
        final stats = VideoStats.fromJson(buildJson(['', '   ', 'nudity']));

        expect(stats.moderationLabels, equals(['nudity']));
      });
    });

    group('collaboratorPubkeys (p tag extraction)', () {
      const authorPubkey =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const collaborator1 =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      const collaborator2 =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

      Map<String, dynamic> buildJson(List<List<Object?>> tags) => {
        'id': 'video-id',
        'pubkey': authorPubkey,
        'created_at': 1700000000,
        'kind': 34236,
        'video_url': 'https://example.com/video.mp4',
        'tags': tags,
        'reactions': 0,
        'comments': 0,
        'reposts': 0,
        'engagement_score': 0,
      };

      test('extracts p-tag pubkeys from flat JSON', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', collaborator1, '', 'collaborator'],
            ['p', collaborator2, '', 'collaborator'],
          ]),
        );

        expect(
          stats.collaboratorPubkeys,
          equals([collaborator1, collaborator2]),
        );
      });

      test('extracts p-tag pubkeys from nested event payload', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'video-id',
            'pubkey': authorPubkey,
            'created_at': 1700000000,
            'kind': 34236,
            'tags': [
              ['d', 'video-1'],
              ['url', 'https://example.com/video.mp4'],
              ['p', collaborator1, '', 'collaborator'],
            ],
          },
          'stats': {
            'reactions': 0,
            'comments': 0,
            'reposts': 0,
            'engagement_score': 0,
          },
        });

        expect(stats.collaboratorPubkeys, equals([collaborator1]));
      });

      test('excludes the event author pubkey', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', authorPubkey, '', 'collaborator'],
            ['p', collaborator1, '', 'collaborator'],
          ]),
        );

        expect(stats.collaboratorPubkeys, equals([collaborator1]));
      });

      test('deduplicates repeated p tags', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', collaborator1, '', 'collaborator'],
            ['p', collaborator1, '', 'collaborator'],
            ['p', collaborator2, '', 'collaborator'],
          ]),
        );

        expect(
          stats.collaboratorPubkeys,
          equals([collaborator1, collaborator2]),
        );
      });

      test('lowercases uppercase p-tag values and compares against author', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', collaborator1.toUpperCase(), '', 'collaborator'],
            ['p', authorPubkey.toUpperCase(), '', 'collaborator'],
          ]),
        );

        expect(stats.collaboratorPubkeys, equals([collaborator1]));
      });

      test('ignores empty p tags', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', '', '', 'collaborator'],
            ['p', collaborator1, '', 'collaborator'],
          ]),
        );

        expect(stats.collaboratorPubkeys, equals([collaborator1]));
      });

      test('returns empty list when no p tags present', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['d', 'video-1'],
            ['url', 'https://example.com/video.mp4'],
          ]),
        );

        expect(stats.collaboratorPubkeys, isEmpty);
      });

      test('forwards collaboratorPubkeys through toVideoEvent', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', collaborator1, '', 'collaborator'],
            ['p', collaborator2, '', 'collaborator'],
          ]),
        );

        final event = stats.toVideoEvent();

        expect(
          event.collaboratorPubkeys,
          equals([collaborator1, collaborator2]),
        );
        expect(event.hasCollaborators, isTrue);
      });

      test('ignores non-collaborator p-tag markers and unmarked p-tags', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', collaborator1, '', 'collaborator'],
            ['p', collaborator2, '', 'mention'],
            ['p', collaborator2],
          ]),
        );

        expect(stats.collaboratorPubkeys, equals([collaborator1]));
      });

      test('accepts historical capitalized collaborator markers', () {
        final stats = VideoStats.fromJson(
          buildJson([
            ['p', collaborator1, '', 'Collaborator'],
            ['p', collaborator2, '', 'COLLABORATOR'],
          ]),
        );

        expect(
          stats.collaboratorPubkeys,
          equals([collaborator1, collaborator2]),
        );
      });

      test('ignores malformed non-string collaborator markers', () {
        final stats = VideoStats.fromJson(
          buildJson([
            <Object?>[
              'p',
              collaborator1,
              '',
              {'role': 'collaborator'},
            ],
            ['p', collaborator2, '', 'collaborator'],
          ]),
        );

        expect(stats.collaboratorPubkeys, equals([collaborator2]));
      });
    });

    group('toVideoEvent', () {
      test('preserves raw created_at when published_at controls display', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000100,
            'kind': 34236,
            'content': 'Test',
            'tags': [
              ['d', 'video-1'],
              ['published_at', '1700000000'],
              ['url', 'https://example.com/video.mp4'],
            ],
          },
        });

        final video = stats.toVideoEvent();

        expect(video.createdAt, 1700000000);
        expect(video.nostrCreatedAt, 1700000100);
      });

      test(
        'does not treat an invalid created_at fallback as raw event time',
        () {
          final stats = VideoStats.fromJson(const {
            'event': {
              'id': 'test-id',
              'pubkey': 'test-pubkey',
              'created_at': 'not-a-date',
              'kind': 34236,
              'content': 'Test',
              'tags': [
                ['d', 'video-1'],
                ['published_at', '1700000000'],
                ['url', 'https://example.com/video.mp4'],
              ],
            },
          });

          final video = stats.toVideoEvent();

          expect(video.createdAt, 1700000000);
          expect(video.eventCreatedAt, isNull);
          expect(video.nostrCreatedAt, 1700000000);
        },
      );

      test('carries the event kind through to the VideoEvent', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'content': 'Test',
            'tags': [
              ['d', 'video-1'],
              ['url', 'https://example.com/video.mp4'],
            ],
          },
        });

        expect(stats.toVideoEvent().eventKind, equals(34236));
      });

      test('a non-addressable REST video is not mistaken for kind 34236', () {
        // Dropping the kind here left every REST-loaded video with a null
        // eventKind, so the view-event drop classifier could not tell an
        // expected kind-22 skip from a structural missing-d-tag defect
        // (#7387), and shareKind guessed 34236 off the vine-id fallback.
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 22,
            'content': 'Test',
            'tags': [
              ['url', 'https://example.com/video.mp4'],
            ],
          },
        });

        final video = stats.toVideoEvent();

        expect(video.eventKind, equals(22));
        expect(video.addressableId, isNull);
        expect(video.shareKind, equals(22));
      });

      test(
        'uses REST proof summary when compact video rows omit raw proof tags',
        () {
          final stats = VideoStats.fromJson(const {
            'event': {
              'id': 'test-id',
              'pubkey': 'test-pubkey',
              'created_at': 1700000000,
              'kind': 34236,
              'content': 'Test',
              'tags': [
                ['d', 'video-1'],
                ['url', 'https://example.com/video.mp4'],
              ],
              'proof': {
                'status': 'present',
                'level': 'basic_proof',
                'checked_at': 1779494400,
                'version': 1,
                'checks': {
                  'proofmode_present': true,
                  'proofmode_parse_ok': true,
                  'pgp_signature_present': true,
                  'pgp_signature_valid': null,
                  'device_attestation_present': false,
                  'device_attestation_valid': null,
                  'c2pa_manifest_present': false,
                  'c2pa_manifest_valid': null,
                },
              },
            },
            'stats': {
              'reactions': 0,
              'comments': 0,
              'reposts': 0,
              'engagement_score': 0,
            },
          });

          final video = stats.toVideoEvent();

          expect(video.rawTags['proofmode'], isNull);
          expect(video.proofSummary?.status, equals('present'));
          expect(video.hasProofMode, isTrue);
          expect(video.hasBasicProof, isTrue);
        },
      );

      test(
        'maps Funnelcake top-level proof fields into rawTags for list rows',
        () {
          final stats = VideoStats.fromJson(const {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'd_tag': 'video-1',
            'title': 'Test',
            'tags': [
              ['d', 'video-1'],
              ['imeta', 'url https://example.com/video.mp4'],
            ],
            'verification': 'verified_mobile',
            'proofmode':
                '{"videoHash":"abc","pgpSignature":"sig",'
                '"deviceAttestation":"att","c2paManifestId":"urn:c2pa:1"}',
            'device_attestation': '{"keyID":"k"}',
            'c2pa_manifest_id': 'urn:c2pa:1',
          });

          final video = stats.toVideoEvent();

          expect(video.rawTags['verification'], equals('verified_mobile'));
          expect(video.rawTags['c2pa_manifest_id'], equals('urn:c2pa:1'));
          expect(video.hasProofMode, isTrue);
          expect(video.hasProofModeC2paManifestId, isTrue);
          expect(video.hasProofModeDeviceAttestation, isTrue);
          expect(video.hasProofModePgpFingerprint, isTrue);
          expect(video.hasProofModeManifest, isTrue);
        },
      );

      test('converts to VideoEvent with all fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          description: 'A description',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          sha256: 'abc123',
          authorName: 'Test Author',
          authorAvatar: 'https://example.com/avatar.jpg',
          blurhash: 'LEHV6nWB2yk8',
          dimensions: '720x1280',
          reactions: 100,
          comments: 20,
          reposts: 5,
          engagementScore: 125,
          loops: 1000,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.id, equals('test-id'));
        expect(videoEvent.pubkey, equals('test-pubkey'));
        expect(videoEvent.createdAt, equals(1700000000));
        expect(videoEvent.content, equals('A description'));
        expect(videoEvent.title, equals('Test Video'));
        expect(videoEvent.videoUrl, equals('https://example.com/video.mp4'));
        expect(
          videoEvent.thumbnailUrl,
          equals('https://example.com/thumb.jpg'),
        );
        expect(videoEvent.vineId, equals('test-dtag'));
        expect(videoEvent.sha256, equals('abc123'));
        expect(videoEvent.authorName, equals('Test Author'));
        expect(
          videoEvent.authorAvatar,
          equals('https://example.com/avatar.jpg'),
        );
        expect(videoEvent.blurhash, equals('LEHV6nWB2yk8'));
        expect(videoEvent.dimensions, equals('720x1280'));
        expect(videoEvent.originalLikes, isNull);
        expect(videoEvent.nostrLikeCount, equals(100));
        expect(videoEvent.originalComments, isNull);
        expect(videoEvent.nostrCommentCount, equals(20));
        expect(videoEvent.originalReposts, isNull);
        expect(videoEvent.nostrRepostCount, equals(5));
        expect(videoEvent.originalLoops, equals(1000));
      });

      test('drops dead REST thumbnails so blurhash fallback can render', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          thumbnail:
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
          videoUrl: 'https://media.divine.video/video.mp4',
          blurhash: 'LEHV6nWB2yk8',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.thumbnailUrl, isNull);
        expect(videoEvent.blurhash, equals('LEHV6nWB2yk8'));
      });

      test('replaces dead REST video URLs with canonical sha256 media URL', () {
        const hash =
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          thumbnail: 'https://media.divine.video/thumb.jpg',
          videoUrl:
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8',
          sha256: hash,
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.videoUrl, equals('https://media.divine.video/$hash'));
        expect(videoEvent.sha256, equals(hash));
      });

      test('keeps dead REST video URL when no sha256 fallback exists', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          thumbnail: 'https://media.divine.video/thumb.jpg',
          videoUrl:
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(
          videoEvent.videoUrl,
          equals(
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/playlist.m3u8',
          ),
        );
      });

      test(
        'promotes content warning tags from REST event data into VideoEvent',
        () {
          final json = {
            'event': {
              'id': 'test-id',
              'pubkey': 'test-pubkey',
              'created_at': 1700000000,
              'kind': 34236,
              'content': 'Test',
              'tags': [
                ['d', 'video-1'],
                ['url', 'https://example.com/video.mp4'],
                ['thumb', 'https://example.com/thumb.jpg'],
                ['content-warning', 'nudity'],
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
              ],
            },
            'stats': {
              'reactions': 0,
              'comments': 0,
              'reposts': 0,
              'engagement_score': 0,
            },
          };

          final stats = VideoStats.fromJson(json);
          final event = stats.toVideoEvent();

          expect(event.rawTags['content-warning'], equals('nudity'));
          expect(event.contentWarningLabels, equals(['nudity']));
        },
      );

      test('handles empty strings by converting to null', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: '',
          title: '',
          thumbnail: '',
          videoUrl: '',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.title, isNull);
        expect(videoEvent.videoUrl, isNull);
        expect(videoEvent.thumbnailUrl, isNull);
        // When dTag is empty, vineId falls back to the event id.
        expect(videoEvent.vineId, equals('test-id'));
        expect(videoEvent.addressableDTag, isNull);
        expect(videoEvent.hasAddressableDTag, isFalse);
        expect(videoEvent.addressableId, isNull);
      });

      test('handles null description', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.content, equals(''));
      });

      test('preserves non-empty dTag as addressableDTag', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 0,
          comments: 0,
          reposts: 0,
          engagementScore: 0,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.vineId, equals('test-dtag'));
        expect(videoEvent.addressableDTag, equals('test-dtag'));
        expect(videoEvent.hasAddressableDTag, isTrue);
        expect(videoEvent.addressableId, equals('34236:test-pubkey:test-dtag'));
      });

      test(
        'propagates NIP-40 expiration tag from REST event data into VideoEvent',
        () {
          final futureExpiry =
              (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600;
          final json = {
            'event': {
              'id': 'test-id',
              'pubkey': 'test-pubkey',
              'created_at': 1700000000,
              'kind': 34236,
              'content': 'Test',
              'tags': [
                ['d', 'video-1'],
                ['url', 'https://example.com/video.mp4'],
                ['expiration', futureExpiry.toString()],
              ],
            },
            'stats': {
              'reactions': 0,
              'comments': 0,
              'reposts': 0,
              'engagement_score': 0,
            },
          };

          final stats = VideoStats.fromJson(json);
          final event = stats.toVideoEvent();

          expect(event.expirationTimestamp, equals(futureExpiry));
          expect(event.isExpired, isFalse);
        },
      );

      test(
        'sets isExpired to true when the expiration timestamp is in the past',
        () {
          final pastExpiry =
              (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 3600;
          final json = {
            'event': {
              'id': 'test-id',
              'pubkey': 'test-pubkey',
              'created_at': 1700000000,
              'kind': 34236,
              'content': 'Test',
              'tags': [
                ['d', 'video-1'],
                ['url', 'https://example.com/video.mp4'],
                ['expiration', pastExpiry.toString()],
              ],
            },
            'stats': {
              'reactions': 0,
              'comments': 0,
              'reposts': 0,
              'engagement_score': 0,
            },
          };

          final event = VideoStats.fromJson(json).toVideoEvent();

          expect(event.expirationTimestamp, equals(pastExpiry));
          expect(event.isExpired, isTrue);
        },
      );

      test('maps API engagement stats to live count fields', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'Test Video',
          thumbnail: 'https://example.com/thumb.jpg',
          videoUrl: 'https://example.com/video.mp4',
          reactions: 500,
          comments: 20,
          reposts: 5,
          engagementScore: 525,
        );

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.originalLikes, isNull);
        expect(videoEvent.nostrLikeCount, equals(500));
        expect(videoEvent.originalComments, isNull);
        expect(videoEvent.nostrCommentCount, equals(20));
        expect(videoEvent.originalReposts, isNull);
        expect(videoEvent.nostrRepostCount, equals(5));
      });

      test('maps archived engagement tags to original count fields', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1700000000,
            'kind': 34236,
            'content': 'Test',
            'tags': [
              ['d', 'video-1'],
              ['url', 'https://example.com/video.mp4'],
              ['likes', '273622'],
              ['comments', '6023'],
              ['reposts', '122059'],
            ],
          },
          'stats': {
            'reactions': 5,
            'comments': 2,
            'reposts': 3,
            'engagement_score': 10,
          },
        });

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.originalLikes, equals(273622));
        expect(videoEvent.nostrLikeCount, equals(5));
        expect(videoEvent.originalComments, equals(6023));
        expect(videoEvent.nostrCommentCount, equals(2));
        expect(videoEvent.originalReposts, equals(122059));
        expect(videoEvent.nostrRepostCount, equals(3));
      });

      test(
        'maps embedded_* counts to original fields when tags are absent',
        () {
          final stats = VideoStats.fromJson(const {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1457922740,
            'kind': 34236,
            'd_tag': 'video-1',
            'title': 'Classic vine',
            'thumbnail': 'https://example.com/thumb.jpg',
            'video_url': 'https://example.com/video.mp4',
            'loops': 142678928,
            'embedded_likes': 459878,
            'embedded_comments': 15227,
            'embedded_reposts': 179996,
            'reactions': 387,
            'comments': 10,
            'reposts': 42,
            'views': 3020,
            'engagement_score': 533,
          });

          final videoEvent = stats.toVideoEvent();

          expect(videoEvent.originalLikes, equals(459878));
          expect(videoEvent.nostrLikeCount, equals(387));
          expect(videoEvent.originalComments, equals(15227));
          expect(videoEvent.nostrCommentCount, equals(10));
          expect(videoEvent.originalReposts, equals(179996));
          expect(videoEvent.nostrRepostCount, equals(42));
          expect(videoEvent.originalLoops, equals(142678928));
          expect(videoEvent.totalLoops, equals(142678928 + 3020));
          expect(videoEvent.totalLikes, equals(459878 + 387));
        },
      );

      test('prefers embedded_* fields over archival event tags', () {
        final stats = VideoStats.fromJson(const {
          'event': {
            'id': 'test-id',
            'pubkey': 'test-pubkey',
            'created_at': 1457922740,
            'kind': 34236,
            'tags': [
              ['d', 'video-1'],
              ['url', 'https://example.com/video.mp4'],
              ['likes', '111'],
              ['comments', '222'],
              ['reposts', '333'],
            ],
          },
          'stats': {
            'reactions': 5,
            'comments': 2,
            'reposts': 3,
            'engagement_score': 10,
            'embedded_likes': 459878,
            'embedded_comments': 15227,
            'embedded_reposts': 179996,
          },
        });

        final videoEvent = stats.toVideoEvent();

        expect(videoEvent.originalLikes, equals(459878));
        expect(videoEvent.originalComments, equals(15227));
        expect(videoEvent.originalReposts, equals(179996));
      });
    });

    group('equality', () {
      test('two instances with same id are equal', () {
        final stats1 = VideoStats(
          id: 'same-id',
          pubkey: 'pubkey1',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'dtag1',
          title: 'Title 1',
          thumbnail: 'thumb1',
          videoUrl: 'video1',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        final stats2 = VideoStats(
          id: 'same-id',
          pubkey: 'pubkey2',
          createdAt: DateTime(2025),
          kind: 34236,
          dTag: 'dtag2',
          title: 'Title 2',
          thumbnail: 'thumb2',
          videoUrl: 'video2',
          reactions: 20,
          comments: 10,
          reposts: 4,
          engagementScore: 34,
        );

        expect(stats1, equals(stats2));
        expect(stats1.hashCode, equals(stats2.hashCode));
      });

      test('two instances with different ids are not equal', () {
        final stats1 = VideoStats(
          id: 'id-1',
          pubkey: 'pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'dtag',
          title: 'Title',
          thumbnail: 'thumb',
          videoUrl: 'video',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        final stats2 = VideoStats(
          id: 'id-2',
          pubkey: 'pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'dtag',
          title: 'Title',
          thumbnail: 'thumb',
          videoUrl: 'video',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        expect(stats1, isNot(equals(stats2)));
      });
    });

    group('toString', () {
      test('returns formatted string with id and title', () {
        final stats = VideoStats(
          id: 'test-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime(2024),
          kind: 34236,
          dTag: 'test-dtag',
          title: 'My Video Title',
          thumbnail: 'thumb',
          videoUrl: 'video',
          reactions: 10,
          comments: 5,
          reposts: 2,
          engagementScore: 17,
        );

        expect(
          stats.toString(),
          equals('VideoStats(id: test-id, title: My Video Title)'),
        );
      });
    });
  });
}
