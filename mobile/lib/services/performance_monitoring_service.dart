// ABOUTME: Performance monitoring service for tracking app performance metrics
// ABOUTME: Uses Firebase Performance Monitoring to track screen transitions, network requests, and custom operations

import 'package:firebase_performance/firebase_performance.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Performance monitoring service for tracking app performance
class PerformanceMonitoringService {
  static PerformanceMonitoringService? _instance;
  static PerformanceMonitoringService get instance =>
      _instance ??= PerformanceMonitoringService._();

  PerformanceMonitoringService._();

  late final FirebasePerformance _performance;
  bool _initialized = false;

  /// Active traces for custom performance tracking
  final Map<String, Trace> _activeTraces = {};

  /// Initialize performance monitoring
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _performance = FirebasePerformance.instance;

      // Enable performance collection
      await _performance.setPerformanceCollectionEnabled(true);

      _initialized = true;
      Log.info(
        'Performance monitoring initialized successfully',
        name: 'PerformanceMonitoring',
      );
    } catch (e) {
      Log.error(
        'Failed to initialize performance monitoring: $e',
        name: 'PerformanceMonitoring',
      );
      // Don't throw - app should continue even if performance monitoring fails
    }
  }

  /// Start a custom trace for tracking operation performance
  Future<void> startTrace(String traceName) async {
    if (!_initialized) return;

    try {
      // Stop existing trace with same name if it exists
      await stopTrace(traceName);

      final trace = _performance.newTrace(traceName);
      await trace.start();
      _activeTraces[traceName] = trace;

      Log.debug(
        'Started performance trace: $traceName',
        name: 'PerformanceMonitoring',
      );
    } catch (e) {
      Log.error(
        'Failed to start trace $traceName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Stop a custom trace and record the duration
  Future<void> stopTrace(String traceName) async {
    if (!_initialized) return;

    try {
      final trace = _activeTraces.remove(traceName);
      if (trace != null) {
        await trace.stop();
        Log.debug(
          'Stopped performance trace: $traceName',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to stop trace $traceName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Add a metric to an active trace
  void incrementMetric(String traceName, String metricName, int value) {
    if (!_initialized) return;

    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.incrementMetric(metricName, value);
        Log.debug(
          'Incremented metric $metricName by $value for trace $traceName',
          name: 'PerformanceMonitoring',
        );
      } else {
        Log.warning(
          'Trace $traceName not found for metric $metricName',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to increment metric $metricName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Set a metric value on an active trace
  void setMetric(String traceName, String metricName, int value) {
    if (!_initialized) return;

    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.setMetric(metricName, value);
        Log.debug(
          'Set metric $metricName to $value for trace $traceName',
          name: 'PerformanceMonitoring',
        );
      } else {
        Log.warning(
          'Trace $traceName not found for metric $metricName',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to set metric $metricName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Add an attribute to an active trace for filtering in Firebase Console
  void putAttribute(String traceName, String attribute, String value) {
    if (!_initialized) return;

    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.putAttribute(attribute, value);
        Log.debug(
          'Set attribute $attribute=$value for trace $traceName',
          name: 'PerformanceMonitoring',
        );
      } else {
        Log.warning(
          'Trace $traceName not found for attribute $attribute',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to put attribute $attribute: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Create an HTTP metric for tracking network performance
  Future<HttpMetric> newHttpMetric(String url, HttpMethod httpMethod) async {
    if (!_initialized) {
      throw StateError('Performance monitoring not initialized');
    }

    return _performance.newHttpMetric(url, httpMethod);
  }

  /// Convenience method to track an async operation with automatic start/stop
  Future<T> trace<T>(String traceName, Future<T> Function() operation) async {
    await startTrace(traceName);
    try {
      final result = await operation();
      await stopTrace(traceName);
      return result;
    } catch (e) {
      await stopTrace(traceName);
      rethrow;
    }
  }
}
