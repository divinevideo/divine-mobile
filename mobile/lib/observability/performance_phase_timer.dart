import 'package:openvine/services/performance_monitoring_service.dart';

/// Records consecutive elapsed phases on one operation's performance trace.
class PerformancePhaseTimer {
  PerformancePhaseTimer(this._trace, {Stopwatch? stopwatch})
    : _stopwatch = stopwatch ?? Stopwatch();

  final PerformanceTrace _trace;
  final Stopwatch _stopwatch;
  String? _phase;

  /// The unfinished phase, also useful for classifying a failure.
  String? get currentPhase => _phase;

  /// Finishes the previous phase and starts [metric]. Names must be static.
  void startPhase(String metric) {
    finishPhase();
    _phase = metric;
    _stopwatch
      ..reset()
      ..start();
  }

  /// Records the active phase once, including time spent awaiting a result.
  void finishPhase() {
    final phase = _phase;
    if (phase == null) return;
    _phase = null;
    _stopwatch.stop();
    _trace.setMetric(phase, _stopwatch.elapsedMilliseconds);
  }
}
