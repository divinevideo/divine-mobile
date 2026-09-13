import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/feed_load_trace.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

class _RecordingTrace implements PerformanceTrace {
  final attributes = <String, String>{};
  final metrics = <String, int>{};
  int stopCount = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() async => stopCount++;
}

void main() {
  group(FeedLoadTrace, () {
    late _RecordingTrace trace;

    setUp(() {
      trace = _RecordingTrace();
    });

    test('reports the live event count at completion time', () async {
      var eventCount = 0;
      final feedLoadTrace = FeedLoadTrace(
        trace: trace,
        eventCount: () => eventCount,
      );

      // Events keep arriving after the trace starts, so the count must be
      // read on completion rather than captured at construction.
      eventCount = 3;
      feedLoadTrace.complete('eose');
      await pumpEventQueue();

      expect(trace.metrics['event_count'], 3);
      expect(trace.attributes['completion'], 'eose');
      expect(trace.stopCount, 1);
    });

    test('eventTotal overrides the live count', () async {
      FeedLoadTrace(
        trace: trace,
        eventCount: () => 0,
      ).complete('cache', eventTotal: 7);
      await pumpEventQueue();

      expect(trace.metrics['event_count'], 7);
    });

    test('first completion wins and later ones do not re-report', () async {
      final feedLoadTrace = FeedLoadTrace(trace: trace, eventCount: () => 1)
        ..complete('first_relay_event')
        ..complete('disposed');
      feedLoadTrace.complete('done');
      await pumpEventQueue();

      expect(trace.attributes['completion'], 'first_relay_event');
      expect(trace.stopCount, 1);
    });

    test('cache completion excludes later relay work', () {
      final load = FeedLoadTrace(trace: trace, eventCount: () => 0)
        ..startPhase('cache_ingest_ms')
        ..complete('cache', eventTotal: 50);
      final metricsAtCompletion = Map<String, int>.of(trace.metrics);
      load
        ..startPhase('relay_wait_ms')
        ..complete('first_relay_event');

      expect(trace.attributes['terminal_phase'], 'cache_ingest_ms');
      expect(trace.metrics, contains('cache_read_ms'));
      expect(trace.metrics, contains('cache_ingest_ms'));
      expect(trace.metrics, metricsAtCompletion);
      expect(trace.stopCount, 1);
    });

    test(
      'cancellation records the interrupted phase and ignores late work',
      () {
        final load = FeedLoadTrace(trace: trace, eventCount: () => 0)
          ..complete('cancelled');
        load.startPhase('cache_ingest_ms');
        expect(trace.attributes['terminal_phase'], 'cache_read_ms');
        expect(trace.metrics, contains('cache_read_ms'));
        expect(trace.metrics, isNot(contains('cache_ingest_ms')));
      },
    );
  });
}
