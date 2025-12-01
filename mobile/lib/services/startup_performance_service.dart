// ABOUTME: Comprehensive startup performance monitoring and optimization service
// ABOUTME: Tracks timing metrics, identifies bottlenecks, and provides lazy loading optimizations

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/crash_reporting_service.dart';

/// Tracks performance timing for different startup phases
class StartupPhaseTimer {
  StartupPhaseTimer(this.name) {
    startTime = DateTime.now();
  }

  final String name;
  late DateTime startTime;
  DateTime? endTime;
  bool _completed = false;

  void complete() {
    if (!_completed) {
      endTime = DateTime.now();
      _completed = true;
    }
  }

  Duration? get duration => endTime?.difference(startTime);

  bool get isCompleted => _completed;
}

/// Service for monitoring and optimizing app startup performance
class StartupPerformanceService {
  StartupPerformanceService._();
  static final StartupPerformanceService _instance =
      StartupPerformanceService._();
  static StartupPerformanceService get instance => _instance;

  final Map<String, StartupPhaseTimer> _phases = {};
  final Map<String, DateTime> _checkpoints = {};
  final List<String> _performanceWarnings = [];

  DateTime? _appStartTime;
  DateTime? _firstFrameTime;
  DateTime? _uiReadyTime;
  DateTime? _videoReadyTime;

  bool _isInitialized = false;

  /// Initialize the performance monitoring service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _appStartTime = DateTime.now();
    _phases['total'] = StartupPhaseTimer('Total App Startup');

    Log.info(
      '🚀 StartupPerformanceService: Monitoring initiated',
      name: 'StartupPerformance',
      category: LogCategory.system,
    );

    _isInitialized = true;

