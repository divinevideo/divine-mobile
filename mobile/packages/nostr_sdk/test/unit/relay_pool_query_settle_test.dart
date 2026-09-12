// ABOUTME: Regression tests for one-shot query completion accounting.
// ABOUTME: A relay that can no longer answer must not hold a query open.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Relay that records what it was sent and only answers when the test says so.
class _SilentRelay extends Relay {
  _SilentRelay(String url, {bool connectSucceeds = true})
    : _connectSucceeds = connectSucceeds,
      super(url, RelayStatus(url));

  final bool _connectSucceeds;

  String? capturedSubId;
  String? capturedAuthEventId;
  final List<List<dynamic>> sentMessages = [];

  /// When false, [send] reports failure the way a dead socket does.
  bool sendSucceeds = true;

  /// When set, a `REQ` write blocks until [releaseReq], which holds the pool's
  /// fan-out open while other relays answer.
  Completer<void>? reqGate;

  void releaseReq() {
    final gate = reqGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  /// `CLOSE` frames this relay was sent, by subscription id.
  List<String> get closedSubIds => [
    for (final message in sentMessages)
      if (message.isNotEmpty && message[0] == 'CLOSE' && message.length > 1)
        message[1] as String,
  ];

  @override
  Future<bool> doConnect() async {
    if (!_connectSucceeds) return false;
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
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      capturedSubId = message[1] as String;
      final gate = reqGate;
      if (gate != null) await gate.future;
    } else if (message.isNotEmpty &&
        message[0] == 'AUTH' &&
        message.length > 1 &&
        message[1] is Map) {
      capturedAuthEventId = (message[1] as Map)['id'] as String?;
    }
    return sendSucceeds;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) await result;
  }

  Future<String> awaitPendingQuery() async {
    for (var i = 0; i < 1000; i++) {
      final subId = capturedSubId;
      if (subId != null && checkQuery(subId)) return subId;
      await Future<void>.delayed(Duration.zero);
    }
    fail('RelayPool never registered a pending query for the REQ');
  }
}

/// A query timeout long enough that reaching it means the pool stalled rather
/// than that the test was slow.
const _timeout = Duration(seconds: 4);

Nostr _newNostr() => Nostr(
  LocalNostrSigner(
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
  ),
  [],
  (url) => RelayBase(url, RelayStatus(url)),
);

