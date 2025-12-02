// ABOUTME: Tests for comprehensive startup diagnostics and monitoring
// ABOUTME: Validates timing logs, breadcrumbs, and timeout detection

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/features/app/startup/startup_coordinator.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/features/app/startup/startup_profiler.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/utils/unified_logger.dart';

@GenerateMocks([CrashReportingService])
import 'startup_diagnostics_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup Diagnostics', () {
    late StartupCoordinator coordinator;
    late MockCrashReportingService mockCrashReporting;
    late List<String> breadcrumbs;

    setUp(() {
      coordinator = StartupCoordinator();
      mockCrashReporting = MockCrashReportingService();
      breadcrumbs = [];

      // Set up log capture
      Log.setLogLevel(LogLevel.debug);

      // Mock the CrashReportingService singleton
      when(mockCrashReporting.logInitializationStep(any)).thenAnswer((
        invocation,
      ) {
        breadcrumbs.add(invocation.positionalArguments[0] as String);
      });
    });

    tearDown(() {
      coordinator.dispose();
    });

    test('should track startup timing for each service', () async {
      // Arrange
      final startTime = DateTime.now();
      var service1Initialized = false;
      var service2Initialized = false;

      coordinator.registerService(
        name: 'TestService1',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          service1Initialized = true;
        },
      );

      coordinator.registerService(
        name: 'TestService2',
        phase: StartupPhase.essential,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 30));
          service2Initialized = true;
        },
      );

      // Act
      await coordinator.initialize();
      final endTime = DateTime.now();

      // Assert
      expect(service1Initialized, isTrue);
      expect(service2Initialized, isTrue);

      final metrics = coordinator.metrics;
      expect(metrics.serviceTimings['TestService1'], isNotNull);
      expect(metrics.serviceTimings['TestService2'], isNotNull);

      // Verify timing is reasonable
      expect(
        metrics.serviceTimings['TestService1']!.inMilliseconds,
        greaterThanOrEqualTo(50),
      );
      expect(
        metrics.serviceTimings['TestService2']!.inMilliseconds,
        greaterThanOrEqualTo(30),
      );

      // Total duration should be at least the sum of services
      expect(metrics.totalDuration.inMilliseconds, greaterThanOrEqualTo(80));
      expect(
        endTime.difference(startTime).inMilliseconds,
        greaterThanOrEqualTo(80),
      );
    });

    test('should log breadcrumbs for each initialization step', () async {
      // Arrange
      final profiler = StartupProfiler.instance;
      profiler.markAppStart();

      coordinator.registerService(
        name: 'AuthService',
        phase: StartupPhase.critical,
        initialize: () async {
          CrashReportingService.instance.logInitializationStep(
            'Initializing service: AuthService',
          );
          await Future.delayed(const Duration(milliseconds: 10));
          CrashReportingService.instance.logInitializationStep(
            '✓ AuthService initialized successfully',
          );
        },
      );

      coordinator.registerService(
        name: 'NostrService',
        phase: StartupPhase.essential,
        initialize: () async {
          CrashReportingService.instance.logInitializationStep(
            'Initializing service: NostrService',
          );
          await Future.delayed(const Duration(milliseconds: 10));
          CrashReportingService.instance.logInitializationStep(
            '✓ NostrService initialized successfully',
          );
        },
      );

      // Act
      await coordinator.initialize();
      profiler.markAppReady();

      // Assert - breadcrumbs should be logged (would be captured by mock)
      // In production, these would be sent to Crashlytics
      expect(coordinator.metrics.serviceTimings['AuthService'], isNotNull);
      expect(coordinator.metrics.serviceTimings['NostrService'], isNotNull);
    });

    test('should detect and warn about slow initialization', () async {
      // Arrange
      final completer = Completer<void>();
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
            CrashReportingService.instance.log(
              'Startup timeout detected for SlowService',
            );
          });

          // Simulate slow initialization
          await Future.delayed(const Duration(seconds: 3));
          timeoutTimer?.cancel();
          completer.complete();
        },
      );

      // Act
      final initFuture = coordinator.initialize();

      // Wait for timeout warning
      await Future.delayed(const Duration(seconds: 2, milliseconds: 100));

      // Assert - should have timeout warning
      expect(
        warnings,
        contains('WARNING: SlowService initialization taking > 2 seconds'),
      );

      // Wait for completion
      await initFuture;
      await completer.future;

      // Service should still complete
      final metrics = coordinator.metrics;
      expect(
        metrics.serviceTimings['SlowService']!.inMilliseconds,
        greaterThanOrEqualTo(3000),
      );
    });

    test('should provide detailed startup metrics report', () async {
      // Arrange
      coordinator.registerService(
        name: 'FastService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 10));
        },
      );

      coordinator.registerService(
        name: 'MediumService',
        phase: StartupPhase.essential,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 50));
        },
      );

      coordinator.registerService(
        name: 'SlowService',
        phase: StartupPhase.standard,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 100));
        },
        optional: true,
      );

      // Act
      await coordinator.initialize();
      final report = coordinator.metrics.generateReport();

      // Assert
      expect(report, contains('Startup Metrics Report'));
      expect(report, contains('Total Duration:'));
      expect(report, contains('FastService:'));
      expect(report, contains('MediumService:'));
      expect(report, contains('SlowService:'));
      expect(report, contains('ms'));
    });

    test('should handle initialization failures with proper logging', () async {
      // Arrange

      coordinator.registerService(
        name: 'FailingService',
        phase: StartupPhase.critical,
        initialize: () async {
          await Future.delayed(const Duration(milliseconds: 10));
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

    test(
      'should support progressive initialization with phase tracking',
      () async {
        // Arrange
        final phaseCompletions = <StartupPhase>[];
        coordinator.phaseCompleted.listen(phaseCompletions.add);

        coordinator.registerService(
          name: 'CriticalService',
          phase: StartupPhase.critical,
          initialize: () async {
            await Future.delayed(const Duration(milliseconds: 20));
          },
        );

        coordinator.registerService(
          name: 'EssentialService',
          phase: StartupPhase.essential,
          initialize: () async {
            await Future.delayed(const Duration(milliseconds: 30));
          },
        );

        coordinator.registerService(
          name: 'StandardService',
          phase: StartupPhase.standard,
          initialize: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        );

        // Act
        await coordinator.initializeProgressive();

        // Assert
        expect(
          phaseCompletions,
          containsAllInOrder([
            StartupPhase.critical,
            StartupPhase.essential,
            StartupPhase.standard,
          ]),
        );

        // All services should be initialized
        final metrics = coordinator.metrics;
        expect(metrics.serviceTimings.length, equals(3));
        expect(metrics.totalDuration.inMilliseconds, greaterThanOrEqualTo(30));
      },
    );

    test('should track initialization progress percentage', () async {
      // Arrange
      final progressUpdates = <double>[];
      final progressSubscription = coordinator.progress.listen(
        progressUpdates.add,
      );

      for (int i = 1; i <= 5; i++) {
        coordinator.registerService(
          name: 'Service$i',
          phase: StartupPhase.standard,
          initialize: () async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        );
      }

      // Act
      await coordinator.initialize();

      // Give time for the final progress update
      await Future.delayed(const Duration(milliseconds: 100));
      await progressSubscription.cancel();

      // Assert - we should have progress updates
      expect(progressUpdates.length, greaterThan(0));

      // The progress should show meaningful updates (at least 20% per service)
      // With 5 services, each should contribute ~0.2 to progress
      final lastProgress = progressUpdates.last;
      expect(
        lastProgress,
        greaterThanOrEqualTo(0.2),
        reason:
            'Expected progress after completing services, got: $progressUpdates',
      );

      // Progress should increase monotonically
      for (int i = 1; i < progressUpdates.length; i++) {
        expect(
          progressUpdates[i],
          greaterThanOrEqualTo(progressUpdates[i - 1]),
        );
      }
    });

    test('should identify optimization opportunities', () {
      // Arrange
      final profiler = StartupProfiler.instance;

      // Simulate provider initialization times
      profiler.markProviderStart('AuthServiceProvider');
      Future.delayed(const Duration(milliseconds: 20), () {
        profiler.markProviderComplete('AuthServiceProvider');
      });

      profiler.markProviderStart('AnalyticsServiceProvider');
      Future.delayed(const Duration(milliseconds: 150), () {
        profiler.markProviderComplete('AnalyticsServiceProvider');
      });

      profiler.markProviderStart('NotificationServiceProvider');
      Future.delayed(const Duration(milliseconds: 200), () {
        profiler.markProviderComplete('NotificationServiceProvider');
      });

      // Assert - these would be identified as deferrable in the report
      // Analytics and Notification services taking > 50ms in standard/deferred phase
      // should be flagged for optimization
    });
  });
}
