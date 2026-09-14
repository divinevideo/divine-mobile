import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/perf/feed_percentile.dart';

void main() {
  group('feed percentile', () {
    test('uses the nearest rank for p50 and p90', () {
      final values = <double>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

      // Nearest rank: p90 of ten samples is the ninth smallest, not the tenth.
      expect(feedPercentile(values, 90), 9);
      expect(feedPercentile(values, 50), 5);
      expect(feedPercentile(values, 1), 1);
      expect(feedPercentile(values, 100), 10);
    });

    test('is independent of input order', () {
      final ascending = <double>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final shuffled = <double>[9, 1, 5, 10, 3, 7, 2, 8, 4, 6];

      expect(feedPercentile(shuffled, 90), feedPercentile(ascending, 90));
      expect(feedPercentile(shuffled, 50), feedPercentile(ascending, 50));
    });

    test('does not reorder the caller list', () {
      final values = <double>[9, 1, 5];

      feedPercentile(values, 50);

      expect(values, [9, 1, 5]);
    });

    test('works on durations', () {
      final values = <Duration>[
        const Duration(milliseconds: 100),
        const Duration(milliseconds: 900),
        const Duration(milliseconds: 300),
        const Duration(milliseconds: 200),
        const Duration(milliseconds: 800),
        const Duration(milliseconds: 400),
        const Duration(milliseconds: 500),
        const Duration(milliseconds: 700),
        const Duration(milliseconds: 600),
        const Duration(milliseconds: 1000),
      ];

      expect(
        feedPercentile(values, 90),
        const Duration(milliseconds: 900),
      );
    });

    test('rejects empty input and invalid percentiles', () {
      expect(() => feedPercentile(<double>[], 90), throwsArgumentError);
      expect(() => feedPercentile(<double>[1], 0), throwsRangeError);
      expect(() => feedPercentile(<double>[1], 101), throwsRangeError);
    });
  });
}
