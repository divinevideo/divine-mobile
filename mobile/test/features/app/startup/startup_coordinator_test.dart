// ABOUTME: Tests for startup sequence coordinator that manages app initialization
// ABOUTME: Verifies progressive loading, timing, and dependency management

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_metrics.dart';
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

    test('should initialize phases in order', () async {
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

      // Now deferred services should start
      await Future.delayed(Duration.zero);
      expect(initializationLog, contains('VideoService:start'));

      // Complete all services
      serviceCompleters['VideoService']!.complete();
      await initFuture;
    });

    test('should track initialization timing', () {
      // `MetricsCollector` measures durations via `package:clock`'s `clock`,
      // which `fakeAsync` drives, so the 50 ms and 200 ms timings are exact
      // and deterministic. Real wall-clock timing flaked under CI scheduler
      // pressure when both timers fired on one starved tick and collapsed to
      // equal (fastMs == slowMs == 200), defeating an earlier relative
      // `fastMs < slowMs` bound.
      fakeAsync((async) {
        final coordinator = StartupCoordinator()
          ..registerService(
            name: 'FastService',
            phase: StartupPhase.critical,
            initialize: () =>
                Future<void>.delayed(const Duration(milliseconds: 50)),
          )
          ..registerService(
            name: 'SlowService',
            phase: StartupPhase.critical,
            initialize: () =>
                Future<void>.delayed(const Duration(milliseconds: 200)),
          );

        var initialized = false;
        unawaited(coordinator.initialize().then((_) => initialized = true));

        async.elapse(const Duration(milliseconds: 200));
        expect(initialized, isTrue);

        final metrics = coordinator.metrics;
        expect(
          metrics.serviceTimings['FastService'],
          const Duration(milliseconds: 50),
        );
        expect(
          metrics.serviceTimings['SlowService'],
          const Duration(milliseconds: 200),
        );
        expect(
          metrics.totalDuration,
          greaterThanOrEqualTo(const Duration(milliseconds: 200)),
        );
      });
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

    test('should initialize only through the requested phase', () async {
      coordinator.registerService(
        name: 'EnvironmentService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('EnvironmentService'),
      );

      coordinator.registerService(
        name: 'AuthService',
        phase: StartupPhase.essential,
        initialize: createServiceInitializer('AuthService'),
      );

      final initFuture = coordinator.initializeThrough(StartupPhase.critical);
      await Future<void>.delayed(Duration.zero);

      expect(initializationLog, contains('EnvironmentService:start'));
      expect(initializationLog, isNot(contains('AuthService:start')));

      serviceCompleters['EnvironmentService']!.complete();
      await initFuture;

      expect(
        initializationLog.where((entry) => entry == 'EnvironmentService:start'),
        hasLength(1),
      );
      expect(initializationLog, isNot(contains('AuthService:start')));
      expect(coordinator.isPhaseComplete(StartupPhase.critical), isTrue);
      expect(coordinator.isPhaseComplete(StartupPhase.essential), isFalse);
    });

    test(
      'should continue remaining phases without restarting completed work',
      () async {
        coordinator.registerService(
          name: 'EnvironmentService',
          phase: StartupPhase.critical,
          initialize: createServiceInitializer('EnvironmentService'),
        );

        coordinator.registerService(
          name: 'AuthService',
          phase: StartupPhase.essential,
          initialize: createServiceInitializer('AuthService'),
        );

        serviceCompleters['EnvironmentService']!.complete();
        await coordinator.initializeThrough(StartupPhase.critical);

        final initFuture = coordinator.initializeRemaining();
        await Future<void>.delayed(Duration.zero);

        expect(
          initializationLog.where(
            (entry) => entry == 'EnvironmentService:start',
          ),
          hasLength(1),
        );
        expect(initializationLog, contains('AuthService:start'));

        serviceCompleters['AuthService']!.complete();
        await initFuture;

        expect(coordinator.isPhaseComplete(StartupPhase.essential), isTrue);
      },
    );

    test('should resolve dependencies completed in earlier phases', () async {
      coordinator.registerService(
        name: 'HiveStorage',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('HiveStorage'),
      );

      coordinator.registerService(
        name: 'UploadManager',
        phase: StartupPhase.standard,
        initialize: createServiceInitializer('UploadManager'),
        dependencies: ['HiveStorage'],
      );

      final criticalFuture = coordinator.initializeThrough(
        StartupPhase.critical,
      );
      await Future<void>.delayed(Duration.zero);

      expect(initializationLog, contains('HiveStorage:start'));
      expect(initializationLog, isNot(contains('UploadManager:start')));

      serviceCompleters['HiveStorage']!.complete();
      await criticalFuture;

      final remainingFuture = coordinator.initializeRemaining();
      await Future<void>.delayed(Duration.zero);

      expect(initializationLog, contains('UploadManager:start'));

      serviceCompleters['UploadManager']!.complete();
      await remainingFuture;

      expect(coordinator.isPhaseComplete(StartupPhase.critical), isTrue);
      expect(coordinator.isPhaseComplete(StartupPhase.standard), isTrue);
    });

    test(
      'should reject service registration after initialization starts',
      () async {
        coordinator.registerService(
          name: 'EnvironmentService',
          phase: StartupPhase.critical,
          initialize: createServiceInitializer('EnvironmentService'),
        );

        final initFuture = coordinator.initializeThrough(StartupPhase.critical);
        await Future<void>.delayed(Duration.zero);

        expect(
          () => coordinator.registerService(
            name: 'LateService',
            phase: StartupPhase.deferred,
            initialize: createServiceInitializer('LateService'),
          ),
          throwsStateError,
        );

        serviceCompleters['EnvironmentService']!.complete();
        await initFuture;
      },
    );

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

      // Critical service failure should throw; await so the future completes
      await expectLater(initFuture, throwsException);

      // Optional service can fail without breaking initialization (tested below)
      serviceCompleters['OptionalService']!.complete();
    });

    test('optional service failure does not abort initialization', () async {
      coordinator.registerService(
        name: 'CriticalService',
        phase: StartupPhase.critical,
        initialize: createServiceInitializer('CriticalService'),
      );

      coordinator.registerService(
        name: 'AnotherOptionalService',
        phase: StartupPhase.deferred,
        initialize: () async {
          throw Exception('Optional service failed');
        },
        optional: true,
      );

      final initFuture = coordinator.initialize();
      serviceCompleters['CriticalService']!.complete();

      // Should complete without throwing; optional failure is logged only
      await initFuture;
    });

    test('should calculate initialization bottlenecks', () {
      final startTime = DateTime.utc(2026);
      final metrics = StartupMetrics(
        startTime: startTime,
        endTime: startTime.add(const Duration(milliseconds: 530)),
        serviceTimings: const {
          'QuickService1': Duration(milliseconds: 10),
          'SlowService': Duration(milliseconds: 500),
          'QuickService2': Duration(milliseconds: 20),
        },
        detailedMetrics: const <String, ServiceMetrics>{},
        errors: const <StartupError>[],
      );

      final bottlenecks = metrics.getBottlenecks();
      expect(bottlenecks, equals(['SlowService']));
    });
  });
}
