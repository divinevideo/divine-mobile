// ABOUTME: Tests the wire contract for creator recommendations.
// ABOUTME: Preserves full keys, archive provenance and opaque cursors.

import 'package:models/models.dart';
import 'package:test/test.dart';

const _pubkey1 =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _pubkey2 =
    'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
const _videoId =
    'e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13';

void main() {
  group('FollowSuggestion.fromJson', () {
    test('preserves full identity and independent archive provenance', () {
      final suggestion = FollowSuggestion.fromJson({
        'pubkey': _pubkey1,
        'profile': {'display_name': 'Restored creator'},
        'reason': 'follow_graph',
        'is_classic': true,
      });
      expect(suggestion.pubkey, _pubkey1);
      expect(suggestion.profile.pubkey, _pubkey1);
      expect(suggestion.profile.displayName, 'Restored creator');
      expect(suggestion.reason, 'follow_graph');
      expect(suggestion.isClassic, isTrue);
    });

    test('legacy responses keep the creator without a video preview', () {
      final suggestion = FollowSuggestion.fromJson({'pubkey': _pubkey1});
      expect(suggestion.videoPreview, isNull);
      expect(suggestion.pubkey, _pubkey1);
    });

    test('preserves a genuine preview identity and canonical thumbnail', () {
      final suggestion = FollowSuggestion.fromJson({
        'pubkey': _pubkey1,
        'video_preview': {
          'id': _videoId,
          'thumbnail_url': 'https://media.example.test/image.jpg?version=1',
          'blurhash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        },
      });
      final preview = suggestion.videoPreview!;
      expect(preview.id, _videoId);
      expect(
        preview.thumbnailUrl,
        'https://media.example.test/image.jpg?version=1',
      );
      expect(preview.blurhash, 'LEHV6nWB2yk8pyo0adR*.7kCMdnj');
    });

    test('malformed optional previews never discard a usable creator', () {
      for (final preview in [
        null,
        'not a preview',
        <Object>[],
        <String, Object>{},
        {'id': _videoId, 'thumbnail_url': ''},
        {
          'id': _videoId.substring(1),
          'thumbnail_url': 'https://example.test/image.jpg',
        },
        {
          'id': _videoId.toUpperCase(),
          'thumbnail_url': 'https://example.test/image.jpg',
        },
        {'id': _videoId, 'thumbnail_url': 12},
        {'id': _videoId, 'thumbnail_url': '/image.jpg'},
        {'id': _videoId, 'thumbnail_url': 'javascript:alert(1)'},
        {'id': _videoId, 'thumbnail_url': 'https://user:pass@example.test/x'},
        {'id': _videoId, 'thumbnail_url': ' https://example.test/image.jpg'},
      ]) {
        final suggestion = FollowSuggestion.fromJson({
          'pubkey': _pubkey1,
          'video_preview': preview,
        });
        expect(suggestion.videoPreview, isNull);
        expect(suggestion.pubkey, _pubkey1);
      }
    });

    test('empty or mistyped blurhash leaves the valid image usable', () {
      for (final blurhash in ['', ' ', 42]) {
        final suggestion = FollowSuggestion.fromJson({
          'pubkey': _pubkey1,
          'video_preview': {
            'id': _videoId,
            'thumbnail_url': 'http://127.0.0.1/image.jpg',
            'blurhash': blurhash,
          },
        });
        expect(
          suggestion.videoPreview!.thumbnailUrl,
          'http://127.0.0.1/image.jpg',
        );
        expect(suggestion.videoPreview!.blurhash, isNull);
      }
    });

    test('rejects incomplete and nonhex public keys', () {
      for (final key in [_pubkey1.substring(1), 'g' * 64]) {
        expect(
          () => FollowSuggestion.fromJson({'pubkey': key}),
          throwsFormatException,
        );
      }
    });
  });

  group('FollowSuggestionsPage.fromJson', () {
    test('keeps a continuation even when the page has no suggestions', () {
      final page = FollowSuggestionsPage.fromJson({
        'suggestions': <Object>[],
        'next_cursor': 'opaque +/?=',
      });
      expect(page.suggestions, isEmpty);
      expect(page.nextCursor, 'opaque +/?=');
    });

    test('skips malformed rows while preserving valid rows and cursor', () {
      final page = FollowSuggestionsPage.fromJson({
        'suggestions': [
          'not-a-map',
          <String, Object?>{},
          {'pubkey': _pubkey1.toUpperCase()},
          {'pubkey': 'not-hex'},
          {'pubkey': _pubkey1, 'profile': 'wrong-type'},
          {
            'pubkey': _pubkey1,
            'profile': {'display_name': 'Valid one'},
            'reason': 42,
            'is_classic': false,
          },
          {
            'pubkey': _pubkey2,
            'profile': {'name': 'Valid two'},
            'reason': 'classic',
            'is_classic': true,
          },
        ],
        'next_cursor': 'cursor-2',
      });
      expect(
        page.suggestions.map((item) => item.pubkey),
        equals([_pubkey1, _pubkey2]),
      );
      expect(page.suggestions.first.reason, equals('popular'));
      expect(page.suggestions.last.isClassic, isTrue);
      expect(page.nextCursor, equals('cursor-2'));
    });
  });
}
