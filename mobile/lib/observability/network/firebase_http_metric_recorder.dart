// ABOUTME: Firebase Performance implementation of the HttpMetricRecorder port.
// ABOUTME: Turns each instrumented request into a NETWORK_REQUEST metric.

import 'dart:async';

import 'package:firebase_performance/firebase_performance.dart';
import 'package:openvine/observability/network/http_metric_recorder.dart';
import 'package:unified_logger/unified_logger.dart';

/// Creates the underlying Firebase metric. Injected so the recorder can be
/// tested without a Firebase app.
typedef HttpMetricFactory = HttpMetric Function(
  String url,
  HttpMethod httpMethod,
);

const String _logName = 'HttpMetricRecorder';

/// Reports HTTP requests to Firebase Performance Monitoring.
///
/// Firebase only auto-instruments the *native* HTTP stacks, so Dart-side
/// requests are invisible unless something opens an [HttpMetric] for them
/// (#7122). This is that something.
class FirebaseHttpMetricRecorder implements HttpMetricRecorder {
  FirebaseHttpMetricRecorder({
    required bool Function() isEnabled,
    HttpMetricFactory? newHttpMetric,
  }) : _isEnabled = isEnabled,
       _newHttpMetric = newHttpMetric ?? _firebaseHttpMetric;

  /// Whether performance collection has initialised. Sampled per request, not
  /// captured, because clients are built during startup — before
  /// `PerformanceMonitoringService.initialize` completes.
  final bool Function() _isEnabled;

  final HttpMetricFactory _newHttpMetric;

  static HttpMetric _firebaseHttpMetric(String url, HttpMethod httpMethod) =>
      FirebasePerformance.instance.newHttpMetric(url, httpMethod);

  @override
  HttpMetricSpan? start({required String urlPattern, required String method}) {
    if (!_isEnabled()) return null;

    final httpMethod = _parseHttpMethod(method);
    if (httpMethod == null) {
      Log.debug(
        'Skipping metric for unsupported HTTP method $method',
        name: _logName,
      );
      return null;
    }

    try {
      final metric = _newHttpMetric(urlPattern, httpMethod);
      final started = metric.start().catchError((Object e) {
        Log.error('Failed to start metric for $urlPattern: $e', name: _logName);
      });
      return _FirebaseHttpMetricSpan(metric, started);
    } catch (e) {
      Log.error('Failed to create metric for $urlPattern: $e', name: _logName);
      return null;
    }
  }
}

HttpMethod? _parseHttpMethod(String method) => switch (method.toUpperCase()) {
  'CONNECT' => HttpMethod.Connect,
  'DELETE' => HttpMethod.Delete,
  'GET' => HttpMethod.Get,
  'HEAD' => HttpMethod.Head,
  'OPTIONS' => HttpMethod.Options,
  'PATCH' => HttpMethod.Patch,
  'POST' => HttpMethod.Post,
  'PUT' => HttpMethod.Put,
  'TRACE' => HttpMethod.Trace,
  _ => null,
};

class _FirebaseHttpMetricSpan implements HttpMetricSpan {
  _FirebaseHttpMetricSpan(this._metric, this._started);

  final HttpMetric _metric;

  /// Completion of the metric's start round-trip. [complete] waits on it
  /// because the plugin drops a stop that arrives before the platform handed
  /// back a handle — the metric is then never reported *and* leaks natively.
  /// A cache hit or a 304 answered in a few milliseconds would race it.
  final Future<void> _started;

  bool _completed = false;

  @override
  void setRequestPayloadSize(int bytes) {
    if (_completed) return;
    _metric.requestPayloadSize = bytes;
  }

  @override
  void complete({
    int? statusCode,
    int? responsePayloadSize,
    String? responseContentType,
  }) {
    if (_completed) return;
    _completed = true;

    if (statusCode != null) _metric.httpResponseCode = statusCode;
    if (responsePayloadSize != null) {
      _metric.responsePayloadSize = responsePayloadSize;
    }
    if (responseContentType != null) {
      _metric.responseContentType = responseContentType;
    }
    unawaited(_stop());
  }

  Future<void> _stop() async {
    try {
      await _started;
      await _metric.stop();
    } catch (e) {
      Log.error('Failed to stop metric: $e', name: _logName);
    }
  }
}
