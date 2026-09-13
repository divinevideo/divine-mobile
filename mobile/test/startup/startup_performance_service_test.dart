// ABOUTME: Tests for StartupPerformanceService auth shell readiness
// ABOUTME: Each test builds its own instance, so no state crosses tests

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/startup_performance_service.dart';

import '../helpers/recording_performance_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(StartupPerformanceService, () {
    late StartupPerformanceService service;

    setUp(() {
      // A fresh instance per test. Before #4743 this was
      // `StartupPerformanceService.instance`, so every test inherited the
      // latch state of the one before it — which is what made the
      // idempotency test below unable to fail.
      service = StartupPerformanceService(
        crashReporting: CrashReportingService(),
      );
    });

    test(
      'flushes early measured milestones once after Firebase is ready',
      () async {
        await service.initialize();
        service.startPhase('bindings');
        service.completePhase('bindings');
        service.markFirstFrame();
        final firstFrameMs = service.getMetrics()['first_frame_ms'];
        final monitor = RecordingPerformanceMonitor();
        service.attachPerformanceMonitor(monitor);
        service.attachPerformanceMonitor(monitor);
        service.markFirstFrame();
        service.markAuthShellReady();
        service.startPhase('private-dynamic-name');
        service.completePhase('private-dynamic-name');
        expect(monitor.traces.length, 3);
        final frame = monitor.traces.singleWhere(
          (trace) => trace.attributes['milestone'] == 'first_frame',
        );
        expect(frame.metrics['elapsed_ms'], firstFrameMs);
        expect(frame.stops, 1);
        expect(
          monitor.traces.map((trace) => trace.attributes.toString()).join(),
          isNot(contains('private-dynamic-name')),
        );
      },
    );

    group('markAuthShellReady', () {
      test('sets authShellReadyTime', () async {
        await service.initialize();

        service.markAuthShellReady();

        expect(service.authShellReadyTime, isNotNull);
      });

      test(
        'is a no-op before initialize, because there is no start time',
        () async {
          service.markAuthShellReady();

          expect(service.authShellReadyTime, isNull);
        },
      );

      test('latches first-write-wins and ignores later calls', () async {
        await service.initialize();

        service.markAuthShellReady();
        final firstTime = service.authShellReadyTime;

        // Regression guard (#4743): asserting only `second == first` passes
        // when the method never runs at all, since null == null. Pinning the
        // latch as non-null first is what makes this test able to fail — it
        // survived a total no-op mutant before the DI conversion.
        expect(firstTime, isNotNull);

        service.markAuthShellReady();

        expect(service.authShellReadyTime, equals(firstTime));
      });
    });

    group('getMetrics', () {
      test(
        'reports auth shell readiness separately from UI readiness',
        () async {
          await service.initialize();

          service.markAuthShellReady();

          expect(service.authShellReadyTime, isNotNull);
          expect(service.getMetrics()['auth_shell_ready_ms'], isA<int>());
        },
      );
    });

    group('isolation', () {
      test('a new instance does not inherit another instance latch', () async {
        await service.initialize();
        service.markAuthShellReady();
        expect(service.authShellReadyTime, isNotNull);

        final other = StartupPerformanceService(
          crashReporting: CrashReportingService(),
        );

        expect(other.authShellReadyTime, isNull);
      });
    });
  });
}
