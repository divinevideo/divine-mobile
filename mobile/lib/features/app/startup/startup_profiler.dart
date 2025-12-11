// ABOUTME: Profiles actual startup times and identifies bottlenecks
// ABOUTME: Analyzes provider initialization to optimize startup sequence

import 'package:flutter/foundation.dart';
import 'package:openvine/features/app/startup/startup_metrics.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Maps provider types to appropriate startup phases
// ignore: avoid_classes_with_only_static_members
class StartupPhaseMapper {
  static StartupPhase getPhaseForProvider(String providerName) {
    // Critical services - must init before app can function
    if (providerName.contains('Auth') ||
        providerName.contains('KeyStorage') ||
        providerName.contains('SecureKey')) {
      return StartupPhase.critical;
    }

    // Essential services - needed for basic UI
    if (providerName.contains('ConnectionStatus') ||
        providerName.contains('VideoVisibility') ||
        providerName.contains('NostrService') ||
        providerName.contains('NostrKeyManager')) {
      return StartupPhase.essential;
    }

    // Deferred services - can load after UI is responsive
    if (providerName.contains('Analytics') ||
        providerName.contains('Notification') ||
        providerName.contains('Curation') ||
        providerName.contains('ContentReporting') ||
        providerName.contains('ContentDeletion') ||
        providerName.contains('WebAuth')) {
      return StartupPhase.deferred;
    }

    // Standard services - everything else
    return StartupPhase.standard;
  }

  /// Get dependencies for a provider
  static List<String> getDependencies(String providerName) {
    final deps = <String>[];

    // Services that depend on auth
    if (providerName.contains('Social') ||
        providerName.contains('VideoEventPublisher') ||
        providerName.contains('CuratedList')) {
      deps.add('AuthService');
    }

    // Services that depend on Nostr
    if (providerName.contains('VideoEvent') ||
        providerName.contains('UserProfile') ||
        providerName.contains('Social') ||
        providerName.contains('Subscription')) {
      deps.add('NostrService');
    }

    // Services that depend on key storage
    if (providerName.contains('Auth')) {
      deps.add('SecureKeyStorage');
    }

    return deps;
  }
}

/// Tracks provider initialization times
class ProviderInitTracker {
  ProviderInitTracker(this.name) {
    isProxy = name.contains('Proxy');
  }
  final String name;
  final DateTime startTime = DateTime.now();
  DateTime? endTime;
  bool isProxy = false;

  void complete() {
    endTime = DateTime.now();
  }

  Duration? get duration => endTime?.difference(startTime);
}

/// Profiles app startup performance
class StartupProfiler {
  StartupProfiler._();
  static final StartupProfiler _instance = StartupProfiler._();
  static StartupProfiler get instance => _instance;

  final Map<String, ProviderInitTracker> _providers = {};
  DateTime? _appStartTime;
  DateTime? _appReadyTime;

  /// Mark app start
  void markAppStart() {
    _appStartTime = DateTime.now();
    Log.info('📱 App startup initiated', name: 'StartupProfiler');
    CrashReportingService.instance.logInitializationStep(
      'App startup initiated',
    );
  }

  /// Mark provider initialization start
  void markProviderStart(String name) {
    _providers[name] = ProviderInitTracker(name);
  }

  /// Mark provider initialization complete
  void markProviderComplete(String name) {
    _providers[name]?.complete();
  }

  /// Mark app ready (UI responsive)
  void markAppReady() {
    _appReadyTime = DateTime.now();
    Log.info('✅ App ready for interaction', name: 'StartupProfiler');

    final startupTime = _appReadyTime!
        .difference(_appStartTime!)
        .inMilliseconds;
    CrashReportingService.instance.logInitializationStep(
      'App ready - startup took ${startupTime}ms',
    );
    CrashReportingService.instance.setCustomKey('startup_time_ms', startupTime);

    if (kDebugMode) {
      printReport();
    }
  }

