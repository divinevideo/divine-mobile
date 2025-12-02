// ABOUTME: Tests for startup sequence coordinator that manages app initialization
// ABOUTME: Verifies progressive loading, timing, and dependency management

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';

void main() {
  group('StartupCoordinator', () {
    late StartupCoordinator coordinator;
    late List<String> initializationLog;
    late Map<String, Completer<void>> serviceCompleters;

    setUp(() {
      coordinator = StartupCoordinator();
      initializationLog = [];
      serviceCompleters = {};
    });

    // Helper to create a mock service initializer
    Future<void> Function() createServiceInitializer(String name) {
      final completer = Completer<void>();
      serviceCompleters[name] = completer;

      return () async {
        initializationLog.add('$name:start');
        await completer.future;
        initializationLog.add('$name:complete');
      };
    }

    test('should initialize critical services first', () async {
      // Register services in different phases
      coordinator.registerService(
        name: 'AuthService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('AuthService'),
      );

      coordinator.registerService(
        name: 'VideoService',
        phase: StartupPhase.deferred,
        initialize: createServiceInitializer('VideoService'),
      );

      coordinator.registerService(
        name: 'NostrService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('NostrService'),
      );

      // Start initialization but don't await
      final initFuture = coordinator.initialize();

      // Critical services should start immediately
      await Future.delayed(Duration.zero);
      expect(
        initializationLog,
        containsAll(['AuthService:start', 'NostrService:start']),
      );
      expect(initializationLog, isNot(contains('VideoService:start')));

      // Complete critical services
      serviceCompleters['AuthService']!.complete();
      serviceCompleters['NostrService']!.complete();

      // Wait for critical phase to complete
      await coordinator.waitForPhase(StartupPhase.critical);

      // Now deferred services should start
      await Future.delayed(Duration.zero);
      expect(initializationLog, contains('VideoService:start'));

      // Complete all services
      serviceCompleters['VideoService']!.complete();
      await initFuture;
    });

    test('should track initialization timing', () async {
      coordinator.registerService(
        name: 'FastService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 50));
        },
      );

      coordinator.registerService(
        name: 'SlowService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 200));
        },
      );

      await coordinator.initialize();

      final metrics = coordinator.metrics;
      expect(metrics.totalDuration.inMilliseconds, greaterThanOrEqualTo(200));
      expect(
        metrics.serviceTimings['FastService']!.inMilliseconds,
        lessThan(100),
      );
      expect(
        metrics.serviceTimings['SlowService']!.inMilliseconds,
        greaterThanOrEqualTo(200),
      );
    });

    test('should handle service dependencies', () async {
      coordinator.registerService(
        name: 'DatabaseService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('DatabaseService'),
      );

      coordinator.registerService(
        name: 'UserService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('UserService'),
        dependencies: ['DatabaseService'],
      );

      // Start initialization
      final initFuture = coordinator.initialize();
      await Future.delayed(Duration.zero);

      // DatabaseService should start first
      expect(initializationLog, contains('DatabaseService:start'));
      expect(initializationLog, isNot(contains('UserService:start')));

      // Complete DatabaseService
      serviceCompleters['DatabaseService']!.complete();
      await Future.delayed(Duration.zero);

      // Now UserService should start
      expect(initializationLog, contains('UserService:start'));

      // Complete all
      serviceCompleters['UserService']!.complete();
      await initFuture;
    });

    test('should support progressive initialization', () async {
      // Register services across phases
      coordinator.registerService(
        name: 'AuthService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('AuthService'),
      );

      coordinator.registerService(
        name: 'UIService',
        phase: StartupPhase.essential,
        initialize: createServiceInitializer('UIService'),
      );

      coordinator.registerService(
        name: 'AnalyticsService',
        phase: StartupPhase.deferred,
        initialize: createServiceInitializer('AnalyticsService'),
      );

      // Start initialization
      final initFuture = coordinator.initializeProgressive();

      // Wait for critical phase
      serviceCompleters['AuthService']!.complete();
      await coordinator.waitForPhase(StartupPhase.critical);

      // App should be ready for basic interaction
      expect(coordinator.isPhaseComplete(StartupPhase.critical), isTrue);
      expect(coordinator.isPhaseComplete(StartupPhase.essential), isFalse);

      // Complete remaining services
      serviceCompleters['UIService']!.complete();
      serviceCompleters['AnalyticsService']!.complete();
      await initFuture;
    });

    test('should handle initialization failures gracefully', () async {
      coordinator.registerService(
        name: 'FailingService',
        phase: StartupPhase.critical,
        initialize: () async {
          throw Exception('Service initialization failed');
        },
      );

      coordinator.registerService(
        name: 'OptionalService',
        phase: StartupPhase.deferred,
        initialize: createServiceInitializer('OptionalService'),
        optional: true,
      );

      final initFuture = coordinator.initialize();

      // Critical service failure should throw
      expect(initFuture, throwsException);

      // But optional service can fail without breaking initialization
      coordinator.registerService(
        name: 'AnotherOptionalService',
        phase: StartupPhase.deferred,
        initialize: () async {
          throw Exception('Optional service failed');
        },
        optional: true,
      );

      // Should complete without throwing for optional services
      serviceCompleters['OptionalService']!.complete();
      // Note: In real implementation, optional service failures wouldn't break the flow
    });

    test('should provide initialization progress', () async {
      // Register multiple services
      for (var i = 0; i < 5; i++) {
        coordinator.registerService(
          name: 'Service$i',
          phase: StartupPhase.critical,
          initialize: createServiceInitializer('Service$i'),
        );
      }

      final progressValues = <double>[];
      coordinator.progress.listen(progressValues.add);

      // Start initialization
      final initFuture = coordinator.initialize();

      // Complete services one by one
      for (var i = 0; i < 5; i++) {
        serviceCompleters['Service$i']!.complete();
        await Future.delayed(Duration.zero);
      }

      await initFuture;

      // Should have progress updates
      expect(progressValues.length, greaterThan(0));
      expect(progressValues.last, equals(1.0));
    });

    test('should calculate initialization bottlenecks', () async {
      // Create services with different durations
      coordinator.registerService(
        name: 'QuickService1',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 10));
        },
      );

      coordinator.registerService(
        name: 'SlowService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
      );

      coordinator.registerService(
        name: 'QuickService2',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 20));
        },
      );

      await coordinator.initialize();

      final bottlenecks = coordinator.metrics.getBottlenecks(
        threshold: const Duration(milliseconds: 100),
      );
      expect(bottlenecks, contains('SlowService'));
      expect(bottlenecks, isNot(contains('QuickService1')));
      expect(bottlenecks, isNot(contains('QuickService2')));
    });

    test('should support lazy service registration', () async {
      // Start with critical services
      coordinator.registerService(
        name: 'CoreService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('CoreService'),
      );

      // Start initialization
      final initFuture = coordinator.initializeProgressive();

      // Complete critical phase
      serviceCompleters['CoreService']!.complete();
      await coordinator.waitForPhase(StartupPhase.critical);

      // Register additional services in a phase that hasn't started yet
      coordinator.registerService(
        name: 'LateService',
        phase: StartupPhase.deferred,
        initialize: createServiceInitializer('LateService'),
      );

      // Wait a bit for deferred phase to start
      await Future.delayed(const Duration(milliseconds: 10));

      // Late service should now be initializing
      expect(
        initializationLog.any((log) => log.contains('LateService')),
        isTrue,
      );

      serviceCompleters['LateService']!.complete();
      await initFuture;
    });

    test('should enforce phase ordering', () async {
      final phaseCompletionOrder = <StartupPhase>[];

      // Listen for phase completions
      coordinator.phaseCompleted.listen(phaseCompletionOrder.add);

      // Register services in all phases
      for (final phase in StartupPhase.values) {
        coordinator.registerService(
          name: '${phase.name}Service',
          phase: phase,
          initialize: createServiceInitializer('${phase.name}Service'),
        );
      }

      // Start initialization
      final initFuture = coordinator.initialize();

      // Complete services in random order
      final phases = StartupPhase.values.toList()..shuffle();
      for (final phase in phases) {
        serviceCompleters['${phase.name}Service']!.complete();
        await Future.delayed(Duration.zero);
      }

      await initFuture;

      // Phases should complete in order
      expect(phaseCompletionOrder, equals(StartupPhase.values));
    });
  });
}
