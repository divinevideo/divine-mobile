// ABOUTME: A live subscription every relay refused is opened again after a
// ABOUTME: capped, doubling delay; anything else ends it as before.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

// A relay can echo the address it saw back in its refusal text.
const _refusal = RelaySubscriptionRefusedException(
  'rate-limited: slow down, 203.0.113.7',
);

Event _event(String content) => Event(
  '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
  EventKind.reaction,
  const [],
  content,
);

/// Opens a fresh controller per call so a test can end each opening.
class _Opener {
  final List<StreamController<Event>> opened = [];

  Stream<Event> call() {
    final controller = StreamController<Event>();
    opened.add(controller);
    return controller.stream;
  }

  void refuseLatest() {
    final latest = opened.last..addError(_refusal);
    unawaited(latest.close());
  }
}

void main() {
  group(RefusalRetryingSubscription, () {
    late _Opener opener;
    late List<Event> received;
    late List<Duration> retryDelays;
    late List<String> reasonCategories;
    late List<Object> errors;

    RefusalRetryingSubscription build() => RefusalRetryingSubscription(
      open: opener.call,
      onEvent: received.add,
      onRefused: (reasonCategory, retryIn) {
        reasonCategories.add(reasonCategory);
        retryDelays.add(retryIn);
      },
      onError: errors.add,
    );

    setUp(() {
      opener = _Opener();
      received = [];
      retryDelays = [];
      reasonCategories = [];
      errors = [];
    });

    group('start', () {
      test('delivers the events of the subscription it opens', () {
        fakeAsync((async) {
          build().start();
          final event = _event('+');
          opener.opened.single.add(event);
          async.flushMicrotasks();

          expect(received, equals([event]));
        });
      });
    });

    group('on a refusal from every relay', () {
      test('opens the subscription again after the initial delay', () {
        fakeAsync((async) {
          build().start();
          opener.refuseLatest();
          async
            ..flushMicrotasks()
            ..elapse(
              RefusalRetryingSubscription.defaultInitialDelay -
                  const Duration(milliseconds: 1),
            );
          expect(opener.opened, hasLength(1));

          async.elapse(const Duration(milliseconds: 1));
          expect(opener.opened, hasLength(2));
          expect(
            retryDelays,
            equals([RefusalRetryingSubscription.defaultInitialDelay]),
          );
          expect(errors, isEmpty);
        });
      });

      test('names the refusal by its category, never by the relay text', () {
        fakeAsync((async) {
          build().start();
          opener.refuseLatest();
          async.flushMicrotasks();

          expect(reasonCategories, equals(['rate-limited']));
        });
      });

      test('doubles the delay on each refusal up to the cap', () {
        fakeAsync((async) {
          build().start();
          for (var i = 0; i < 7; i++) {
            opener.refuseLatest();
            async
              ..flushMicrotasks()
              ..elapse(RefusalRetryingSubscription.defaultMaxDelay);
          }

          expect(retryDelays, const [
            Duration(seconds: 2),
            Duration(seconds: 4),
            Duration(seconds: 8),
            Duration(seconds: 16),
            Duration(seconds: 32),
            Duration(minutes: 1),
            Duration(minutes: 1),
          ]);
          expect(opener.opened, hasLength(8));
        });
      });

      test(
        'keeps doubling when each reopen delivers stored events before the '
        'refusal',
        () {
          fakeAsync((async) {
            build().start();
            for (var i = 0; i < 3; i++) {
              // A reopen replays the relay's stored batch before it refuses.
              opener.opened.last.add(_event('+'));
              opener.refuseLatest();
              async
                ..flushMicrotasks()
                ..elapse(RefusalRetryingSubscription.defaultMaxDelay);
            }

            expect(retryDelays, const [
              Duration(seconds: 2),
              Duration(seconds: 4),
              Duration(seconds: 8),
            ]);
          });
        },
      );

      test('starts from the initial delay again after an opening stayed up '
          'for the longest delay', () {
        fakeAsync((async) {
          build().start();
          opener.refuseLatest();
          async
            ..flushMicrotasks()
            ..elapse(RefusalRetryingSubscription.defaultInitialDelay);
          opener.refuseLatest();
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 4))
            ..elapse(RefusalRetryingSubscription.defaultMaxDelay);
          opener.refuseLatest();
          async.flushMicrotasks();

          expect(retryDelays, const [
            Duration(seconds: 2),
            Duration(seconds: 4),
            Duration(seconds: 2),
          ]);
        });
      });
    });

    group('reopen that throws', () {
      test('reports the error instead of letting it escape', () {
        fakeAsync((async) {
          var opens = 0;
          final failure = StateError('client disposed');
          RefusalRetryingSubscription(
            open: () {
              if (++opens > 1) throw failure;
              return Stream.error(_refusal);
            },
            onEvent: received.add,
            onError: errors.add,
          ).start();
          async
            ..flushMicrotasks()
            ..elapse(RefusalRetryingSubscription.defaultInitialDelay);

          expect(opens, equals(2));
          expect(errors, equals([failure]));
        });
      });
    });

    group('on anything else', () {
      test('passes another error on without opening again', () {
        fakeAsync((async) {
          build().start();
          final failure = StateError('socket gone');
          final opened = opener.opened.single..addError(failure);
          unawaited(opened.close());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(minutes: 5));

          expect(errors, equals([failure]));
          expect(opener.opened, hasLength(1));
        });
      });

      test('does not open again when the stream just ends', () {
        fakeAsync((async) {
          build().start();
          unawaited(opener.opened.single.close());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(minutes: 5));

          expect(opener.opened, hasLength(1));
          expect(retryDelays, isEmpty);
        });
      });
    });

    group('cancel', () {
      test('stops a pending reopen', () {
        fakeAsync((async) {
          final subscription = build()..start();
          opener.refuseLatest();
          async.flushMicrotasks();

          unawaited(subscription.cancel());
          async.elapse(const Duration(minutes: 5));

          expect(opener.opened, hasLength(1));
        });
      });

      test('stops listening to the open subscription', () {
        fakeAsync((async) {
          final subscription = build()..start();
          unawaited(subscription.cancel());
          async.flushMicrotasks();

          expect(opener.opened.single.hasListener, isFalse);
        });
      });
    });
  });
}
