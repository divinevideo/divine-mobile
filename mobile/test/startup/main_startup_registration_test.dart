import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/app/startup/startup_phase.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/device_scope.dart';
import 'package:openvine/providers/media_cache_budget_provider.dart';
import 'package:openvine/providers/startup_performance_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/media_cache_budget.dart';
import 'package:openvine/services/media_cache_budget_service.dart';
import 'package:openvine/services/startup_performance_service.dart';
import 'package:openvine/startup/app_bootstrap.dart' as bootstrap;
import 'package:openvine/startup/startup_coordinator_factory.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

class _MockDeviceScope extends Mock implements DeviceScope {}

class _MockMediaCacheBudgetService extends Mock
    implements MediaCacheBudgetService {}

class _FakeUpdater implements ShorebirdUpdater {
  _FakeUpdater({this.status = UpdateStatus.upToDate, this.updateError});

  final UpdateStatus status;
  final Object? updateError;

  @override
  bool get isAvailable => true;

  @override
  Future<UpdateStatus> checkForUpdate({UpdateTrack? track}) async => status;

  @override
  Future<Patch?> readCurrentPatch() async => null;

  @override
  Future<Patch?> readNextPatch() async => null;

  @override
  Future<void> update({UpdateTrack? track}) async {
    if (updateError case final error?) throw error;
  }
}

