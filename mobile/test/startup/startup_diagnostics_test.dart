// ABOUTME: Tests for comprehensive startup diagnostics and monitoring
// ABOUTME: Validates timing logs, breadcrumbs, and timeout detection

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockCrashReporter extends Mock implements CrashReporter {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup Diagnostics', () {
    late StartupCoordinator coordinator;
    late _MockCrashReporter mockCrashReporting;
    late List<String> breadcrumbs;

    setUp(() {
      mockCrashReporting = _MockCrashReporter();
      breadcrumbs = [];
      when(() => mockCrashReporting.log(any())).thenAnswer((invocation) {
        breadcrumbs.add(invocation.positionalArguments[0] as String);
      });
      when(
        () => mockCrashReporting.recordError(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async {});
      coordinator = StartupCoordinator(crashReporter: mockCrashReporting);

      // Set up log capture
      Log.setLogLevel(LogLevel.debug);
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('should track startup timing for each service', () {
      fakeAsync((async) {
        coordinator = StartupCoordinator(crashReporter: mockCrashReporting);
        final first = Completer<void>();
        final second = Completer<void>();
        coordinator.registerService(
          name: 'TestService1',
          phase: StartupPhase.critical,
          initialize: () => first.future,
        );
        coordinator.registerService(
          name: 'TestService2',
          phase: StartupPhase.essential,
          initialize: () => second.future,
        );
        var initialized = false;
        unawaited(coordinator.initialize().then((_) => initialized = true));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        first.complete();
        async.flushMicrotasks();
        expect(initialized, isFalse);
        async.elapse(const Duration(milliseconds: 30));
        second.complete();
        async.flushMicrotasks();
        expect(initialized, isTrue);
        expect(
          coordinator.metrics.serviceTimings['TestService1'],
          const Duration(milliseconds: 50),
        );
        expect(
          coordinator.metrics.serviceTimings['TestService2'],
          const Duration(milliseconds: 30),
        );
        expect(
          coordinator.metrics.totalDuration,
          const Duration(milliseconds: 80),
        );
      });
    });

    test('should log breadcrumbs for each initialization step', () async {
      // Arrange
      coordinator.registerService(
        name: 'AuthService',
        phase: StartupPhase.critical,
        initialize: () async {},
      );

      coordinator.registerService(
        name: 'NostrService',
        phase: StartupPhase.essential,
        initialize: () async {},
      );

      // Act
      await coordinator.initialize();

      expect(breadcrumbs, contains('Initializing service: AuthService'));
      expect(breadcrumbs, contains('✓ AuthService initialized successfully'));
      expect(breadcrumbs, contains('Initializing service: NostrService'));
      expect(breadcrumbs, contains('✓ NostrService initialized successfully'));
      expect(coordinator.metrics.serviceTimings['AuthService'], isNotNull);
      expect(coordinator.metrics.serviceTimings['NostrService'], isNotNull);
    });

    test(
      'should leave deferred phases pending after blocking startup only',
      () async {
        final deferredCompleter = Completer<void>();

        coordinator.registerService(
          name: 'EnvironmentService',
          phase: StartupPhase.critical,
          initialize: () async {},
        );

        coordinator.registerService(
          name: 'DeferredWarmup',
          phase: StartupPhase.deferred,
          initialize: () => deferredCompleter.future,
          optional: true,
        );

        await coordinator.initializeThrough(StartupPhase.critical);

        expect(coordinator.isPhaseComplete(StartupPhase.critical), isTrue);
        expect(coordinator.isPhaseComplete(StartupPhase.deferred), isFalse);

        final remainingFuture = coordinator.initializeRemaining();
        await pumpEventQueue();
        expect(coordinator.isPhaseComplete(StartupPhase.deferred), isFalse);

        deferredCompleter.complete();
        await remainingFuture;

        expect(coordinator.isPhaseComplete(StartupPhase.deferred), isTrue);
      },
    );

    test('should generate a startup metrics report', () async {
      coordinator.registerService(
        name: 'FastService',
        phase: StartupPhase.critical,
        initialize: () async {},
      );

      coordinator.registerService(
        name: 'DeferredService',
        phase: StartupPhase.deferred,
        initialize: () async {},
        optional: true,
      );

      await coordinator.initialize();

      final report = coordinator.metrics.generateReport();
      expect(report, contains('Startup Performance Report'));
      expect(report, contains('Total time:'));
      expect(report, contains('FastService'));
      expect(report, contains('DeferredService'));
    });

    test('should detect and warn about slow initialization', () {
      fakeAsync((async) {
        final completer = Completer<void>();
        final slowWork = Completer<void>();
        final warnings = <String>[];
        Timer? timeoutTimer;

        coordinator.registerService(
          name: 'SlowService',
          phase: StartupPhase.critical,
          initialize: () async {
            // Start timeout detection
            timeoutTimer = Timer(const Duration(seconds: 2), () {
              warnings.add(
                'WARNING: SlowService initialization taking > 2 seconds',
              );
              mockCrashReporting.log(
                'Startup timeout detected for SlowService',
              );
            });

            await slowWork.future;
            timeoutTimer?.cancel();
            completer.complete();
          },
        );

        // Kick off initialization (fire-and-forget; we'll elapse past it).
        unawaited(coordinator.initialize());

        // After 2.1s, the 2s Timer should have fired.
        async.elapse(const Duration(seconds: 2, milliseconds: 100));
        expect(
          warnings,
          contains('WARNING: SlowService initialization taking > 2 seconds'),
        );

        // Release the service at exactly three seconds.
        async.elapse(const Duration(milliseconds: 900));
        slowWork.complete();
        async.flushMicrotasks();

        expect(completer.isCompleted, isTrue);
        final metrics = coordinator.metrics;
        expect(
          metrics.serviceTimings['SlowService']!.inMilliseconds,
          greaterThanOrEqualTo(3000),
        );
      });
    });

    test('should handle initialization failures with proper logging', () async {
      // Arrange

      coordinator.registerService(
        name: 'FailingService',
        phase: StartupPhase.critical,
        initialize: () async {
          throw Exception('Service initialization failed');
        },
      );

      // Act & Assert
      try {
        await coordinator.initialize();
        fail('Should have thrown an exception');
      } catch (e) {
        expect(e.toString(), contains('Service initialization failed'));

        // Metrics should still be available with error info
        final metrics = coordinator.metrics;
        expect(metrics.errors.length, greaterThan(0));
        expect(metrics.errors.first.serviceName, equals('FailingService'));
        expect(
          metrics.errors.first.error.toString(),
          contains('Service initialization failed'),
        );
      }
    });
  });
}
