// ABOUTME: Tests for batchedListen / BatchedSubscription — events are handed
// ABOUTME: over in windows and never dropped, and a pending window is flushed
// ABOUTME: on demand, on done, and discarded on cancel without leaking a timer.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/comments/comments_list/batched_subscription.dart';

const _window = Duration(milliseconds: 100);

void main() {
  group('batchedListen', () {
    test('hands a burst over in one batch and loses none of it', () {
      fakeAsync((fake) {
        final batches = <List<int>>[];
        final source = StreamController<int>.broadcast();
        addTearDown(source.close);

        final sub = batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
        );
        addTearDown(sub.cancel);

        for (var i = 1; i <= 25; i++) {
          source.add(i);
        }
        fake.flushMicrotasks();
        expect(batches, isEmpty, reason: 'held until the window closes');

        fake.elapse(_window);

        expect(batches, [
          [for (var i = 1; i <= 25; i++) i],
        ]);
      });
    });

    test('opens a new window for what arrives after a batch', () {
      fakeAsync((fake) {
        final batches = <List<int>>[];
        final source = StreamController<int>.broadcast();
        addTearDown(source.close);

        final sub = batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
        );
        addTearDown(sub.cancel);

        source
          ..add(1)
          ..add(2);
        fake.elapse(_window);
        source.add(3);
        fake.elapse(_window);

        expect(batches, [
          [1, 2],
          [3],
        ]);
      });
    });

    test('hands over nothing for a window that saw no event', () {
      fakeAsync((fake) {
        final batches = <List<int>>[];
        final source = StreamController<int>.broadcast();
        addTearDown(source.close);

        final sub = batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
        );
        addTearDown(sub.cancel);

        fake.elapse(const Duration(seconds: 5));

        expect(batches, isEmpty);
        expect(fake.nonPeriodicTimerCount, 0);
      });
    });

    test('flush() hands over what is held now and stops the timer', () {
      fakeAsync((fake) {
        final batches = <List<int>>[];
        final source = StreamController<int>.broadcast();
        addTearDown(source.close);

        final sub = batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
        );
        addTearDown(sub.cancel);

        source
          ..add(1)
          ..add(2);
        fake.flushMicrotasks();
        expect(fake.nonPeriodicTimerCount, 1);

        sub.flush();

        expect(batches, [
          [1, 2],
        ]);
        expect(fake.nonPeriodicTimerCount, 0);
        fake.elapse(_window);
        expect(batches, hasLength(1), reason: 'not handed over twice');
      });
    });

    test('cancel() drops what is held and leaves no timer behind', () {
      fakeAsync((fake) {
        final batches = <List<int>>[];
        final source = StreamController<int>.broadcast();
        addTearDown(source.close);

        final sub = batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
        );

        source.add(1);
        fake.flushMicrotasks();
        expect(fake.nonPeriodicTimerCount, 1);

        final cancellation = sub.cancel();
        addTearDown(() => cancellation);
        fake.flushMicrotasks();
        fake.elapse(_window);
        sub.flush();

        expect(batches, isEmpty, reason: 'what was held is discarded');
        expect(fake.nonPeriodicTimerCount, 0);
      });
    });

    test('an error from the stream reaches onError at once', () {
      fakeAsync((fake) {
        final errors = <Object>[];
        final batches = <List<int>>[];
        final source = StreamController<int>.broadcast();
        addTearDown(source.close);

        final sub = batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
          onError: errors.add,
        );
        addTearDown(sub.cancel);

        source
          ..add(1)
          ..addError(Exception('relay went away'));
        fake.flushMicrotasks();

        expect(errors, hasLength(1));
        expect(batches, isEmpty, reason: 'the held event is still held');
        fake.elapse(_window);
        expect(batches, [
          [1],
        ]);
      });
    });

    test('hands over what is held when the stream ends', () {
      fakeAsync((fake) {
        final batches = <List<int>>[];
        final source = StreamController<int>();

        batchedListen<int>(
          source.stream,
          window: _window,
          onBatch: batches.add,
        );

        source.add(1);
        unawaited(source.close());
        fake.flushMicrotasks();

        expect(batches, [
          [1],
        ]);
        expect(fake.nonPeriodicTimerCount, 0);
      });
    });
  });
}
