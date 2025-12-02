// ABOUTME: Centralized utilities for proper asynchronous programming patterns
// ABOUTME: Provides alternatives to Future.delayed and other timing hacks

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Utilities for proper asynchronous programming patterns
class AsyncUtils {
  AsyncUtils._(); // Private constructor to prevent instantiation

  /// Wait for a condition to become true with timeout
  ///
  /// Replaces polling loops with Future.delayed()
  ///
  /// Example:
  /// ```dart
  /// // ❌ OLD PATTERN
  /// while (!isReady && attempts < 50) {
  ///   await Future.delayed(Duration(milliseconds: 100));
  ///   attempts++;
  /// }
  ///
  /// // ✅ NEW PATTERN
  /// await AsyncUtils.waitForCondition(
  ///   condition: () => isReady,
  ///   timeout: Duration(seconds: 5),
  ///   checkInterval: Duration(milliseconds: 100),
  /// );
  /// ```
  static Future<bool> waitForCondition({
    required bool Function() condition,
    Duration timeout = const Duration(seconds: 10),
    Duration checkInterval = const Duration(milliseconds: 100),
    String? debugName,
  }) async {
    final completer = Completer<bool>();
    Timer? timeoutTimer;
    Timer? checkTimer;

    void cleanup() {
      timeoutTimer?.cancel();
      checkTimer?.cancel();
    }

    // Set up timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        cleanup();
        if (debugName != null) {
          Log.debug(
            '⏰ AsyncUtils.waitForCondition timeout: $debugName',
            name: 'AsyncUtils',
            category: LogCategory.system,
          );
        }
        completer.complete(false);
      }
    });

    // Set up condition checking
    void checkCondition() {
      try {
        if (condition()) {
          if (!completer.isCompleted) {
            cleanup();
            if (debugName != null) {
              Log.info(
                'AsyncUtils.waitForCondition success: $debugName',
                name: 'AsyncUtils',
                category: LogCategory.system,
              );
            }
            completer.complete(true);
          }
        }
      } catch (e) {
        if (!completer.isCompleted) {
          cleanup();
          if (debugName != null) {
            Log.error(
              'AsyncUtils.waitForCondition error: $debugName - $e',
              name: 'AsyncUtils',
              category: LogCategory.system,
            );
          }
          completer.completeError(e);
        }
      }
    }

    // Check immediately
    checkCondition();

    // If not completed, start periodic checking
    if (!completer.isCompleted) {
      checkTimer = Timer.periodic(checkInterval, (_) => checkCondition());
    }

    return completer.future;
  }

  /// Create a completer that can be completed by external events
  ///
  /// Replaces arbitrary delays for operation completion
  ///
  /// Example:
  /// ```dart
  /// // ❌ OLD PATTERN
  /// await Future.delayed(Duration(milliseconds: 500));
  ///
  /// // ✅ NEW PATTERN
  /// final operationCompleter = AsyncUtils.createCompletionHandler<String>();
  /// someService.onComplete = operationCompleter.complete;
  /// final result = await operationCompleter.future.timeout(Duration(seconds: 5));
  /// ```
  static Completer<T> createCompletionHandler<T>() => Completer<T>();

  /// Enhanced retry mechanism with exponential backoff
  ///
  /// Replaces fixed delays in retry logic
  ///
  /// Example:
  /// ```dart
  /// // ❌ OLD PATTERN
  /// await Future.delayed(config.retryDelay);
  ///
  /// // ✅ NEW PATTERN
  /// await AsyncUtils.retryWithBackoff(
  ///   operation: () => performOperation(),
  ///   maxRetries: 3,
  ///   baseDelay: Duration(seconds: 1),
  /// );
  /// ```
  static Future<T> retryWithBackoff<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration baseDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(minutes: 5),
    double backoffMultiplier = 2.0,
    bool Function(dynamic error)? retryWhen,
    String? debugName,
    void Function(Duration delay)? onDelayStart,
  }) async {
    var attempts = 0;

    while (attempts <= maxRetries) {
      try {
        final result = await operation();
        if (debugName != null && attempts > 0) {
          Log.warning(
            'AsyncUtils.retryWithBackoff succeeded after $attempts retries: $debugName',
            name: 'AsyncUtils',
            category: LogCategory.system,
          );
        }
        return result;
      } catch (error) {
        attempts++;

        // Check if we should retry this error
        if (retryWhen != null && !retryWhen(error)) {
          if (debugName != null) {
            Log.error(
              'AsyncUtils.retryWithBackoff not retrying error: $debugName - $error',
              name: 'AsyncUtils',
              category: LogCategory.system,
            );
          }
          rethrow;
        }

        // If we've exceeded max retries, throw the error
        if (attempts > maxRetries) {
          if (debugName != null) {
            Log.error(
              'AsyncUtils.retryWithBackoff max retries exceeded: $debugName - $error',
              name: 'AsyncUtils',
              category: LogCategory.system,
            );
          }
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delayMs = math
            .min(
              baseDelay.inMilliseconds *
                  math.pow(backoffMultiplier, attempts - 1),
              maxDelay.inMilliseconds.toDouble(),
            )
            .round();
        final delay = Duration(milliseconds: delayMs);

        if (debugName != null) {
          Log.error(
            'AsyncUtils.retryWithBackoff attempt $attempts failed, retrying in ${delay.inMilliseconds}ms: $debugName',
            name: 'AsyncUtils',
            category: LogCategory.system,
          );
        }

        // Use Timer-based delay instead of Future.delayed
        final completer = Completer<void>();
        Timer(delay, completer.complete);

        // Notify test/debug code about delay start
        onDelayStart?.call(delay);

        await completer.future;
      }
    }

    throw StateError('Should never reach here');
  }

  /// Create a future that completes when a stream emits a specific value
  ///
  /// Useful for waiting on state changes
  ///
  /// Example:
  /// ```dart
  /// await AsyncUtils.waitForStreamValue(
  ///   stream: controller.stream,
  ///   predicate: (value) => value.isInitialized,
  ///   timeout: Duration(seconds: 5),
  /// );
  /// ```
  static Future<T> waitForStreamValue<T>({
    required Stream<T> stream,
    required bool Function(T value) predicate,
    Duration timeout = const Duration(seconds: 10),
    String? debugName,
  }) async {
    final completer = Completer<T>();
    StreamSubscription<T>? subscription;
    Timer? timeoutTimer;

    void cleanup() {
      subscription?.cancel();
      timeoutTimer?.cancel();
    }

    // Set up timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        cleanup();
        if (debugName != null) {
          Log.debug(
            '⏰ AsyncUtils.waitForStreamValue timeout: $debugName',
            name: 'AsyncUtils',
            category: LogCategory.system,
          );
        }
        completer.completeError(
          TimeoutException('Stream value timeout', timeout),
        );
      }
    });

    // Listen to stream
    subscription = stream.listen(
      (value) {
        try {
          if (predicate(value) && !completer.isCompleted) {
            cleanup();
            if (debugName != null) {
              Log.info(
                'AsyncUtils.waitForStreamValue success: $debugName',
                name: 'AsyncUtils',
                category: LogCategory.system,
              );
            }
            completer.complete(value);
          }
        } catch (e) {
          if (!completer.isCompleted) {
            cleanup();
            if (debugName != null) {
              Log.error(
                'AsyncUtils.waitForStreamValue predicate error: $debugName - $e',
                name: 'AsyncUtils',
                category: LogCategory.system,
              );
            }
            completer.completeError(e);
          }
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          cleanup();
          if (debugName != null) {
            Log.error(
              'AsyncUtils.waitForStreamValue stream error: $debugName - $error',
              name: 'AsyncUtils',
              category: LogCategory.system,
            );
          }
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Debounce multiple rapid calls to the same operation
  ///
  /// Useful for preventing excessive API calls or operations
  ///
  /// Example:
  /// ```dart
  /// final debouncedSave = AsyncUtils.debounce(
  ///   operation: () => saveData(),
  ///   delay: Duration(milliseconds: 500),
  /// );
  ///
  /// // Multiple rapid calls will be debounced
  /// debouncedSave();
  /// debouncedSave();
  /// debouncedSave(); // Only this one will execute after 500ms
  /// ```
  static VoidCallback debounce({
    required VoidCallback operation,
    Duration delay = const Duration(milliseconds: 300),
  }) {
    Timer? timer;

    return () {
      timer?.cancel();
      timer = Timer(delay, operation);
    };
  }

  /// Throttle calls to ensure operation doesn't execute more than once per interval
  ///
  /// Useful for rate limiting
  ///
  /// Example:
  /// ```dart
  /// final throttledUpdate = AsyncUtils.throttle(
  ///   operation: () => updateUI(),
  ///   interval: Duration(milliseconds: 100),
  /// );
  /// ```
  static VoidCallback throttle({
    required VoidCallback operation,
    Duration interval = const Duration(milliseconds: 100),
  }) {
    DateTime? lastCall;

    return () {
      final now = DateTime.now();
      if (lastCall == null || now.difference(lastCall!) >= interval) {
        lastCall = now;
        operation();
      }
    };
  }

  /// Execute a list of operations with rate limiting between each
  ///
  /// Replaces patterns like:
  /// ```dart
  /// for (final item in items) {
  ///   await processItem(item);
  ///   await Future.delayed(Duration(milliseconds: 100));
  /// }
  /// ```
  ///
  /// With:
  /// ```dart
  /// await AsyncUtils.executeWithRateLimit(
  ///   operations: items.map((item) => () => processItem(item)).toList(),
  ///   minInterval: Duration(milliseconds: 100),
  /// );
  /// ```
  static Future<List<T?>> executeWithRateLimit<T>({
    required List<Future<T> Function()> operations,
    required Duration minInterval,
    bool continueOnError = false,
    String? debugName,
  }) async {
    if (operations.isEmpty) return [];

    final results = <T?>[];
    DateTime? lastExecutionTime;

    for (var i = 0; i < operations.length; i++) {
      // Calculate delay needed
      if (lastExecutionTime != null) {
        final elapsed = DateTime.now().difference(lastExecutionTime);
        final remaining = minInterval - elapsed;

        if (remaining.isNegative == false && remaining.inMicroseconds > 0) {
          // Use Timer-based delay instead of Future.delayed
          final completer = Completer<void>();
          Timer(remaining, completer.complete);
          await completer.future;
        }
      }

      // Execute operation
      try {
        lastExecutionTime = DateTime.now();
        final result = await operations[i]();
        results.add(result);

        if (debugName != null) {
          Log.debug(
            'AsyncUtils.executeWithRateLimit: Operation ${i + 1}/${operations.length} completed',
            name: 'AsyncUtils',
            category: LogCategory.system,
          );
        }
      } catch (e) {
        if (continueOnError) {
          results.add(null);
          if (debugName != null) {
            Log.error(
              'AsyncUtils.executeWithRateLimit: Operation ${i + 1}/${operations.length} failed: $e',
              name: 'AsyncUtils',
              category: LogCategory.system,
            );
          }
        } else {
          rethrow;
        }
      }
    }

    return results;
  }
}

/// Exception thrown when an async operation times out
class AsyncTimeoutException extends TimeoutException {
  AsyncTimeoutException(String super.message, Duration super.timeout);
}

/// Mixin for classes that need proper async initialization patterns
mixin AsyncInitialization {
  Completer<void>? _initializationCompleter;
  bool _isInitialized = false;

  /// Whether the object is initialized
  bool get isInitialized => _isInitialized;

  /// Future that completes when initialization is done
  Future<void> get initialized =>
      _initializationCompleter?.future ?? Future.value();

  /// Start the initialization process
  @protected
  void startInitialization() {
    if (_initializationCompleter != null) return; // Already started
    _initializationCompleter = Completer<void>();
  }

  /// Mark initialization as complete
  @protected
  void completeInitialization() {
    if (_isInitialized) return; // Already completed
    _isInitialized = true;
    _initializationCompleter?.complete();
  }

  /// Mark initialization as failed
  @protected
  void failInitialization(Object error, [StackTrace? stackTrace]) {
    _initializationCompleter?.completeError(error, stackTrace);
  }

  /// Wait for initialization with timeout
  Future<void> waitForInitialization({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_isInitialized) return;

    if (_initializationCompleter == null) {
      throw StateError('Initialization not started');
    }

    await _initializationCompleter!.future.timeout(timeout);
  }
}
