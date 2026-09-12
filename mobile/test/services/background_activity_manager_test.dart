// ABOUTME: Tests BackgroundActivityManager's lifecycle fan-out and reset.
// ABOUTME: Gives each test a fresh manager and resets it to cancel its timers.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/services/background_activity_manager.dart';

class TestBackgroundService implements BackgroundAwareService {
  @override
  String get serviceName => 'TestService';

  bool backgroundCalled = false;
  bool extendedBackgroundCalled = false;
  bool resumedCalled = false;

  @override
  void onAppBackgrounded() {
    backgroundCalled = true;
  }

  @override
  void onExtendedBackground() {
    extendedBackgroundCalled = true;
  }

  @override
  void onAppResumed() {
    resumedCalled = true;
  }
}

/// Service whose [onAppBackgrounded] throws synchronously — used to assert
/// the manager isolates failures and keeps processing remaining services.
class _ThrowingBackgroundService implements BackgroundAwareService {
  bool entered = false;

  @override
  String get serviceName => 'ThrowingService';

  @override
  void onAppBackgrounded() {
    entered = true;
    throw StateError('boom');
  }

  @override
  void onExtendedBackground() {}

  @override
  void onAppResumed() {}
}

void main() {
  group('BackgroundActivityManager', () {
    late BackgroundActivityManager manager;
    late TestBackgroundService testService;

    setUp(() async {
      manager = BackgroundActivityManager();
      testService = TestBackgroundService();

      await pumpEventQueue();
    });

    // Several cases arm timers or deliberately end in the background state.
    tearDown(() => manager.resetForTesting());

    group('resetForTesting', () {
      test('clears registrations', () {
        manager.registerService(testService);

        manager.resetForTesting();

        expect(manager.getStatus()['registeredServices'], 0);
      });

      test('restores the foreground state', () {
        manager.onAppLifecycleStateChanged(AppLifecycleState.paused);
        expect(manager.isAppInForeground, isFalse);

        manager.resetForTesting();

        expect(manager.isAppInForeground, isTrue);
      });
    });

    test('should start in foreground state', () {
      expect(manager.isAppInForeground, isTrue);
      expect(manager.isAppInBackground, isFalse);
    });

    test('should register and notify services', () async {
      manager.registerService(testService);
      addTearDown(() => manager.unregisterService(testService));

      // Simulate app going to background
      manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(manager.isAppInBackground, isTrue);

      // _performImmediateBackgroundActions wraps each service notification in
      // `Future.microtask(() async { await Future(fn).timeout(...); })`, so
      // the notification chain is microtask → Timer(0) → completion. Drain
      // the event queue deterministically instead of relying on a fixed
      // wall-clock delay, which is flaky under CI load.
      await pumpEventQueue();

      expect(testService.backgroundCalled, isTrue);
    });

    test(
      'isolates a throwing service so remaining services still get notified',
      () async {
        final throwing = _ThrowingBackgroundService();
        manager.registerService(throwing);
        manager.registerService(testService);
        addTearDown(() {
          manager.unregisterService(throwing);
          manager.unregisterService(testService);
        });

        manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

        // Same drain pattern as 'should register and notify services' —
        // the per-service notification chain is microtask → completion.
        await pumpEventQueue();

        expect(throwing.entered, isTrue);
        // The healthy service still received its notification despite the
        // sibling service throwing inside the same suspend pass.
        expect(testService.backgroundCalled, isTrue);
      },
    );

    test('should handle app resume', () async {
      manager.registerService(testService);
      addTearDown(() => manager.unregisterService(testService));

      // Go to background then resume
      manager.onAppLifecycleStateChanged(AppLifecycleState.paused);

      // Drain the background notification chain before transitioning back.
      await pumpEventQueue();

      manager.onAppLifecycleStateChanged(AppLifecycleState.resumed);

      expect(manager.isAppInForeground, isTrue);
      expect(testService.resumedCalled, isTrue);
    });

    test('should unregister services', () {
      final initialCount = manager.getStatus()['registeredServices'] as int;

      manager.registerService(testService);
      expect(
        manager.getStatus()['registeredServices'],
        equals(initialCount + 1),
      );

      manager.unregisterService(testService);
      expect(manager.getStatus()['registeredServices'], equals(initialCount));
    });

    test('should provide status information', () {
      manager.registerService(testService);
      addTearDown(() => manager.unregisterService(testService));

      final status = manager.getStatus();
      expect(status['isAppInForeground'], isTrue);
      expect(status['registeredServices'], greaterThanOrEqualTo(1));
      expect(status['serviceNames'], contains('TestService'));
    });
  });
}
