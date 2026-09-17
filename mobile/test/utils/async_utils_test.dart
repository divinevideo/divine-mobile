// ABOUTME: Tests for AsyncScope cancellation of timer-backed waits
// ABOUTME: Proves no callback or retry fires after the owning scope is disposed

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/async_utils.dart';

void main() {
  group(AsyncScope, () {
    group('retryWithBackoff', () {
      test('does not invoke operation again after dispose during backoff', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          var operationCalls = 0;
          Object? thrown;

          unawaited(
            scope
                .retryWithBackoff<void>(
                  operation: () async {
                    operationCalls++;
                    throw Exception('network down');
                  },
                  maxRetries: 5,
                  baseDelay: const Duration(seconds: 2),
                  // Production PendingActionService ladder: 2+4+8+16+32s.
                )
                .catchError((Object e) => thrown = e),
          );

          async.flushMicrotasks();
          expect(operationCalls, 1, reason: 'first attempt ran');

          scope.dispose();
          async.elapse(const Duration(minutes: 2));

          expect(
            operationCalls,
            1,
            reason: 'no further invocation may happen after dispose',
          );
          expect(thrown, isA<AsyncCancelledException>());
          expect(
            async.pendingTimers,
            isEmpty,
            reason: 'the backoff timer must be owned and cancelled',
          );
        });
      });

      test('cancelAll aborts the backoff and leaves the scope usable', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          var operationCalls = 0;
          Object? thrown;

          unawaited(
            scope
                .retryWithBackoff<void>(
                  operation: () async {
                    operationCalls++;
                    throw Exception('boom');
                  },
                )
                .catchError((Object e) => thrown = e),
          );
          async.flushMicrotasks();
          scope.cancelAll();
          async.elapse(const Duration(seconds: 30));

          expect(operationCalls, 1);
          expect(thrown, isA<AsyncCancelledException>());
          expect(scope.isDisposed, isFalse);

          // Still usable: a fresh wait runs to completion.
          var second = 0;
          unawaited(
            scope.retryWithBackoff<void>(
              operation: () async => second++,
            ),
          );
          async.elapse(const Duration(seconds: 1));
          expect(second, 1);
        });
      });

      test('an in-flight operation finishes but its result is discarded', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          final gate = Completer<String>();
          var completedNormally = false;
          Object? thrown;

          unawaited(
            () async {
              try {
                await scope.retryWithBackoff<String>(
                  operation: () => gate.future,
                );
                completedNormally = true;
              } catch (e) {
                thrown = e;
              }
            }(),
          );
          async.flushMicrotasks();

          scope.dispose();
          gate.complete('published'); // in-flight call lands after dispose
          async.flushMicrotasks();

          expect(
            completedNormally,
            isFalse,
            reason: 'the success path must not run against a disposed owner',
          );
          expect(thrown, isA<AsyncCancelledException>());
        });
      });

      test('throws immediately when the scope is already disposed', () async {
        final scope = AsyncScope()..dispose();
        var calls = 0;

        await expectLater(
          scope.retryWithBackoff<void>(operation: () async => calls++),
          throwsA(isA<AsyncCancelledException>()),
        );
        expect(calls, 0);
      });

      test('retries then succeeds when not cancelled', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          var calls = 0;
          String? result;

          unawaited(
            scope
                .retryWithBackoff<String>(
                  operation: () async {
                    calls++;
                    if (calls < 3) throw Exception('transient');
                    return 'ok';
                  },
                )
                .then((value) => result = value),
          );

          async.elapse(const Duration(seconds: 10));
          expect(calls, 3);
          expect(result, 'ok');
          expect(async.pendingTimers, isEmpty);
          scope.dispose();
        });
      });

      test('rethrows the original error once retries are exhausted', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          Object? thrown;

          unawaited(
            scope
                .retryWithBackoff<void>(
                  operation: () async => throw StateError('permanent'),
                  maxRetries: 2,
                )
                .catchError((Object e) => thrown = e),
          );

          async.elapse(const Duration(seconds: 30));
          expect(thrown, isA<StateError>());
          scope.dispose();
        });
      });

      test('honours a retryWhen veto without waiting', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          var calls = 0;
          Object? thrown;

          unawaited(
            scope
                .retryWithBackoff<void>(
                  operation: () async {
                    calls++;
                    throw ArgumentError('fatal');
                  },
                  retryWhen: (error) => error is! ArgumentError,
                )
                .catchError((Object e) => thrown = e),
          );

          async.flushMicrotasks();
          expect(calls, 1, reason: 'a vetoed error must not be retried');
          expect(thrown, isA<ArgumentError>());
          expect(async.pendingTimers, isEmpty);
          scope.dispose();
        });
      });

      test('clamps the backoff delay to maxDelay', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          final delays = <Duration>[];

          unawaited(
            scope
                .retryWithBackoff<void>(
                  operation: () async => throw Exception('down'),
                  maxRetries: 4,
                  baseDelay: const Duration(seconds: 2),
                  maxDelay: const Duration(seconds: 3),
                  onDelayStart: delays.add,
                )
                .catchError((_) {}),
          );

          async.elapse(const Duration(minutes: 1));
          expect(
            delays,
            const [
              Duration(seconds: 2),
              Duration(seconds: 3), // 4s clamped
              Duration(seconds: 3), // 8s clamped
              Duration(seconds: 3), // 16s clamped
            ],
          );
          scope.dispose();
        });
      });
    });

    group('waitForCondition', () {
      test('stops polling the condition after dispose', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          var conditionCalls = 0;
          Object? thrown;

          unawaited(
            scope
                .waitForCondition(
                  condition: () {
                    conditionCalls++;
                    return false;
                  },
                  timeout: const Duration(seconds: 30),
                )
                .catchError((Object e) {
                  thrown = e;
                  return false;
                }),
          );

          async.elapse(const Duration(milliseconds: 300));
          final callsAtDispose = conditionCalls;
          expect(callsAtDispose, greaterThan(0), reason: 'polling started');

          scope.dispose();
          async.elapse(const Duration(seconds: 30));

          expect(
            conditionCalls,
            callsAtDispose,
            reason: 'no poll may run after dispose',
          );
          expect(thrown, isA<AsyncCancelledException>());
          expect(
            async.pendingTimers,
            isEmpty,
            reason: 'timeout and poll timers must both be cancelled',
          );
        });
      });

      test('returns true without arming a timer when already satisfied', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          bool? result;

          unawaited(
            scope
                .waitForCondition(condition: () => true)
                .then((value) => result = value),
          );

          async.flushMicrotasks();
          expect(result, isTrue);
          expect(async.pendingTimers, isEmpty);
          scope.dispose();
        });
      });

      test('returns false when the timeout elapses first', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          bool? result;

          unawaited(
            scope
                .waitForCondition(
                  condition: () => false,
                  timeout: const Duration(seconds: 5),
                )
                .then((value) => result = value),
          );

          async.elapse(const Duration(seconds: 6));
          expect(result, isFalse);
          expect(async.pendingTimers, isEmpty);
          scope.dispose();
        });
      });

      test('propagates an error thrown by the condition', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          Object? thrown;

          unawaited(
            scope
                .waitForCondition(
                  condition: () => throw StateError('bad condition'),
                )
                .catchError((Object e) {
                  thrown = e;
                  return false;
                }),
          );

          async.flushMicrotasks();
          expect(thrown, isA<StateError>());
          expect(async.pendingTimers, isEmpty);
          scope.dispose();
        });
      });

      test('throws immediately when the scope is already disposed', () async {
        final scope = AsyncScope()..dispose();
        var calls = 0;

        await expectLater(
          scope.waitForCondition(
            condition: () {
              calls++;
              return true;
            },
          ),
          throwsA(isA<AsyncCancelledException>()),
        );
        expect(calls, 0);
      });
    });

    group('delay', () {
      test('completes once the duration elapses', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          var completed = false;

          unawaited(
            scope
                .delay(const Duration(seconds: 2))
                .then((_) => completed = true),
          );
          async.elapse(const Duration(seconds: 1));
          expect(completed, isFalse);

          async.elapse(const Duration(seconds: 1));
          expect(completed, isTrue);
          expect(scope.pendingWaitCount, 0);
          scope.dispose();
        });
      });

      test('dispose aborts a pending delay with AsyncCancelledException', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          Object? thrown;

          unawaited(
            scope
                .delay(const Duration(seconds: 2), debugName: 'backoff')
                .catchError((Object e) => thrown = e),
          );
          async.flushMicrotasks();

          scope.dispose();
          async.elapse(const Duration(seconds: 5));

          expect(
            thrown,
            isA<AsyncCancelledException>().having(
              (e) => e.debugName,
              'debugName',
              'backoff',
            ),
          );
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('throws immediately when the scope is already disposed', () async {
        final scope = AsyncScope()..dispose();

        await expectLater(
          scope.delay(const Duration(seconds: 1)),
          throwsA(isA<AsyncCancelledException>()),
        );
      });
    });

    group('lifecycle', () {
      test('dispose is idempotent and clears outstanding waits', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          unawaited(
            scope
                .waitForCondition(
                  condition: () => false,
                )
                .catchError((_) => false),
          );
          async.flushMicrotasks();
          expect(scope.pendingWaitCount, 1);

          scope
            ..dispose()
            ..dispose();

          expect(scope.isDisposed, isTrue);
          expect(scope.pendingWaitCount, 0);
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('unregisters a wait that completed normally', () {
        fakeAsync((async) {
          final scope = AsyncScope();
          unawaited(scope.waitForCondition(condition: () => true));
          async.flushMicrotasks();

          expect(
            scope.pendingWaitCount,
            0,
            reason: 'a settled wait must not leak a registration',
          );
          scope.dispose();
        });
      });
    });
  });

  group(AsyncCancelledException, () {
    test('names the abandoned wait when given a debugName', () {
      expect(
        const AsyncCancelledException('Sync-like').toString(),
        contains('Sync-like'),
      );
      expect(
        const AsyncCancelledException().toString(),
        'AsyncCancelledException',
      );
    });
  });
}
