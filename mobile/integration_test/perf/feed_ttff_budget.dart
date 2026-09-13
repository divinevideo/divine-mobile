import 'package:infinite_video_feed/infinite_video_feed.dart';

import 'feed_percentile.dart';

/// Number of distinct feed activations in the TTFF sample.
const feedTtffSampleCount = 10;

/// Maximum allowed p90 activation-to-first-frame time at 5 Mbps.
const feedTtffP90Budget = Duration(seconds: 5);

/// Returns the nearest-rank percentile from a non-empty metric collection.
Duration feedTtffPercentile(
  Iterable<FeedFirstFrameMetric> metrics, {
  required int percentile,
}) {
  return feedPercentile(
    metrics.map((metric) => metric.duration).toList(),
    percentile,
  );
}

/// Human-readable sample table included in assertion failures and CI logs.
String formatFeedTtffSamples(Iterable<FeedFirstFrameMetric> metrics) {
  final buffer = StringBuffer('Feed TTFF samples:\n');
  for (final metric in metrics) {
    buffer.writeln(
      'index=${metric.index} videoId=${metric.videoId} '
      'durationMs=${metric.duration.inMilliseconds} '
      'controllerInitializedMs='
      '${metric.controllerInitializedAt?.inMilliseconds} '
      'sourceReadyMs=${metric.sourceReadyAt?.inMilliseconds} '
      'playbackRequestedMs=${metric.playbackRequestedAt?.inMilliseconds} '
      'cache=${metric.loadedFromCache ? 'hit' : 'miss'}',
    );
  }
  return buffer.toString().trimRight();
}
