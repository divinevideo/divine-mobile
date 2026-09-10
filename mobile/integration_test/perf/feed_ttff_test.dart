// ABOUTME: Enforces fullscreen-feed first-frame latency on the native player.
// ABOUTME: Uses local rate-limited video fixtures without auth or backend state.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';

import 'feed_ttff_budget.dart';

const _baseUrl = String.fromEnvironment(
  'FEED_TTFF_BASE_URL',
  defaultValue: 'http://127.0.0.1:8765',
);

const _fixtureNames = <String>[
  '0cfc8ec503ae05856ec43165bebb7d0d2a3759b2900e38f509b8d08154ef6dc2.mp4',
  '606486ed7079b4b2614e9ca3e0f46c1c9a4a39d52c90dd25a9e51d1b7cf96b33.mp4',
  '6c7bf42367895238e3bd20b12e95a171e9a37a41e2b9b18b89f228de38e9f827.mp4',
];

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockDownload extends Mock implements CancellableDownload {}

List<VideoEvent> _videos() => List.generate(
  feedTtffWarmupCount + feedTtffSampleCount,
  (index) {
    final id = index.toRadixString(16).padLeft(64, '0');
    return VideoEvent(
      id: id,
      pubkey: '1'.padLeft(64, '1'),
      createdAt: index,
      content: '',
      timestamp: DateTime.utc(2026),
      videoUrl:
          '$_baseUrl/${_fixtureNames[index % _fixtureNames.length]}'
          '?sample=$index',
    );
  },
);

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
        final cache = _MockMediaCacheManager();
        final download = _MockDownload();
        when(() => cache.getCachedFileSync(any())).thenReturn(null);
        when(() => cache.removeCachedFile(any())).thenAnswer((_) async {});
        when(() => download.file).thenAnswer((_) async => null);
        when(
          () => download.result,
        ).thenAnswer((_) async => const CancellableDownloadResult(file: null));
        when(() => download.isCancelled).thenReturn(false);
        when(download.cancel).thenReturn(null);
        final cancellable = CancellableCacheOperation.fromDownload(download);
        when(
          () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
        ).thenReturn(cancellable);

        final metrics = StreamIterator(FeedFirstFrameMetrics.events);
        addTearDown(metrics.cancel);
        final feedKey = GlobalKey<InfiniteVideoFeedState>();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: InfiniteVideoFeed(
                key: feedKey,
                videos: _videos(),
                cache: cache,
                prefetchCount: 0,
                keepPreviousAlive: false,
                keepNextAlive: false,
                preloadGracePeriod: Duration.zero,
              ),
            ),
          ),
        );

        // Prime the emulator's renderer/decoder and every fixture container
        // layout before scoring steady-state feed activations. Cold platform
        // startup is intentionally outside this scroll-to-first-frame SLO.
        for (var warmup = 0; warmup < feedTtffWarmupCount; warmup++) {
          if (warmup > 0) {
            feedKey.currentState!.debugActivatePage(warmup);
          }
          await _waitForSample(metrics, warmup + 1);
        }

        final samples = <FeedFirstFrameMetric>[];
        for (var sample = 0; sample < feedTtffSampleCount; sample++) {
          feedKey.currentState!.debugActivatePage(feedTtffWarmupCount + sample);
          samples.add(await _waitForSample(metrics, sample + 1));
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
