// ABOUTME: Coordinates app startup sequence with phased initialization

import 'package:flutter/foundation.dart'; // ABOUTME: Manages service dependencies and tracks performance metrics
import 'package:openvine/features/app/startup/startup_metrics.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service registration info
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ServiceRegistration {
  ServiceRegistration({
    required this.name,
    required this.phase,
    required this.initialize,
    this.dependencies = const [],
    this.optional = false,
  });
  final String name;
  final StartupPhase phase;
  final Future<void> Function() initialize;
  final List<String> dependencies;
  final bool optional;
}

/// Coordinates application startup sequence
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class StartupCoordinator {
  StartupCoordinator({CrashReporter? crashReporter})
    : _crashReporter = crashReporter ?? const SilentCrashReporter();

  final CrashReporter _crashReporter;

  final Map<String, ServiceRegistration> _services = {};
  final Map<StartupPhase, List<String>> _servicesByPhase = {};
  final Map<String, bool> _completedServices = {};
  final Map<StartupPhase, bool> _completedPhases = {};
  final MetricsCollector _metricsCollector = MetricsCollector();

  bool _registrationLocked = false;
  bool _isInitializing = false;
  StartupMetrics? _metrics;

  /// Get final metrics after initialization
  StartupMetrics get metrics => _metrics ?? _metricsCollector.generateMetrics();

  /// Check if a phase is complete
  bool isPhaseComplete(StartupPhase phase) => _completedPhases[phase] ?? false;

  /// Returns a registered service for startup-registration tests.
  @visibleForTesting
  ServiceRegistration? serviceRegistrationForTesting(String name) {
    return _services[name];
  }

  @visibleForTesting
  CrashReporter get crashReporterForTesting => _crashReporter;

  /// Register a service for initialization
  void registerService({
    required String name,
    required StartupPhase phase,
    required Future<void> Function() initialize,
    List<String> dependencies = const [],
    bool optional = false,
  }) {
    if (_registrationLocked) {
      throw StateError('Cannot register services after startup begins');
    }

    _services[name] = ServiceRegistration(
      name: name,
      phase: phase,
      initialize: initialize,
      dependencies: dependencies,
      optional: optional,
    );

    _servicesByPhase.putIfAbsent(phase, () => []).add(name);

    Log.debug(
      'Registered service $name in phase ${phase.name}',
      name: 'StartupCoordinator',
    );
  }

  /// Initialize all services
  Future<void> initialize() => _runInitialization(
    logMessage: 'Starting app initialization',
    body: () => _initializePhases(StartupPhase.values),
  );

  /// Initialize services only through the requested phase.
  Future<void> initializeThrough(StartupPhase lastPhase) => _runInitialization(
    logMessage: 'Starting app initialization through ${lastPhase.name} phase',
    body: () => _initializePhases(
      StartupPhase.values.where(
        (phase) => phase.priority <= lastPhase.priority,
      ),
    ),
  );

  /// Initialize every phase that has not already completed.
  Future<void> initializeRemaining() => _runInitialization(
    logMessage: 'Starting remaining app initialization phases',
    body: () => _initializePhases(
      StartupPhase.values.where((phase) => !isPhaseComplete(phase)),
    ),
  );

  /// Initialize all services in a phase
  Future<void> _initializePhase(StartupPhase phase) async {
    if (isPhaseComplete(phase)) return;

    final services = _servicesByPhase[phase] ?? [];
    if (services.isEmpty) {
      _markPhaseComplete(phase);
      return;
    }

    Log.info(
      'Initializing ${phase.name} phase with ${services.length} services',
      name: 'StartupCoordinator',
    );

    // Group services by dependency level
    final serviceLevels = _groupServicesByDependencyLevel(services);

    // Initialize each level sequentially
    for (final level in serviceLevels) {
      final futures = <Future<void>>[];

      for (final serviceName in level) {
        final service = _services[serviceName]!;
        futures.add(_initializeService(service));
      }

      // Wait for all services in this level
      await Future.wait(futures);
    }

    _markPhaseComplete(phase);
  }

  /// Initialize a single service
  Future<void> _initializeService(ServiceRegistration service) async {
    if (_completedServices[service.name] ?? false) {
      return;
    }

    Log.debug('Initializing ${service.name}', name: 'StartupCoordinator');
    _crashReporter.log('Initializing service: ${service.name}');
    _metricsCollector.startService(service.name);

    try {
      await service.initialize();

      _completedServices[service.name] = true;
      _metricsCollector.completeService(service.name);

      Log.debug(
        '✓ ${service.name} initialized in ${_metricsCollector.generateMetrics().serviceTimings[service.name]?.inMilliseconds ?? 0}ms',
        name: 'StartupCoordinator',
      );
      _crashReporter.log('✓ ${service.name} initialized successfully');
    } catch (error, stackTrace) {
      _metricsCollector.completeService(
        service.name,
        success: false,
        error: error,
        stackTrace: stackTrace,
      );

      // Log before awaiting the report: a bug report carries the unified log.
      if (!service.optional) {
        Log.error(
          'Failed to initialize ${service.name}',
          name: 'StartupCoordinator',
          error: error,
        );
      } else {
        Log.warning(
          'Optional service ${service.name} failed to initialize: $error',
          name: 'StartupCoordinator',
        );
      }

      try {
        await _crashReporter.recordError(
          error,
          stackTrace,
          reason: 'Service initialization failed: ${service.name}',
        );
      } catch (reportError, reportStackTrace) {
        // A failed report must not replace the service's own failure.
        Log.error(
          'Failed to report the ${service.name} failure',
          name: 'StartupCoordinator',
          error: reportError,
          stackTrace: reportStackTrace,
        );
      }
      _crashReporter.log('✗ ${service.name} failed: $error');

      if (!service.optional) {
        rethrow;
      }
      // Mark as "complete" to continue.
      _completedServices[service.name] = true;
    }
  }

  /// Group services by dependency level for parallel initialization
  List<List<String>> _groupServicesByDependencyLevel(List<String> services) {
    final levels = <List<String>>[];
    final processed = <String>{};
    final remaining = services.toSet();

    while (remaining.isNotEmpty) {
      final currentLevel = <String>[];

      for (final serviceName in remaining) {
        final service = _services[serviceName]!;

        // Dependencies may have completed in an earlier startup phase.
        if (service.dependencies.every(
          (dependency) => _isDependencySatisfied(dependency, processed),
        )) {
          currentLevel.add(serviceName);
        }
      }

      if (currentLevel.isEmpty && remaining.isNotEmpty) {
        // Circular dependency or missing dependency
        throw StateError(
          'Circular or missing dependencies detected for services: $remaining',
        );
      }

      levels.add(currentLevel);
      processed.addAll(currentLevel);
      remaining.removeAll(currentLevel);
    }

    return levels;
  }

  bool _isDependencySatisfied(
    String dependency,
    Set<String> processedInCurrentPhase,
  ) {
    return processedInCurrentPhase.contains(dependency) ||
        (_completedServices[dependency] ?? false);
  }

  /// Mark a phase as complete
  void _markPhaseComplete(StartupPhase phase) {
    _completedPhases[phase] = true;

    Log.info('✓ ${phase.name} phase complete', name: 'StartupCoordinator');
  }

  Future<void> _initializePhases(Iterable<StartupPhase> phases) async {
    for (final phase in phases) {
      await _initializePhase(phase);
    }
  }

  Future<void> _runInitialization({
    required String logMessage,
    required Future<void> Function() body,
  }) async {
    if (_isInitializing) {
      throw StateError('Initialization already in progress');
    }

    _registrationLocked = true;
    _isInitializing = true;
    Log.info(logMessage, name: 'StartupCoordinator');

    try {
      await body();
      _finalizeMetricsIfComplete();
    } finally {
      _isInitializing = false;
    }
  }

  void _finalizeMetricsIfComplete() {
    final allPhasesComplete = StartupPhase.values.every(isPhaseComplete);
    if (!allPhasesComplete) {
      return;
    }

    _metrics = _metricsCollector.generateMetrics();
    Log.info(
      'App initialization complete in ${_metrics!.totalDuration.inMilliseconds}ms',
      name: 'StartupCoordinator',
    );

    if (kDebugMode) {
      Log.debug(
        _metrics!.generateReport(),
        name: 'StartupCoordinator',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {}
}
