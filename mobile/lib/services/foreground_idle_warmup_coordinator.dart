// ABOUTME: Runs low-priority feed and notification warmups while the app is foreground idle.
// ABOUTME: Keeps warmups serialized, rate-limited, and non-critical.

import 'dart:async';

import 'package:unified_logger/unified_logger.dart';

/// App signals that can opportunistically trigger a lightweight warmup pass.
enum ForegroundIdleWarmupTrigger {
  /// Startup finished and the first frames have had time to settle.
  startupSettled,

  /// A foreground video has settled enough that tiny data requests are safe.
  videoPlaybackSettled,

  /// A periodic foreground-idle check fired.
  periodicIdleCheck,
}

/// Function used by the scheduler to request a warmup pass.
typedef ForegroundIdleWarmupRequest = Future<void> Function(
  ForegroundIdleWarmupTrigger trigger,
);

/// Starts delayed and periodic foreground-idle warmup requests.
class ForegroundIdleWarmupScheduler {
  /// Creates a scheduler.
  ForegroundIdleWarmupScheduler({
    required ForegroundIdleWarmupRequest requestWarmup,
    Duration startupDelay = const Duration(seconds: 10),
    Duration interval = const Duration(minutes: 5),
  }) : _requestWarmup = requestWarmup,
       _startupDelay = startupDelay,
       _interval = interval;

  final ForegroundIdleWarmupRequest _requestWarmup;
  final Duration _startupDelay;
  final Duration _interval;

  Timer? _startupTimer;
  Timer? _periodicTimer;

  /// Starts the scheduler once.
  void start() {
    if (_startupTimer != null || _periodicTimer != null) {
      Log.debug(
        'Foreground idle warmup scheduler already started',
        name: 'ForegroundIdleWarmupScheduler',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      'Foreground idle warmup scheduler started '
      '(startupDelay=${_startupDelay.inSeconds}s, '
      'interval=${_interval.inMinutes}m)',
      name: 'ForegroundIdleWarmupScheduler',
      category: LogCategory.system,
    );

    _startupTimer = Timer(_startupDelay, () {
      _requestSafely(ForegroundIdleWarmupTrigger.startupSettled);
    });
    _periodicTimer = Timer.periodic(_interval, (_) {
      _requestSafely(ForegroundIdleWarmupTrigger.periodicIdleCheck);
    });
  }

  /// Cancels all scheduled warmup requests.
  void stop() {
    if (_startupTimer != null || _periodicTimer != null) {
      Log.info(
        'Foreground idle warmup scheduler stopped',
        name: 'ForegroundIdleWarmupScheduler',
        category: LogCategory.system,
      );
    }
    _startupTimer?.cancel();
    _periodicTimer?.cancel();
    _startupTimer = null;
    _periodicTimer = null;
  }

  void _requestSafely(ForegroundIdleWarmupTrigger trigger) {
    Log.debug(
      'Foreground idle warmup scheduler fired (${trigger.name})',
      name: 'ForegroundIdleWarmupScheduler',
      category: LogCategory.system,
    );
    unawaited(
      Future.sync(() => _requestWarmup(trigger)).catchError((Object error) {
        Log.warning(
          'Scheduled foreground idle warmup failed '
          '(${trigger.name}): $error',
          name: 'ForegroundIdleWarmupScheduler',
          category: LogCategory.system,
        );
      }),
    );
  }
}

/// Logical warmup surfaces.
enum ForegroundIdleWarmupTaskId {
  forYou,
  newVideos,
  popular,
  notifications,
}

/// A lightweight data warmup task.
class ForegroundIdleWarmupTask {
  /// Creates a warmup task.
  const ForegroundIdleWarmupTask({
    required this.id,
    required this.run,
    required this.cooldown,
    this.shouldRun,
    this.timeout = const Duration(seconds: 12),
  });

  /// Surface warmed by this task.
  final ForegroundIdleWarmupTaskId id;

  /// Minimum time between successful runs.
  final Duration cooldown;

  /// Maximum time this low-priority task may occupy the serial queue.
  final Duration timeout;

  /// Whether this task has applicable warmup work right now.
  final bool Function()? shouldRun;

  /// Performs the data-only warmup.
  final Future<void> Function() run;
}

/// Serial, best-effort coordinator for foreground-idle data warmups.
class ForegroundIdleWarmupCoordinator {
  /// Creates a coordinator.
  ForegroundIdleWarmupCoordinator({
    required List<ForegroundIdleWarmupTask> tasks,
    required bool Function() isForeground,
    required bool Function() isIdle,
    Stream<void>? gateChanges,
    DateTime Function()? now,
  }) : _tasks = List.unmodifiable(tasks),
       _isForeground = isForeground,
       _isIdle = isIdle,
       _gateChanges = gateChanges,
       _now = now ?? DateTime.now;

  final List<ForegroundIdleWarmupTask> _tasks;
  final bool Function() _isForeground;
  final bool Function() _isIdle;
  final Stream<void>? _gateChanges;
  final DateTime Function() _now;

  final Map<ForegroundIdleWarmupTaskId, DateTime> _lastSuccessAt = {};
  Future<void>? _inFlight;
  Future<void>? _abandonedTaskRun;

