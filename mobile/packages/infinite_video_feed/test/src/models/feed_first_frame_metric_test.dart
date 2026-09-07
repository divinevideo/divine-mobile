import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';

void main() {
  group(FeedFirstFrameMetrics, () {
    test('publishes a full-id measurement exactly once', () async {
      const videoId =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final metricFuture = FeedFirstFrameMetrics.events.first;
      final timer = FeedFirstFrameMetrics.start(videoId: videoId, index: 4);

      final first = timer.complete(loadedFromCache: true);
      final second = timer.complete(loadedFromCache: true);
      final published = await metricFuture;

      expect(first, same(published));
      expect(second, isNull);
      expect(published.videoId, videoId);
      expect(published.index, 4);
      expect(published.loadedFromCache, isTrue);
      expect(published.duration, greaterThanOrEqualTo(Duration.zero));
    });
  });
}
