import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/foreground_idle_warmup_coordinator.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  group('ForegroundIdleWarmupCoordinator', () {
    late DateTime now;
    late bool isForeground;
    late bool isIdle;
    late List<String> calls;

    ForegroundIdleWarmupCoordinator coordinatorWith(
      List<ForegroundIdleWarmupTask> tasks,
    ) {
      return ForegroundIdleWarmupCoordinator(
        tasks: tasks,
        isForeground: () => isForeground,
        isIdle: () => isIdle,
        now: () => now,
      );
    }

    ForegroundIdleWarmupTask task(
      ForegroundIdleWarmupTaskId id, {
      Duration cooldown = const Duration(minutes: 5),
      Future<void> Function()? run,
    }) {
      return ForegroundIdleWarmupTask(
        id: id,
        cooldown: cooldown,
        run: run ?? () async => calls.add(id.name),
      );
    }

    setUp(() async {
      await LogCaptureService().clearAllLogs();
      now = DateTime(2026, 6, 17, 12);
      isForeground = true;
      isIdle = true;
      calls = [];
    });

    tearDown(() async {
      await LogCaptureService().clearAllLogs();
    });

    test('runs eligible warmups when the app is foreground and idle', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
        task(ForegroundIdleWarmupTaskId.newVideos),
        task(ForegroundIdleWarmupTaskId.popular),
        task(ForegroundIdleWarmupTaskId.notifications),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, ['forYou', 'newVideos', 'popular', 'notifications']);
    });

    test('routine successful pass logs stay below info level', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      final warmupLogs = LogCaptureService().getRecentLogs().where(
        (entry) => entry.message.startsWith('Foreground idle warmup '),
      );
      expect(
        warmupLogs.where((entry) => entry.level == LogLevel.info),
        isEmpty,
      );
      expect(
        _latestLogContaining('Foreground idle warmup started')?.level,
        LogLevel.debug,
      );
      expect(
        _latestLogContaining('Foreground idle warmup completed forYou')?.level,
        LogLevel.debug,
      );
    });

    test('does not run while the app is backgrounded', () async {
      isForeground = false;
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, isEmpty);
    });

    test('does not run while the app is not idle', () async {
      isIdle = false;
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, isEmpty);
    });

    test('blocked requests do not prevent later eligible warmups', () async {
      isForeground = false;
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, isEmpty);

      isForeground = true;
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou']);
    });

    test('coalesces concurrent warmup requests into one serial run', () async {
      final completer = Completer<void>();
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou-start');
            await completer.future;
            calls.add('forYou-end');
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      final first = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      final second = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(identical(first, second), isTrue);
      expect(calls, ['forYou-start']);

      completer.complete();
      await first;

      expect(calls, ['forYou-start', 'forYou-end', 'popular']);
    });

    test('coalesces in-flight requests after gates close', () async {
      final completer = Completer<void>();
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou-start');
            await completer.future;
            calls.add('forYou-end');
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      final first = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      isIdle = false;
      final second = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(identical(first, second), isTrue);
      expect(calls, ['forYou-start']);

      completer.complete();
      await first;

      expect(calls, ['forYou-start', 'forYou-end']);
    });

    test('stops waiting for an in-flight task when a gate closes', () async {
      final gateChanges = StreamController<void>.broadcast();
      addTearDown(gateChanges.close);
      final taskCompleter = Completer<void>();
      final coordinator = ForegroundIdleWarmupCoordinator(
        tasks: [
          task(
            ForegroundIdleWarmupTaskId.forYou,
            run: () async {
              calls.add('forYou-start');
              await taskCompleter.future;
              calls.add('forYou-end');
            },
          ),
          task(ForegroundIdleWarmupTaskId.popular),
        ],
        isForeground: () => isForeground,
        isIdle: () => isIdle,
        gateChanges: gateChanges.stream,
        now: () => now,
      );

      final warmup = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.startupSettled,
      );

      await pumpEventQueue();
      expect(calls, ['forYou-start']);

      isIdle = false;
      gateChanges.add(null);
      await warmup;

      expect(calls, ['forYou-start']);
      expect(taskCompleter.isCompleted, isFalse);

      taskCompleter.complete();
    });

    test('skips tasks inside their cooldown window', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou']);

      now = now.add(const Duration(minutes: 5, seconds: 1));
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou', 'forYou']);
    });

    test('not-applicable tasks do not consume cooldown', () async {
      var shouldRun = false;
      final coordinator = coordinatorWith([
        ForegroundIdleWarmupTask(
          id: ForegroundIdleWarmupTaskId.forYou,
          cooldown: const Duration(minutes: 5),
          shouldRun: () => shouldRun,
          run: () async => calls.add('forYou'),
        ),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.startupSettled,
      );

      expect(calls, isEmpty);

      shouldRun = true;
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou']);
    });

    test('runs tasks again at the cooldown boundary', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      now = now.add(const Duration(minutes: 5));

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou', 'forYou']);
    });

    test('applies cooldowns independently per task', () async {
      final coordinator = coordinatorWith([
        task(ForegroundIdleWarmupTaskId.forYou),
        task(ForegroundIdleWarmupTaskId.popular, cooldown: Duration.zero),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou', 'popular', 'popular']);
    });

    test('failed tasks do not consume cooldown or block later tasks', () async {
      var shouldFail = true;
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou');
            if (shouldFail) {
              throw StateError('network failed');
            }
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, ['forYou', 'popular']);

      shouldFail = false;
      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );

      expect(calls, ['forYou', 'popular', 'forYou']);
    });

    test('a timed-out task blocks later passes until it settles', () {
      fakeAsync((async) {
        final slowTask = Completer<void>();
        final coordinator = coordinatorWith([
          ForegroundIdleWarmupTask(
            id: ForegroundIdleWarmupTaskId.forYou,
            cooldown: const Duration(minutes: 5),
            timeout: const Duration(seconds: 1),
            run: () async {
              calls.add('forYou');
              await slowTask.future;
            },
          ),
          task(ForegroundIdleWarmupTaskId.newVideos),
          task(ForegroundIdleWarmupTaskId.popular),
        ]);

        unawaited(
          coordinator.requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.startupSettled,
          ),
        );
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        // The timed-out task stops the pass; later tasks are blocked rather
        // than run alongside the still-active task.
        expect(calls, ['forYou']);

        // A new request cannot start an overlapping pass while the abandoned
        // task is still active.
        unawaited(
          coordinator.requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
          ),
        );
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(calls, ['forYou']);

        // Once it settles, the next request runs the remaining tasks. The
        // timed-out task did not consume cooldown, so it runs again.
        slowTask.complete();
        async.flushMicrotasks();
        unawaited(
          coordinator.requestWarmup(
            trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
          ),
        );
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(calls, ['forYou', 'forYou', 'newVideos', 'popular']);
      });
    });

    test('blocks a new pass until an abandoned task settles after gate '
        'close', () async {
      final gateChanges = StreamController<void>.broadcast();
      addTearDown(gateChanges.close);
      final taskCompleter = Completer<void>();
      final coordinator = ForegroundIdleWarmupCoordinator(
        tasks: [
          task(
            ForegroundIdleWarmupTaskId.forYou,
            run: () async {
              calls.add('forYou');
              await taskCompleter.future;
            },
          ),
          task(ForegroundIdleWarmupTaskId.popular),
        ],
        isForeground: () => isForeground,
        isIdle: () => isIdle,
        gateChanges: gateChanges.stream,
        now: () => now,
      );

      final first = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.startupSettled,
      );
      await pumpEventQueue();
      expect(calls, ['forYou']);

      // Gate closes mid-task: the pass returns but the task is still running.
      isIdle = false;
      gateChanges.add(null);
      await first;
      expect(calls, ['forYou']);

      // Idle resumes, but a new request must not start an overlapping pass
      // while the abandoned task is still active.
      isIdle = true;
      final held = coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );
      await pumpEventQueue();
      expect(calls, ['forYou']);

      // Once the abandoned task settles, the held request resolves and
      // later requests run normally.
      taskCompleter.complete();
      await held;
      expect(calls, ['forYou']);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.periodicIdleCheck,
      );
      expect(calls, ['forYou', 'forYou', 'popular']);
    });

    test('stops before the next task if the app stops being idle', () async {
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou');
            isIdle = false;
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, ['forYou']);
    });

    test('stops before the next task if the app is backgrounded', () async {
      final coordinator = coordinatorWith([
        task(
          ForegroundIdleWarmupTaskId.forYou,
          run: () async {
            calls.add('forYou');
            isForeground = false;
          },
        ),
        task(ForegroundIdleWarmupTaskId.popular),
      ]);

      await coordinator.requestWarmup(
        trigger: ForegroundIdleWarmupTrigger.videoPlaybackSettled,
      );

      expect(calls, ['forYou']);
    });
  });

  group('ForegroundIdleWarmupScheduler', () {
    setUp(() async {
      await LogCaptureService().clearAllLogs();
    });

    tearDown(() async {
      await LogCaptureService().clearAllLogs();
    });

    test('runs an initial warmup after the startup delay', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 9));

        expect(triggers, isEmpty);

        async.elapse(const Duration(seconds: 1));

        expect(triggers, [ForegroundIdleWarmupTrigger.startupSettled]);
        scheduler.stop();
      });
    });

    test('keeps lifecycle logs at info and routine ticks at debug', () {
      fakeAsync((async) {
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (_) => Future<void>.value(),
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 10));
        scheduler.stop();

        expect(
          _latestLogContaining(
            'Foreground idle warmup scheduler started',
          )?.level,
          LogLevel.info,
        );
        expect(
          _latestLogContaining('Foreground idle warmup scheduler fired')?.level,
          LogLevel.debug,
        );
        expect(
          _latestLogContaining(
            'Foreground idle warmup scheduler stopped',
          )?.level,
          LogLevel.info,
        );
      });
    });

    test('runs periodic warmups after start', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 10));
        async.elapse(const Duration(minutes: 10));

        expect(triggers, [
          ForegroundIdleWarmupTrigger.startupSettled,
          ForegroundIdleWarmupTrigger.periodicIdleCheck,
          ForegroundIdleWarmupTrigger.periodicIdleCheck,
        ]);
        scheduler.stop();
      });
    });

    test('start is idempotent', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        scheduler.start();
        async.elapse(const Duration(seconds: 10));
        async.elapse(const Duration(minutes: 5));

        expect(triggers, [
          ForegroundIdleWarmupTrigger.startupSettled,
          ForegroundIdleWarmupTrigger.periodicIdleCheck,
        ]);
        scheduler.stop();
      });
    });

    test('stop cancels scheduled warmups', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        scheduler.stop();
        async.elapse(const Duration(minutes: 10));

        expect(triggers, isEmpty);
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('stop cancels periodic warmups after startup fires', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 10));
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.periodicTimerCount, 1);

        scheduler.stop();
        async.elapse(const Duration(minutes: 5));

        expect(triggers, [ForegroundIdleWarmupTrigger.startupSettled]);
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('can be restarted after stop', () {
      fakeAsync((async) {
        final triggers = <ForegroundIdleWarmupTrigger>[];
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (trigger) {
            triggers.add(trigger);
            return Future<void>.value();
          },
        );

        scheduler.start();
        scheduler.stop();
        async.elapse(const Duration(seconds: 10));

        scheduler.start();
        async.elapse(const Duration(seconds: 10));

        expect(triggers, [ForegroundIdleWarmupTrigger.startupSettled]);
        scheduler.stop();
        expect(async.nonPeriodicTimerCount, 0);
        expect(async.periodicTimerCount, 0);
      });
    });

    test('handles failed scheduled warmup futures', () {
      fakeAsync((async) {
        final scheduler = ForegroundIdleWarmupScheduler(
          requestWarmup: (_) => Future<void>.error(StateError('boom')),
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 10));

        expect(() => async.flushMicrotasks(), returnsNormally);
        scheduler.stop();
      });
    });

    test('delegates overlapping periodic ticks to request coalescing', () {
      fakeAsync((async) {
        final completer = Completer<void>();
        var calls = 0;
        final scheduler = ForegroundIdleWarmupScheduler(
          startupDelay: const Duration(days: 1),
          interval: const Duration(seconds: 1),
          requestWarmup: (_) {
            calls++;
            return completer.future;
          },
        );

        scheduler.start();
        async.elapse(const Duration(seconds: 3));

        expect(calls, 3);
        completer.complete();
        async.flushMicrotasks();
        scheduler.stop();
      });
    });
  });
}

LogEntry? _latestLogContaining(String message) {
  final matches = LogCaptureService().getRecentLogs().where(
    (entry) => entry.message.contains(message),
  );
  return matches.isEmpty ? null : matches.last;
}
