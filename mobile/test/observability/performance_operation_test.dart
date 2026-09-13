// ABOUTME: Verifies telemetry failures cannot fail the measured operation.
// ABOUTME: Checks handle closure and nonblocking completion with a stalled SDK.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';

import '../helpers/recording_performance_monitor.dart';

class _ThrowingMonitor implements PerformanceTraceMonitor {
  @override
  PerformanceTrace startOperationTrace(String name) => throw StateError('SDK');
}

class _TraceMonitor implements PerformanceTraceMonitor {
  _TraceMonitor(this.trace);
  final PerformanceTrace trace;
  @override
  PerformanceTrace startOperationTrace(String name) => trace;
}

class _FailingTrace extends RecordedPerformanceTrace {
  _FailingTrace() : super('failure');
  @override
  void putAttribute(String attribute, String value) => throw StateError('SDK');
  @override
  Future<void> stop() async {
    stops++;
    throw StateError('SDK');
  }
}

class _PendingTrace extends RecordedPerformanceTrace {
  _PendingTrace() : super('pending');
  final completed = Completer<void>();
  @override
  Future<void> stop() {
    stops++;
    return completed.future;
  }
}

void main() {
  test('contains start, attribute, and asynchronous stop failures', () async {
    PerformanceOperation(_ThrowingMonitor(), 'operation').finish();
    final trace = _FailingTrace();
    PerformanceOperation(_TraceMonitor(trace), 'operation').finish(
      attributes: {'outcome': 'success'},
    );
    await Future<void>.value();
    expect(trace.stops, 1);
  });

  test('finishes once without waiting for telemetry transport', () {
    final trace = _PendingTrace();
    final operation = PerformanceOperation(_TraceMonitor(trace), 'operation');
    operation.finish(attributes: {'outcome': 'success'});
    operation.finish(attributes: {'outcome': 'failure'});
    expect(trace.attributes['outcome'], 'success');
    expect(trace.stops, 1);
    trace.completed.complete();
  });
}
