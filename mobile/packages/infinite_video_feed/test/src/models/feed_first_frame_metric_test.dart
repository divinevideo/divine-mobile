import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';

void main() {
  group(FeedFirstFrameMetrics, () {
    tearDown(() => FeedPlaybackTelemetry.configure(enabled: false));

    test('suspension cancels attempts without consuming success timing', () {
      fakeAsync((async) {
        FeedPlaybackTelemetry.configure(enabled: true);
        final events = <Map<String, Object?>>[];
        final successes = <FeedFirstFrameMetric>[];
        final operational = FeedPlaybackTelemetry.events.listen(events.add);
        final success = FeedFirstFrameMetrics.events.listen(successes.add);
        final first = FeedFirstFrameMetrics.start(
          videoId: 'synthetic',
          index: 0,
        );
        final second = FeedFirstFrameMetrics.start(
          videoId: 'synthetic',
          index: 1,
        );
        expect(async.pendingTimers, hasLength(2));
        async.elapse(const Duration(seconds: 1));
        first.markSourceReady();
        FeedFirstFrameMetrics.cancelActivePlaybackAttempts();
        expect(events, hasLength(2));
        expect(
          events.every((event) => event['outcome'] == 'cancelled'),
          isTrue,
        );
        expect(successes, isEmpty);
        expect(async.pendingTimers, isEmpty);
        first.finish(outcome: FeedPlaybackOutcome.cancelled);
        FeedFirstFrameMetrics.cancelActivePlaybackAttempts();
        expect(events, hasLength(2));
        async.elapse(const Duration(seconds: 2));
        first.markPlaybackRequested();
        final recovered = first.complete(loadedFromCache: true);
        expect(recovered, same(successes.single));
        expect(recovered!.sourceReadyAt, isNotNull);
        expect(
          recovered.playbackRequestedAt,
          greaterThan(recovered.sourceReadyAt!),
        );
        expect(
          recovered.duration,
          greaterThanOrEqualTo(recovered.playbackRequestedAt!),
        );
        expect(first.complete(loadedFromCache: false), isNull);
        second.complete(loadedFromCache: false);
        expect(successes, hasLength(2));
        expect(events, hasLength(2));
        unawaited(operational.cancel());
        unawaited(success.cancel());
      });
    });

    test('old privacy contexts cannot emit when later suspended', () {
      fakeAsync((async) {
        FeedPlaybackTelemetry.configure(enabled: true);
        final events = <Map<String, Object?>>[];
        final sub = FeedPlaybackTelemetry.events.listen(events.add);
        final old = FeedFirstFrameMetrics.start(videoId: 'synthetic', index: 0);
        FeedPlaybackTelemetry.configure(enabled: true, reset: true);
        expect(events, isEmpty);
        final fresh = FeedFirstFrameMetrics.start(
          videoId: 'synthetic',
          index: 1,
        );
        FeedFirstFrameMetrics.cancelActivePlaybackAttempts();
        old.finish(outcome: FeedPlaybackOutcome.cancelled);
        fresh.finish(outcome: FeedPlaybackOutcome.cancelled);
        async.elapse(const Duration(seconds: 60));
        expect(events, hasLength(1));
        expect(events.single['outcome'], 'cancelled');
        expect(async.pendingTimers, isEmpty);
        unawaited(sub.cancel());
      });
    });

    test('completed and timed-out attempts leave the active registry', () {
      fakeAsync((async) {
        FeedPlaybackTelemetry.configure(enabled: true);
        final events = <Map<String, Object?>>[];
        final sub = FeedPlaybackTelemetry.events.listen(events.add);
        FeedFirstFrameMetrics.start(
          videoId: 'synthetic',
          index: 0,
        ).complete(loadedFromCache: false);
        FeedFirstFrameMetrics.start(videoId: 'synthetic', index: 1);
        async.elapse(const Duration(seconds: 60));
        expect(events.map((event) => event['outcome']), [
          'first_frame',
          'no_frame',
        ]);
        FeedFirstFrameMetrics.cancelActivePlaybackAttempts();
        expect(events, hasLength(2));
        expect(async.pendingTimers, isEmpty);
        unawaited(sub.cancel());
      });
    });

    test('disabled telemetry preserves first-frame success after retry', () {
      fakeAsync((async) {
        FeedPlaybackTelemetry.configure(enabled: false);
        final successes = <FeedFirstFrameMetric>[];
        final sub = FeedFirstFrameMetrics.events.listen(successes.add);
        final timer = FeedFirstFrameMetrics.start(videoId: 'private', index: 2);
        expect(async.pendingTimers, isEmpty);
        FeedFirstFrameMetrics.cancelActivePlaybackAttempts();
        expect(successes, isEmpty);
        async.elapse(const Duration(seconds: 1));
        timer.finish(
          outcome: FeedPlaybackOutcome.error,
          errorCategory: FeedPlaybackError.initialization,
        );
        expect(successes, isEmpty);
        async.elapse(const Duration(seconds: 2));
        timer
          ..markControllerInitialized()
          ..markSourceReady()
          ..markPlaybackRequested();
        final recovered = timer.complete(loadedFromCache: true);
        expect(recovered, same(successes.single));
        expect(recovered!.duration, greaterThanOrEqualTo(Duration.zero));
        expect(recovered.controllerInitializedAt, isNotNull);
        expect(recovered.sourceReadyAt, isNotNull);
        expect(recovered.playbackRequestedAt, isNotNull);
        expect(recovered.loadedFromCache, isTrue);
        expect(recovered.index, 2);
        expect(timer.complete(loadedFromCache: false), isNull);
        expect(successes, hasLength(1));
        expect(async.pendingTimers, isEmpty);
        unawaited(sub.cancel());
      });
    });

    test('publishes a full-id measurement exactly once', () async {
      const videoId =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final metricFuture = FeedFirstFrameMetrics.events.first;
      final timer = FeedFirstFrameMetrics.start(videoId: videoId, index: 4)
        ..markControllerInitialized()
        ..markSourceReady()
        ..markPlaybackRequested();

      final first = timer.complete(loadedFromCache: true);
      final second = timer.complete(loadedFromCache: true);
      final published = await metricFuture;

      expect(first, same(published));
      expect(second, isNull);
      expect(published.videoId, videoId);
      expect(published.index, 4);
      expect(published.loadedFromCache, isTrue);
      expect(published.duration, greaterThanOrEqualTo(Duration.zero));
      expect(published.controllerInitializedAt, isNotNull);
      expect(published.sourceReadyAt, isNotNull);
      expect(published.playbackRequestedAt, isNotNull);
    });
  });
}
