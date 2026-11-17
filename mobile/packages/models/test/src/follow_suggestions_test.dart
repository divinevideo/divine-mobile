// ABOUTME: Tests the wire contract for creator recommendations.
// ABOUTME: Preserves full keys, archive provenance and opaque cursors.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('FollowSuggestion.fromJson', () {
    test('preserves full identity and independent archive provenance', () {
      final key = 'a' * 64;
      final suggestion = FollowSuggestion.fromJson({
        'pubkey': key,
        'profile': {'display_name': 'Restored creator'},
        'reason': 'follow_graph',
        'is_classic': true,
      });
      expect(suggestion.pubkey, key);
      expect(suggestion.profile.pubkey, key);
      expect(suggestion.profile.displayName, 'Restored creator');
      expect(suggestion.reason, 'follow_graph');
      expect(suggestion.isClassic, isTrue);
    });

    test('legacy responses keep the creator without a video preview', () {
      final suggestion = FollowSuggestion.fromJson({'pubkey': 'a' * 64});
      expect(suggestion.videoPreview, isNull);
      expect(suggestion.pubkey, 'a' * 64);
    });

    test('preserves a genuine preview identity and canonical thumbnail', () {
      final suggestion = FollowSuggestion.fromJson({
        'pubkey': 'a' * 64,
        'video_preview': {
          'id': 'b' * 64,
          'thumbnail_url': 'https://media.example.test/image.jpg?version=1',
          'blurhash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        },
      });
      final preview = suggestion.videoPreview!;
      expect(preview.id, 'b' * 64);
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
        {'id': 'b' * 64, 'thumbnail_url': ''},
        {'id': 'b' * 63, 'thumbnail_url': 'https://example.test/image.jpg'},
        {'id': 'B' * 64, 'thumbnail_url': 'https://example.test/image.jpg'},
        {'id': 'b' * 64, 'thumbnail_url': 12},
        {'id': 'b' * 64, 'thumbnail_url': '/image.jpg'},
        {'id': 'b' * 64, 'thumbnail_url': 'javascript:alert(1)'},
        {'id': 'b' * 64, 'thumbnail_url': 'https://user:pass@example.test/x'},
        {'id': 'b' * 64, 'thumbnail_url': ' https://example.test/image.jpg'},
      ]) {
        final suggestion = FollowSuggestion.fromJson({
          'pubkey': 'a' * 64,
          'video_preview': preview,
        });
        expect(suggestion.videoPreview, isNull);
        expect(suggestion.pubkey, 'a' * 64);
      }
    });

    test('empty or mistyped blurhash leaves the valid image usable', () {
      for (final blurhash in ['', ' ', 42]) {
        final suggestion = FollowSuggestion.fromJson({
          'pubkey': 'a' * 64,
          'video_preview': {
            'id': 'b' * 64,
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
      for (final key in ['a' * 63, 'g' * 64]) {
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
  });
}
