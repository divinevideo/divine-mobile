import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';

import '../../integration_test/perf/feed_ttff_budget.dart';

void main() {
  group('feed TTFF budget', () {
    FeedFirstFrameMetric metric(int milliseconds, int index) {
      return FeedFirstFrameMetric(
        videoId: index.toRadixString(16).padLeft(64, '0'),
        index: index,
        duration: Duration(milliseconds: milliseconds),
        loadedFromCache: index.isEven,
      );
    }

    test('uses nearest-rank p90 independent of input order', () {
      final samples = <FeedFirstFrameMetric>[
        metric(1000, 0),
        metric(9000, 1),
        metric(3000, 2),
        metric(2000, 3),
        metric(8000, 4),
        metric(4000, 5),
        metric(5000, 6),
        metric(7000, 7),
        metric(6000, 8),
        metric(10000, 9),
      ];

      expect(
        feedTtffPercentile(samples, percentile: 90),
        const Duration(seconds: 9),
      );
    });

    test('rejects empty samples and invalid percentiles', () {
      expect(
        () => feedTtffPercentile(const [], percentile: 90),
        throwsArgumentError,
      );
      expect(
        () => feedTtffPercentile([metric(1, 0)], percentile: 0),
        throwsRangeError,
      );
    });

    test('formats actionable per-video evidence', () {
      final output = formatFeedTtffSamples([metric(1234, 7)]);

      expect(output, contains('index=7'));
      expect(
        output,
        contains(
          'videoId=0000000000000000000000000000000000000000000000000000000000000007',
        ),
      );
      expect(output, contains('durationMs=1234'));
      expect(output, contains('cache=miss'));
    });
  });
}
