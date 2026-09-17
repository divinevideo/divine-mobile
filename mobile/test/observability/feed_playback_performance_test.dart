// ABOUTME: Verifies first-frame metrics reach telemetry with measured timings.
// ABOUTME: Protects privacy and observer subscription disposal.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/observability/feed_playback_performance.dart';

import '../helpers/recording_performance_monitor.dart';

void main() {
  group('recordFirstFrame', () {
    test(
      'exports measured playback latency and stops observing on dispose',
      () async {
        final events = StreamController<FeedFirstFrameMetric>.broadcast(
          sync: true,
        );
        addTearDown(events.close);
        final monitor = RecordingPerformanceMonitor();
        final observer = FeedPlaybackPerformance(events.stream, monitor);
        const metric = FeedFirstFrameMetric(
          videoId: 'private-event',
          index: 42,
          duration: Duration(milliseconds: 1234),
          loadedFromCache: false,
          sourceReadyAt: Duration(milliseconds: 800),
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
  });
}
