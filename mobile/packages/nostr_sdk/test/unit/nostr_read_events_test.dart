// ABOUTME: Tests Nostr.readEvents — each way a read ends, arrived events kept —
// ABOUTME: and the flags queryEventsDetailed and queryEvents map from it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Relay that records what it was sent and only answers when the test says so.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url) : super(url, RelayStatus(url));

  final List<List<dynamic>> sentMessages = [];

  /// When false, [send] reports failure the way a dead socket does.
  bool sendSucceeds = true;

  /// When true, writing a `REQ` throws, the way a broken sink does.
  bool reqWriteThrows = false;

  /// When set, a `REQ` write blocks until the gate completes, which holds the
  /// pool's fan-out open.
  Completer<void>? reqGate;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    sentMessages.add(message);
    if (message.firstOrNull == 'REQ') {
      if (reqWriteThrows) throw StateError('REQ write failed');
      final gate = reqGate;
      if (gate != null) await gate.future;
    }
    return sendSucceeds;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) await result;
  }
}

/// Holds back the first timer a read creates, its deadline timer: the
/// deadline never fires, so no ordering of microtasks and timers decides
/// whether it beats the pool.
class _DeadlineHold {
  _HeldTimer? timer;

  Future<T> run<T>(Future<T> Function() read) => runZoned(
    read,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (timer != null) return parent.createTimer(zone, duration, callback);
        return timer = _HeldTimer(duration);
      },
    ),
  );
}

/// A timer that is never scheduled; it only records what it was asked for.
class _HeldTimer implements Timer {
  _HeldTimer(this.duration);

  final Duration duration;

  bool _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;

  @override
  void cancel() => _active = false;
}

const _privateKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

const _readId = 'read-events-query';

const _authChallenge =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

/// A deadline the test's frames are delivered well inside: the events are
/// signed before the read starts, so only the pool's handling of a few frames
/// races it.
const _deadlineAfterDelivery = Duration(milliseconds: 500);

/// A deadline nothing races: the read is never answered, so the test pays it
/// in full.
const _unansweredDeadline = Duration(milliseconds: 200);

/// Bounds a wait that only a regression could stretch. Shorter than the
/// default read timeout, so a read that ignored its own deadline for the
/// default one still fails the test.
const _guard = Duration(seconds: 3);

List<Map<String, dynamic>> _filters({int limit = 10}) => [
  {
    'kinds': [EventKind.textNote],
    'limit': limit,
  },
];

