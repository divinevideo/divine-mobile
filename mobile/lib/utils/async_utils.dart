// ABOUTME: Lifecycle-owned async coordination primitives for timer-backed waits
// ABOUTME: AsyncScope owns every timer it creates and cancels them on dispose

import 'dart:async';
import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:unified_logger/unified_logger.dart';

/// Thrown when a wait is abandoned because its owning [AsyncScope] was
/// cancelled or disposed.
///
/// This is the signal that the *owner* went away, not that the work failed.
/// Callers should treat it as "stop, nobody is listening any more" and return
/// without touching owner state — see [AsyncScope] for why that matters.
class AsyncCancelledException implements Exception {
  /// Creates a cancellation signal, optionally naming the abandoned wait.
  const AsyncCancelledException([this.debugName]);

  /// The `debugName` of the wait that was abandoned, when one was supplied.
  final String? debugName;

  @override
  String toString() => debugName == null
      ? 'AsyncCancelledException'
      : 'AsyncCancelledException: $debugName';
}

/// A cancellation-aware owner for timer-backed waiting.
///
/// Every `Timer` this scope creates is tracked, and [cancelAll] / [dispose]
/// cancels all of them. That ownership is the whole point: a bare
/// `Timer(delay, completer.complete)` awaited by a caller keeps running after
/// its owner is gone, and the awaiting code then resumes into a disposed
/// object. `close()`/`dispose()` do not cancel in-flight work, so the wait has
/// to be cancellable from the outside (#8457, epic #4339).
///
/// This is also why the scope is an object rather than a set of static
/// helpers: an "explicit owner" is a field somebody disposes, not a call
/// convention somebody has to remember.
///
/// The owner **must** call [dispose] when its lifecycle ends. The scope cannot
/// infer that its owner went away, and an undisposed scope deliberately keeps
/// its active waits alive until they settle.
///
/// Give the owner a scope and dispose it alongside everything else it owns:
///
/// ```dart
/// class PendingActionService {
///   final _async = AsyncScope(debugName: 'PendingActionService');
///
///   Future<void> _sync(PendingAction action) => _async.retryWithBackoff(
///         operation: () => _executor(action),
///         debugName: 'Sync-${action.type}',
///       );
///
///   void dispose() {
///     _async.dispose(); // pending backoff aborts; no further operation() runs
///     super.dispose();
///   }
/// }
/// ```
///
/// A cancelled wait completes with [AsyncCancelledException] rather than
/// hanging, so an owner that forgets to handle it gets a loud async error
/// instead of a silently pinned closure.
class AsyncScope {
  /// Creates a scope, optionally named for logging.
  AsyncScope({String? debugName}) : _debugName = debugName;

  final String? _debugName;
  final Set<_Registration> _active = <_Registration>{};
  bool _disposed = false;

  /// Whether [dispose] has been called. A disposed scope starts no new waits.
  bool get isDisposed => _disposed;

  /// Number of waits currently outstanding. Test-only observability.
  @visibleForTesting
  int get pendingWaitCount => _active.length;

  /// Cancels every outstanding wait; the scope stays usable afterwards.
  ///
  /// Use this for owners whose lifecycle resets rather than ends — a static
  /// holder with a `reset()`, for example.
  void cancelAll() {
    if (_active.isEmpty) return;
    final registrations = List<_Registration>.of(_active);
    _active.clear();
    for (final registration in registrations) {
      registration.cancel();
    }
  }