    // Set up first frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      markFirstFrame();
    });
  }

  /// Mark the start of a startup phase
  void startPhase(String phaseName) {
    if (!_isInitialized) return;

    _phases[phaseName] = StartupPhaseTimer(phaseName);
    Log.debug(
      '⏱️ Started phase: $phaseName',
      name: 'StartupPerformance',
      category: LogCategory.system,
    );

    CrashReportingService.instance.logInitializationStep(
      'Phase started: $phaseName',
    );
  }

  /// Mark the end of a startup phase
  void completePhase(String phaseName) {
    final phase = _phases[phaseName];
    if (phase != null && !phase.isCompleted) {
      phase.complete();
      final duration = phase.duration?.inMilliseconds ?? 0;

      Log.info(
        '✅ Completed phase: $phaseName in ${duration}ms',
        name: 'StartupPerformance',
        category: LogCategory.system,
      );

      CrashReportingService.instance.logInitializationStep(
        'Phase completed: $phaseName (${duration}ms)',
      );

      // Check for performance warnings
      if (duration > 1000) {
        _performanceWarnings.add('Phase $phaseName took ${duration}ms (>1s)');
      }
    }
  }

  /// Mark a performance checkpoint
  void checkpoint(String name) {
    if (!_isInitialized) return;

    _checkpoints[name] = DateTime.now();
    final elapsed = _checkpoints[name]!
        .difference(_appStartTime!)
        .inMilliseconds;

    Log.debug(
      '📍 Checkpoint: $name at ${elapsed}ms',
      name: 'StartupPerformance',
      category: LogCategory.system,
    );
  }

  /// Mark when first frame is rendered
  void markFirstFrame() {
    if (_firstFrameTime != null) return;

    _firstFrameTime = DateTime.now();
    final elapsed = _firstFrameTime!.difference(_appStartTime!).inMilliseconds;

    Log.info(
      '🖼️ First frame rendered in ${elapsed}ms',
      name: 'StartupPerformance',
      category: LogCategory.system,
    );

    CrashReportingService.instance.logInitializationStep(
      'First frame: ${elapsed}ms',
    );
    CrashReportingService.instance.setCustomKey('first_frame_ms', elapsed);
  }

  /// Mark when UI is ready for interaction
  void markUIReady() {
    if (_uiReadyTime != null) return;

    _uiReadyTime = DateTime.now();
    final elapsed = _uiReadyTime!.difference(_appStartTime!).inMilliseconds;

    Log.info(
      '🎯 UI ready for interaction in ${elapsed}ms',
      name: 'StartupPerformance',
      category: LogCategory.system,
    );

    CrashReportingService.instance.logInitializationStep(
      'UI ready: ${elapsed}ms',
    );
    CrashReportingService.instance.setCustomKey('ui_ready_ms', elapsed);
  }

  /// Mark when video system is ready
  void markVideoReady() {
    if (_videoReadyTime != null) return;

    _videoReadyTime = DateTime.now();
    final elapsed = _videoReadyTime!.difference(_appStartTime!).inMilliseconds;

    Log.info(
      '🎬 Video system ready in ${elapsed}ms',
      name: 'StartupPerformance',
      category: LogCategory.system,
    );

    CrashReportingService.instance.logInitializationStep(
      'Video ready: ${elapsed}ms',
    );
    CrashReportingService.instance.setCustomKey('video_ready_ms', elapsed);

    // Complete the total startup phase
    completePhase('total');

    // Generate final report
    if (kDebugMode) {
      generateReport();
    }
  }

  /// Defer heavy work until after UI is ready
  Future<T> deferUntilUIReady<T>(
    Future<T> Function() work, {
    String? taskName,
  }) async {
    // If UI is already ready, execute immediately
    if (_uiReadyTime != null) {
      return await work();
    }

    final completer = Completer<T>();

    // Wait for UI to be ready
    void checkUIReady() {
      if (_uiReadyTime != null) {
        // Execute the deferred work
        work()
            .then((result) {
              completer.complete(result);
            })
            .catchError((error) {
              completer.completeError(error);
            });
      } else {
        // Check again on next frame
        WidgetsBinding.instance.addPostFrameCallback((_) => checkUIReady());
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => checkUIReady());

    if (taskName != null) {
      Log.debug(
        '⏳ Deferring task: $taskName until UI ready',
        name: 'StartupPerformance',
        category: LogCategory.system,
      );
    }

    return completer.future;
  }

  /// Execute work with performance monitoring
  Future<T> measureWork<T>(String taskName, Future<T> Function() work) async {
    startPhase(taskName);

    try {
      final result = await work();
      completePhase(taskName);
      return result;
    } catch (error) {
      completePhase(taskName);
      _performanceWarnings.add('Task $taskName failed: $error');
      rethrow;
    }
  }

  /// Check if startup is taking too long and log warnings
  void checkForSlowStartup() {
    if (_appStartTime == null) return;

    final elapsed = DateTime.now().difference(_appStartTime!).inMilliseconds;

    if (elapsed > 5000 && _firstFrameTime == null) {
      Log.warning(
        '🐌 Slow startup: No first frame after ${elapsed}ms',
        name: 'StartupPerformance',
        category: LogCategory.system,
      );
      CrashReportingService.instance.log(
        'Slow startup detected: ${elapsed}ms without first frame',
      );
    }

    if (elapsed > 10000 && _uiReadyTime == null) {
      Log.warning(
        '🚨 Very slow startup: UI not ready after ${elapsed}ms',
        name: 'StartupPerformance',
        category: LogCategory.system,
      );
      CrashReportingService.instance.log(
        'Very slow startup: ${elapsed}ms without UI ready',
      );
    }
  }

  /// Generate performance report
  void generateReport() {
    if (!_isInitialized || _appStartTime == null) return;

    final report = StringBuffer();
    report.writeln('\n=== STARTUP PERFORMANCE REPORT ===');

    // Overall timings
    if (_firstFrameTime != null) {
      final firstFrameMs = _firstFrameTime!
          .difference(_appStartTime!)
          .inMilliseconds;
      report.writeln('First Frame: ${firstFrameMs}ms');
    }

    if (_uiReadyTime != null) {
      final uiReadyMs = _uiReadyTime!.difference(_appStartTime!).inMilliseconds;
      report.writeln('UI Ready: ${uiReadyMs}ms');
    }

    if (_videoReadyTime != null) {
      final videoReadyMs = _videoReadyTime!
          .difference(_appStartTime!)
          .inMilliseconds;
      report.writeln('Video Ready: ${videoReadyMs}ms');
    }

    // Phase timings
    report.writeln('\n--- Phase Timings ---');
    final sortedPhases = _phases.entries.toList()
      ..sort((a, b) => (a.value.startTime).compareTo(b.value.startTime));

    for (final entry in sortedPhases) {
      final phase = entry.value;
      if (phase.isCompleted) {
        final duration = phase.duration!.inMilliseconds;
        report.writeln('${entry.key}: ${duration}ms');
      }
    }

    // Checkpoints
    if (_checkpoints.isNotEmpty) {
      report.writeln('\n--- Checkpoints ---');
      final sortedCheckpoints = _checkpoints.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final entry in sortedCheckpoints) {
        final elapsed = entry.value.difference(_appStartTime!).inMilliseconds;
        report.writeln('${entry.key}: ${elapsed}ms');
      }
    }

    // Performance warnings
    if (_performanceWarnings.isNotEmpty) {
      report.writeln('\n--- Performance Warnings ---');
      for (final warning in _performanceWarnings) {
        report.writeln('⚠️  $warning');
      }
    }

    // Optimization recommendations
    report.writeln('\n--- Optimization Recommendations ---');

    if (_firstFrameTime != null &&
        _firstFrameTime!.difference(_appStartTime!).inMilliseconds > 2000) {
      report.writeln(
        '• Consider deferring heavy initialization until after first frame',
      );
    }

    if (_uiReadyTime != null &&
        _uiReadyTime!.difference(_appStartTime!).inMilliseconds > 3000) {
      report.writeln(
        '• Move non-critical service initialization to background',
      );
    }

    final slowPhases = _phases.entries
        .where(
          (e) => e.value.isCompleted && e.value.duration!.inMilliseconds > 500,
        )
        .toList();

    if (slowPhases.isNotEmpty) {
      report.writeln('• Optimize these slow phases:');
      for (final phase in slowPhases) {
        report.writeln(
          '  - ${phase.key}: ${phase.value.duration!.inMilliseconds}ms',
        );
      }
    }

    report.writeln('=====================================\n');

    Log.info(
      report.toString(),
      name: 'StartupPerformance',
      category: LogCategory.system,
    );
  }

  /// Get startup metrics for analytics
  Map<String, dynamic> getMetrics() {
    final metrics = <String, dynamic>{};

    if (_appStartTime != null) {
      metrics['app_start'] = _appStartTime!.millisecondsSinceEpoch;
    }

    if (_firstFrameTime != null) {
      metrics['first_frame_ms'] = _firstFrameTime!
          .difference(_appStartTime!)
          .inMilliseconds;
    }

    if (_uiReadyTime != null) {
      metrics['ui_ready_ms'] = _uiReadyTime!
          .difference(_appStartTime!)
          .inMilliseconds;
    }

    if (_videoReadyTime != null) {
      metrics['video_ready_ms'] = _videoReadyTime!
          .difference(_appStartTime!)
          .inMilliseconds;
    }

    // Add phase timings
    for (final entry in _phases.entries) {
      if (entry.value.isCompleted) {
        metrics['phase_${entry.key}_ms'] = entry.value.duration!.inMilliseconds;
      }
    }

    metrics['performance_warnings'] = _performanceWarnings.length;

    return metrics;
  }
}
