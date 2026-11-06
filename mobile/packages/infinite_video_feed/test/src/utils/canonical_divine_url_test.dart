import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';

void main() {
  group('B2 host recognition', () {
    const hash =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    for (final host in ['media-b2.divine.video', 'media-b2-cdn.divine.video']) {
      test('recognizes exact original on $host', () {
        expect(isB2OriginalPlaybackSource('https://$host/$hash'), isTrue);
        for (final suffix in ['/720p.mp4', '?token=private', '#fragment']) {
          expect(
            isB2OriginalPlaybackSource('https://$host/$hash$suffix'),
            isFalse,
          );
        }
      });
    }
    test('rejects an unapproved host', () {
      expect(
        isB2OriginalPlaybackSource(
          'https://media-b2-cdn.divine.video.evil.test/$hash',
        ),
        isFalse,
      );
    });
  });
  group('extractCanonicalDivineBlobHash', () {
    const validHash =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    test('returns hash for a canonical media.divine.video URL', () {
      const url = 'https://media.divine.video/$validHash';
      expect(extractCanonicalDivineBlobHash(url), equals(validHash));
    });

    test('returns hash for a URL with extra path segments', () {
      const url = 'https://media.divine.video/$validHash/hls/master.m3u8';
      expect(extractCanonicalDivineBlobHash(url), equals(validHash));
    });

    test('returns null for a non-divine URL', () {
      expect(
        extractCanonicalDivineBlobHash('https://example.com/$validHash'),
        isNull,
      );
    });

    test('returns null when hash is too short', () {
      expect(
        extractCanonicalDivineBlobHash('https://media.divine.video/abc123'),
        isNull,
      );
    });

    test('returns null when hash contains non-hex characters', () {
      const badHash =
          'g1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      expect(
        extractCanonicalDivineBlobHash('https://media.divine.video/$badHash'),
        isNull,
      );
    });

    test('returns null for an empty path', () {
      expect(
        extractCanonicalDivineBlobHash('https://media.divine.video/'),
        isNull,
      );
    });

    test('returns null for a malformed URL (FormatException)', () {
      expect(extractCanonicalDivineBlobHash('not a url ://:'), isNull);
    });

    test('is case-insensitive for the host', () {
      const url = 'https://MEDIA.DIVINE.VIDEO/$validHash';
      expect(extractCanonicalDivineBlobHash(url), equals(validHash));
    });
  });

  group('canonicalDivineBlobHlsUrl', () {
    test('builds the expected HLS master URL', () {
      const hash =
          'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      expect(
        canonicalDivineBlobHlsUrl(hash),
        equals('https://media.divine.video/$hash/hls/master.m3u8'),
      );
    });
  });

  group('isDivineBlobRawUrl', () {
    const hash =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    test('recognizes query-bearing and alternate-host raw blobs', () {
      expect(
        isDivineBlobRawUrl('https://media.divine.video/$hash?download=1'),
        isTrue,
      );
      expect(isDivineBlobRawUrl('https://cdn.divine.video/$hash'), isTrue);
      expect(isDivineBlobRawUrl('https://blossom.divine.video/$hash/'), isTrue);
    });

    test('rejects derivatives and non-Divine URLs', () {
      expect(
        isDivineBlobRawUrl('https://media.divine.video/$hash/720p.mp4'),
        isFalse,
      );
      expect(isDivineBlobRawUrl('https://example.com/$hash'), isFalse);
    });
  });

  group('canonicalDivineBlobRawUrl', () {
    test('builds the expected raw blob URL', () {
      const hash =
          'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      expect(
        canonicalDivineBlobRawUrl(hash),
        equals('https://media.divine.video/$hash'),
      );
    });
  });

  group('orderedUniqueSources', () {
    test('deduplicates while preserving order', () {
      expect(
        orderedUniqueSources(['a', 'b', 'a', 'c']),
        equals(['a', 'b', 'c']),
      );
    });

    test('skips null entries', () {
      expect(orderedUniqueSources([null, 'a', null, 'b']), equals(['a', 'b']));
    });

    test('skips empty string entries', () {
      expect(orderedUniqueSources(['', 'a', '', 'b']), equals(['a', 'b']));
    });

    test('returns empty list for all-null input', () {
      expect(orderedUniqueSources([null, null]), isEmpty);
    });

    test('returns single element for one unique value', () {
      expect(orderedUniqueSources(['x']), equals(['x']));
    });
  });
}