void main() {
  group('RelayPool one-shot query settling', () {
    test('an auth-gated relay with no handshake outstanding does not hold the '
        'query open', () async {
      final nostr = _newNostr();
      final relay = _SilentRelay('wss://auth-gated.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      // The relay challenged us at some earlier point in the session, so
      // alwaysAuth is latched on. Nothing ever completed NIP-42 — signing was
      // unavailable, or the challenge was never answered — so no AUTH event is
      // in flight and the gate will never open on its own.
      relay.relayStatus.alwaysAuth = true;

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await relay.awaitPendingQuery();
      await relay.deliver(['CLOSED', subId, 'auth-required: sign in']);

      final result = await pending;
      stopwatch.stop();

      expect(
        result.timedOut,
        isFalse,
        reason: 'nothing was going to release this query but the timeout',
      );
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'the caller must not pay the full query timeout',
      );
    });

    test(
      'a rejected AUTH releases queries parked for post-AUTH replay',
      () async {
        final nostr = _newNostr();
        final relay = _SilentRelay('wss://auth-rejects.example');
        expect(await nostr.relayPool.add(relay), isTrue);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        final subId = await relay.awaitPendingQuery();
        await relay.deliver(['AUTH', 'test-challenge']);
        await relay.deliver(['CLOSED', subId, 'auth-required: sign in']);

        // The handshake is outstanding here, so the query is legitimately parked
        // waiting for the replay (pinned by relay_pool_closed_frame_test).
        final authEventId = relay.capturedAuthEventId;
        expect(authEventId, isNotNull);

        // The relay refuses our AUTH: the replay is never going to happen.
        await relay.deliver([
          'OK',
          authEventId,
          false,
          'invalid: bad signature',
        ]);

        final result = await pending;
        stopwatch.stop();

        expect(result.timedOut, isFalse);
        expect(
          stopwatch.elapsed,
          lessThan(_timeout),
          reason: 'a refused AUTH must release the parked query immediately',
        );
      },
    );

    test('a relay that drops its socket does not hold the query open', () async {
      final nostr = _newNostr();
      final dropping = _SilentRelay('wss://drops.example');
      expect(await nostr.relayPool.add(dropping), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      await dropping.awaitPendingQuery();
      // The socket dies before any terminal frame arrives. The REQ that was on
      // it is gone; a reconnect replays it on a fresh socket, long after this
      // caller has given up.
      dropping.onError('socket closed', reconnect: true);

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'a dropped socket cannot deliver EOSE for its REQ',
      );
    });

    test('one relay that never answers cannot hold the caller past the settle '
        'window once another relay has', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final mute = _SilentRelay('wss://never-eoses.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(mute), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await mute.awaitPendingQuery();
      // `mute` stays connected and simply never sends a terminal frame — the
      // shape measured against relay.divine.video.
      await answering.deliver(['EOSE', subId]);

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'the settle window must bound the silent relay',
      );
      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(RelayPool.querySettleWindow),
        reason: 'the silent relay still gets its grace period first',
      );
    });

    test(
      'a relay CLOSED refusal arms the settle window for a silent peer',
      () async {
        final nostr = _newNostr();
        final refusing = _SilentRelay('wss://refuses-req.example');
        final mute = _SilentRelay('wss://never-eoses.example');
        expect(await nostr.relayPool.add(refusing), isTrue);
        expect(await nostr.relayPool.add(mute), isTrue);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        final subId = await refusing.awaitPendingQuery();
        await mute.awaitPendingQuery();
        // The refusal is terminal for this relay, but the peer still gets the
        // same grace period it would after a sibling EOSE.
        await refusing.deliver([
          'CLOSED',
          subId,
          'error: too many concurrent REQs',
        ]);

        final result = await pending;
        stopwatch.stop();

        expect(result.timedOut, isFalse);
        expect(
          stopwatch.elapsed,
          lessThan(_timeout),
          reason: 'the caller must not wait out the full query timeout',
        );
        expect(
          stopwatch.elapsed,
          greaterThanOrEqualTo(RelayPool.querySettleWindow),
          reason: 'the silent relay still gets its grace period first',
        );
      },
    );

    test('the settle window closes the REQ it abandons', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final mute = _SilentRelay('wss://never-eoses.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(mute), isTrue);

      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await mute.awaitPendingQuery();
      await answering.deliver(['EOSE', subId]);
      await pending;

      // The caller is gone, so the REQ it left on the silent relay has to go
      // with it. Left open it stays live for the life of the socket — against
      // the relay's concurrent-subscription cap, pinning the caller's event
      // box, and re-issued by every post-AUTH and zombie-reconnect replay.
      expect(
        mute.closedSubIds,
        contains(subId),
        reason: 'the abandoned REQ must be closed on the relay',
      );
      expect(
        mute.checkQuery(subId),
        isFalse,
        reason: 'and dropped from the pool-side query book',
      );
    });

    test('a terminal frame that lands during fan-out still arms the settle '
        'window', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final blocked = _SilentRelay('wss://slow-to-accept.example')
        ..reqGate = Completer<void>();
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(blocked), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      // `fast` answers while `blocked` has not finished accepting its REQ, so
      // the completion sweep driven by that EOSE is swallowed by the fan-out
      // guard. The window still has to arm off it once fan-out ends.
      final subId = await fast.awaitPendingQuery();
      await fast.deliver(['EOSE', subId]);
      blocked.releaseReq();

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(_timeout),
        reason: 'an EOSE during fan-out is still proof the fan-out is served',
      );
    });

    test('an auth-gated relay that has not been challenged yet still holds '
        'the query', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final gated = _SilentRelay('wss://gated.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);

      // `alwaysAuth` latches for the session, so a relay that has just
      // reconnected sits in this state for the round trip before its challenge
      // arrives. Writing it off there would drop every read-gated relay's
      // results on cold start.
      gated.relayStatus.alwaysAuth = true;

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', subId]);

      await pending;
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(RelayPool.querySettleWindow),
        reason: 'an unchallenged auth gate is not evidence the gate is shut',
      );
    });

    test('a reconnect gives a relay whose auth gate was shut a fresh '
        'handshake', () async {
      final nostr = _newNostr();
      final gated = _SilentRelay('wss://gated.example');
      expect(await nostr.relayPool.add(gated), isTrue);
      gated.relayStatus.alwaysAuth = true;

      // First connection: the relay refuses the REQ outright, so the gate is
      // recorded shut and the caller stops waiting on it.
      final first = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);
      final firstSubId = await gated.awaitPendingQuery();
      await gated.deliver(['CLOSED', firstSubId, 'auth-required: sign in']);
      expect((await first).timedOut, isFalse);

      // The socket cycles. Whatever the previous connection concluded about
      // NIP-42 does not carry over to the new one.
      gated.onError('socket closed', reconnect: true);
      expect(await gated.connect(), isTrue);

      final answering = _SilentRelay('wss://answers.example');
      expect(await nostr.relayPool.add(answering), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await answering.awaitPendingQuery();
      await gated.awaitPendingQuery();
      await answering.deliver(['EOSE', subId]);

      await pending;
      stopwatch.stop();

      expect(
        stopwatch.elapsed,
        greaterThanOrEqualTo(RelayPool.querySettleWindow),
        reason: 'the fresh connection has not refused anything yet',
      );
    });

    test('a relay still streaming its result set is not cut off by the settle '
        'window', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final streaming = _SilentRelay('wss://streams-slowly.example');
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(streaming), isTrue);
      final pubkey = await nostr.ensurePublicKey();

      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);

      final subId = await fast.awaitPendingQuery();
      await streaming.awaitPendingQuery();
      // `fast` has nothing to return and answers at once, arming the window.
      await fast.deliver(['EOSE', subId]);

      // `streaming` is healthy and part-way through a result set larger than
      // the window. Its events are the proof it has not gone silent, so the
      // window must not expire under it and truncate the caller's results.
      const streamed = 5;
      for (var i = 0; i < streamed; i++) {
        await Future<void>.delayed(RelayPool.querySettleWindow ~/ 2);
        final event = await nostr.nostrSigner.signEvent(
          Event(pubkey, EventKind.textNote, const [], 'streamed-$i'),
        );
        await streaming.deliver(['EVENT', subId, event!.toJson()]);
      }
      await streaming.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.timedOut, isFalse);
      expect(
        result.events,
        hasLength(streamed),
        reason:
            'every event the relay sent must reach the caller — a '
            'truncated result set reads as a complete one',
      );
    });

    test('events the subscription filter rejects still prove the relay has '
        'not gone silent', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final streaming = _SilentRelay('wss://streams-slowly.example');
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(streaming), isTrue);
      final pubkey = await nostr.ensurePublicKey();

      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [EventKind.textNote],
        },
      ], timeout: _timeout);

      final subId = await fast.awaitPendingQuery();
      await streaming.awaitPendingQuery();
      await fast.deliver(['EOSE', subId]);

      // The relay leads with events this subscription did not ask for. They
      // are dropped at the admission gate, but arriving at all is what proves
      // the socket is still working — the settle window bounds silence, and a
      // relay sending the wrong events is not silent. Before #6585's gate the
      // window expired under this and the caller was handed a truncated set
      // with `timedOut: false`, which reads exactly like a complete one.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(RelayPool.querySettleWindow ~/ 2);
        final unwanted = await nostr.nostrSigner.signEvent(
          Event(pubkey, EventKind.reaction, const [], '+'),
        );
        await streaming.deliver(['EVENT', subId, unwanted!.toJson()]);
      }

      final wanted = await nostr.nostrSigner.signEvent(
        Event(pubkey, EventKind.textNote, const [], 'the tail'),
      );
      await streaming.deliver(['EVENT', subId, wanted!.toJson()]);
      await streaming.deliver(['EOSE', subId]);

      final result = await pending;
      expect(result.timedOut, isFalse);
      expect(
        result.events.map((e) => e.content),
        ['the tail'],
        reason:
            'the matching tail must survive: rejected events are dropped '
            'from the result set, not treated as the relay falling silent',
      );
    });

    test(
      'an outstanding NIP-42 handshake survives the settle window',
      () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        final gated = _SilentRelay('wss://gated.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(gated), isTrue);

        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        final subId = await answering.awaitPendingQuery();
        await gated.awaitPendingQuery();

        // The gate challenges us and parks the query for the post-AUTH replay.
        // Signing is a network call under a NIP-46 remote signer, so the `OK`
        // can easily land after the settle window a sibling arms.
        await gated.deliver(['AUTH', 'test-challenge']);
        await gated.deliver(['CLOSED', subId, 'auth-required: sign in']);
        expect(gated.capturedAuthEventId, isNotNull);

        await answering.deliver(['EOSE', subId]);
        await Future<void>.delayed(RelayPool.querySettleWindow * 1.5);

        // Closing the REQ here would leave the replay loop in the AUTH `OK`
        // handler nothing to re-issue, so a read-gated relay would contribute
        // nothing to any query a sibling answers first.
        expect(
          gated.getQueries(),
          isNotEmpty,
          reason: 'a relay mid-handshake is being served, not silent',
        );
        expect(gated.closedSubIds, isNot(contains(subId)));

        await gated.deliver(['OK', gated.capturedAuthEventId, true, '']);
        expect(
          gated.sentMessages.where((m) => m.isNotEmpty && m[0] == 'REQ'),
          hasLength(2),
          reason: 'the post-AUTH replay still reaches the original caller',
        );

        await pending;
      },
    );

    test('a handshake that is never answered still gets bounded', () async {
      final nostr = _newNostr();
      final answering = _SilentRelay('wss://answers.example');
      final gated = _SilentRelay('wss://swallows-auth.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(gated), isTrue);

      final stopwatch = Stopwatch()..start();
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: RelayPool.authHandshakeWindow * 3);

      final subId = await answering.awaitPendingQuery();
      await gated.awaitPendingQuery();
      // Our AUTH event goes out and the relay never answers it. Nothing about
      // that relay distinguishes it from one still working, so only the
      // handshake window can end the wait.
      await gated.deliver(['AUTH', 'test-challenge']);
      await gated.deliver(['CLOSED', subId, 'auth-required: sign in']);
      await answering.deliver(['EOSE', subId]);

      final result = await pending;
      stopwatch.stop();

      expect(result.timedOut, isFalse);
      expect(
        stopwatch.elapsed,
        lessThan(RelayPool.authHandshakeWindow * 3),
        reason: 'a swallowed AUTH must not cost the caller its whole budget',
      );
    });

    test(
      "a stale handshake stops suppressing the relay's own refusal",
      () async {
        final nostr = _newNostr();
        final gated = _SilentRelay('wss://swallows-auth.example');
        expect(await nostr.relayPool.add(gated), isTrue);

        // The relay challenges us, takes our AUTH event, and never answers it.
        final first = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: const Duration(milliseconds: 300));
        final firstSubId = await gated.awaitPendingQuery();
        await gated.deliver(['AUTH', 'test-challenge']);
        await gated.deliver(['CLOSED', firstSubId, 'auth-required: sign in']);
        expect(gated.capturedAuthEventId, isNotNull);
        await first;

        // No `OK` lands and the socket never cycles, so the marker is still
        // there while the handshake it describes is long dead.
        await Future<void>.delayed(RelayPool.authHandshakeWindow * 1.2);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);
        final subId = await gated.awaitPendingQuery();
        // The relay names the gate again. A dead handshake is not a reason to
        // discard that evidence — nothing is going to run the replay it parks
        // the query for, so every later query would pay its full budget.
        await gated.deliver(['CLOSED', subId, 'auth-required: sign in']);

        final result = await pending;
        stopwatch.stop();

        expect(result.timedOut, isFalse);
        expect(
          stopwatch.elapsed,
          lessThan(RelayPool.querySettleWindow),
          reason: 'the refusal releases the query outright, not on a timer',
        );
      },
    );

    test('a healthy relay still holds the query until its EOSE', () async {
      final nostr = _newNostr();
      final fast = _SilentRelay('wss://fast.example');
      final slow = _SilentRelay('wss://slow.example');
      expect(await nostr.relayPool.add(fast), isTrue);
      expect(await nostr.relayPool.add(slow), isTrue);

      var completedEarly = false;
      final pending = nostr.queryEventsDetailed([
        {
          'kinds': [1],
        },
      ], timeout: _timeout);
      unawaited(pending.whenComplete(() => completedEarly = true));

      final fastSubId = await fast.awaitPendingQuery();
      final slowSubId = await slow.awaitPendingQuery();

      await fast.deliver(['EOSE', fastSubId]);
      await Future<void>.delayed(Duration.zero);
      expect(
        completedEarly,
        isFalse,
        reason: 'the second, still-connected relay owes a terminal frame',
      );

      await slow.deliver(['EOSE', slowSubId]);
      final result = await pending;
      expect(result.timedOut, isFalse);
    });

    // A relay-participation count is the only thing that separates "every
    // relay says there is nothing" from "nobody was asked". A connected-relay
    // snapshot cannot: a relay counts as connected while being write-only, or
    // while its socket is dead but not yet observed.
    group('noRelaysParticipated', () {
      test('reports a fan-out no relay took', () async {
        final nostr = _newNostr();
        final unreachable = _SilentRelay('wss://send-fails.example')
          ..sendSucceeds = false;
        expect(await nostr.relayPool.add(unreachable), isTrue);

        final result = await nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        expect(result.noRelaysParticipated, isTrue);
      });

      test(
        'reports a connected write-only relay as no participation',
        () async {
          final nostr = _newNostr();
          final writeOnly = _SilentRelay('wss://write-only.example');
          expect(await nostr.relayPool.add(writeOnly), isTrue);
          writeOnly.relayStatus.readAccess = false;

          final result = await nostr.queryEventsDetailed([
            {
              'kinds': [1],
            },
          ], timeout: _timeout);

          expect(
            writeOnly.relayStatus.connected,
            equals(ClientConnected.connected),
            reason:
                'the point of this case is that the relay looks healthy to '
                'everything except the REQ',
          );
          expect(result.noRelaysParticipated, isTrue);
        },
      );

      test('reports participation once a relay answers', () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        expect(await nostr.relayPool.add(answering), isTrue);

        final pending = nostr.queryEventsDetailed([
          {
            'kinds': [1],
          },
        ], timeout: _timeout);

        final subId = await answering.awaitPendingQuery();
        await answering.deliver(['EOSE', subId]);

        final result = await pending;

        expect(result.noRelaysParticipated, isFalse);
      });

      test(
        'reports participation when only some relays took the REQ',
        () async {
          final nostr = _newNostr();
          final answering = _SilentRelay('wss://answers.example');
          final unreachable = _SilentRelay('wss://send-fails.example')
            ..sendSucceeds = false;
          expect(await nostr.relayPool.add(answering), isTrue);
          expect(await nostr.relayPool.add(unreachable), isTrue);

          final pending = nostr.queryEventsDetailed([
            {
              'kinds': [1],
            },
          ], timeout: _timeout);

          final subId = await answering.awaitPendingQuery();
          await answering.deliver(['EOSE', subId]);

          final result = await pending;

          expect(
            result.noRelaysParticipated,
            isFalse,
            reason:
                'one relay answered, so the box is what that relay holds — not '
                'an answer nobody gave',
          );
        },
      );
    });

    group('requireAllRelaysSettled', () {
      // Long enough that the settle window would have completed the query
      // well before it, so a timeout here can only mean the window was
      // genuinely not armed.
      const timeout = Duration(seconds: 2);

      test(
        'reports a mute relay as a timeout instead of an empty answer',
        () async {
          final nostr = _newNostr();
          final answering = _SilentRelay('wss://answers.example');
          final mute = _SilentRelay('wss://never-eoses.example');
          expect(await nostr.relayPool.add(answering), isTrue);
          expect(await nostr.relayPool.add(mute), isTrue);

          final pending = nostr.queryEventsDetailed(
            [
              {
                'kinds': [10003],
              },
            ],
            timeout: timeout,
            requireAllRelaysSettled: true,
          );

          final subId = await answering.awaitPendingQuery();
          await mute.awaitPendingQuery();
          // The one relay that answers has nothing; the relay that might hold
          // the list stays connected and never sends a terminal frame.
          await answering.deliver(['EOSE', subId]);

          final result = await pending;

          expect(result.events, isEmpty);
          expect(
            result.timedOut,
            isTrue,
            reason:
                'default settling would have reported this same empty box as a '
                'complete answer, which a caller about to republish a '
                'replaceable event would act on and truncate the list',
          );
          expect(
            result.noRelaysParticipated,
            isFalse,
            reason:
                'both relays took the REQ — one is just slow. Conflating this '
                'with "nobody was asked" tells the user their relays are '
                'unreachable when they are reachable and mid-answer',
          );
        },
      );

      test(
        'completes a query no relay took at once, still inconclusive',
        () async {
          final nostr = _newNostr();
          final unreachable = _SilentRelay('wss://send-fails.example')
            ..sendSucceeds = false;
          expect(await nostr.relayPool.add(unreachable), isTrue);

          final stopwatch = Stopwatch()..start();
          final result = await nostr.queryEventsDetailed(
            [
              {
                'kinds': [10003],
              },
            ],
            timeout: _timeout,
            requireAllRelaysSettled: true,
          );
          stopwatch.stop();

          expect(result.events, isEmpty);
          expect(
            result.timedOut,
            isTrue,
            reason:
                'an empty box no relay contributed to reads exactly like '
                '"every relay says there is nothing", which is what lets a '
                'caller about to republish truncate a replaceable list',
          );
          expect(
            result.noRelaysParticipated,
            isTrue,
            reason: 'and this is what tells it apart from a relay gone quiet',
          );
          expect(
            stopwatch.elapsed,
            // Well under the deadline rather than merely inside it: holding
            // the query runs it to ~4.002s, which `lessThan(_timeout)` would
            // reject by a margin thin enough to depend on the machine.
            lessThan(_timeout ~/ 2),
            reason:
                'no relay saved the REQ, so nothing it could still draw back '
                'has a subscription to land in — waiting out the deadline '
                'only delays the error the caller is going to show',
          );
        },
      );

      // Short: this query is never going to be answered, so the test pays it
      // in full. Nothing races it, so it cannot flake short.
      const unacceptedTimeout = Duration(milliseconds: 400);

      test(
        'reports a relay CLOSED refusal as a timeout, not an empty answer',
        () async {
          final nostr = _newNostr();
          final refusing = _SilentRelay('wss://refuses-req.example');
          expect(await nostr.relayPool.add(refusing), isTrue);

          var completed = false;
          final pending = nostr.queryEventsDetailed(
            [
              {
                'kinds': [10003],
              },
            ],
            timeout: unacceptedTimeout,
            requireAllRelaysSettled: true,
          );

          final subId = await refusing.awaitPendingQuery();
          await refusing.deliver([
            'CLOSED',
            subId,
            'error: too many concurrent REQs',
          ]);

          pending.then((_) => completed = true);
          await pumpEventQueue();
          expect(
            completed,
            isTrue,
            reason:
                'CLOSED is terminal for this relay copy, so waiting out the '
                'deadline cannot make the incomplete answer more complete',
          );
          final result = await pending;

          expect(result.events, isEmpty);
          expect(
            result.timedOut,
            isTrue,
            reason:
                'a relay refusal is not a data-bearing answer, so a '
                'replaceable-event caller must treat it as inconclusive',
          );
          expect(
            result.noRelaysParticipated,
            isFalse,
            reason: 'the relay took the REQ before refusing it',
          );
        },
      );

      test('reports a peer CLOSED refusal after EOSE as a timeout', () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        final refusing = _SilentRelay('wss://refuses-req.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(refusing), isTrue);

        var completed = false;
        final pending = nostr.queryEventsDetailed(
          [
            {
              'kinds': [10003],
            },
          ],
          timeout: timeout,
          requireAllRelaysSettled: true,
        );

        final subId = await answering.awaitPendingQuery();
        await refusing.awaitPendingQuery();
        await answering.deliver(['EOSE', subId]);
        await refusing.deliver([
          'CLOSED',
          subId,
          'error: too many concurrent REQs',
        ]);

        pending.then((_) => completed = true);
        await pumpEventQueue();
        expect(
          completed,
          isTrue,
          reason:
              'the healthy relay answered and the refusing relay terminated '
              'its copy, so no participant can still change this result',
        );
        final result = await pending;

        expect(result.events, isEmpty);
        expect(
          result.timedOut,
          isTrue,
          reason:
              'one relay answered empty, but the peer refusal is still '
              'inconclusive for a caller about to replace what it read',
        );
        expect(
          result.noRelaysParticipated,
          isFalse,
          reason: 'both relays took the REQ before settling or refusing it',
        );
      });

      // Participation is acceptance, not a successful write. `relayDoQuery`
      // saves the query before sending on the auth-gated branch, so the REQ is
      // replayed after NIP-42 even though the frame never landed — counting
      // that relay out would waive the hold on one still about to answer.
      test(
        'an auth-gated relay whose send failed still holds the query open',
        () async {
          final nostr = _newNostr();
          final authGated = _SilentRelay('wss://auth-gated.example')
            ..sendSucceeds = false;
          expect(await nostr.relayPool.add(authGated), isTrue);
          authGated.relayStatus.alwaysAuth = true;

          final stopwatch = Stopwatch()..start();
          final result = await nostr.queryEventsDetailed(
            [
              {
                'kinds': [10003],
              },
            ],
            timeout: unacceptedTimeout,
            requireAllRelaysSettled: true,
          );
          stopwatch.stop();

          expect(result.timedOut, isTrue);
          expect(
            result.noRelaysParticipated,
            isFalse,
            reason:
                'the query is saved for post-AUTH replay, so this relay can '
                'still serve it — reporting nobody was asked would tell the '
                'user their relays are unreachable when one is mid-handshake',
          );
          expect(
            stopwatch.elapsed,
            // Half the deadline, not the whole of it: the timeout fires off a
            // Timer while this measures a Stopwatch, and the two disagree by
            // microseconds — CI saw 399.958ms against a 400ms bound. Waived
            // participation completes in single-digit ms, so nothing lands
            // between the two readings and the margin costs no discrimination.
            greaterThan(unacceptedTimeout ~/ 2),
            reason:
                'and a participant that has not answered holds the caller to '
                'its own deadline, exactly as a relay gone quiet does',
          );
        },
      );

      // The fan-out can outlive its caller: `relayDoQuery` waits up to
      // `perRelaySendTimeout` on a half-open socket, which is the default
      // query deadline over again. Whatever it records on the way out must
      // not land on an id the caller has already abandoned.
      test(
        'a fan-out that resolves after its caller gave up records nothing',
        () async {
          const reusedId = 'reused-one-shot-subscription-id';
          final nostr = _newNostr();
          final relay = _SilentRelay('wss://send-fails.example')
            ..sendSucceeds = false
            ..reqGate = Completer<void>();
          expect(await nostr.relayPool.add(relay), isTrue);

          final abandoned = nostr.relayPool.query(
            [
              {
                'kinds': [10003],
              },
            ],
            (_) {},
            id: reusedId,
            onComplete: () {},
            requireAllRelaysSettled: true,
          );

          // Park inside the REQ write, then give the query up the way
          // Nostr.queryEventsDetailed does when its deadline beats the
          // fan-out.
          for (var i = 0; i < 1000 && relay.capturedSubId == null; i++) {
            await Future<void>.delayed(Duration.zero);
          }
          expect(relay.capturedSubId, equals(reusedId));
          nostr.unsubscribe(reusedId);
          relay.releaseReq();
          expect((await abandoned).sentTo, isEmpty);

          // A later query on that id must still get the full-settlement hold.
          // A stale "no relay took it" would skip it and hand the empty box
          // back as authoritative.
          relay
            ..sendSucceeds = true
            ..reqGate = null;
          final pending = nostr.queryEventsDetailed(
            [
              {
                'kinds': [10003],
              },
            ],
            id: reusedId,
            timeout: unacceptedTimeout,
            requireAllRelaysSettled: true,
          );

          final subId = await relay.awaitPendingQuery();
          await relay.deliver([
            'CLOSED',
            subId,
            'error: too many concurrent REQs',
          ]);

          final result = await pending;

          expect(
            result.timedOut,
            isTrue,
            reason:
                'the refusal is still inconclusive; the abandoned fan-out '
                'must not have left anything behind that waives the hold',
          );
        },
      );

      test(
        'a query no relay accepted still completes at once without the flag',
        () async {
          final nostr = _newNostr();
          final unreachable = _SilentRelay('wss://send-fails.example')
            ..sendSucceeds = false;
          expect(await nostr.relayPool.add(unreachable), isTrue);

          final stopwatch = Stopwatch()..start();
          final result = await nostr.queryEventsDetailed([
            {
              'kinds': [1],
            },
          ], timeout: timeout);
          stopwatch.stop();

          expect(result.timedOut, isFalse);
          expect(
            stopwatch.elapsed,
            lessThan(timeout),
            reason:
                'a display read is content to be told what the reachable '
                'relays hold; only a caller about to replace what it read '
                'pays the timeout for the difference',
          );
        },
      );

      test('still completes promptly once every relay answers', () async {
        final nostr = _newNostr();
        final first = _SilentRelay('wss://first.example');
        final second = _SilentRelay('wss://second.example');
        expect(await nostr.relayPool.add(first), isTrue);
        expect(await nostr.relayPool.add(second), isTrue);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed(
          [
            {
              'kinds': [10003],
            },
          ],
          timeout: timeout,
          requireAllRelaysSettled: true,
        );

        final firstSubId = await first.awaitPendingQuery();
        final secondSubId = await second.awaitPendingQuery();
        await first.deliver(['EOSE', firstSubId]);
        await second.deliver(['EOSE', secondSubId]);

        final result = await pending;
        stopwatch.stop();

        expect(result.timedOut, isFalse);
        expect(
          stopwatch.elapsed,
          lessThan(timeout),
          reason: 'full settlement is reached, so nothing has to be waited out',
        );
      });

      // A relay that TOOK the REQ and then went dark records none of the three
      // facts the settlement guard consults, so the peers' answers alone used
      // to complete the query and report it as conclusive. For a caller about
      // to republish a replaceable event, that is an empty box read as "every
      // relay says there is nothing".
      test('reports a relay that dropped its socket as a timeout, not an empty '
          'answer', () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        final dropping = _SilentRelay('wss://drops.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(dropping), isTrue);

        final pending = nostr.queryEventsDetailed(
          [
            {
              'kinds': [10003],
            },
          ],
          timeout: timeout,
          requireAllRelaysSettled: true,
        );

        final subId = await answering.awaitPendingQuery();
        await dropping.awaitPendingQuery();
        dropping.onError('socket closed', reconnect: true);
        await answering.deliver(['EOSE', subId]);

        final result = await pending;

        expect(result.events, isEmpty);
        expect(
          result.timedOut,
          isTrue,
          reason:
              'the relay that went dark may be the only one holding the '
              'list, and it never got to say so',
        );
        expect(
          result.noRelaysParticipated,
          isFalse,
          reason: 'both relays took the REQ — one of them then died',
        );
      });

      // The same hole reached through the other entry point: the drop arrives
      // after the peer has already answered, so the release runs through the
      // path that records nothing at all.
      test('a socket that drops after its peer answered still holds the query '
          'open', () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        final dropping = _SilentRelay('wss://drops.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(dropping), isTrue);

        final pending = nostr.queryEventsDetailed(
          [
            {
              'kinds': [10003],
            },
          ],
          timeout: timeout,
          requireAllRelaysSettled: true,
        );

        final subId = await answering.awaitPendingQuery();
        await dropping.awaitPendingQuery();
        await answering.deliver(['EOSE', subId]);
        dropping.onError('socket closed', reconnect: true);

        final result = await pending;

        expect(result.timedOut, isTrue);
        expect(result.noRelaysParticipated, isFalse);
      });

      // Not a driver for the fix — a guard against over-applying it. A relay
      // that comes back and answers inside the caller's budget has settled,
      // and reporting that as inconclusive would roll back writes that
      // succeeded. This is what a recorded flag would get wrong.
      test('a relay that reconnects and answers still settles the query '
          'conclusively', () async {
        final nostr = _newNostr();
        final answering = _SilentRelay('wss://answers.example');
        final flapping = _SilentRelay('wss://flaps.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(flapping), isTrue);

        final stopwatch = Stopwatch()..start();
        final pending = nostr.queryEventsDetailed(
          [
            {
              'kinds': [10003],
            },
          ],
          timeout: timeout,
          requireAllRelaysSettled: true,
        );

        final subId = await answering.awaitPendingQuery();
        await flapping.awaitPendingQuery();
        flapping.onError('socket closed', reconnect: true);
        await answering.deliver(['EOSE', subId]);
        expect(await flapping.connect(), isTrue);
        await flapping.deliver(['EOSE', subId]);

        final result = await pending;
        stopwatch.stop();

        expect(
          result.timedOut,
          isFalse,
          reason:
              'the reconnect re-issued the REQ under the same id and the '
              'relay answered it, so full settlement was reached',
        );
        expect(
          stopwatch.elapsed,
          lessThan(timeout),
          reason: 'a settled query must not be held to the deadline',
        );
      });
    });
  });
}
