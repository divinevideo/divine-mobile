// ABOUTME: Verifies first-frame metrics reach telemetry with measured timings.
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
    late StreamController<FeedFirstFrameMetric> events;
    late StartupPerformanceService startup;

    const metric = FeedFirstFrameMetric(
      videoId: 'private-event',
      index: 42,
      duration: Duration(milliseconds: 1234),
      loadedFromCache: false,
      sourceReadyAt: Duration(milliseconds: 800),
    );

    setUp(() {
      events = StreamController<FeedFirstFrameMetric>.broadcast(sync: true);
      addTearDown(events.close);
      startup = StartupPerformanceService(
        crashReporting: CrashReportingService(),
      );
    });

    test(
      'exports measured playback latency and stops observing on dispose',
      () async {
        final monitor = RecordingPerformanceMonitor();
        final observer = FeedPlaybackPerformance(
          events.stream,
          monitor,
          startup,
        );
        events.add(metric);
        final trace = monitor.traces.single;
        expect(trace.name, 'video_first_frame');
        expect(trace.attributes, {'cache': 'miss', 'position': 'subsequent'});
        expect(trace.metrics, {'ttff_ms': 1234, 'source_ready_ms': 800});
        expect(trace.stops, 1);
        await observer.dispose();
        events.add(metric);
        expect(monitor.traces.length, 1);
      },
    );

    test('marks startup video readiness when a first frame renders', () async {
      await startup.initialize();
      final observer = FeedPlaybackPerformance(
        events.stream,
        RecordingPerformanceMonitor(),
        startup,
      );
      addTearDown(observer.dispose);
      expect(startup.getMetrics(), isNot(contains('video_ready_ms')));

      events.add(metric);

      expect(startup.getMetrics()['video_ready_ms'], isA<int>());
    });
  });
}