void main() {
  group('startShorebirdStartupUpdate', () {
    test(
      'starts the Shorebird track update without waiting for a frame',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        var updaterCreations = 0;
        var updateCalls = 0;

        bootstrap.startShorebirdStartupUpdate(
          preferences: preferences,
          updaterFactory: () {
            updaterCreations++;
            return _FakeUpdater();
          },
          updateSubscribedTrack:
              ({required updater, required preferences}) async {
                updateCalls++;
              },
        );

        // No frame is rendered anywhere in this test. Startup calls this ~236
        // lines before `runApp`, so anything that only ran on the first frame
        // was stranded by a Dart-side failure in between — the launch a patch
        // most often exists to repair.
        await pumpEventQueue();

        expect(updaterCreations, 1);
        expect(updateCalls, 1);
      },
    );

    test('constructs the updater exactly once for the whole startup', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      ShorebirdUpdater? shared;
      var updaterCreations = 0;

      bootstrap.startShorebirdStartupUpdate(
        preferences: preferences,
        updaterFactory: () {
          updaterCreations++;
          return shared ??= _FakeUpdater();
        },
        updateSubscribedTrack: ({
          required updater,
          required preferences,
        }) async {},
      );

      // The synchronous FFI probe in the real constructor is the cost of moving
      // this off the first frame, so build provenance must reuse this instance
      // rather than pay it twice.
      expect(updaterCreations, 1);
      expect(shared, isNotNull);
    });
  });

  group('updateShorebirdFromSubscribedTrack', () {
    test('does not report expected Shorebird update failures', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var reports = 0;

      await bootstrap.updateShorebirdFromSubscribedTrack(
        updater: _FakeUpdater(
          status: UpdateStatus.outdated,
          updateError: const UpdateException(
            message: 'download failed',
            reason: UpdateFailureReason.downloadFailed,
          ),
        ),
        preferences: preferences,
        reportUnexpectedError: (error, stackTrace) async => reports++,
      );

      expect(reports, 0);
    });

    test('reports unexpected Shorebird startup failures', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      Object? reported;
      final error = StateError('broken invariant');

      await bootstrap.updateShorebirdFromSubscribedTrack(
        updater: _FakeUpdater(
          status: UpdateStatus.outdated,
          updateError: error,
        ),
        preferences: preferences,
        reportUnexpectedError: (value, stackTrace) async => reported = value,
      );

      expect(reported, same(error));
    });
  });

  group('createStartupCoordinatorForTesting', () {
    test('initializes disk-backed startup services before runApp', () {
      final container = _containerWithStartupPerformance();
      addTearDown(container.dispose);

      final coordinator = app.createStartupCoordinatorForTesting(container);

      expect(
        coordinator.crashReporterForTesting,
        same(container.read(crashReportingServiceProvider)),
      );
      expect(
        coordinator.serviceRegistrationForTesting('HiveStorage')?.phase,
        StartupPhase.critical,
      );
      expect(
        coordinator.serviceRegistrationForTesting('CacheSync')?.phase,
        StartupPhase.critical,
      );
    });

    test('opens the uploads box only after Hive has a home path', () {
      final container = _containerWithStartupPerformance();
      addTearDown(container.dispose);

      final coordinator = app.createStartupCoordinatorForTesting(container);

      // HiveStorage is the only owner of Hive's process-global home path, so the
      // uploads box must not open before it — otherwise the box lands in
      // whatever directory happens to be current (#6958).
      expect(
        coordinator
            .serviceRegistrationForTesting('UploadManager')
            ?.dependencies,
        contains('HiveStorage'),
      );
    });

    test('initializes performance monitoring before runApp', () {
      final container = _containerWithStartupPerformance();
      addTearDown(container.dispose);

      final coordinator = app.createStartupCoordinatorForTesting(container);

      // Anything later drops every trace started during cold start: the monitor
      // early-returns until it is initialized, so the traces are never created
      // rather than merely late (#7118).
      expect(
        coordinator
            .serviceRegistrationForTesting('PerformanceMonitoring')
            ?.phase,
        StartupPhase.critical,
      );
    });

    test('performance monitoring does not extend the critical phase', () {
      final container = _containerWithStartupPerformance();
      addTearDown(container.dispose);

      final coordinator = app.createStartupCoordinatorForTesting(container);

      // The phase runs each dependency level with `Future.wait`, so a
      // dependency-free service costs nothing beyond the slowest sibling. Giving
      // it a dependency would move it into a later level and put its platform
      // round-trip on the critical path in series.
      expect(
        coordinator
            .serviceRegistrationForTesting('PerformanceMonitoring')
            ?.dependencies,
        isEmpty,
      );
    });

    test('runs C2PA debris cleanup as optional deferred startup work', () {
      final container = _containerWithStartupPerformance();
      addTearDown(container.dispose);

      final coordinator = app.createStartupCoordinatorForTesting(container);
      final registration = coordinator.serviceRegistrationForTesting(
        'C2paDebrisSweep',
      );

      expect(registration?.phase, StartupPhase.deferred);
      expect(registration?.optional, isTrue);
    });

    testWidgets(
      'VideoCacheManifest refreshes the live account container when an '
      'account switch finishes before the detached sweep',
      (tester) async {
        final controller = AccountSwitchController();
        final scope = _MockDeviceScope();
        when(() => scope.switchController).thenReturn(controller);
        final startupBudget = _MockMediaCacheBudgetService();
        final nextBudget = _MockMediaCacheBudgetService();
        when(
          startupBudget.refresh,
        ).thenAnswer((_) async => mediaCacheBudgetFloor);
        when(nextBudget.refresh).thenAnswer((_) async => mediaCacheBudgetFloor);

        final crashReporting = CrashReportingService();
        final startupPerformance = StartupPerformanceService(
          crashReporting: crashReporting,
        );
        final startup = ProviderContainer(
          overrides: [
            deviceScopeProvider.overrideWithValue(scope),
            crashReportingServiceProvider.overrideWithValue(crashReporting),
            startupPerformanceServiceProvider.overrideWithValue(
              startupPerformance,
            ),
            mediaCacheBudgetServiceProvider.overrideWithValue(startupBudget),
          ],
        );
        final next = ProviderContainer(
          overrides: [
            mediaCacheBudgetServiceProvider.overrideWithValue(nextBudget),
          ],
        );
        addTearDown(next.dispose);

        Future<void> Function()? refreshBudget;
        final coordinator = app.createStartupCoordinatorForTesting(
          startup,
          videoCacheManifestInitializer:
              ({
                required startupPerformance,
                required crashReporting,
                required refreshMediaCacheBudget,
              }) async {
                refreshBudget = refreshMediaCacheBudget;
              },
        );

        await tester.pumpWidget(
          ContainerSwapHost(
            initialContainer: startup,
            controller: controller,
            child: const SizedBox(),
          ),
        );
        await coordinator
            .serviceRegistrationForTesting('VideoCacheManifest')!
            .initialize();

        await controller.swapTo(next);
        await tester.pump();

        await refreshBudget!();

        verifyNever(startupBudget.refresh);
        verify(nextBudget.refresh).called(1);
      },
    );
  });
}

/// A container carrying the device-scoped overrides `DeviceScope` supplies in
/// production (#4743). Both providers are override-only, so a bare
/// `ProviderContainer` cannot build the coordinator.
ProviderContainer _containerWithStartupPerformance() {
  final crashReporting = CrashReportingService();
  return ProviderContainer(
    overrides: [
      crashReportingServiceProvider.overrideWithValue(crashReporting),
      startupPerformanceServiceProvider.overrideWithValue(
        StartupPerformanceService(crashReporting: crashReporting),
      ),
    ],
  );
}