void main() {
  group('Nostr', () {
    late List<RelayDiagnostic> diagnostics;
    late Nostr nostr;
    var eventNumber = 0;

    setUp(() {
      diagnostics = [];
      nostr = Nostr(
        LocalNostrSigner(_privateKey),
        const [],
        (url) => RelayBase(url, RelayStatus(url)),
        diagnosticsSink: diagnostics.add,
      );
    });

    List<RelayDiagnostic> completionLines() => [
      for (final entry in diagnostics)
        if (entry.site == RelayDiagnosticSite.queryCompletion) entry,
    ];

    Future<_ScriptedRelay> addRelay(String url) async {
      final relay = _ScriptedRelay(url);
      expect(await nostr.relayPool.add(relay), isTrue);
      return relay;
    }

    Future<List<Event>> signedEvents(int count) async {
      final pubkey = await nostr.ensurePublicKey();
      return [
        for (var i = 0; i < count; i++)
          (await nostr.nostrSigner.signEvent(
            Event(pubkey, EventKind.textNote, [], 'read-${eventNumber++}'),
          ))!,
      ];
    }

    /// Pumps until [relay] holds the read's REQ, so the frames the test
    /// delivers next land in the read.
    Future<void> reqLanded(_ScriptedRelay relay) async {
      for (var turn = 0; turn < 50 && !relay.checkQuery(_readId); turn++) {
        await pumpEventQueue(times: 1);
      }
      expect(
        relay.checkQuery(_readId),
        isTrue,
        reason: 'the REQ never reached the relay',
      );
    }

    Future<void> deliverEvents(_ScriptedRelay relay, List<Event> events) async {
      for (final event in events) {
        await relay.deliver(['EVENT', _readId, event.toJson()]);
      }
    }

    List<List<dynamic>> sentOfType(_ScriptedRelay relay, String type) => [
      for (final message in relay.sentMessages)
        if (message.first == type) message,
    ];

    /// A relay that gates reads behind NIP-42, and whose first `REQ` write
    /// throws. The pool saves a gated query before writing it, so the relay
    /// holds a `REQ` the fan-out reports no relay took.
    Future<_ScriptedRelay> addAuthGatedRelay() async {
      final relay = await addRelay('wss://auth-gated.example')
        ..reqWriteThrows = true;
      relay.relayStatus.alwaysAuth = true;
      return relay;
    }

    /// Waits until the read's `REQ` write to [relay] has failed and the
    /// fan-out has moved past it.
    Future<void> reqWriteFailed(_ScriptedRelay relay) async {
      await reqLanded(relay);
      await pumpEventQueue();
      expect(sentOfType(relay, 'REQ'), hasLength(1));
    }

    /// Takes [relay] through NIP-42, so the pool replays the read's saved
    /// `REQ`, then answers the replay with [events] and `EOSE`.
    Future<void> authenticateAndAnswer(
      _ScriptedRelay relay,
      List<Event> events,
    ) async {
      relay.reqWriteThrows = false;
      await relay.deliver(['AUTH', _authChallenge]);
      final authEvent = sentOfType(relay, 'AUTH').single[1] as Map;
      await relay.deliver(['OK', authEvent['id'], true, '']);
      expect(
        sentOfType(relay, 'REQ'),
        hasLength(2),
        reason: 'the pool replays the saved REQ once the relay accepts AUTH',
      );
      await deliverEvents(relay, events);
      await relay.deliver(['EOSE', _readId]);
    }

    Iterable<String> idsOf(List<Event> events) =>
        events.map((event) => event.id);

    group('readEvents', () {
      group('when every relay sends EOSE', () {
        test('returns every event that arrived, as complete', () async {
          final answering = await addRelay('wss://answers.example');
          final empty = await addRelay('wss://empty.example');
          final events = await signedEvents(2);
          final pending = nostr.readEvents(
            _filters(),
            id: _readId,
            timeout: _guard,
          );
          await reqLanded(answering);
          await deliverEvents(answering, events);
          await answering.deliver(['EOSE', _readId]);
          await empty.deliver(['EOSE', _readId]);

          final result = await pending;

          expect(idsOf(result.events), unorderedEquals(idsOf(events)));
          expect(result.endedBy, QueryEnd.complete);
          expect(result.isComplete, isTrue);
          expect(
            result.possiblyCapped,
            isFalse,
            reason: 'two events stay under a limit of ten',
          );
          expect(
            result.confirmedExhaustive,
            isFalse,
            reason: 'no relay sent a NIP-67 finish hint',
          );
          expect(
            completionLines(),
            isEmpty,
            reason: 'a complete, uncapped read is not worth a line',
          );
        });

        test('carries a NIP-67 finish hint through as '
            'confirmedExhaustive', () async {
          final relay = await addRelay('wss://finishes.example');
          final pending = nostr.readEvents(
            _filters(),
            id: _readId,
            timeout: _guard,
          );
          await reqLanded(relay);
          await relay.deliver([
            'EOSE',
            _readId,
            ['finish'],
          ]);

          final result = await pending;

          expect(result.endedBy, QueryEnd.complete);
          expect(result.confirmedExhaustive, isTrue);
          expect(result.possiblyCapped, isFalse);
        });
      });

      group('when the settle window releases a silent relay', () {
        test("keeps the answering relay's events, as settledEarly", () async {
          final answering = await addRelay('wss://answers.example');
          await addRelay('wss://never-answers.example');
          final events = await signedEvents(1);
          final pending = nostr.readEvents(
            _filters(),
            id: _readId,
            timeout: _guard,
          );
          await reqLanded(answering);
          await deliverEvents(answering, events);
          await answering.deliver(['EOSE', _readId]);

          final result = await pending;

          expect(idsOf(result.events), equals(idsOf(events)));
          expect(result.endedBy, QueryEnd.settledEarly);
        });
      });

      group('when a relay sends CLOSED', () {
        test('keeps the events that arrived before it, as '
            'relayClosed', () async {
          final relay = await addRelay('wss://refuses.example');
          final events = await signedEvents(1);
          final pending = nostr.readEvents(
            _filters(),
            id: _readId,
            timeout: _guard,
          );
          await reqLanded(relay);
          await deliverEvents(relay, events);
          await relay.deliver([
            'CLOSED',
            _readId,
            'error: too many concurrent REQs',
          ]);

          final result = await pending;

          expect(idsOf(result.events), equals(idsOf(events)));
          expect(result.endedBy, QueryEnd.relayClosed);
        });
      });

      group('when a socket drops', () {
        test('keeps the events that arrived before it, as '
            'socketDropped', () async {
          final relay = await addRelay('wss://drops.example');
          final events = await signedEvents(1);
          final pending = nostr.readEvents(
            _filters(),
            id: _readId,
            timeout: _guard,
          );
          await reqLanded(relay);
          await deliverEvents(relay, events);
          relay.onError('socket closed', reconnect: true);

          final result = await pending;

          expect(idsOf(result.events), equals(idsOf(events)));
          expect(result.endedBy, QueryEnd.socketDropped);
        });
      });

      group('when no relay takes the REQ', () {
        test('ends as noRelay without waiting for the deadline', () async {
          final relay = await addRelay('wss://send-fails.example');
          relay.sendSucceeds = false;

          final result = await nostr
              .readEvents(
                _filters(),
                id: _readId,
                timeout: const Duration(minutes: 1),
              )
              .timeout(
                _guard,
                onTimeout: () => fail('the read waited out its deadline'),
              );

          expect(result.endedBy, QueryEnd.noRelay);
          expect(result.events, isEmpty);
        });
      });

      group('when a relay behind NIP-42 answers the REQ its write '
          'failed', () {
        test('keeps its events, as complete', () async {
          final relay = await addAuthGatedRelay();
          final events = await signedEvents(1);
          final pending = nostr.readEvents(
            _filters(),
            id: _readId,
            timeout: _guard,
          );
          await reqWriteFailed(relay);
          await authenticateAndAnswer(relay, events);

          final result = await pending;

          expect(idsOf(result.events), equals(idsOf(events)));
          expect(
            result.endedBy,
            QueryEnd.complete,
            reason:
                'the fan-out found no relay that took the REQ, but the relay '
                'answered its replay, so it took part',
          );
        });
      });

      group('when the deadline fires', () {
        test('keeps the events that arrived, as deadline, with the cap they '
            'reached', () async {
          final relay = await addRelay('wss://streams.example');
          final events = await signedEvents(2);
          final pending = nostr.readEvents(
            _filters(limit: 2),
            id: _readId,
            timeout: _deadlineAfterDelivery,
          );
          await reqLanded(relay);
          await deliverEvents(relay, events);

          final result = await pending;

          expect(idsOf(result.events), unorderedEquals(idsOf(events)));
          expect(result.endedBy, QueryEnd.deadline);
          expect(
            result.possiblyCapped,
            isTrue,
            reason: 'the relay had sent as many events as the limit asked for',
          );
          expect(
            relay.checkQuery(_readId),
            isFalse,
            reason: 'the read hands its REQ back once it stops waiting',
          );
          expect(
            completionLines(),
            hasLength(1),
            reason: 'the pool reports the deadline once; Nostr adds none',
          );
          expect(completionLines().single.level, RelayDiagnosticLevel.warning);
          expect(completionLines().single.message, contains('ended deadline'));
        });

        test('derives its deadline from timeout when none is given', () async {
          await addRelay('wss://never-answers.example');

          final result = await nostr
              .readEvents(_filters(), id: _readId, timeout: _unansweredDeadline)
              .timeout(
                _guard,
                onTimeout: () => fail('the read outlived its timeout'),
              );

          expect(result.endedBy, QueryEnd.deadline);
        });

        test('ends at an absolute deadline, whatever timeout says', () async {
          await addRelay('wss://never-answers.example');

          final result = await nostr
              .readEvents(
                _filters(),
                id: _readId,
                timeout: const Duration(minutes: 1),
                deadline: DateTime.now().add(_unansweredDeadline),
              )
              .timeout(
                _guard,
                onTimeout: () => fail('the read ignored its deadline'),
              );

          expect(result.endedBy, QueryEnd.deadline);
        });

        test('does not wait for a fan-out still under way, and ends as '
            'deadline, never noRelay', () async {
          final relay = await addRelay('wss://slow-to-refuse.example')
            ..sendSucceeds = false
            ..reqGate = Completer<void>();

          final result = await nostr
              .readEvents(_filters(), id: _readId, timeout: _unansweredDeadline)
              .timeout(
                _guard,
                onTimeout: () => fail('the read waited for the fan-out'),
              );
          relay.reqGate!.complete();
          await pumpEventQueue();

          expect(
            result.endedBy,
            QueryEnd.deadline,
            reason:
                'the fan-out had not finished, so whether a relay would take '
                'the REQ was still unknown',
          );
          expect(
            completionLines(),
            hasLength(1),
            reason: 'the fan-out finishing afterwards adds no line',
          );
          expect(completionLines().single.message, contains('ended deadline'));
        });

        test('ends a read whose deadline had already passed before any REQ '
            'is written (#7301)', () async {
          final relay = await addRelay('wss://answers.example');
          final hold = _DeadlineHold();

          final result = await hold
              .run(
                () => nostr.readEvents(
                  _filters(),
                  id: _readId,
                  deadline: DateTime.now().subtract(const Duration(seconds: 1)),
                ),
              )
              .timeout(_guard, onTimeout: () => fail('the read never ended'));

          expect(
            relay.sentMessages,
            isEmpty,
            reason:
                'a REQ the deadline would unsubscribe on the next event-loop '
                'turn is never written; it only made every relay look like '
                'it had swallowed the request',
          );
          expect(
            hold.timer,
            isNull,
            reason: 'no deadline timer is armed for a read that never starts',
          );
          expect(result.endedBy, QueryEnd.deadline);
          expect(result.events, isEmpty);
          expect(completionLines(), hasLength(1));
          expect(completionLines().single.level, RelayDiagnosticLevel.warning);
          expect(
            completionLines().single.message,
            contains('ended deadline before any REQ was written'),
          );
        });
      });

      group('when the read cannot start', () {
        test("passes on the pool's error", () async {
          await expectLater(
            nostr.readEvents(const [], id: _readId),
            throwsArgumentError,
          );
        });

        test(
          'still rejects empty filters when the deadline has passed',
          () async {
            // The expired-deadline branch returns before [RelayPool.query] can
            // raise this, so without its own guard the read answers an empty
            // result for a call that was never valid (#7301).
            await expectLater(
              nostr.readEvents(
                const [],
                id: _readId,
                deadline: DateTime.now().subtract(const Duration(seconds: 1)),
              ),
              throwsArgumentError,
            );
          },
        );
      });
    });

    group('queryEventsDetailed', () {
      test('keeps the events that arrived when the deadline fires, as a '
          'timeout', () async {
        final relay = await addRelay('wss://streams.example');
        final events = await signedEvents(2);
        final pending = nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _deadlineAfterDelivery,
        );
        await reqLanded(relay);
        await deliverEvents(relay, events);

        final result = await pending;

        expect(idsOf(result.events), unorderedEquals(idsOf(events)));
        expect(result.timedOut, isTrue);
        expect(
          result.noRelaysParticipated,
          isFalse,
          reason: 'the relay took the REQ; it only never finished',
        );
      });

      test('times out, without claiming no relay took part, when the '
          'deadline beats the fan-out', () async {
        final relay = await addRelay('wss://slow-to-refuse.example')
          ..sendSucceeds = false
          ..reqGate = Completer<void>();

        final result = await nostr
            .queryEventsDetailed(
              _filters(),
              id: _readId,
              timeout: _unansweredDeadline,
            )
            .timeout(
              _guard,
              onTimeout: () => fail('the read waited for the fan-out'),
            );
        relay.reqGate!.complete();

        expect(result.timedOut, isTrue);
        expect(
          result.noRelaysParticipated,
          isFalse,
          reason:
              'the fan-out had not finished, so whether a relay would take '
              'the REQ was still unknown',
        );
      });

      test('does not time out once every relay sends EOSE', () async {
        final answering = await addRelay('wss://answers.example');
        final empty = await addRelay('wss://empty.example');
        final events = await signedEvents(1);
        final pending = nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
        );
        await reqLanded(answering);
        await deliverEvents(answering, events);
        await answering.deliver(['EOSE', _readId]);
        await empty.deliver(['EOSE', _readId]);

        final result = await pending;

        expect(idsOf(result.events), equals(idsOf(events)));
        expect(result.timedOut, isFalse);
        expect(result.noRelaysParticipated, isFalse);
      });

      test('does not time out when the settle window releases a silent '
          'relay', () async {
        final answering = await addRelay('wss://answers.example');
        await addRelay('wss://never-answers.example');
        final events = await signedEvents(1);
        final pending = nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
        );
        await reqLanded(answering);
        await deliverEvents(answering, events);
        await answering.deliver(['EOSE', _readId]);

        final result = await pending;

        expect(idsOf(result.events), equals(idsOf(events)));
        expect(result.timedOut, isFalse);
        expect(result.noRelaysParticipated, isFalse);
      });

      test('keeps the events that arrived before a CLOSED, without a '
          'timeout', () async {
        final relay = await addRelay('wss://refuses.example');
        final events = await signedEvents(1);
        final pending = nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
        );
        await reqLanded(relay);
        await deliverEvents(relay, events);
        await relay.deliver([
          'CLOSED',
          _readId,
          'error: too many concurrent REQs',
        ]);

        final result = await pending;

        expect(idsOf(result.events), equals(idsOf(events)));
        expect(result.timedOut, isFalse);
        expect(result.noRelaysParticipated, isFalse);
      });

      test('keeps the events that arrived before the socket dropped, '
          'without a timeout', () async {
        final relay = await addRelay('wss://drops.example');
        final events = await signedEvents(1);
        final pending = nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
        );
        await reqLanded(relay);
        await deliverEvents(relay, events);
        relay.onError('socket closed', reconnect: true);

        final result = await pending;

        expect(idsOf(result.events), equals(idsOf(events)));
        expect(result.timedOut, isFalse);
        expect(result.noRelaysParticipated, isFalse);
      });

      test('reports a fan-out no relay took, without a timeout by '
          'default', () async {
        final relay = await addRelay('wss://send-fails.example');
        relay.sendSucceeds = false;

        final result = await nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
        );

        expect(result.noRelaysParticipated, isTrue);
        expect(result.timedOut, isFalse);
      });

      test('reports a fan-out no relay took as a timeout when every relay '
          'must settle', () async {
        final relay = await addRelay('wss://send-fails.example');
        relay.sendSucceeds = false;

        final result = await nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
          requireAllRelaysSettled: true,
        );

        expect(result.noRelaysParticipated, isTrue);
        expect(result.timedOut, isTrue);
      });

      test('times out when its deadline catches a fan-out no relay took '
          'while a relay still holds the REQ', () async {
        // The auth-gated path saves the query before writing it, so a write
        // that throws leaves the relay holding a REQ it never took: the pool
        // waits on it, and the deadline ends the read.
        final relay = await addRelay('wss://auth-gated.example')
          ..reqWriteThrows = true;
        relay.relayStatus.alwaysAuth = true;

        final result = await nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _unansweredDeadline,
        );

        expect(
          relay.sentMessages.where((message) => message.first == 'REQ'),
          hasLength(1),
          reason: 'the REQ write was attempted',
        );
        expect(result.noRelaysParticipated, isTrue);
        expect(
          result.timedOut,
          isTrue,
          reason: 'the read ran out its deadline, as it always reported',
        );
      });

      test('counts a relay behind NIP-42 that answers the REQ its write '
          'failed as taking part, without a timeout', () async {
        final relay = await addAuthGatedRelay();
        final pending = nostr.queryEventsDetailed(
          _filters(),
          id: _readId,
          timeout: _guard,
        );
        await reqWriteFailed(relay);
        await authenticateAndAnswer(relay, const []);

        final result = await pending;

        expect(result.events, isEmpty);
        expect(result.timedOut, isFalse);
        expect(
          result.noRelaysParticipated,
          isFalse,
          reason:
              'the relay answered the replayed REQ with EOSE alone: that is '
              'taking part, although the fan-out saw its write fail',
        );
      });
    });

    group('queryEvents', () {
      test('returns the events that arrived when the deadline fires', () async {
        final relay = await addRelay('wss://streams.example');
        final events = await signedEvents(2);
        final pending = nostr.queryEvents(
          _filters(),
          id: _readId,
          timeout: _deadlineAfterDelivery,
        );
        await reqLanded(relay);
        await deliverEvents(relay, events);

        expect(idsOf(await pending), unorderedEquals(idsOf(events)));
      });

      test('returns every event once every relay sends EOSE', () async {
        final relay = await addRelay('wss://answers.example');
        final events = await signedEvents(2);
        final pending = nostr.queryEvents(
          _filters(),
          id: _readId,
          timeout: _guard,
        );
        await reqLanded(relay);
        await deliverEvents(relay, events);
        await relay.deliver(['EOSE', _readId]);

        expect(idsOf(await pending), unorderedEquals(idsOf(events)));
      });
    });
  });
}
