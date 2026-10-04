// ABOUTME: Tests timeout and cancellation ownership in subscription fixtures.
// ABOUTME: Verifies both mock implementations release timers on completion and disposal.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subscription_manager.dart';

import '../mocks/mock_subscription_manager.dart' as streaming;
import 'test_subscription_manager.dart' as helper;

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('subscription mock timeout ownership', () {
    for (final entry in <String, SubscriptionManager Function()>{
      'helper': helper.MockSubscriptionManager.new,
      'streaming': () => streaming.MockSubscriptionManager(_MockNostrClient()),
    }.entries) {
      test('${entry.key} completes on timeout and releases its timer', () {
        fakeAsync((async) {
          final manager = entry.value();
          var completed = 0;
          unawaited(
            manager.createSubscription(
              name: 'timeout',
              filters: [
                Filter(kinds: [1]),
              ],
              onEvent: (_) {},
              onComplete: () => completed++,
              timeout: const Duration(seconds: 1),
            ),
          );
          async.flushMicrotasks();
          async.elapse(const Duration(milliseconds: 999));
          expect(completed, 0);
          async.elapse(const Duration(milliseconds: 1));
          expect(completed, 1);
          expect(async.nonPeriodicTimerCount, 0);
          unawaited(manager.dispose());
          async.flushMicrotasks();
        });
      });

      test(
        '${entry.key} cancels the timer when the subscription is cancelled',
        () {
          fakeAsync((async) {
            final manager = entry.value();
            var completed = 0;
            String? id;
            unawaited(
              manager
                  .createSubscription(
                    name: 'cancel',
                    filters: [
                      Filter(kinds: [1]),
                    ],
                    onEvent: (_) {},
                    onComplete: () => completed++,
                    timeout: const Duration(seconds: 1),
                  )
                  .then((value) => id = value),
            );
            async.flushMicrotasks();
            expect(id, isNotNull);
            unawaited(manager.cancelSubscription(id!));
            async.flushMicrotasks();
            final completionsAtCancel = completed;
            expect(async.nonPeriodicTimerCount, 0);
            async.elapse(const Duration(seconds: 2));
            expect(completed, completionsAtCancel);
            unawaited(manager.dispose());
            async.flushMicrotasks();
          });
        },
      );

      test('${entry.key} releases pending timers on dispose', () {
        fakeAsync((async) {
          final manager = entry.value();
          var completed = 0;
          unawaited(
            manager.createSubscription(
              name: 'dispose',
              filters: [
                Filter(kinds: [1]),
              ],
              onEvent: (_) {},
              onComplete: () => completed++,
              timeout: const Duration(seconds: 1),
            ),
          );
          async.flushMicrotasks();
          unawaited(manager.dispose());
          async.flushMicrotasks();
          final completionsAtDispose = completed;
          expect(async.nonPeriodicTimerCount, 0);
          async.elapse(const Duration(seconds: 2));
          expect(completed, completionsAtDispose);
        });
      });
    }
  });
}
