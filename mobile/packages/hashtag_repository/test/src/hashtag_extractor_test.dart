// ABOUTME: Tests for the HashtagExtractor rules every published video
// ABOUTME: hashtag goes through: length, lowercase, count and separators.

import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:test/test.dart';

void main() {
  group(HashtagExtractor, () {
    final maxLength = 'a' * HashtagExtractor.maxHashtagLength;
    final tooLong = 'a' * (HashtagExtractor.maxHashtagLength + 1);

    group('isWithinLengthLimit', () {
      test('accepts a tag of exactly the maximum length', () {
        expect(HashtagExtractor.isWithinLengthLimit(maxLength), isTrue);
      });

      test('rejects a tag over the maximum length', () {
        expect(HashtagExtractor.isWithinLengthLimit(tooLong), isFalse);
      });

      test('rejects an empty tag', () {
        expect(HashtagExtractor.isWithinLengthLimit(''), isFalse);
      });
    });

    group('normalizeVideoHashtag', () {
      test('lowercases and strips non-alphanumeric characters', () {
        expect(
          HashtagExtractor.normalizeVideoHashtag('#Funny-Divines!'),
          equals('funnydivines'),
        );
      });

      test('rejects rather than truncates an over-long tag', () {
        expect(HashtagExtractor.normalizeVideoHashtag(tooLong), isNull);
      });

      test('measures the length after stripping', () {
        expect(
          HashtagExtractor.normalizeVideoHashtag('#$maxLength!'),
          equals(maxLength),
        );
      });

      test('returns null when nothing is left', () {
        expect(HashtagExtractor.normalizeVideoHashtag('#!?'), isNull);
      });
    });

    group('normalizeVideoHashtags', () {
      test('drops invalid tags and case-insensitive duplicates', () {
        expect(
          HashtagExtractor.normalizeVideoHashtags([
            'Vine',
            'vine',
            tooLong,
            '',
            'Comedy',
          ]),
          equals(['vine', 'comedy']),
        );
      });

      test('keeps at most maxHashtagsPerVideo tags, in order', () {
        final tags = [for (var i = 0; i < 15; i++) 'tag$i'];

        final result = HashtagExtractor.normalizeVideoHashtags(tags);

        expect(result, hasLength(HashtagExtractor.maxHashtagsPerVideo));
        expect(result.first, equals('tag0'));
        expect(result.last, equals('tag9'));
      });
    });

    group('separatorPattern', () {
      test('splits on whitespace, Unicode spaces, commas and #', () {
        const pasted = '#vines\n#vine\tfunny comedy,meme #fyp';

        final tokens = pasted
            .split(HashtagExtractor.separatorPattern)
            .where((t) => t.isNotEmpty);

        expect(
          tokens,
          equals(['vines', 'vine', 'funny', 'comedy', 'meme', 'fyp']),
        );
      });
    });
  });
}
