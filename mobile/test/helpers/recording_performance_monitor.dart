// ABOUTME: Captures emitted performance telemetry for behavioral assertions.
// ABOUTME: Keeps trace ownership and terminal samples visible without Firebase.

import 'package:openvine/services/performance_monitoring_service.dart';

class RecordingPerformanceMonitor implements PerformanceTraceMonitor {
  final traces = <RecordedPerformanceTrace>[];

  @override
  PerformanceTrace startOperationTrace(String traceName) {
    final trace = RecordedPerformanceTrace(traceName);
    traces.add(trace);
    return trace;
  }
}

class RecordedPerformanceTrace implements PerformanceTrace {
  RecordedPerformanceTrace(this.name);

  final String name;
  final attributes = <String, String>{};
  final metrics = <String, int>{};
  int stops = 0;

  @override
  void putAttribute(String attribute, String value) =>
      attributes[attribute] = value;

  @override
  void setMetric(String metric, int value) => metrics[metric] = value;

  @override
  Future<void> stop() async => stops++;
}
