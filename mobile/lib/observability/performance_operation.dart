// ABOUTME: Owns one telemetry handle without putting telemetry on the user path.
// ABOUTME: Contains monitor failures and stops each operation exactly once.

import 'dart:async';

import 'package:openvine/services/performance_monitoring_service.dart';

class PerformanceOperation {
  PerformanceOperation(PerformanceTraceMonitor monitor, String name) {
    try {
      _trace = monitor.startOperationTrace(name);
    } on Object {
      // Monitoring must never change the operation it measures.
    }
  }

  PerformanceTrace? _trace;
  bool _finished = false;

  void finish({
    Map<String, String> attributes = const {},
    Map<String, int> metrics = const {},
  }) {
    if (_finished) return;
    _finished = true;
    final trace = _trace;
    if (trace == null) return;
    try {
      for (final entry in attributes.entries) {
        trace.putAttribute(entry.key, entry.value);
      }
      for (final entry in metrics.entries) {
        trace.setMetric(entry.key, entry.value);
      }
    } on Object {
      // Still close the handle if adding a field fails.
    }
    unawaited(_stop(trace));
  }

  Future<void> _stop(PerformanceTrace trace) async {
    try {
      await trace.stop();
    } on Object {
      // Includes both synchronous SDK failures and failed futures.
    }
  }
}
