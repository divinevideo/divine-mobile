import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/hashtag_extractor.dart';

void main() {
  group('HashtagExtractor', () {
    test('extracts hashtags from text', () {
      final hashtags = HashtagExtractor.extractHashtags(
        'This is a #funny #vine about #coding and #bitcoin!',
      );

      expect(hashtags, equals(['funny', 'vine', 'coding', 'bitcoin']));
    });

    test('validates hashtag format', () {
      expect(HashtagExtractor.isValidHashtag('funny'), isTrue);
      expect(HashtagExtractor.isValidHashtag('coding123'), isTrue);
      expect(HashtagExtractor.isValidHashtag('my_tag'), isTrue);

      expect(HashtagExtractor.isValidHashtag(''), isFalse);
      expect(HashtagExtractor.isValidHashtag('123invalid'), isFalse);
      expect(HashtagExtractor.isValidHashtag('has-dash'), isFalse);
      expect(HashtagExtractor.isValidHashtag('has space'), isFalse);
    });

    test('normalizes hashtags', () {
      final normalized = HashtagExtractor.normalizeHashtags([
        'FUNNY',
        'Coding',
        'bitcoin!',
        'my-tag',
        'valid_tag',
      ]);

      expect(
        normalized,
        equals(['funny', 'coding', 'bitcoin', 'mytag', 'valid_tag']),
      );
    });

    test('combines caption and additional hashtags', () {
      final combined = HashtagExtractor.combineHashtags(
        caption: 'Check out this #funny video!',
        additionalHashtags: [
          'nostrvine',
          'comedy',
          'funny',
        ], // 'funny' should be deduplicated
      );

      expect(combined, equals(['funny', 'nostrvine', 'comedy']));
    });

    test('provides relevant suggestions', () {
      final suggestions = HashtagExtractor.getSuggestedHashtags(
        caption: 'Funny dance video with music',
        maxSuggestions: 3,
      );

      expect(suggestions, contains('funny'));
      expect(suggestions, contains('dance'));
      expect(suggestions.length, equals(3));
    });

    test('handles empty input', () {
      expect(HashtagExtractor.extractHashtags(''), isEmpty);
      expect(HashtagExtractor.normalizeHashtags([]), isEmpty);
      expect(HashtagExtractor.combineHashtags(caption: ''), isEmpty);
    });

    test('limits hashtag count', () {
      final manyHashtags = List.generate(25, (i) => '#tag$i').join(' ');
      final extracted = HashtagExtractor.extractHashtags(manyHashtags);

      expect(extracted.length, equals(HashtagExtractor.maxHashtagCount));
    });

    test('calculates hashtag statistics', () {
      final stats = HashtagExtractor.getHashtagStats([
        'valid',
        'also_valid',
        '123invalid',
        'another_valid',
      ]);

      expect(stats.totalCount, equals(4));
      expect(stats.validCount, equals(3));
      expect(stats.invalidCount, equals(1));
      expect(stats.hasInvalidHashtags, isTrue);
    });
  });
}
