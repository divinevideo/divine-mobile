import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/performance_phase_timer.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

class _ManualStopwatch extends Fake implements Stopwatch {
  @override
  int elapsedMilliseconds = 0;

  @override
  void reset() => elapsedMilliseconds = 0;

  @override
  void start() {}

  @override
  void stop() {}
}

class _Trace extends Fake implements PerformanceTrace {
  final metrics = <String, int>{};

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;
}

void main() {
  group(PerformancePhaseTimer, () {
    test('records separate phases and finishes each phase once', () {
      final trace = _Trace();
      final stopwatch = _ManualStopwatch();
      final phases = PerformancePhaseTimer(trace, stopwatch: stopwatch);

      phases.startPhase('database_read_ms');
      stopwatch.elapsedMilliseconds = 7000;
      phases.startPhase('database_merge_ms');
      expect(trace.metrics, {'database_read_ms': 7000});
      expect(phases.currentPhase, 'database_merge_ms');

      stopwatch.elapsedMilliseconds = 12;
      phases.finishPhase();
      stopwatch.elapsedMilliseconds = 9999;
      phases.finishPhase();

      expect(trace.metrics, {
        'database_read_ms': 7000,
        'database_merge_ms': 12,
      });
      expect(phases.currentPhase, isNull);
    });

    test('operations do not share timing state', () {
      final first = _Trace();
      final second = _Trace();
      final firstClock = _ManualStopwatch();
      final secondClock = _ManualStopwatch();
      final firstPhases = PerformancePhaseTimer(first, stopwatch: firstClock)
        ..startPhase('wait_ms');
      final secondPhases = PerformancePhaseTimer(second, stopwatch: secondClock)
        ..startPhase('wait_ms');
      firstClock.elapsedMilliseconds = 8;
      secondClock.elapsedMilliseconds = 3;

      secondPhases.finishPhase();
      expect(first.metrics, isEmpty);
      firstPhases.finishPhase();
      expect(first.metrics, {'wait_ms': 8});
      expect(second.metrics, {'wait_ms': 3});
    });
  });
}
