// ABOUTME: Tests for SignedEventRelayPublisher: the 3-attempt 2s/4s retry ladder,
// ABOUTME: relay-presence recovery, the outer timeout guard, and its derivation

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/video_publish/signed_event_relay_publisher.dart';
import 'package:openvine/utils/async_utils.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockEventApiClient extends Mock implements EventApiClient {}

class _FakeEvent extends Fake implements Event {}

// Deliberately not the default trusted relay, so the tests that bind
// `trustedRelayUrl` to it prove the classification follows the wiring.
const _relayUrl = 'wss://relay.trusted.example';
const _pubkey =
    '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

Event _signedEvent() => Event(
  _pubkey,
  NIP71VideoKinds.getPreferredAddressableKind(),
  const [
    ['d', 'test-video-id'],
  ],
  'A plant video',
  createdAt: 1700000000,
);

PublishOutcome _accepted(Event event) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const [_relayUrl],
  rejectedBy: const {},
  noResponseFrom: const [],
);

PublishOutcome _rejected(Event event, String reason) => PublishOutcome(
  eventId: event.id,
  acceptedBy: const [],
  rejectedBy: {_relayUrl: reason},
  noResponseFrom: const [],
);

void main() {
  late _MockNostrClient nostrClient;
  late _MockEventApiClient eventApiClient;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() {
    nostrClient = _MockNostrClient();
    eventApiClient = _MockEventApiClient();
    when(() => nostrClient.isInitialized).thenReturn(true);
    when(() => nostrClient.configuredRelayCount).thenReturn(1);
    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.configuredRelays).thenReturn(const [_relayUrl]);
    when(() => nostrClient.connectedRelays).thenReturn(const [_relayUrl]);
    when(
      () => nostrClient.queryEvents(any(), useCache: any(named: 'useCache')),
    ).thenAnswer((_) async => <Event>[]);
  });

  void stubWebSocket(PublishOutcome Function(Event event) outcome) {
    when(
      () => nostrClient.publishEventAwaitOk(
        any(),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (invocation) async =>
          outcome(invocation.positionalArguments.first as Event),
    );
  }

  group(SignedEventRelayPublisher, () {
    group('publishViaWebSocket', () {
      test('reports published when a relay confirms with OK', () async {
        stubWebSocket(_accepted);
        final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);

        final outcome = await publisher.publishViaWebSocket(_signedEvent());

        expect(outcome, EventPublishOutcome.published);
      });

      test('reports a transient failure when every relay rejects', () async {
        stubWebSocket((event) => _rejected(event, 'error: relay is full'));
        final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);

        final outcome = await publisher.publishViaWebSocket(_signedEvent());

        expect(outcome, EventPublishOutcome.transientFailure);
      });

      test(
        'throws AccountRestrictedPublishException from the trusted relay',
        () async {
          stubWebSocket(
            (event) => _rejected(event, 'blocked: pubkey is suspended'),
          );
          final publisher = SignedEventRelayPublisher(
            nostrClient: nostrClient,
            trustedRelayUrl: _relayUrl,
          );

          await expectLater(
            publisher.publishViaWebSocket(_signedEvent()),
            throwsA(
              isA<AccountRestrictedPublishException>().having(
                (e) => e.source,
                'source',
                AccountRestrictionSource.webSocket,
              ),
            ),
          );
        },
      );

      test(
        'treats the same rejection from another relay as transient',
        () async {
          stubWebSocket(
            (event) => _rejected(event, 'blocked: pubkey is suspended'),
          );
          final publisher = SignedEventRelayPublisher(
            nostrClient: nostrClient,
            trustedRelayUrl: 'wss://other.example',
          );

          final outcome = await publisher.publishViaWebSocket(_signedEvent());

          expect(outcome, EventPublishOutcome.transientFailure);
        },
      );

      test('gives up with a transient failure when the OK never arrives', () {
        fakeAsync((async) {
          when(
            () => nostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((_) => Completer<PublishOutcome>().future);
          final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);
          EventPublishOutcome? outcome;

          unawaited(
            publisher
                .publishViaWebSocket(_signedEvent())
                .then((value) => outcome = value),
          );
          async.flushMicrotasks();

          final guard =
              publisher.currentOuterPublishTimeout +
              RelayPool.perRelaySendTimeout;
          async.elapse(guard - const Duration(seconds: 1));
          expect(outcome, isNull, reason: 'still inside the outer guard');

          async.elapse(const Duration(seconds: 2));
          expect(outcome, EventPublishOutcome.transientFailure);
        });
      });

      test('passes the derived outer timeout to the SDK', () async {
        when(() => nostrClient.configuredRelayCount).thenReturn(6);
        stubWebSocket(_accepted);
        final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);

        await publisher.publishViaWebSocket(_signedEvent());

        final captured = verify(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: captureAny(named: 'timeout'),
          ),
        ).captured;
        expect(captured.single, outerPublishTimeoutFor(6));
      });
    });

    group('publish without an EventApiClient', () {
      test('retries over WebSocket with a 2s then 4s backoff', () {
        fakeAsync((async) {
          var attempts = 0;
          when(
            () => nostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((invocation) async {
            attempts++;
            final event = invocation.positionalArguments.first as Event;
            return attempts == 3
                ? _accepted(event)
                : _rejected(event, 'error: try later');
          });
          final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);
          EventPublishOutcome? outcome;

          unawaited(
            publisher.publish(_signedEvent()).then((value) => outcome = value),
          );
          async.flushMicrotasks();
          expect(attempts, 1);

          async.elapse(const Duration(seconds: 1));
          expect(attempts, 1, reason: 'first backoff is 2s');
          async.elapse(const Duration(seconds: 1));
          expect(attempts, 2);

          async.elapse(const Duration(seconds: 3));
          expect(attempts, 2, reason: 'second backoff is 4s');
          async.elapse(const Duration(seconds: 1));
          expect(attempts, 3);
          expect(outcome, EventPublishOutcome.published);
        });
      });

      test('stops after three failed attempts', () {
        fakeAsync((async) {
          var attempts = 0;
          when(
            () => nostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((invocation) async {
            attempts++;
            return _rejected(
              invocation.positionalArguments.first as Event,
              'error: try later',
            );
          });
          final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);
          EventPublishOutcome? outcome;

          unawaited(
            publisher.publish(_signedEvent()).then((value) => outcome = value),
          );
          async.elapse(const Duration(minutes: 1));

          expect(attempts, 3);
          expect(outcome, EventPublishOutcome.transientFailure);
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('dispose cancels a pending backoff instead of retrying', () {
        fakeAsync((async) {
          var attempts = 0;
          when(
            () => nostrClient.publishEventAwaitOk(
              any(),
              timeout: any(named: 'timeout'),
            ),
          ).thenAnswer((invocation) async {
            attempts++;
            return _rejected(
              invocation.positionalArguments.first as Event,
              'error: try later',
            );
          });
          final publisher = SignedEventRelayPublisher(nostrClient: nostrClient);
          Object? error;

          unawaited(
            publisher
                .publish(_signedEvent())
                .then<void>((_) {}, onError: (Object e) => error = e),
          );
          async.flushMicrotasks();
          expect(attempts, 1);

          publisher.dispose();
          async.elapse(const Duration(minutes: 1));

          expect(attempts, 1, reason: 'no attempt may run after dispose');
          expect(error, isA<AsyncCancelledException>());
          expect(async.pendingTimers, isEmpty);
        });
      });
    });

    group('publish with an EventApiClient', () {
      late SignedEventRelayPublisher publisher;

      setUp(() {
        publisher = SignedEventRelayPublisher(
          nostrClient: nostrClient,
          eventApiClient: eventApiClient,
          trustedRelayUrl: _relayUrl,
        );
      });

      test('retries with a 2s then 4s backoff', () {
        fakeAsync((async) {
          final event = _signedEvent();
          var restAttempts = 0;
          when(() => eventApiClient.publishEvent(any())).thenAnswer((_) async {
            restAttempts++;
            return restAttempts == 3
                ? EventApiAccepted(event.id)
                : const EventApiTransientFailure('timeout');
          });
          stubWebSocket((event) => _rejected(event, 'error: try later'));
          EventPublishOutcome? outcome;

          unawaited(publisher.publish(event).then((value) => outcome = value));
          async.flushMicrotasks();
          expect(restAttempts, 1);

          async.elapse(const Duration(seconds: 1));
          expect(restAttempts, 1, reason: 'first backoff is 2s');
          async.elapse(const Duration(seconds: 1));
          expect(restAttempts, 2);

          async.elapse(const Duration(seconds: 3));
          expect(restAttempts, 2, reason: 'second backoff is 4s');
          async.elapse(const Duration(seconds: 1));
          expect(restAttempts, 3);
          expect(outcome, EventPublishOutcome.published);
        });
      });

      test('stops after three attempts and a final presence check', () {
        fakeAsync((async) {
          var restAttempts = 0;
          when(() => eventApiClient.publishEvent(any())).thenAnswer((_) async {
            restAttempts++;
            return const EventApiTransientFailure('timeout');
          });
          stubWebSocket((event) => _rejected(event, 'error: try later'));
          EventPublishOutcome? outcome;

          unawaited(
            publisher.publish(_signedEvent()).then((value) => outcome = value),
          );
          async.elapse(const Duration(minutes: 1));

          expect(restAttempts, 3);
          expect(outcome, EventPublishOutcome.transientFailure);
          verify(
            () => nostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(3);
          expect(async.pendingTimers, isEmpty);
        });
      });

      test('dispose cancels a pending backoff instead of retrying', () {
        fakeAsync((async) {
          var restAttempts = 0;
          when(() => eventApiClient.publishEvent(any())).thenAnswer((_) async {
            restAttempts++;
            return const EventApiTransientFailure('timeout');
          });
          stubWebSocket((event) => _rejected(event, 'error: try later'));
          Object? error;

          unawaited(
            publisher
                .publish(_signedEvent())
                .then<void>((_) {}, onError: (Object e) => error = e),
          );
          async.flushMicrotasks();
          expect(restAttempts, 1);

          publisher.dispose();
          expect(
            async.pendingTimers,
            isEmpty,
            reason: 'dispose must cancel the backoff timer itself',
          );
          async.elapse(const Duration(minutes: 1));

          expect(restAttempts, 1, reason: 'no attempt may run after dispose');
          expect(error, isA<AsyncCancelledException>());
        });
      });

      test('a REST acceptance publishes without touching WebSocket', () async {
        when(
          () => eventApiClient.publishEvent(any()),
        ).thenAnswer((_) async => EventApiAccepted(_signedEvent().id));

        final outcome = await publisher.publish(_signedEvent());

        expect(outcome, EventPublishOutcome.published);
        verifyNever(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        );
      });

      test('a transient REST failure falls back to WebSocket', () async {
        when(() => eventApiClient.publishEvent(any())).thenAnswer(
          (_) async => const EventApiTransientFailure('timeout'),
        );
        stubWebSocket(_accepted);

        final outcome = await publisher.publish(_signedEvent());

        expect(outcome, EventPublishOutcome.published);
        verify(
          () => nostrClient.publishEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
          ),
        ).called(1);
      });

      test('a REST account restriction is thrown, not retried', () async {
        when(() => eventApiClient.publishEvent(any())).thenAnswer(
          (_) async => const EventApiRejected(
            statusCode: 403,
            reason: 'blocked: pubkey is banned',
          ),
        );

        await expectLater(
          publisher.publish(_signedEvent()),
          throwsA(
            isA<AccountRestrictedPublishException>().having(
              (e) => e.source,
              'source',
              AccountRestrictionSource.rest,
            ),
          ),
        );
        verify(() => eventApiClient.publishEvent(any())).called(1);
      });

      test(
        'an event already on a relay is not re-published on retry',
        () async {
          final event = _signedEvent();
          when(
            () => nostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          final outcome = await publisher.publish(event, isRetry: true);

          expect(outcome, EventPublishOutcome.published);
          verifyNever(() => eventApiClient.publishEvent(any()));
        },
      );

      test('a lost OK is recovered from the relay before the next attempt', () {
        fakeAsync((async) {
          final event = _signedEvent();
          var restAttempts = 0;
          when(() => eventApiClient.publishEvent(any())).thenAnswer((_) async {
            restAttempts++;
            return const EventApiTransientFailure('timeout');
          });
          stubWebSocket((event) => _rejected(event, 'error: no response'));
          // Not consulted before the first attempt (isRetry is false), so
          // the relay answering "already here" means the OK was lost.
          when(
            () => nostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);
          EventPublishOutcome? outcome;

          unawaited(publisher.publish(event).then((value) => outcome = value));
          async.elapse(const Duration(minutes: 1));

          expect(restAttempts, 1, reason: 'the event surfaced before retry 2');
          expect(outcome, EventPublishOutcome.published);
        });
      });
    });
  });

  group('outerPublishTimeoutFor', () {
    // Pins the derivation introduced as the follow-up to PR #3683 / issue
    // #3688: the outer publish timeout is `RelayPool.perRelaySendTimeout *
    // relayCount + buffer`, clamped to `[floor, ceiling]`. Encoding the
    // relationship in code keeps the outer guard from silently firing
    // before the inner sequential fan-out can complete on degraded
    // networks, regardless of how many relays the user configures.

    test('clamps to the floor when the relay count is zero', () {
      // 0 * 5s + 5s = 5s, which is below the 10s floor.
      expect(outerPublishTimeoutFor(0), equals(const Duration(seconds: 10)));
    });

    test('still clamps to the floor for a single relay', () {
      // 1 * 5s + 5s = 10s, exactly at the floor — never below it.
      expect(outerPublishTimeoutFor(1), equals(const Duration(seconds: 10)));
    });

    test('scales linearly between the floor and ceiling', () {
      // 2 * 5s + 5s = 15s
      expect(outerPublishTimeoutFor(2), equals(const Duration(seconds: 15)));
      // 6 * 5s + 5s = 35s — the current default-config worst case.
      expect(outerPublishTimeoutFor(6), equals(const Duration(seconds: 35)));
      // 11 * 5s + 5s = 60s, exactly at the ceiling.
      expect(outerPublishTimeoutFor(11), equals(const Duration(seconds: 60)));
    });

    test('clamps to the ceiling for misconfigured huge relay lists', () {
      // 12 * 5s + 5s = 65s → clamped to 60s ceiling. Bounds worst-case
      // publish latency so the user never stares at a spinner for
      // several minutes.
      expect(outerPublishTimeoutFor(12), equals(const Duration(seconds: 60)));
      expect(outerPublishTimeoutFor(50), equals(const Duration(seconds: 60)));
    });

    test('strictly exceeds the inner worst-case fan-out up to the ceiling '
        'boundary', () {
      // The whole point of the derivation: the outer guard must never
      // fire before the inner sequential fan-out inside
      // `RelayPool._sendCollect` can complete. Asserts the invariant
      // strictly (with the buffer present) for the full range up to
      // the ceiling boundary.
      for (final relayCount in [0, 1, 2, 6, 7, 11]) {
        final innerWorstCase = RelayPool.perRelaySendTimeout * relayCount;
        final outer = outerPublishTimeoutFor(relayCount);
        expect(
          outer > innerWorstCase,
          isTrue,
          reason:
              'outer ($outer) must strictly exceed inner worst case '
              '($innerWorstCase) for relayCount=$relayCount '
              '(buffer must be present)',
        );
      }
    });

    test('invariant degrades at the ceiling boundary (relayCount >= 12)', () {
      // Pinned trade-off: clamping to the 60s ceiling means the
      // strict `outer > inner_worst_case` invariant evaporates at the
      // boundary and inverts beyond it. This test locks the documented
      // edge so any change to the ceiling, the per-relay timeout, or
      // the buffer surfaces here loudly. See the
      // `_outerPublishTimeoutCeiling` doc comment for the rationale.

      // At relayCount == 12: derived = 12 * 5s + 5s = 65s, clamped to
      // 60s. Inner worst case = 12 * 5s = 60s. Outer == inner; buffer
      // is gone but the invariant is not yet violated.
      final innerAt12 = RelayPool.perRelaySendTimeout * 12;
      final outerAt12 = outerPublishTimeoutFor(12);
      expect(outerAt12, equals(const Duration(seconds: 60)));
      expect(outerAt12, equals(innerAt12));
      expect(
        outerAt12 > innerAt12,
        isFalse,
        reason: 'buffer is exhausted at relayCount == 12',
      );

      // At relayCount == 13: derived = 70s, clamped to 60s. Inner
      // worst case = 65s. Outer < inner — the original false-negative
      // failure mode is back for this edge. The retry loop in
      // SignedEventRelayPublisher.publish absorbs it.
      final innerAt13 = RelayPool.perRelaySendTimeout * 13;
      final outerAt13 = outerPublishTimeoutFor(13);
      expect(outerAt13, equals(const Duration(seconds: 60)));
      expect(
        outerAt13 < innerAt13,
        isTrue,
        reason:
            'invariant breaks at relayCount == 13: '
            'outer ($outerAt13) < inner ($innerAt13)',
      );
    });
  });
}
