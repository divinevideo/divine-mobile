import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';

import '../../helpers/fake_controller.dart';

const _playing = DivineVideoPlayerState(
  status: PlaybackStatus.playing,
  isFirstFrameRendered: true,
);
const _buffering = DivineVideoPlayerState(
  status: PlaybackStatus.buffering,
  isFirstFrameRendered: true,
);
const _paused = DivineVideoPlayerState(
  status: PlaybackStatus.paused,
  isFirstFrameRendered: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    group('playback sessions', () {
      late List<FeedPlaybackSessionMetric> sessions;
      late StreamSubscription<FeedPlaybackSessionMetric> subscription;

      setUp(() {
        sessions = [];
        subscription = FeedFirstFrameMetrics.sessions.listen(sessions.add);
      });

      tearDown(() => subscription.cancel());

      void push(
        FakeAsync async,
        FakeController controller,
        DivineVideoPlayerState state,
      ) {
        controller.pushState(state);
        async.flushMicrotasks();
      }

      test('reports a played activation with its stall and watch time', () {
        fakeAsync((async) {
          final controller = FakeController();
          final timer = FeedFirstFrameMetrics.start(
            videoId: 'synthetic',
            index: 0,
          )..markSourceReady();
          async.elapse(const Duration(milliseconds: 400));
          timer
            ..complete(loadedFromCache: true)
            ..observePlayback(controller, reportsStalls: true);
          push(async, controller, _playing);
          async.elapse(const Duration(milliseconds: 1000));
          push(async, controller, _buffering);
          async.elapse(const Duration(milliseconds: 300));
          push(async, controller, _playing);
          async.elapse(const Duration(milliseconds: 500));

          final metric = timer.end(
            FeedPlaybackSessionEnd.swipe,
            loadedFromCache: false,
          );

          expect(sessions, [same(metric)]);
          expect(metric!.outcome, FeedPlaybackSessionOutcome.played);
          expect(metric.end, FeedPlaybackSessionEnd.swipe);
          expect(metric.index, 0);
          expect(metric.loadedFromCache, isTrue);
          expect(metric.timeToFirstFrame, const Duration(milliseconds: 400));
          expect(metric.sourceReadyAt, Duration.zero);
          expect(metric.active, const Duration(milliseconds: 2200));
          expect(metric.watched, const Duration(milliseconds: 1500));
          expect(metric.stallCount, 1);
          expect(metric.stalled, const Duration(milliseconds: 300));
          expect(metric.error, isNull);
        });
      });

      test('closes a stall that is still open when the activation ends', () {
        fakeAsync((async) {
          final controller = FakeController();
          final timer =
              FeedFirstFrameMetrics.start(
                  videoId: 'synthetic',
                  index: 3,
                )
                ..complete(loadedFromCache: false)
                ..observePlayback(controller, reportsStalls: true);
          push(async, controller, _playing);
          async.elapse(const Duration(milliseconds: 200));
          push(async, controller, _buffering);
          async.elapse(const Duration(milliseconds: 700));

          final metric = timer.end(
            FeedPlaybackSessionEnd.hidden,
            loadedFromCache: false,
          )!;

          expect(metric.stallCount, 1);
          expect(metric.stalled, const Duration(milliseconds: 700));
          expect(metric.watched, const Duration(milliseconds: 200));
          expect(metric.end, FeedPlaybackSessionEnd.hidden);
          push(async, controller, _playing);
          async.elapse(const Duration(seconds: 1));
          expect(
            timer.end(FeedPlaybackSessionEnd.closed, loadedFromCache: true),
            isNull,
          );
          expect(sessions, hasLength(1));
        });
      });

      test('does not count the start-up wait or a pause as a stall', () {
        fakeAsync((async) {
          final first = FakeController();
          final replacement = FakeController();
          final timer =
              FeedFirstFrameMetrics.start(
                  videoId: 'synthetic',
                  index: 1,
                )
                ..complete(loadedFromCache: false)
                ..observePlayback(first, reportsStalls: true);
          push(async, first, _buffering);
          async.elapse(const Duration(milliseconds: 600));
          push(async, first, _playing);
          async.elapse(const Duration(milliseconds: 400));
          push(async, first, _paused);
          async.elapse(const Duration(seconds: 2));
          timer
            ..observePlayback(replacement, reportsStalls: true)
            ..observePlayback(replacement, reportsStalls: true);
          push(async, first, _buffering);
          push(async, replacement, _playing);
          async.elapse(const Duration(milliseconds: 100));

          final metric = timer.end(
            FeedPlaybackSessionEnd.closed,
            loadedFromCache: false,
          )!;

          expect(metric.stallCount, 0);
          expect(metric.stalled, Duration.zero);
          expect(metric.watched, const Duration(milliseconds: 500));
          expect(metric.active, const Duration(milliseconds: 3100));
        });
      });

      test('leaves stalls out where the player does not report them', () {
        fakeAsync((async) {
          final controller = FakeController();
          final timer =
              FeedFirstFrameMetrics.start(
                  videoId: 'synthetic',
                  index: 2,
                )
                ..complete(loadedFromCache: false)
                ..observePlayback(controller, reportsStalls: false);
          push(async, controller, _playing);
          async.elapse(const Duration(milliseconds: 300));
          push(async, controller, _buffering);
          async.elapse(const Duration(milliseconds: 300));

          final metric = timer.end(
            FeedPlaybackSessionEnd.swipe,
            loadedFromCache: false,
          )!;

          expect(metric.outcome, FeedPlaybackSessionOutcome.played);
          expect(metric.watched, const Duration(milliseconds: 300));
          expect(metric.stallCount, isNull);
          expect(metric.stalled, isNull);
        });
      });

      test('reports an activation left before its first frame', () {
        fakeAsync((async) {
          final controller = FakeController();
          final timer = FeedFirstFrameMetrics.start(
            videoId: 'synthetic',
            index: 5,
          );
          async.elapse(const Duration(milliseconds: 150));
          timer
            ..markControllerInitialized()
            ..observePlayback(controller, reportsStalls: true);
          async.elapse(const Duration(milliseconds: 650));

          final metric = timer.end(
            FeedPlaybackSessionEnd.swipe,
            loadedFromCache: true,
          )!;

          expect(metric.outcome, FeedPlaybackSessionOutcome.abandoned);
          expect(metric.active, const Duration(milliseconds: 800));
          expect(
            metric.controllerInitializedAt,
            const Duration(milliseconds: 150),
          );
          expect(metric.loadedFromCache, isTrue);
          expect(metric.timeToFirstFrame, isNull);
          expect(metric.watched, isNull);
          expect(metric.stallCount, isNull);
          expect(metric.stalled, isNull);
          expect(metric.error, isNull);
          expect(timer.complete(loadedFromCache: false), isNull);
        });
      });

      test('reports a failed activation with its error category', () {
        fakeAsync((async) {
          final timer = FeedFirstFrameMetrics.start(
            videoId: 'synthetic',
            index: 6,
          );
          async.elapse(const Duration(milliseconds: 900));
          timer.finish(
            outcome: FeedPlaybackOutcome.error,
            errorCategory: FeedPlaybackError.playback,
          );
          async.elapse(const Duration(milliseconds: 100));

          final metric = timer.end(
            FeedPlaybackSessionEnd.closed,
            loadedFromCache: false,
          )!;

          expect(metric.outcome, FeedPlaybackSessionOutcome.failed);
          expect(metric.error, FeedPlaybackError.playback);
          expect(metric.active, const Duration(seconds: 1));
          expect(metric.timeToFirstFrame, isNull);
        });
      });

      test('a frame after a recovered error counts as played', () {
        final timer =
            FeedFirstFrameMetrics.start(videoId: 'synthetic', index: 7)
              ..finish(
                outcome: FeedPlaybackOutcome.error,
                errorCategory: FeedPlaybackError.initialization,
              )
              ..complete(loadedFromCache: false);

        final metric = timer.end(
          FeedPlaybackSessionEnd.swipe,
          loadedFromCache: false,
        )!;

        expect(metric.outcome, FeedPlaybackSessionOutcome.played);
        expect(metric.error, isNull);
        expect(metric.watched, Duration.zero);
        expect(metric.stallCount, isNull);
      });

      test('drops an activation held back from autoplay without a frame', () {
        final held = FeedFirstFrameMetrics.start(videoId: 'synthetic', index: 8)
          ..markAutoPlay(allowed: false);
        expect(
          held.end(FeedPlaybackSessionEnd.swipe, loadedFromCache: false),
          isNull,
        );
        expect(sessions, isEmpty);

        final revealed =
            FeedFirstFrameMetrics.start(videoId: 'synthetic', index: 9)
              ..markAutoPlay(allowed: false)
              ..markAutoPlay(allowed: true);
        final metric = revealed.end(
          FeedPlaybackSessionEnd.swipe,
          loadedFromCache: false,
        );
        expect(metric?.outcome, FeedPlaybackSessionOutcome.abandoned);
        expect(sessions, hasLength(1));
      });

      test('ends the operational attempt as cancelled', () {
        fakeAsync((async) {
          FeedPlaybackTelemetry.configure(enabled: true);
          final events = <Map<String, Object?>>[];
          final sub = FeedPlaybackTelemetry.events.listen(events.add);
          FeedFirstFrameMetrics.start(
            videoId: 'synthetic',
            index: 0,
          ).end(FeedPlaybackSessionEnd.hidden, loadedFromCache: false);

          expect(events.single['outcome'], 'cancelled');
          expect(async.pendingTimers, isEmpty);
          unawaited(sub.cancel());
        });
      });

      test('stops counting watch and stall time when the followed controller '
          'closes', () {
        fakeAsync((async) {
          final controller = FakeController();
          final timer =
              FeedFirstFrameMetrics.start(
                  videoId: 'synthetic',
                  index: 0,
                )
                ..complete(loadedFromCache: false)
                ..observePlayback(controller, reportsStalls: true);
          push(async, controller, _playing);
          async.elapse(const Duration(milliseconds: 300));
          push(async, controller, _buffering);
          async.elapse(const Duration(milliseconds: 200));
          unawaited(controller.dispose());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 1000));

          final metric = timer.end(
            FeedPlaybackSessionEnd.swipe,
            loadedFromCache: false,
          )!;

          expect(metric.watched, const Duration(milliseconds: 300));
          expect(metric.stallCount, 1);
          expect(metric.stalled, const Duration(milliseconds: 200));
          expect(metric.active, const Duration(milliseconds: 1500));
        });
      });
    });
  });
}