  /// Requests a best-effort warmup pass.
  ///
  /// If another pass is running, returns the same future. Each pass checks the
  /// foreground/idle gates before every task so user interaction can stop the
  /// queue quickly.
  ///
  /// When a pass abandons a still-running task (a gate closed or the task
  /// timed out), the coordinator keeps accounting for that task until it
  /// settles. A new request made in that window waits for the abandoned task
  /// instead of starting an overlapping pass, so warmups can never contend
  /// with each other.
  Future<void> requestWarmup({required ForegroundIdleWarmupTrigger trigger}) {
    final inFlight = _inFlight;
    if (inFlight != null) {
      Log.debug(
        'Foreground idle warmup coalesced (${trigger.name})',
        name: 'ForegroundIdleWarmupCoordinator',
        category: LogCategory.system,
      );
      return inFlight;
    }

    final abandonedTaskRun = _abandonedTaskRun;
    if (abandonedTaskRun != null) {
      Log.debug(
        'Foreground idle warmup held (${trigger.name}): '
        'awaiting an abandoned task to settle',
        name: 'ForegroundIdleWarmupCoordinator',
        category: LogCategory.system,
      );
      return abandonedTaskRun;
    }

    if (!_canRun) {
      Log.debug(
        'Foreground idle warmup skipped (${trigger.name}): '
        'foreground=${_isForeground()}, idle=${_isIdle()}',
        name: 'ForegroundIdleWarmupCoordinator',
        category: LogCategory.system,
      );
      return Future<void>.value();
    }

    final future = _run(trigger).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  bool get _canRun => _isForeground() && _isIdle();

  Future<void> _run(ForegroundIdleWarmupTrigger trigger) async {
    Log.debug(
      'Foreground idle warmup started (${trigger.name})',
      name: 'ForegroundIdleWarmupCoordinator',
      category: LogCategory.system,
    );

    for (final task in _tasks) {
      if (!_canRun) {
        Log.info(
          'Foreground idle warmup stopped before ${task.id.name}: '
          'foreground=${_isForeground()}, idle=${_isIdle()}',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        return;
      }
      if (_isCoolingDown(task)) {
        Log.debug(
          'Foreground idle warmup skipped ${task.id.name}: cooling down',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        continue;
      }
      if (task.shouldRun?.call() == false) {
        Log.debug(
          'Foreground idle warmup skipped ${task.id.name}: not applicable',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        continue;
      }

      try {
        Log.debug(
          'Foreground idle warmup running ${task.id.name}',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        final (outcome, run) = await _runTask(task);
        switch (outcome) {
          case _ForegroundIdleWarmupTaskOutcome.completed:
            _lastSuccessAt[task.id] = _now();
            Log.debug(
              'Foreground idle warmup completed ${task.id.name}',
              name: 'ForegroundIdleWarmupCoordinator',
              category: LogCategory.system,
            );
            continue;
          case _ForegroundIdleWarmupTaskOutcome.gateClosed:
            Log.info(
              'Foreground idle warmup stopped during ${task.id.name}: '
              'foreground=${_isForeground()}, idle=${_isIdle()}',
              name: 'ForegroundIdleWarmupCoordinator',
              category: LogCategory.system,
            );
            _trackAbandonedRun(run);
            return;
          case _ForegroundIdleWarmupTaskOutcome.timedOut:
            Log.warning(
              'Foreground idle warmup timed out '
              '(${task.id.name}, ${trigger.name}, ${task.timeout.inSeconds}s)',
              name: 'ForegroundIdleWarmupCoordinator',
              category: LogCategory.system,
            );
            _trackAbandonedRun(run);
            return;
        }
      } catch (error) {
        Log.warning(
          'Foreground idle warmup failed '
          '(${task.id.name}, ${trigger.name}): $error',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
      }
    }
  }

  Future<(_ForegroundIdleWarmupTaskOutcome, Future<void>)> _runTask(
    ForegroundIdleWarmupTask task,
  ) async {
    final gateChanges = _gateChanges;
    StreamSubscription<void>? gateSubscription;
    final gateClosed = Completer<_ForegroundIdleWarmupTaskOutcome>();

    void completeIfGateClosed() {
      if (_canRun || gateClosed.isCompleted) return;
      gateClosed.complete(_ForegroundIdleWarmupTaskOutcome.gateClosed);
    }

    final run = task.run();

    if (gateChanges != null) {
      gateSubscription = gateChanges.listen((_) => completeIfGateClosed());
      completeIfGateClosed();
    }

    try {
      final outcome = await Future.any([
        run.then((_) => _ForegroundIdleWarmupTaskOutcome.completed),
        Future<_ForegroundIdleWarmupTaskOutcome>.delayed(
          task.timeout,
          () => _ForegroundIdleWarmupTaskOutcome.timedOut,
        ),
        if (gateChanges != null) gateClosed.future,
      ]);
      return (outcome, run);
    } finally {
      await gateSubscription?.cancel();
    }
  }

  /// Keeps a still-running task accounted for after its pass stopped waiting
  /// on it, so a later request waits instead of starting an overlapping pass.
  void _trackAbandonedRun(Future<void> run) {
    final abandoned = run.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _abandonedTaskRun = abandoned;
    unawaited(
      abandoned.whenComplete(() {
        if (identical(_abandonedTaskRun, abandoned)) {
          _abandonedTaskRun = null;
        }
      }),
    );
  }

  bool _isCoolingDown(ForegroundIdleWarmupTask task) {
    final lastSuccessAt = _lastSuccessAt[task.id];
    if (lastSuccessAt == null) return false;
    return _now().difference(lastSuccessAt) < task.cooldown;
  }
}

enum _ForegroundIdleWarmupTaskOutcome { completed, gateClosed, timedOut }
