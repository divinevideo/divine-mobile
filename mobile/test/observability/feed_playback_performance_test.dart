// ABOUTME: Verifies each ended feed activation reaches telemetry once, by outcome.
// ABOUTME: Protects privacy, startup video readiness, and observer disposal.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/observability/feed_playback_performance.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/startup_performance_service.dart';

import '../helpers/recording_performance_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(FeedPlaybackPerformance, () {
    late StreamController<FeedFirstFrameMetric> firstFrames;
    late StreamController<FeedPlaybackSessionMetric> sessions;
    late StartupPerformanceService startup;
    late RecordingPerformanceMonitor monitor;

    const firstFrame = FeedFirstFrameMetric(
      videoId: 'private-event',
      index: 42,
      duration: Duration(milliseconds: 1234),
      loadedFromCache: false,
    );

    setUp(() {
      firstFrames = StreamController<FeedFirstFrameMetric>.broadcast(
        sync: true,
      );
      sessions = StreamController<FeedPlaybackSessionMetric>.broadcast(
        sync: true,
      );
      addTearDown(firstFrames.close);
      addTearDown(sessions.close);
      startup = StartupPerformanceService(
        crashReporting: CrashReportingService(),
      );
      monitor = RecordingPerformanceMonitor();
    });

    FeedPlaybackPerformance observe() {
      final observer = FeedPlaybackPerformance(
        firstFrames: firstFrames.stream,
        sessions: sessions.stream,
        monitor: monitor,
        startup: startup,
      );
      addTearDown(observer.dispose);
      return observer;
    }

    test('exports a played activation with its stalls and watch time', () {
      observe();
      sessions.add(
        const FeedPlaybackSessionMetric(
          index: 42,
          outcome: FeedPlaybackSessionOutcome.played,
          end: FeedPlaybackSessionEnd.swipe,
          loadedFromCache: false,
          active: Duration(milliseconds: 9000),
          timeToFirstFrame: Duration(milliseconds: 1234),
          sourceReadyAt: Duration(milliseconds: 800),
          watched: Duration(milliseconds: 7000),
          stallCount: 2,
          stalled: Duration(milliseconds: 650),
        ),
      );

      final trace = monitor.traces.single;
      expect(trace.name, 'video_first_frame');
      expect(trace.attributes, {
        'outcome': 'played',
        'end': 'swipe',
        'cache': 'miss',
        'position': 'subsequent',
      });
      expect(trace.metrics, {
        'active_ms': 9000,
        'ttff_ms': 1234,
        'source_ready_ms': 800,
        'watched_ms': 7000,
        'stall_count': 2,
        'stall_ms': 650,
      });
      expect(trace.stops, 1);
    });

    test('exports an activation abandoned before its first frame', () {
      observe();
      sessions.add(
        const FeedPlaybackSessionMetric(
          index: 0,
          outcome: FeedPlaybackSessionOutcome.abandoned,
          end: FeedPlaybackSessionEnd.hidden,
          loadedFromCache: true,
          active: Duration(milliseconds: 2500),
          controllerInitializedAt: Duration(milliseconds: 90),
          playbackRequestedAt: Duration(milliseconds: 400),
        ),
      );

      final trace = monitor.traces.single;
      expect(trace.attributes, {
        'outcome': 'abandoned',
        'end': 'hidden',
        'cache': 'hit',
        'position': 'initial',
      });
      expect(trace.metrics, {
        'active_ms': 2500,
        'controller_initialized_ms': 90,
        'playback_requested_ms': 400,
      });
    });

    test('exports a failed activation with its error category', () {
      observe();
      sessions.add(
        const FeedPlaybackSessionMetric(
          index: 3,
          outcome: FeedPlaybackSessionOutcome.failed,
          end: FeedPlaybackSessionEnd.closed,
          loadedFromCache: false,
          active: Duration(milliseconds: 4100),
          error: FeedPlaybackError.source,
        ),
      );

      final trace = monitor.traces.single;
      expect(trace.attributes, {
        'outcome': 'failed',
        'end': 'closed',
        'cache': 'miss',
        'position': 'subsequent',
        'error': 'source',
      });
      expect(trace.metrics, {'active_ms': 4100});
    });

    test('a first frame alone exports nothing', () {
      observe();
      firstFrames.add(firstFrame);

      expect(monitor.traces, isEmpty);
    });

    test('marks startup video readiness when a first frame renders', () async {
      await startup.initialize();
      observe();
      expect(startup.getMetrics(), isNot(contains('video_ready_ms')));

      firstFrames.add(firstFrame);

      expect(startup.getMetrics()['video_ready_ms'], isA<int>());
    });

    test('stops observing both streams on dispose', () async {
      await startup.initialize();
      final observer = observe();
      await observer.dispose();

      firstFrames.add(firstFrame);
      sessions.add(
        const FeedPlaybackSessionMetric(
          index: 0,
          outcome: FeedPlaybackSessionOutcome.abandoned,
          end: FeedPlaybackSessionEnd.swipe,
          loadedFromCache: false,
          active: Duration(milliseconds: 10),
        ),
      );

      expect(monitor.traces, isEmpty);
      expect(startup.getMetrics(), isNot(contains('video_ready_ms')));
    });
  });
}
