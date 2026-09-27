// ABOUTME: Unit tests for shared profile/enrichment tag merge (#3384).

import 'package:flutter_test/flutter_test.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group('mergeVideoRawTagsPrimaryWins', () {
    test('primary wins on ordinary keys; views uses max', () {
      final merged = mergeVideoRawTagsPrimaryWins(
        {'d': 'x', 'title': 'Nostr', 'views': '0'},
        {'d': 'x', 'views': '100', 'k': 'rest-only'},
      );
      expect(merged['title'], equals('Nostr'));
      expect(merged['k'], equals('rest-only'));
      expect(merged['views'], equals('100'));
    });

    test('leaves merged map unchanged when neither side parses views', () {
      final merged = mergeVideoRawTagsPrimaryWins(
        {'d': 'x', 'views': ''},
        {'d': 'x', 'views': '   '},
      );
      expect(merged['views'], equals(''));
    });

    test('parses comma-separated and fractional views then takes max', () {
      expect(
        mergeVideoRawTagsPrimaryWins(
          {'views': '1,000'},
          {'views': '999'},
        )['views'],
        equals('1000'),
      );
      expect(
        mergeVideoRawTagsPrimaryWins(
          {'views': '3'},
          {'views': '12.7'},
        )['views'],
        equals('13'),
      );
    });

    test('keeps the higher count when aliases differ across edits', () {
      final merged = mergeVideoRawTagsPrimaryWins(
        {'unique_viewers': '5'},
        {'unique_views': '100'},
      );
      expect(merged['unique_viewers'], equals('100'));
      expect(merged.containsKey('unique_views'), isFalse);
    });

    test('keeps the higher unique-viewer count across edits', () {
      final merged = mergeVideoRawTagsPrimaryWins(
        {'unique_viewers': '5', 'title': 'newer'},
        {'unique_viewers': '100', 'title': 'older'},
      );
      expect(merged['title'], equals('newer'));
      expect(merged['unique_viewers'], equals('100'));
    });

    test('ignores negative parsed counts for max', () {
      final merged = mergeVideoRawTagsPrimaryWins(
        {'views': '-1'},
        {'views': '40'},
      );
      expect(merged['views'], equals('40'));
    });
  });

  group('mergeNullableEngagementMax', () {
    test('null handling and max with zero', () {
      expect(mergeNullableEngagementMax(null, null), isNull);
      expect(mergeNullableEngagementMax(0, 9), equals(9));
      expect(mergeNullableEngagementMax(9, 0), equals(9));
    });

    test('equal non-null values', () {
      expect(mergeNullableEngagementMax(12, 12), equals(12));
    });

    test('non-null with null picks present value', () {
      expect(mergeNullableEngagementMax(null, 7), equals(7));
      expect(mergeNullableEngagementMax(7, null), equals(7));
    });
  });
}
