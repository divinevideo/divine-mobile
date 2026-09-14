// ABOUTME: Enforces fullscreen-feed first-frame latency on the native player.
// ABOUTME: Uses local rate-limited video fixtures without auth or backend state.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'feed_perf_fixtures.dart';
import 'feed_ttff_budget.dart';

Future<FeedFirstFrameMetric> _waitForSample(
  StreamIterator<FeedFirstFrameMetric> samples,
  int count,
) async {
  final received = await samples.moveNext().timeout(
    const Duration(seconds: 15),
    onTimeout: () => false,
  );
  expect(
    received,
    isTrue,
    reason: 'No native first-frame metric for sample $count',
  );
  return samples.current;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('feed TTFF', () {
    testWidgets(
      'stays within the 5 Mbps p90 budget',
      (tester) async {
        final cache = installFeedPerfMediaCacheMock();

        final metrics = StreamIterator(FeedFirstFrameMetrics.events);
        addTearDown(metrics.cancel);
        final feedKey = GlobalKey<InfiniteVideoFeedState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InfiniteVideoFeed(
                key: feedKey,
                videos: feedPerfVideos(feedTtffSampleCount),
                cache: cache,
                prefetchCount: 0,
                keepPreviousAlive: false,
                keepNextAlive: false,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          ),
        );

        final samples = <FeedFirstFrameMetric>[
          await _waitForSample(metrics, 1),
        ];
        for (var expected = 2; expected <= feedTtffSampleCount; expected++) {
          feedKey.currentState!.debugActivatePage(expected - 1);
          samples.add(await _waitForSample(metrics, expected));
        }

        for (final metric in samples) {
          // Kept machine-readable for the retained Codemagic log artifact.
          debugPrint(
            'FEED_TTFF videoId=${metric.videoId} index=${metric.index} '
            'durationMs=${metric.duration.inMilliseconds} '
            'controllerInitializedMs='
            '${metric.controllerInitializedAt?.inMilliseconds} '
            'sourceReadyMs=${metric.sourceReadyAt?.inMilliseconds} '
            'playbackRequestedMs=${metric.playbackRequestedAt?.inMilliseconds} '
            'cache=${metric.loadedFromCache ? 'hit' : 'miss'}',
          );
        }
        final p90 = feedTtffPercentile(samples, percentile: 90);
        final evidence = formatFeedTtffSamples(samples);
        debugPrint('$evidence\nFeed TTFF p90=${p90.inMilliseconds}ms');
        expect(
          p90,
          lessThanOrEqualTo(feedTtffP90Budget),
          reason:
              '$evidence\n'
              'p90=${p90.inMilliseconds}ms exceeded '
              '${feedTtffP90Budget.inMilliseconds}ms',
        );
      },
      timeout: const Timeout(Duration(minutes: 4)),
    );
  });
}
