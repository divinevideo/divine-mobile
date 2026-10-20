// ABOUTME: Unit tests for PublishTracker and PublishOutcome used to await
// ABOUTME: OK responses from relays when publishing events.

import 'dart:async';

import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:test/test.dart';

/// Every targeted relay must appear in exactly one bucket, and no relay may
/// appear that was never targeted.
///
/// This single invariant is what the pre-fix code violated three different
/// ways: a target the pool could not write to appeared in no bucket, a relay
/// that answered after the first OK appeared in the wrong bucket, and a relay
/// that was never a target could appear in `acceptedBy`.
void expectPartitions(PublishOutcome outcome, Set<String> targets) {
  final buckets = <String>[
    ...outcome.acceptedBy,
    ...outcome.rejectedBy.keys,
    ...outcome.noResponseFrom,
    ...outcome.unreachableTargets,
  ];
  expect(
    buckets.toSet(),
    equals(targets),
    reason: 'every target must appear in exactly one bucket',
  );
  expect(
    buckets.length,
    equals(targets.length),
    reason: 'no relay may appear in two buckets',
  );
}

PublishTracker trackerFor(
  Set<String> targets, {
  String eventId = 'event-1',
  Duration timeout = const Duration(seconds: 30),
  Duration settleWindow = const Duration(milliseconds: 50),
}) {
  return PublishTracker(
    eventId: eventId,
    expectedRelays: targets,
    timeout: timeout,
    settleWindow: settleWindow,
  );
}

