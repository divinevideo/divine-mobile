// ABOUTME: Tests for the canonical divine.video share-URL regexes and builders.
// ABOUTME: Covers casing, trailing punctuation, query strings, id shapes, and
// ABOUTME: the author query parameter (#10929).

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('divineVideoUrlLineRegex', () {
    test('matches a standalone canonical divine.video URL line', () {
      expect(
        divineVideoUrlLineRegex.hasMatch('https://divine.video/video/abc123'),
        isTrue,
      );
    });

    test('matches a line that names the author', () {
      expect(
        divineVideoUrlLineRegex.hasMatch(
          'https://divine.video/video/abc123?author=${'a' * 64}',
        ),
        isTrue,
      );
    });

    test('rejects a line with any other query string', () {
      expect(
        divineVideoUrlLineRegex.hasMatch(
          'https://divine.video/video/abc123?author=not-a-pubkey',
        ),
        isFalse,
      );
    });

    test('rejects surrounding non-URL text on the same line', () {
      expect(
        divineVideoUrlLineRegex.hasMatch(
          'watch https://divine.video/video/abc123 now',
        ),
        isFalse,
      );
    });
  });

  group('divineVideoUrlRegex', () {
    const validId = 'abc123def456';

    String? firstDivineVideoUrl(String content) =>
        divineVideoUrlRegex.firstMatch(content)?.group(0);

    test('returns null when content has no URL', () {
      expect(firstDivineVideoUrl('just plain text'), isNull);
    });

    test('extracts canonical https URL', () {
      expect(
        firstDivineVideoUrl('see https://divine.video/video/$validId'),
        equals('https://divine.video/video/$validId'),
      );
    });

    test('extracts http URL (no scheme upgrade)', () {
      expect(
        firstDivineVideoUrl('http://divine.video/video/$validId here'),
        equals('http://divine.video/video/$validId'),
      );
    });

    test('extracts URL with www subdomain', () {
      expect(
        firstDivineVideoUrl(
          'check https://www.divine.video/video/$validId',
        ),
        equals('https://www.divine.video/video/$validId'),
      );
    });

    group('casing', () {
      test('matches HTTPS in uppercase', () {
        expect(
          firstDivineVideoUrl('HTTPS://DIVINE.VIDEO/VIDEO/$validId'),
          equals('HTTPS://DIVINE.VIDEO/VIDEO/$validId'),
        );
      });

      test('matches mixed-case host and path', () {
        expect(
          firstDivineVideoUrl('https://Divine.Video/Video/$validId'),
          equals('https://Divine.Video/Video/$validId'),
        );
      });
    });

    group('trailing punctuation', () {
      test('strips trailing period', () {
        expect(
          firstDivineVideoUrl(
            'watch this: https://divine.video/video/$validId.',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('strips trailing comma', () {
        expect(
          firstDivineVideoUrl(
            'see https://divine.video/video/$validId, nice right?',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('strips trailing closing paren', () {
        expect(
          firstDivineVideoUrl(
            'parenthetical (https://divine.video/video/$validId)',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('strips trailing exclamation mark', () {
        expect(
          firstDivineVideoUrl('https://divine.video/video/$validId!'),
          equals('https://divine.video/video/$validId'),
        );
      });
    });

    group('query strings and fragments', () {
      test('excludes ?query=string from match', () {
        expect(
          firstDivineVideoUrl(
            'https://divine.video/video/$validId?utm=share',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('excludes #fragment from match', () {
        expect(
          firstDivineVideoUrl(
            'https://divine.video/video/$validId#t=10',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });
    });

    group('ID shapes', () {
      test('matches 64-char hex event ID', () {
        const hexId =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        expect(
          firstDivineVideoUrl('https://divine.video/video/$hexId'),
          equals('https://divine.video/video/$hexId'),
        );
      });

      test('matches hyphenated d-tag', () {
        const dTag = 'my-video-d-tag-2026';
        expect(
          firstDivineVideoUrl('https://divine.video/video/$dTag'),
          equals('https://divine.video/video/$dTag'),
        );
      });

      test('matches alphanumeric d-tag with underscore', () {
        const dTag = 'abc_123_xyz';
        expect(
          firstDivineVideoUrl('https://divine.video/video/$dTag'),
          equals('https://divine.video/video/$dTag'),
        );
      });
    });

    group('rejects non-canonical shapes', () {
      test('rejects non-divine domain', () {
        expect(
          firstDivineVideoUrl('https://example.com/video/$validId'),
          isNull,
        );
      });

      test('rejects /video/ path missing the id', () {
        expect(
          firstDivineVideoUrl('https://divine.video/video/'),
          isNull,
        );
      });

      test('rejects non-/video/ path on divine.video', () {
        expect(
          firstDivineVideoUrl('https://divine.video/profile/$validId'),
          isNull,
        );
      });
    });

    test('extracts first URL when content has multiple', () {
      expect(
        firstDivineVideoUrl(
          'a https://divine.video/video/aaa111 b https://divine.video/video/bbb222',
        ),
        equals('https://divine.video/video/aaa111'),
      );
    });
  });

  // #10929: a d tag is not unique across accounts, so share links name the
  // author and the parsers read it back.
  group('divineVideoUrlRegex author', () {
    const author =
        'e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3';

    test('captures the author and spans it in the match', () {
      const url = 'https://divine.video/video/abc123?author=$author';
      final match = divineVideoUrlRegex.firstMatch('look $url then');

      expect(match?.group(0), equals(url));
      expect(match?.group(1), equals('abc123'));
      expect(match?.group(2), equals(author));
    });

    test('leaves the author group empty for a link without one', () {
      final match = divineVideoUrlRegex.firstMatch(
        'https://divine.video/video/abc123',
      );

      expect(match?.group(1), equals('abc123'));
      expect(match?.group(2), isNull);
    });

    test('does not take a value longer than a pubkey as the author', () {
      final match = divineVideoUrlRegex.firstMatch(
        'https://divine.video/video/abc123?author=${author}ff',
      );

      expect(match?.group(0), equals('https://divine.video/video/abc123'));
      expect(match?.group(2), isNull);
    });
  });

  group('divineVideoShareUrl', () {
    const author =
        'e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3e7d3';

    test('names a hex author in the query, lower-cased', () {
      expect(
        divineVideoShareUrl('abc123', authorPubkey: author.toUpperCase()),
        equals('https://divine.video/video/abc123?author=$author'),
      );
    });

    test('omits the query when no usable author is known', () {
      expect(
        divineVideoShareUrl('abc123'),
        equals('https://divine.video/video/abc123'),
      );
      expect(
        divineVideoShareUrl('abc123', authorPubkey: 'npub1notahexkey'),
        equals('https://divine.video/video/abc123'),
      );
    });

    test('round-trips through divineVideoUrlRegex', () {
      final url = divineVideoShareUrl('abc123', authorPubkey: author);
      final match = divineVideoUrlRegex.firstMatch(url);

      expect(match?.group(1), equals('abc123'));
      expect(match?.group(2), equals(author));
      expect(divineVideoUrlLineRegex.hasMatch(url), isTrue);
    });
  });

  group('divineVideoUrlWithAuthor', () {
    test('appends the author to a link on another base', () {
      expect(
        divineVideoUrlWithAuthor('https://example.test/video/x', 'b' * 64),
        equals('https://example.test/video/x?author=${'b' * 64}'),
      );
    });
  });
}
