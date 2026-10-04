// ABOUTME: Tests condition-probe completion, pacing, deadlines, and failures.
// ABOUTME: Uses virtual time and held futures to verify polling timer ownership.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'observe_until.dart';

void main() {
  group('observeUntil', () {
    test('returns immediately on a ready probe and cancels the deadline', () {
      fakeAsync((async) {
        bool? result;
        unawaited(
          observeUntil(
            probe: () => true,
            ready: (value) => value,
            initialValue: false,
            interval: const Duration(seconds: 1),
            timeout: const Duration(seconds: 5),
          ).then((value) => result = value),
        );
        async.flushMicrotasks();
        expect(result, isTrue);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('paces probes, never overlaps a held probe, and stops when ready', () {
      fakeAsync((async) {
        final held = Completer<int>();
        var calls = 0;
        int? result;
        unawaited(
          observeUntil<int>(
            probe: () => ++calls == 1 ? held.future : 2,
            ready: (value) => value == 2,
            initialValue: 0,
            interval: const Duration(seconds: 1),
            timeout: const Duration(seconds: 5),
          ).then((value) => result = value),
        );
        async.elapse(const Duration(seconds: 2));
        expect(calls, 1);
        expect(result, isNull);
        held.complete(1);
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 999));
        expect(calls, 1);
        async.elapse(const Duration(milliseconds: 1));
        expect(calls, 2);
        expect(result, 2);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('deadline returns the latest value and ignores a late probe', () {
      fakeAsync((async) {
        final held = Completer<int>();
        var calls = 0;
        int? result;
        unawaited(
          observeUntil<int>(
            probe: () => ++calls == 1 ? 1 : held.future,
            ready: (value) => value == 2,
            initialValue: 0,
            interval: const Duration(seconds: 1),
            timeout: const Duration(seconds: 5),
          ).then((value) => result = value),
        );
        async.elapse(const Duration(seconds: 5));
        expect(result, 1);
        expect(calls, 2);
        expect(async.nonPeriodicTimerCount, 0);
        held.complete(2);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        expect(result, 1);
        expect(calls, 2);
        expect(async.nonPeriodicTimerCount, 0);
      });
    });

    test('propagates probe failures and cancels both timers', () {
      fakeAsync((async) {
        Object? failure;
        unawaited(
          observeUntil<bool>(
            probe: () => throw StateError('probe failed'),
            ready: (value) => value,
            initialValue: false,
            interval: const Duration(seconds: 1),
            timeout: const Duration(seconds: 5),
          ).then((_) {}, onError: (Object error) => failure = error),
        );
        async.flushMicrotasks();
        expect(failure, isA<StateError>());
        expect(async.nonPeriodicTimerCount, 0);
      });
    });
  });
}