void main() {
  group(PublishTracker, () {
    group('onAccepted', () {
      test('waits for the other relays instead of completing on the first '
          'acceptance', () async {
        final tracker = trackerFor({'wss://a.example', 'wss://b.example'});

        tracker.onAccepted('wss://a.example');
        var resolved = false;
        unawaited(tracker.future.then((_) => resolved = true));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          resolved,
          isFalse,
          reason: 'a second relay had not answered yet',
        );

        tracker.onAccepted('wss://b.example');
        final outcome = await tracker.future;

        expect(outcome.acceptedByAll, isTrue);
        expect(
          outcome.acceptedBy,
          unorderedEquals(['wss://a.example', 'wss://b.example']),
        );
        expectPartitions(outcome, {'wss://a.example', 'wss://b.example'});
      });

      test('completes at once when the only target accepts', () async {
        final tracker = trackerFor({'wss://only.example'});

        tracker.onAccepted('wss://only.example');
        final outcome = await tracker.future;

        expect(outcome.acceptedByAll, isTrue);
        expect(outcome.acceptedByPartial, isFalse);
        expectPartitions(outcome, {'wss://only.example'});
      });
    });

    // The behaviour issue #3366 was filed for: an acceptance and a later
    // rejection must both survive into the outcome, in either arrival order.
    group('one accept plus a later reject', () {
      test('records the rejection that arrives after an acceptance', () async {
        final tracker = trackerFor({
          'wss://fast.example',
          'wss://slow.example',
        });

        tracker.onAccepted('wss://fast.example');
        tracker.onRejected('wss://slow.example', 'blocked: policy');
        final outcome = await tracker.future;

        expect(outcome.acceptedBy, equals(['wss://fast.example']));
        expect(
          outcome.rejectedBy,
          equals({'wss://slow.example': 'blocked: policy'}),
          reason: 'the rejection must not be discarded as a non-response',
        );
        expect(outcome.acceptedByAll, isFalse);
        expect(outcome.acceptedByAny, isTrue);
        expect(outcome.acceptedByPartial, isTrue);
        expectPartitions(outcome, {'wss://fast.example', 'wss://slow.example'});
      });

      test(
        'produces the same outcome when the rejection arrives first',
        () async {
          final tracker = trackerFor({
            'wss://fast.example',
            'wss://slow.example',
          });

          tracker.onRejected('wss://slow.example', 'blocked: policy');
          tracker.onAccepted('wss://fast.example');
          final outcome = await tracker.future;

          expect(outcome.acceptedBy, equals(['wss://fast.example']));
          expect(
            outcome.rejectedBy,
            equals({'wss://slow.example': 'blocked: policy'}),
            reason: 'the outcome must not depend on arrival order',
          );
          expect(outcome.acceptedByPartial, isTrue);
          expectPartitions(outcome, {
            'wss://fast.example',
            'wss://slow.example',
          });
        },
      );

      test(
        'reports a relay that never answers as silent, not as accepting',
        () async {
          final tracker = trackerFor({
            'wss://fast.example',
            'wss://mute.example',
          });

          tracker.setReachable(['wss://fast.example', 'wss://mute.example']);
          tracker.onAccepted('wss://fast.example');
          final outcome = await tracker.future;

          expect(outcome.acceptedBy, equals(['wss://fast.example']));
          expect(outcome.noResponseFrom, equals(['wss://mute.example']));
          expect(outcome.acceptedByAll, isFalse);
          expectPartitions(outcome, {
            'wss://fast.example',
            'wss://mute.example',
          });
        },
      );
    });

    group('settle window', () {
      test(
        'bounds the wait for a silent relay well below the timeout',
        () async {
          final tracker = trackerFor(
            {'wss://fast.example', 'wss://mute.example'},
            timeout: const Duration(seconds: 30),
            settleWindow: const Duration(milliseconds: 40),
          );

          final stopwatch = Stopwatch()..start();
          tracker.setReachable(['wss://fast.example', 'wss://mute.example']);
          tracker.onAccepted('wss://fast.example');
          await tracker.future;
          stopwatch.stop();

          expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
        },
      );

      // `RelayPool.sendEventAwaitOk` registers the tracker before it awaits
      // the sequential fan-out, and only calls `setReachable` once that
      // fan-out returns. A connected relay therefore answers while a later
      // target may not have been written to yet — and the fan-out can outlast
      // the settle window, since it waits out a relay's `connecting` state and
      // caps each one at `perRelaySendTimeout`.
      test(
        'does not start before the fan-out has reported its targets',
        () async {
          final tracker = trackerFor({
            'wss://fast.example',
            'wss://slow.example',
          }, settleWindow: const Duration(milliseconds: 20));

          tracker.onAccepted('wss://fast.example');
          await Future<void>.delayed(const Duration(milliseconds: 60));

          var resolved = false;
          unawaited(tracker.future.then((_) => resolved = true));
          await Future<void>.delayed(Duration.zero);
          expect(
            resolved,
            isFalse,
            reason: 'the fan-out was still writing to wss://slow.example',
          );

          tracker.setReachable(['wss://fast.example', 'wss://slow.example']);
          tracker.onAccepted('wss://slow.example');
          final outcome = await tracker.future;

          expect(
            outcome.acceptedByAll,
            isTrue,
            reason: 'both relays accepted, so this is not a partial publish',
          );
          expectPartitions(outcome, {
            'wss://fast.example',
            'wss://slow.example',
          });
        },
      );
    });

    group('unreachable targets', () {
      test('reports a target the fan-out could not write to', () async {
        final tracker = trackerFor({'wss://up.example', 'wss://down.example'});

        tracker.setReachable(['wss://up.example']);
        tracker.onAccepted('wss://up.example');
        final outcome = await tracker.future;

        expect(outcome.acceptedBy, equals(['wss://up.example']));
        expect(outcome.unreachableTargets, equals(['wss://down.example']));
        expect(
          outcome.acceptedByAll,
          isFalse,
          reason: 'a target we never reached is not an acceptance',
        );
        expect(outcome.targetCount, equals(2));
        expectPartitions(outcome, {'wss://up.example', 'wss://down.example'});
      });

      test('settles immediately when the fan-out reached nothing', () async {
        final tracker = trackerFor({'wss://a.example', 'wss://b.example'});

        tracker.setReachable(const <String>[]);
        final outcome = await tracker.future;

        expect(outcome.failed, isTrue);
        expect(
          outcome.unreachableTargets,
          unorderedEquals(['wss://a.example', 'wss://b.example']),
        );
        expect(outcome.summary, contains('unreachable'));
        expectPartitions(outcome, {'wss://a.example', 'wss://b.example'});
      });

      // `RelayPool` bounds the fan-out by the same deadline as this tracker,
      // so a fan-out that spends the whole budget racing the hard timeout is
      // the normal case rather than an exotic one. Completing first would
      // report every target the fan-out never got to as silent, and the pool
      // force-reconnects silent relays — cycling connections the publish
      // never wrote to.
      test(
        'waits for the fan-out report when the timeout wins the race',
        () async {
          final tracker = trackerFor({
            'wss://written.example',
            'wss://untouched.example',
          }, timeout: const Duration(milliseconds: 20));

          await Future<void>.delayed(const Duration(milliseconds: 60));

          var resolved = false;
          unawaited(tracker.future.then((_) => resolved = true));
          await Future<void>.delayed(Duration.zero);
          expect(
            resolved,
            isFalse,
            reason: 'the fan-out had not said what it wrote to yet',
          );

          tracker.setReachable(['wss://written.example']);
          final outcome = await tracker.future;

          expect(outcome.noResponseFrom, equals(['wss://written.example']));
          expect(
            outcome.unreachableTargets,
            equals(['wss://untouched.example']),
            reason: 'the fan-out never wrote to it, so it was not silent',
          );
          expectPartitions(outcome, {
            'wss://written.example',
            'wss://untouched.example',
          });
        },
      );

      // A relay outside `sentTo` can still answer: `_sendCollect` reports the
      // write as failed when its per-relay timeout fires, which can happen
      // after the frame already went out. That answer must not settle the
      // publish on behalf of a relay that is still silent.
      test(
        'does not let an unreached relay answer for a reached one',
        () async {
          final tracker = trackerFor({
            'wss://late.example',
            'wss://b.example',
            'wss://c.example',
          }, settleWindow: const Duration(seconds: 10));

          tracker.onAccepted('wss://late.example');
          tracker.setReachable(['wss://b.example', 'wss://c.example']);
          tracker.onAccepted('wss://b.example');

          var resolved = false;
          unawaited(tracker.future.then((_) => resolved = true));
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(
            resolved,
            isFalse,
            reason: 'wss://c.example had not answered yet',
          );

          tracker.onAccepted('wss://c.example');
          final outcome = await tracker.future;

          expect(outcome.acceptedByAll, isTrue);
          expectPartitions(outcome, {
            'wss://late.example',
            'wss://b.example',
            'wss://c.example',
          });
        },
      );
    });

    group('isTarget', () {
      test('rejects a relay that was never a publish target', () {
        final tracker = trackerFor({'wss://target.example'});

        expect(tracker.isTarget('wss://target.example'), isTrue);
        expect(tracker.isTarget('wss://intruder.example'), isFalse);

        tracker.cancel();
      });

      test('ignores a relay the caller adds after construction', () {
        final targets = {'wss://target.example'};
        final tracker = trackerFor(targets);

        targets.add('wss://intruder.example');

        expect(
          tracker.isTarget('wss://intruder.example'),
          isFalse,
          reason:
              'the target set is fixed when the publish starts, and '
              'RelayPool admits an OK frame on isTarget alone — so a relay '
              'the caller adds afterwards could otherwise accept or reject '
              'an event it was never sent',
        );

        tracker.cancel();
      });
    });

    group('onRejected', () {
      test(
        'reports rejection reason and does not consider the publish confirmed',
        () async {
          final tracker = trackerFor({
            'wss://only.example',
          }, eventId: 'event-2');

          tracker.onRejected('wss://only.example', 'blocked: policy');
          final outcome = await tracker.future;

          expect(outcome.failed, isTrue);
          expect(
            outcome.rejectedBy,
            equals({'wss://only.example': 'blocked: policy'}),
          );
          expect(outcome.summary, contains('blocked'));
        },
      );
    });

    group('timeout', () {
      test(
        'completes with every relay in noResponseFrom when no response arrives',
        () async {
          final tracker = trackerFor(
            {'wss://a.example', 'wss://b.example'},
            eventId: 'event-3',
            timeout: const Duration(milliseconds: 20),
          );

          final outcome = await tracker.future;

          expect(outcome.failed, isTrue);
          expect(outcome.acceptedBy, isEmpty);
          expect(outcome.rejectedBy, isEmpty);
          expect(
            outcome.noResponseFrom,
            unorderedEquals(['wss://a.example', 'wss://b.example']),
          );
        },
      );
    });

    group('cancel', () {
      test('completes the tracker synchronously for pool shutdown', () async {
        final tracker = trackerFor({'wss://only.example'}, eventId: 'event-4');

        tracker.cancel();
        final outcome = await tracker.future;

        expect(outcome.failed, isTrue);
        expect(outcome.noResponseFrom, equals(['wss://only.example']));
      });

      test('never lists an accepting relay as unanswered', () async {
        final tracker = trackerFor({'wss://a.example', 'wss://b.example'});

        tracker.onAccepted('wss://a.example');
        tracker.cancel();
        final outcome = await tracker.future;

        expect(outcome.acceptedBy, equals(['wss://a.example']));
        expect(outcome.noResponseFrom, equals(['wss://b.example']));
        expectPartitions(outcome, {'wss://a.example', 'wss://b.example'});
      });

      test(
        'keeps a deferred rejection reason when nothing was accepted',
        () async {
          final tracker = trackerFor({'wss://a.example'});

          tracker.deferRejection('wss://a.example', 'auth-required: sign in');
          tracker.cancel();
          final outcome = await tracker.future;

          expect(
            outcome.rejectedBy,
            equals({'wss://a.example': 'auth-required: sign in'}),
            reason: 'shutdown must report the same reasons a timeout would',
          );
        },
      );
    });

    group('publish diagnostics metadata', () {
      test('does not expose mutable counted target state', () {
        final expectedRelays = {'wss://a.example', 'wss://b.example'};
        final tracker = PublishTracker(
          eventId: 'note-1',
          expectedRelays: expectedRelays,
          timeout: const Duration(seconds: 30),
        );

        expectedRelays.add('wss://outside.example');

        expect(
          tracker.countedTargets,
          equals({'wss://a.example', 'wss://b.example'}),
        );
        expect(
          () => tracker.countedTargets.add('wss://mutated.example'),
          throwsUnsupportedError,
        );
        tracker.cancel();
      });
    });
  });

  group(PublishOutcome, () {
    test('treats a publish with no targets as not accepted', () {
      const outcome = PublishOutcome(
        eventId: 'empty',
        acceptedBy: [],
        rejectedBy: {},
        noResponseFrom: [],
      );

      expect(
        outcome.acceptedByAll,
        isFalse,
        reason: '"all of zero" must not read as success',
      );
      expect(outcome.acceptedByAny, isFalse);
      expect(outcome.failed, isTrue);
    });

    group('summary', () {
      test('names a refusal by its category, never the relay text', () {
        const outcome = PublishOutcome(
          eventId: 'refused',
          acceptedBy: [],
          rejectedBy: {
            'wss://refuses.example':
                'invalid: event too large from 203.0.113.9',
          },
          noResponseFrom: [],
        );

        expect(outcome.summary, contains('wss://refuses.example'));
        expect(outcome.summary, contains('invalid'));
        expect(outcome.summary, isNot(contains('203.0.113.9')));
        expect(outcome.summary, isNot(contains('event too large')));
      });
    });

    group('rejectionCategories', () {
      test('maps each rejecting relay to its category alone', () {
        const outcome = PublishOutcome(
          eventId: 'refused',
          acceptedBy: ['wss://accepts.example'],
          rejectedBy: {
            'wss://large.example': 'invalid: event too large from 203.0.113.9',
            'wss://busy.example': 'rate-limited: slow down, 2001:db8::7',
            'wss://terse.example': 'go away 203.0.113.9',
          },
          noResponseFrom: [],
        );

        expect(
          outcome.rejectionCategories,
          equals({
            'wss://large.example': 'invalid',
            'wss://busy.example': 'rate-limited',
            'wss://terse.example': 'other',
          }),
        );
      });
    });
  });
}
