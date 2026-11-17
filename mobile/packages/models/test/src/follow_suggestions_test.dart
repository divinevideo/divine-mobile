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
