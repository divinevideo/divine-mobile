// ABOUTME: Tests TestHelpers.waitForCondition's deadline semantics.
// ABOUTME: Pins the final condition check the polling loop it replaced made.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  group('TestHelpers.waitForCondition', () {
    test('passes when the condition turns true after the last poll', () {
      fakeAsync((async) {
        var ready = false;
        Timer(const Duration(milliseconds: 90), () => ready = true);

        var completed = false;
        Object? failure;
        unawaited(
          TestHelpers.waitForCondition(
            () => ready,
            timeout: const Duration(milliseconds: 100),
            checkInterval: const Duration(milliseconds: 40),
          ).then<void>(
            (_) {
              completed = true;
            },
            onError: (Object error) {
              failure = error;
            },
          ),
        );

        async.elapse(const Duration(milliseconds: 100));

        expect(failure, isNull);
        expect(completed, isTrue);
      });
    });

    test('throws naming the condition when it never holds', () {
      fakeAsync((async) {
        Object? failure;
        unawaited(
          TestHelpers.waitForCondition(
            () => false,
            timeout: const Duration(milliseconds: 100),
            checkInterval: const Duration(milliseconds: 40),
            description: 'a never-true condition',
          ).then<void>(
            (_) {},
            onError: (Object error) {
              failure = error;
            },
          ),
        );

        async.elapse(const Duration(milliseconds: 100));

        expect(
          failure,
          isA<TimeoutException>().having(
            (error) => error.message,
            'message',
            contains('a never-true condition'),
          ),
        );
      });
    });
  });
}