  /// Cancels every outstanding wait and permanently closes the scope.
  ///
  /// Call from the owner's `dispose()` / `close()`. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelAll();
  }

  /// Waits for [condition] to become true, polling every [checkInterval].
  ///
  /// Returns `true` when the condition was met and `false` when [timeout]
  /// elapsed first. Throws [AsyncCancelledException] if the scope is cancelled
  /// or disposed while waiting, and rethrows anything [condition] throws.
  ///
  /// Both the timeout timer and the polling timer are owned by this scope, so
  /// cancelling stops the polling immediately instead of letting it run out
  /// the clock against a disposed owner.
  Future<bool> waitForCondition({
    required bool Function() condition,
    Duration timeout = const Duration(seconds: 10),
    Duration checkInterval = const Duration(milliseconds: 100),
    String? debugName,
  }) async {
    _throwIfDisposed(debugName);

    final completer = Completer<bool>();
    Timer? timeoutTimer;
    Timer? checkTimer;

    final registration = _register(() {
      timeoutTimer?.cancel();
      checkTimer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(AsyncCancelledException(debugName));
      }
    });

    void settle(void Function() complete) {
      timeoutTimer?.cancel();
      checkTimer?.cancel();
      _unregister(registration);
      complete();
    }

    void checkCondition() {
      if (completer.isCompleted) return;
      final bool met;
      try {
        met = condition();
      } catch (error, stackTrace) {
        if (debugName != null) {
          Log.error(
            'AsyncScope.waitForCondition error: $debugName - $error',
            name: 'AsyncScope',
            category: LogCategory.system,
          );
        }
        settle(() => completer.completeError(error, stackTrace));
        return;
      }
      if (!met) return;
      if (debugName != null) {
        Log.info(
          'AsyncScope.waitForCondition success: $debugName',
          name: 'AsyncScope',
          category: LogCategory.system,
        );
      }
      settle(() => completer.complete(true));
    }

    timeoutTimer = Timer(timeout, () {
      if (completer.isCompleted) return;
      if (debugName != null) {
        Log.debug(
          '⏰ AsyncScope.waitForCondition timeout: $debugName',
          name: 'AsyncScope',
          category: LogCategory.system,
        );
      }
      settle(() => completer.complete(false));
    });

    // Check once before arming the poll, so an already-true condition avoids
    // the periodic timer and immediately cancels the timeout timer above.
    checkCondition();
    if (!completer.isCompleted) {
      checkTimer = Timer.periodic(checkInterval, (_) => checkCondition());
    }

    return completer.future;
  }

  /// Runs [operation], retrying with exponential backoff on failure.
  ///
  /// Retries up to [maxRetries] times (so up to `maxRetries + 1` invocations),
  /// waiting `baseDelay * backoffMultiplier^(attempt - 1)` between attempts,
  /// clamped to [maxDelay]. [retryWhen] can veto a retry for a given error;
  /// vetoed and exhausted errors are rethrown unchanged.
  ///
  /// Cancellation contract: cancelling the scope aborts the pending backoff
  /// immediately and guarantees [operation] is **never invoked again**. It does
  /// **not** abort an invocation already in flight — an arbitrary `Future` is
  /// not cancellable — so that call is allowed to finish and its result is
  /// discarded, with [AsyncCancelledException] delivered to the caller instead.
  /// Discarding a late success is deliberate: running the caller's success path
  /// against a disposed owner is the failure this exists to prevent, and the
  /// work is safe to repeat next session.
  Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(minutes: 5),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? retryWhen,
    String? debugName,
    void Function(Duration delay)? onDelayStart,
  }) async {
    _throwIfDisposed(debugName);

    var cancelled = false;
    final registration = _register(() => cancelled = true);

    try {
      var attempts = 0;

      while (attempts <= maxRetries) {
        try {
          final result = await operation();
          if (cancelled) throw AsyncCancelledException(debugName);
          if (debugName != null && attempts > 0) {
            Log.warning(
              'AsyncScope.retryWithBackoff succeeded after $attempts '
              'retries: $debugName',
              name: 'AsyncScope',
              category: LogCategory.system,
            );
          }
          return result;
        } on AsyncCancelledException {
          rethrow;
        } catch (error) {
          // The owner went away while this attempt was in flight. Stop here
          // rather than burning the rest of the ladder against a dead owner.
          if (cancelled) throw AsyncCancelledException(debugName);

          attempts++;

          if (retryWhen != null && !retryWhen(error)) {
            if (debugName != null) {
              Log.error(
                'AsyncScope.retryWithBackoff not retrying error: '
                '$debugName - $error',
                name: 'AsyncScope',
                category: LogCategory.system,
              );
            }
            rethrow;
          }

          if (attempts > maxRetries) {
            if (debugName != null) {
              Log.error(
                'AsyncScope.retryWithBackoff max retries exceeded: '
                '$debugName - $error',
                name: 'AsyncScope',
                category: LogCategory.system,
              );
            }
            rethrow;
          }

          final delay = _backoffDelay(
            attempts: attempts,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
            backoffMultiplier: backoffMultiplier,
          );

          if (debugName != null) {
            Log.error(
              'AsyncScope.retryWithBackoff attempt $attempts failed, retrying '
              'in ${delay.inMilliseconds}ms: $debugName',
              name: 'AsyncScope',
              category: LogCategory.system,
            );
          }

          onDelayStart?.call(delay);

          // Owned, cancellable sleep. Throws AsyncCancelledException if the
          // scope is cancelled before it elapses.
          await _sleep(delay, debugName);
        }
      }

      throw StateError('retryWithBackoff loop exited without a result');
    } finally {
      _unregister(registration);
    }
  }

  /// Waits [duration], as a timer this scope owns.
  ///
  /// The owned replacement for `Future.delayed` in a backoff loop: completes
  /// normally once [duration] elapses, and throws [AsyncCancelledException]
  /// if the scope is cancelled or disposed first, or immediately if it is
  /// already disposed, so the awaiting loop stops instead of resuming into a
  /// torn-down owner.
  Future<void> delay(Duration duration, {String? debugName}) async {
    _throwIfDisposed(debugName);
    await _sleep(duration, debugName);
  }

  /// A cancellable sleep owned by this scope.
  Future<void> _sleep(Duration duration, String? debugName) {
    final completer = Completer<void>();
    Timer? timer;

    final registration = _register(() {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.completeError(AsyncCancelledException(debugName));
      }
    });

    timer = Timer(duration, () {
      _unregister(registration);
      if (!completer.isCompleted) completer.complete();
    });

    return completer.future;
  }

  static Duration _backoffDelay({
    required int attempts,
    required Duration baseDelay,
    required Duration maxDelay,
    required double backoffMultiplier,
  }) {
    final delayMs = math
        .min(
          baseDelay.inMilliseconds * math.pow(backoffMultiplier, attempts - 1),
          maxDelay.inMilliseconds.toDouble(),
        )
        .round();
    return Duration(milliseconds: delayMs);
  }

  _Registration _register(void Function() cancel) {
    final registration = _Registration(cancel);
    _active.add(registration);
    return registration;
  }

  void _unregister(_Registration registration) => _active.remove(registration);

  void _throwIfDisposed(String? debugName) {
    if (_disposed) {
      throw AsyncCancelledException(debugName ?? _debugName);
    }
  }
}

/// One outstanding wait's cancellation hook, kept identity-unique so a scope
/// can hold several and remove exactly the one that finished.
class _Registration {
  _Registration(this.cancel);

  final void Function() cancel;
}
