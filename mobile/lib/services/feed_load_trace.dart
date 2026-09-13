// ABOUTME: Owns a single started feed-load performance trace until it reports
// ABOUTME: Keeps completion first-wins so any teardown path can close the trace

import 'dart:async';

import 'package:openvine/observability/performance_phase_timer.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

/// A started feed-load trace, held by its owner until it reports.
///
/// Starting a trace takes a native handle the plugin only releases on stop, so
/// a load abandoned mid-flight — the owning service is disposed before any
/// completion path runs — would keep a live trace for the process lifetime.
/// Reporting it as `disposed` releases the handle and keeps an honestly
/// attributed sample instead of dropping it (#7151).
class FeedLoadTrace {
  FeedLoadTrace({
    required PerformanceTrace trace,
    required int Function() eventCount,
  }) : _trace = trace,
       _eventCount = eventCount,
       _phases = PerformancePhaseTimer(trace)..startPhase('cache_read_ms');

  final PerformanceTrace _trace;
  final PerformancePhaseTimer _phases;

  /// Read at completion time: the count keeps rising after the trace starts.
  final int Function() _eventCount;

  bool _completed = false;

  /// Advances the breakdown only while this load is still pending.
  void startPhase(String metric) {
    if (_completed) return;
    _phases.startPhase(metric);
  }

  /// Reports the trace under [completion], first caller wins.
  ///
  /// Later callers are no-ops, so an abandoned-load sweep cannot re-attribute
  /// or double-stop a load that already reported.
  void complete(String completion, {int? eventTotal}) {
    if (_completed) return;
    _completed = true;
    _trace.putAttribute('terminal_phase', _phases.currentPhase!);
    _phases.finishPhase();
    _trace
      ..setMetric('event_count', eventTotal ?? _eventCount())
      ..putAttribute('completion', completion);
    unawaited(_trace.stop());
  }
}
