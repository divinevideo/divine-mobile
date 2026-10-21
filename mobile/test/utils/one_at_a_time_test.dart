// ABOUTME: Tests for OneAtATime: tasks run one after another, in the order
// ABOUTME: given, and a failed task neither blocks nor fails the next.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/one_at_a_time.dart';

void main() {
  group(OneAtATime, () {
    group('run', () {
      test('starts a task only once the one before it settled', () async {
        final queue = OneAtATime();
        final first = Completer<int>();
        var secondStarted = false;

        final firstRun = queue.run(() => first.future);
        final secondRun = queue.run(() async {
          secondStarted = true;
          return 2;
        });
        await pumpEventQueue();
        expect(secondStarted, isFalse);

        first.complete(1);

        expect(await firstRun, equals(1));
        expect(await secondRun, equals(2));
        expect(secondStarted, isTrue);
      });

      test(
        'starts the next task after one that failed, which fails only its '
        'own caller',
        () async {
          final queue = OneAtATime();

          final failed = queue.run<int>(() async => throw StateError('broke'));
          final next = queue.run(() async => 2);

          await expectLater(failed, throwsStateError);
          expect(await next, equals(2));
        },
      );
    });
  });
}