  /// Generate startup report
  StartupMetrics generateMetrics() {
    if (_appStartTime == null || _appReadyTime == null) {
      throw StateError('Startup profiling not complete');
    }

    final serviceTimings = <String, Duration>{};
    final detailedMetrics = <String, ServiceMetrics>{};

    for (final entry in _providers.entries) {
      final duration = entry.value.duration;
      if (duration != null) {
        serviceTimings[entry.key] = duration;
        detailedMetrics[entry.key] = ServiceMetrics(
          name: entry.key,
          startTime: entry.value.startTime,
          endTime: entry.value.endTime,
        );
      }
    }

    return StartupMetrics(
      startTime: _appStartTime!,
      endTime: _appReadyTime!,
      serviceTimings: serviceTimings,
      detailedMetrics: detailedMetrics,
      errors: [],
    );
  }

  /// Print startup report
  void printReport() {
    try {
      final metrics = generateMetrics();
      Log.info('\n${metrics.generateReport()}', name: 'StartupProfiler');

      // Additional analysis
      Log.info('\n=== Provider Analysis ===', name: 'StartupProfiler');

      // Group by phase
      final byPhase = <StartupPhase, List<MapEntry<String, Duration>>>{};
      for (final entry in metrics.serviceTimings.entries) {
        final phase = StartupPhaseMapper.getPhaseForProvider(entry.key);
        byPhase.putIfAbsent(phase, () => []).add(entry);
      }

      // Print by phase
      for (final phase in StartupPhase.values) {
        final providers = byPhase[phase] ?? [];
        if (providers.isEmpty) continue;

        final phaseTime = providers
            .map((e) => e.value.inMilliseconds)
            .reduce((a, b) => a + b);

        Log.info(
          '\n${phase.description}: ${phaseTime}ms total',
          name: 'StartupProfiler',
        );
        for (final provider in providers) {
          Log.info(
            '  ${provider.key}: ${provider.value.inMilliseconds}ms',
            name: 'StartupProfiler',
          );
        }
      }

      // Optimization suggestions
      Log.info('\n=== Optimization Suggestions ===', name: 'StartupProfiler');

      final deferrable = metrics.serviceTimings.entries
          .where(
            (e) =>
                StartupPhaseMapper.getPhaseForProvider(e.key) ==
                    StartupPhase.standard ||
                StartupPhaseMapper.getPhaseForProvider(e.key) ==
                    StartupPhase.deferred,
          )
          .where((e) => e.value.inMilliseconds > 50)
          .toList();

      if (deferrable.isNotEmpty) {
        Log.info(
          '\nConsider deferring these providers:',
          name: 'StartupProfiler',
        );
        for (final entry in deferrable) {
          Log.info(
            '  ${entry.key}: ${entry.value.inMilliseconds}ms',
            name: 'StartupProfiler',
          );
        }
      }

      // Parallel initialization opportunities
      final sequentialProviders = _identifySequentialProviders();
      if (sequentialProviders.isNotEmpty) {
        Log.info(
          '\nThese providers could initialize in parallel:',
          name: 'StartupProfiler',
        );
        for (final group in sequentialProviders) {
          Log.info('  Group: ${group.join(', ')}', name: 'StartupProfiler');
        }
      }
    } catch (e) {
      Log.error(
        'Failed to generate startup report',
        name: 'StartupProfiler',
        error: e,
      );
    }
  }

  /// Identify providers that could be initialized in parallel
  List<List<String>> _identifySequentialProviders() {
    final groups = <List<String>>[];

    // Find providers with no dependencies on each other
    final providers = _providers.keys.toList();
    final processed = <String>{};

    for (final provider in providers) {
      if (processed.contains(provider)) continue;

      final group = <String>[provider];
      final deps = StartupPhaseMapper.getDependencies(provider);

      // Find other providers with same dependencies
      for (final other in providers) {
        if (other == provider || processed.contains(other)) continue;

        final otherDeps = StartupPhaseMapper.getDependencies(other);
        if (_listEquals(deps, otherDeps)) {
          group.add(other);
        }
      }

      if (group.length > 1) {
        groups.add(group);
        processed.addAll(group);
      }
    }

    return groups;
  }

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
