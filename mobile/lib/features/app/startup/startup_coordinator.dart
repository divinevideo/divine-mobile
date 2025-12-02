// ABOUTME: Coordinates app startup sequence with progressive initialization
import 'package:flutter/foundation.dart'; // ABOUTME: Manages service dependencies and tracks performance metrics

import 'dart:async';

import 'package:openvine/features/app/startup/startup_metrics.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
  final Map<String, ServiceRegistration> _services = {};
  final Map<StartupPhase, List<String>> _servicesByPhase = {};
  final Map<String, bool> _completedServices = {};
  final Map<StartupPhase, bool> _completedPhases = {};
  final MetricsCollector _metricsCollector = MetricsCollector();
  final Set<String> _pendingLateServices = {};

  final _progressController = StreamController<double>.broadcast();
  final _phaseCompletedController = StreamController<StartupPhase>.broadcast();

  bool _isInitializing = false;
  StartupMetrics? _metrics;

  /// Stream of initialization progress (0.0 to 1.0)
  Stream<double> get progress => _progressController.stream;

  /// Stream of completed phases
  Stream<StartupPhase> get phaseCompleted => _phaseCompletedController.stream;

  /// Get final metrics after initialization
  StartupMetrics get metrics => _metrics ?? _metricsCollector.generateMetrics();

  /// Check if a phase is complete
  bool isPhaseComplete(StartupPhase phase) => _completedPhases[phase] ?? false;

  /// Register a service for initialization
  void registerService({
    required String name,
    required StartupPhase phase,
    required Future<void> Function() initialize,
    List<String> dependencies = const [],
    bool optional = false,
  }) {
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

    // If we're already initializing and this phase hasn't completed yet,
    // we can still initialize this service
    if (_isInitializing && !isPhaseComplete(phase)) {
      final currentPhase = _getCurrentPhase();
      if (phase == currentPhase) {
        // Add to ongoing initialization
        _pendingLateServices.add(name);
        _initializeService(_services[name]!).then((_) {
          _pendingLateServices.remove(name);
        });
      }
    }
  }

  /// Initialize all services
  Future<void> initialize() async {
    if (_isInitializing) {
      throw StateError('Initialization already in progress');
    }

    _isInitializing = true;
    Log.info('Starting app initialization', name: 'StartupCoordinator');

    try {
      // Initialize phases in order
      for (final phase in StartupPhase.values) {
        await _initializePhase(phase);
      }

      _metrics = _metricsCollector.generateMetrics();
      Log.info(
        'App initialization complete in ${_metrics!.totalDuration.inMilliseconds}ms',
        name: 'StartupCoordinator',
      );

      if (kDebugMode) {
        debugPrint(_metrics!.generateReport());
      }
    } finally {
      _isInitializing = false;
      _progressController.add(1);
    }
  }

  /// Initialize with progressive loading
  Future<void> initializeProgressive() async {
    if (_isInitializing) {
      throw StateError('Initialization already in progress');
    }

    _isInitializing = true;
    Log.info(
      'Starting progressive app initialization',
      name: 'StartupCoordinator',
    );

    // Start all phases concurrently but respect dependencies
    final phaseFutures = <StartupPhase, Future<void>>{};

    for (final phase in StartupPhase.values) {
      phaseFutures[phase] = _initializePhaseWithDependencies(
        phase,
        phaseFutures,
      );
    }

    // Wait for all phases
    try {
      await Future.wait(phaseFutures.values);
      _metrics = _metricsCollector.generateMetrics();

      Log.info(
        'Progressive initialization complete in ${_metrics!.totalDuration.inMilliseconds}ms',
        name: 'StartupCoordinator',
      );
    } finally {
      _isInitializing = false;
      _progressController.add(1);
    }
  }

  /// Wait for a specific phase to complete
  Future<void> waitForPhase(StartupPhase phase) async {
    if (isPhaseComplete(phase)) return;

    await for (final completedPhase in phaseCompleted) {
      if (completedPhase == phase) return;
    }
  }

  /// Initialize a phase with its dependencies
  Future<void> _initializePhaseWithDependencies(
    StartupPhase phase,
    Map<StartupPhase, Future<void>> phaseFutures,
  ) async {
    // Wait for dependent phases
    for (final dep in phase.dependencies) {
      final depFuture = phaseFutures[dep];
      if (depFuture != null) {
        await depFuture;
      }
    }

    // Initialize this phase
    await _initializePhase(phase);

    // Wait for any pending late services in this phase
    while (_pendingLateServices.isNotEmpty) {
      final pending = _pendingLateServices
          .where((name) => _services[name]?.phase == phase)
          .toList();
      if (pending.isEmpty) break;

      // Wait a bit for late services to complete
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Initialize all services in a phase
  Future<void> _initializePhase(StartupPhase phase) async {
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
    Log.debug('Initializing ${service.name}', name: 'StartupCoordinator');
    CrashReportingService.instance.logInitializationStep(
      'Initializing service: ${service.name}',
    );
    _metricsCollector.startService(service.name);

    try {
      await service.initialize();

      _completedServices[service.name] = true;
      _metricsCollector.completeService(service.name);
      _updateProgress();

      Log.debug(
        '✓ ${service.name} initialized in ${_metricsCollector.generateMetrics().serviceTimings[service.name]?.inMilliseconds ?? 0}ms',
        name: 'StartupCoordinator',
      );
      CrashReportingService.instance.logInitializationStep(
        '✓ ${service.name} initialized successfully',
      );
    } catch (error, stackTrace) {
      _metricsCollector.completeService(
        service.name,
        success: false,
        error: error,
        stackTrace: stackTrace,
      );

      CrashReportingService.instance.recordError(
        error,
        stackTrace,
        reason: 'Service initialization failed: ${service.name}',
      );
      CrashReportingService.instance.logInitializationStep(
        '✗ ${service.name} failed: $error',
      );

      if (!service.optional) {
        Log.error(
          'Failed to initialize ${service.name}',
          name: 'StartupCoordinator',
          error: error,
        );
        rethrow;
      } else {
        Log.warning(
          'Optional service ${service.name} failed to initialize: $error',
          name: 'StartupCoordinator',
        );
        _completedServices[service.name] =
            true; // Mark as "complete" to continue
        _updateProgress();
      }
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

        // Check if all dependencies are processed
        if (service.dependencies.every(processed.contains)) {
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

  /// Mark a phase as complete
  void _markPhaseComplete(StartupPhase phase) {
    _completedPhases[phase] = true;
    _phaseCompletedController.add(phase);

    Log.info('✓ ${phase.name} phase complete', name: 'StartupCoordinator');
  }

  /// Update initialization progress
  void _updateProgress() {
    final total = _services.length;
    final completed = _completedServices.length;

    if (total > 0) {
      final progress = completed / total;
      _progressController.add(progress);
    }
  }

  /// Get current phase being initialized
  StartupPhase _getCurrentPhase() {
    for (final phase in StartupPhase.values.reversed) {
      if (_completedPhases[phase] ?? false) {
        final nextIndex = phase.index + 1;
        if (nextIndex < StartupPhase.values.length) {
          return StartupPhase.values[nextIndex];
        }
        return phase;
      }
    }
    return StartupPhase.values.first;
  }

  void dispose() {
    _progressController.close();
    _phaseCompletedController.close();
  }
}
