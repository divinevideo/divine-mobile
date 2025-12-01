// ABOUTME: Tracks startup performance metrics and identifies bottlenecks
// ABOUTME: Provides data for optimizing initialization sequence

/// Metrics collected during app startup
class StartupMetrics {
  StartupMetrics({
    required this.startTime,
    required this.endTime,
    required this.serviceTimings,
    required this.detailedMetrics,
    required this.errors,
  });
  final DateTime startTime;
  final DateTime endTime;
  final Map<String, Duration> serviceTimings;
  final Map<String, ServiceMetrics> detailedMetrics;
  final List<StartupError> errors;

  /// Total startup duration
  Duration get totalDuration => endTime.difference(startTime);

  /// Get services that took longer than threshold
  List<String> getBottlenecks({
    Duration threshold = const Duration(milliseconds: 100),
  }) =>
      serviceTimings.entries
          .where((entry) => entry.value > threshold)
          .map((entry) => entry.key)
          .toList()
        ..sort((a, b) => serviceTimings[b]!.compareTo(serviceTimings[a]!));

  /// Get services by initialization time
  List<MapEntry<String, Duration>> get servicesByDuration {
    final entries = serviceTimings.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Calculate percentage of time spent in each service
  Map<String, double> get serviceTimePercentages {
    final total = totalDuration.inMicroseconds;
    if (total == 0) return {};

    return Map.fromEntries(
      serviceTimings.entries.map(
        (entry) =>
            MapEntry(entry.key, (entry.value.inMicroseconds / total) * 100),
      ),
    );
  }

  /// Generate performance report
  String generateReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== Startup Performance Report ===');
    buffer.writeln('Total time: ${totalDuration.inMilliseconds}ms');
    buffer.writeln('');

    buffer.writeln('Service Timings:');
    for (final entry in servicesByDuration) {
      final percentage = serviceTimePercentages[entry.key] ?? 0;
      buffer.writeln(
        '  ${entry.key}: ${entry.value.inMilliseconds}ms (${percentage.toStringAsFixed(1)}%)',
      );
    }

    if (errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  ${error.serviceName}: ${error.error}');
      }
    }

    final bottlenecks = getBottlenecks();
    if (bottlenecks.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Bottlenecks (>100ms):');
      for (final service in bottlenecks) {
        buffer.writeln(
          '  $service: ${serviceTimings[service]!.inMilliseconds}ms',
        );
      }
    }

    return buffer.toString();
  }
}

/// Detailed metrics for a single service
class ServiceMetrics {
  ServiceMetrics({
    required this.name,
    required this.startTime,
    this.endTime,
    this.success = true,
    this.error,
    this.stackTrace,
  });
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final bool success;
  final Object? error;
  final StackTrace? stackTrace;

  Duration? get duration => endTime?.difference(startTime);

  ServiceMetrics complete({
    bool success = true,
    Object? error,
    StackTrace? stackTrace,
  }) => ServiceMetrics(
    name: name,
    startTime: startTime,
    endTime: DateTime.now(),
    success: success,
    error: error,
    stackTrace: stackTrace,
  );
}

/// Error that occurred during startup
class StartupError {
  StartupError({
    required this.serviceName,
    required this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  final String serviceName;
  final Object error;
  final StackTrace? stackTrace;
  final DateTime timestamp;
}

/// Tracks metrics during startup
class MetricsCollector {
  final DateTime _startTime = DateTime.now();
  final Map<String, ServiceMetrics> _services = {};
  final List<StartupError> _errors = [];

  /// Start tracking a service
  void startService(String name) {
    _services[name] = ServiceMetrics(name: name, startTime: DateTime.now());
  }

  /// Mark service as complete
  void completeService(
    String name, {
    bool success = true,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final existing = _services[name];
    if (existing != null) {
      _services[name] = existing.complete(
        success: success,
        error: error,
        stackTrace: stackTrace,
      );

      if (!success && error != null) {
        _errors.add(
          StartupError(serviceName: name, error: error, stackTrace: stackTrace),
        );
      }
    }
  }

  /// Generate final metrics
  StartupMetrics generateMetrics() {
    final endTime = DateTime.now();
    final serviceTimings = <String, Duration>{};

    for (final entry in _services.entries) {
      final duration = entry.value.duration;
      if (duration != null) {
        serviceTimings[entry.key] = duration;
      }
    }

    return StartupMetrics(
      startTime: _startTime,
      endTime: endTime,
      serviceTimings: serviceTimings,
      detailedMetrics: Map.from(_services),
      errors: List.from(_errors),
    );
  }
}
