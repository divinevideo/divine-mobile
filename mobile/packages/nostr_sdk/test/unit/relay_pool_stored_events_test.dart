// ABOUTME: Tests the stored-events phase of a live subscription: when every
// ABOUTME: connected relay has finished sending stored events (#10191).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

const _signerKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

/// A relay whose connection the test controls and whose frames the test
/// delivers by hand.
class _Relay extends Relay {
  _Relay(String url, {this.reachable = true, this.connectGate})
    : super(url, RelayStatus(url));

  bool reachable;

  /// When set, the connection stays mid-handshake until this completes.
  final Completer<void>? connectGate;

  /// The id of the last AUTH event the pool sent.
  String? authEventId;

  bool _socketConnecting = false;

  @override
  bool get isSocketConnecting => _socketConnecting;

  @override
  Future<bool> doConnect() async {
    final gate = connectGate;
    if (gate != null) {
      // Like RelayBase, the status reports the handshake a microtask after
      // the socket starts it.
      _socketConnecting = true;
      scheduleMicrotask(() {
        if (_socketConnecting) {
          relayStatus.connected = ClientConnected.connecting;
        }
      });
      await gate.future;
      _socketConnecting = false;
    }
    relayStatus.connected = reachable
        ? ClientConnected.connected
        : ClientConnected.disconnect;
    return reachable;
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
    if (message.length > 1 && message[0] == 'AUTH' && message[1] is Map) {
      authEventId = (message[1] as Map)['id'] as String?;
    }
    return reachable;
  }

  /// The socket dropped, as the connection manager reports it.
  void drop() {
    relayStatus.connected = ClientConnected.disconnect;
    relayStatusCallback?.call();
  }

  /// A new socket came up and the saved REQs were written to it again.
  Future<void> reconnect() async {
    relayStatus.connected = ClientConnected.connected;
    relayStatusCallback?.call();
    await onConnected(source: 'test-reconnect');
  }

  Future<void> deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }
}

/// Holds every signature check until the test releases it.
class _HeldVerifyWorker implements EventVerifyWorker {
  final Completer<void> release = Completer<void>();

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async {
    await release.future;
    return true;
  }

  @override
  void close() {}
}

Map<String, dynamic> _event(int createdAt) {
  final event = Event(
    getPublicKey(_signerKey),
    1059,
    [],
    'stored $createdAt',
    createdAt: createdAt,
  )..sign(_signerKey);
  return event.toJson();
}

void main() {
  group('RelayPool stored-events phase', () {
    Relay tempRelay(String url) => RelayBase(url, RelayStatus(url));

    late Nostr nostr;
    late List<String> delivered;
    late List<int> ends;
    late int starts;

    setUp(() {
      nostr = Nostr(LocalNostrSigner(_signerKey), [], tempRelay);
      delivered = [];
      ends = [];
      starts = 0;
    });

    String subscribe() => nostr.subscribe(
      [
        {
          'kinds': [1059],
        },
      ],
      (Event event) => delivered.add(event.content),
      onStoredEventsStart: () => starts++,
      onStoredEventsEnd: ends.add,
    );

    test('ends once every connected relay has answered, ignoring a relay '
        'that never connected', () async {
      final live = _Relay('wss://live.example');
      final dead = _Relay('wss://dead.example', reachable: false);
      expect(await nostr.relayPool.add(live), isTrue);
      expect(await nostr.relayPool.add(dead), isFalse);
      final subId = subscribe();
      await pumpEventQueue();
      expect(dead.hasSubscriptionById(subId), isTrue);

      await live.deliver(['EVENT', subId, _event(1700000002)]);
      await live.deliver(['EVENT', subId, _event(1700000001)]);
      await live.deliver(['EOSE', subId]);

      expect(ends, [2]);
      expect(delivered, ['stored 1700000002', 'stored 1700000001']);
    });

    test('a connected relay that has not answered keeps it open', () async {
      final first = _Relay('wss://first.example');
      final second = _Relay('wss://second.example');
      await nostr.relayPool.add(first);
      await nostr.relayPool.add(second);
      final subId = subscribe();
      await pumpEventQueue();

      await first.deliver(['EOSE', subId]);
      expect(ends, isEmpty);

      await second.deliver(['EOSE', subId]);
      expect(ends, [0]);
    });

    test('a relay that streamed and dropped before answering keeps it open '
        'until it reconnects and answers', () async {
      final dropped = _Relay('wss://dropped.example');
      final steady = _Relay('wss://steady.example');
      await nostr.relayPool.add(dropped);
      await nostr.relayPool.add(steady);
      final subId = subscribe();
      await pumpEventQueue();

      await dropped.deliver(['EVENT', subId, _event(1700000009)]);
      dropped.drop();
      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty, reason: 'its older stored events never arrived');

      await dropped.reconnect();
      await dropped.deliver(['EVENT', subId, _event(1700000009)]);
      await dropped.deliver(['EVENT', subId, _event(1700000005)]);
      await dropped.deliver(['EOSE', subId]);
      expect(ends, [3]);
    });

    test('a relay that dropped without sending anything does not keep it '
        'open', () async {
      final silent = _Relay('wss://silent.example');
      final steady = _Relay('wss://steady.example');
      await nostr.relayPool.add(silent);
      await nostr.relayPool.add(steady);
      final subId = subscribe();
      await pumpEventQueue();

      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty);

      silent.drop();
      expect(ends, [0]);
    });

    test('a replay after a reconnect reopens it and ends it again', () async {
      final relay = _Relay('wss://relay.example');
      await nostr.relayPool.add(relay);
      final subId = subscribe();
      await pumpEventQueue();
      await relay.deliver(['EVENT', subId, _event(1700000003)]);
      await relay.deliver(['EOSE', subId]);
      expect(ends, [1]);
      expect(starts, 0);

      relay.drop();
      await relay.reconnect();
      await relay.deliver(['EVENT', subId, _event(1700000003)]);
      expect(starts, 1);
      await relay.deliver(['EVENT', subId, _event(1700000001)]);
      await relay.deliver(['EOSE', subId]);

      expect(ends, [1, 3]);
    });

    test('a replay on a replacement relay object reopens it', () async {
      // RelayManager reconnects by building a new relay object for the same
      // URL, removing the old one and adding the new one; app resume does
      // this for every relay.
      final first = _Relay('wss://relay.example');
      await nostr.relayPool.add(first);
      final subId = subscribe();
      await pumpEventQueue();
      await first.deliver(['EOSE', subId]);
      expect(ends, [0]);

      final replacement = _Relay('wss://relay.example');
      nostr.relayPool.remove('wss://relay.example');
      await nostr.relayPool.add(replacement, autoSubscribe: true);
      await pumpEventQueue();
      expect(replacement.hasSubscriptionById(subId), isTrue);
      await replacement.deliver(['EVENT', subId, _event(1700000007)]);

      expect(starts, 1);
      await replacement.deliver(['EOSE', subId]);
      expect(ends, [0, 1]);
    });

    test('a relay replaced while it was sending stored events keeps it open '
        'until the replacement answers', () async {
      final first = _Relay('wss://relay.example');
      final steady = _Relay('wss://steady.example');
      await nostr.relayPool.add(first);
      await nostr.relayPool.add(steady);
      final subId = subscribe();
      await pumpEventQueue();
      await first.deliver(['EVENT', subId, _event(1700000008)]);
      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty, reason: 'its older stored events never arrived');

      first.drop();
      // RelayManager reconnects by removing the URL and re-adding a new
      // relay object for it in the same synchronous run.
      final replacement = _Relay('wss://relay.example');
      nostr.relayPool.remove('wss://relay.example');
      final added = nostr.relayPool.add(replacement, autoSubscribe: true);
      await pumpEventQueue();
      expect(ends, isEmpty, reason: 'the replacement has not answered');

      await added;
      await pumpEventQueue();
      await replacement.deliver(['EVENT', subId, _event(1700000008)]);
      await replacement.deliver(['EVENT', subId, _event(1700000002)]);
      await replacement.deliver(['EOSE', subId]);
      expect(ends, [3]);
    });

    test('an event from a relay that was never sent the request does not '
        'reopen it', () async {
      final relay = _Relay('wss://relay.example');
      final stranger = _Relay('wss://stranger.example');
      await nostr.relayPool.add(relay);
      final subId = subscribe();
      await pumpEventQueue();
      await relay.deliver(['EOSE', subId]);
      // Joins the pool after the subscription, so it is never sent the REQ.
      await nostr.relayPool.add(stranger);

      await stranger.deliver(['EVENT', subId, _event(1700000006)]);

      expect(starts, 0);
    });

    test('a malformed event frame does not reopen it', () async {
      final relay = _Relay('wss://relay.example');
      await nostr.relayPool.add(relay);
      final subId = subscribe();
      await pumpEventQueue();
      await relay.deliver(['EOSE', subId]);
      relay.drop();
      await relay.reconnect();

      await relay.deliver(['EVENT', subId]);
      await relay.deliver([
        'EVENT',
        subId,
        {'kind': 1059},
      ]);

      expect(starts, 0);
    });

    test('a relay that is still connecting keeps it open', () async {
      final steady = _Relay('wss://steady.example');
      final slowGate = Completer<void>();
      final slow = _Relay('wss://slow.example', connectGate: slowGate);
      await nostr.relayPool.add(steady);
      unawaited(nostr.relayPool.add(slow));
      await pumpEventQueue();
      final subId = subscribe();
      await pumpEventQueue();

      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty);

      slowGate.complete();
      await pumpEventQueue();
      await slow.deliver(['EOSE', subId]);
      expect(ends, [0]);
    });

    test('an inbox relay the subscription dials keeps it open while it '
        'connects', () async {
      final inboxGate = Completer<void>();
      // The pool keys temp relays by their normalized address.
      final inbox = _Relay('wss://inbox.example/', connectGate: inboxGate);
      final withInbox = Nostr(
        LocalNostrSigner(_signerKey),
        [],
        (url) => url == inbox.url ? inbox : tempRelay(url),
      );
      final steady = _Relay('wss://steady.example');
      await withInbox.relayPool.add(steady);
      final subId = withInbox.subscribe(
        [
          {
            'kinds': [1059],
          },
        ],
        (Event event) {},
        tempRelays: [inbox.url],
        onStoredEventsEnd: ends.add,
      );
      await pumpEventQueue();

      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty);

      inboxGate.complete();
      await pumpEventQueue();
      await inbox.deliver(['EVENT', subId, _event(1700000030)]);
      await inbox.deliver(['EOSE', subId]);
      expect(ends, [1]);
    });

    test('relays rebuilt on resume keep it open until every replacement '
        'has answered', () async {
      final a = _Relay('wss://a.example');
      final b = _Relay('wss://b.example');
      await nostr.relayPool.add(a);
      await nostr.relayPool.add(b);
      final subId = subscribe();
      await pumpEventQueue();
      await a.deliver(['EOSE', subId]);
      await b.deliver(['EOSE', subId]);
      expect(ends, [0]);

      // RelayManager.forceReconnectAll: a new object per URL, each dialled.
      final aGate = Completer<void>();
      final bGate = Completer<void>();
      final a2 = _Relay('wss://a.example', connectGate: aGate);
      final b2 = _Relay('wss://b.example', connectGate: bGate);
      for (final relay in [a2, b2]) {
        nostr.relayPool.remove(relay.url);
        unawaited(nostr.relayPool.add(relay, autoSubscribe: true));
      }
      aGate.complete();
      await pumpEventQueue();
      await a2.deliver(['EVENT', subId, _event(1700000100)]);
      expect(starts, 1);
      await a2.deliver(['EOSE', subId]);
      expect(ends, [0], reason: 'b is still reconnecting');

      bGate.complete();
      await pumpEventQueue();
      await b2.deliver(['EVENT', subId, _event(1699800000)]);
      await b2.deliver(['EOSE', subId]);
      expect(ends, [0, 2]);
    });

    test('a relay whose AUTH was refused stops holding it open', () async {
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      await steady.deliver(['EOSE', subId]);
      // The relay challenges, then refuses the REQ until the handshake
      // completes; the REQ is kept for the replay after AUTH.
      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      expect(gated.authEventId, isNotNull);
      await gated.deliver(['CLOSED', subId, 'auth-required: sign in first']);
      expect(ends, isEmpty, reason: 'the handshake is still outstanding');

      await gated.deliver(['OK', gated.authEventId, false, 'restricted: no']);

      expect(ends, [0]);
    });

    test('a CLOSED after part of the batch keeps it open', () async {
      final partial = _Relay('wss://partial.example');
      final steady = _Relay('wss://steady.example');
      await nostr.relayPool.add(partial);
      await nostr.relayPool.add(steady);
      final subId = subscribe();
      await pumpEventQueue();

      await partial.deliver(['EVENT', subId, _event(1700000020)]);
      await partial.deliver(['CLOSED', subId, 'rate-limited: slow down']);
      await steady.deliver(['EOSE', subId]);

      expect(ends, isEmpty, reason: 'the rest of its batch never arrived');
    });

    test(
      'a relay removed while sending its batch stops holding it open',
      () async {
        final partial = _Relay('wss://partial.example');
        final steady = _Relay('wss://steady.example');
        await nostr.relayPool.add(partial);
        await nostr.relayPool.add(steady);
        final subId = subscribe();
        await pumpEventQueue();

        await partial.deliver(['EVENT', subId, _event(1700000020)]);
        await steady.deliver(['EOSE', subId]);
        expect(ends, isEmpty);

        nostr.relayPool.remove(partial.url);
        await pumpEventQueue();

        expect(ends, [1]);
      },
    );

    test('an EOSE counts for the socket it arrived on', () async {
      final worker = _HeldVerifyWorker();
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _Relay('wss://relay.example');
      await nostr.relayPool.add(relay);
      final subId = subscribe();
      await pumpEventQueue();

      // The old socket's EVENT and EOSE are still queued behind the
      // signature check when the relay reconnects and replays.
      final frames = <Future<void>>[
        relay.deliver(['EVENT', subId, _event(1700000009)]),
        relay.deliver(['EOSE', subId]),
      ];
      await pumpEventQueue();
      relay.drop();
      await relay.reconnect();
      frames
        ..add(relay.deliver(['EVENT', subId, _event(1700000009)]))
        ..add(relay.deliver(['EVENT', subId, _event(1700000004)]))
        ..add(relay.deliver(['EOSE', subId]));
      worker.release.complete();
      await Future.wait(frames);
      await pumpEventQueue();

      expect(ends, [3]);
    });

    test('a replay after AUTH on the same connection reopens it', () async {
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      // The relay leaves out what needs AUTH and answers at once.
      await gated.deliver(['EOSE', subId]);
      await steady.deliver(['EOSE', subId]);
      expect(ends, [0]);

      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await gated.deliver(['OK', gated.authEventId, true, '']);
      await pumpEventQueue();
      // The pool re-sent the REQ on the same socket; the relay replays.
      await gated.deliver(['EVENT', subId, _event(1700000050)]);
      expect(starts, 1);
      await gated.deliver(['EVENT', subId, _event(1700000040)]);
      expect(ends, [0]);
      await gated.deliver(['EOSE', subId]);
      expect(ends, [0, 2]);
    });

    test('a REQ refused until AUTH ends with the answer to the one re-sent '
        'after it', () async {
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      await steady.deliver(['EOSE', subId]);
      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await gated.deliver(['CLOSED', subId, 'auth-required: sign in first']);
      await gated.deliver(['OK', gated.authEventId, true, '']);
      await pumpEventQueue();
      expect(ends, isEmpty);

      await gated.deliver(['EVENT', subId, _event(1700000050)]);
      await gated.deliver(['EOSE', subId]);
      expect(ends, [1]);
    });

    test('a relay waiting on AUTH keeps it open', () async {
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      await gated.deliver(['EOSE', subId]);
      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty, reason: 'its replay after AUTH is still to come');

      await gated.deliver(['OK', gated.authEventId, true, '']);
      await pumpEventQueue();
      await gated.deliver(['EVENT', subId, _event(1700000050)]);
      await gated.deliver(['EOSE', subId]);
      expect(ends, [1]);
    });

    test('an answer queued behind the signature check before AUTH does not '
        'stand in for the replay', () async {
      final worker = _HeldVerifyWorker();
      nostr.relayPool.eventVerifyWorker = worker;
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      await steady.deliver(['EOSE', subId]);

      final frames = <Future<void>>[
        gated.deliver(['EVENT', subId, _event(1700000050)]),
        gated.deliver(['EOSE', subId]),
      ];
      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await gated.deliver(['OK', gated.authEventId, true, '']);
      await pumpEventQueue();
      worker.release.complete();
      await Future.wait(frames);
      await pumpEventQueue();
      expect(ends, isEmpty, reason: 'the re-sent REQ has not been answered');

      await gated.deliver(['EVENT', subId, _event(1700000040)]);
      await gated.deliver(['EOSE', subId]);
      expect(ends, [2]);
    });

    test('a relay starting a new batch while the phase is open announces '
        'it', () async {
      final partial = _Relay('wss://partial.example');
      final steady = _Relay('wss://steady.example');
      await nostr.relayPool.add(partial);
      await nostr.relayPool.add(steady);
      final subId = subscribe();
      await pumpEventQueue();
      await partial.deliver(['EVENT', subId, _event(1700000020)]);
      await partial.deliver(['CLOSED', subId, 'rate-limited: slow down']);
      await steady.deliver(['EOSE', subId]);
      expect(starts, 0);

      steady.drop();
      await steady.reconnect();
      await steady.deliver(['EVENT', subId, _event(1700000010)]);
      expect(starts, 1);
    });

    test(
      'an inbox relay another caller replaces stops holding it open',
      () async {
        final first = _Relay('wss://inbox.example/');
        final replacements = <Relay>[first, _Relay('wss://inbox.example/')];
        final withInbox = Nostr(
          LocalNostrSigner(_signerKey),
          [],
          (url) => replacements.removeAt(0),
        );
        final steady = _Relay('wss://steady.example');
        await withInbox.relayPool.add(steady);
        final subId = withInbox.subscribe(
          [
            {
              'kinds': [1059],
            },
          ],
          (Event event) {},
          tempRelays: ['wss://inbox.example'],
          onStoredEventsEnd: ends.add,
        );
        await pumpEventQueue();
        await first.deliver(['EVENT', subId, _event(1700000030)]);
        await steady.deliver(['EOSE', subId]);
        first.drop();
        expect(ends, isEmpty);

        withInbox.relayPool.checkAndGenTempRelay('wss://inbox.example/');
        await pumpEventQueue();
        expect(ends, [1], reason: 'the new connection was never sent the REQ');
      },
    );

    test(
      'an inbox relay removed while sending stops holding it open',
      () async {
        final inbox = _Relay('wss://inbox.example/');
        final withInbox = Nostr(
          LocalNostrSigner(_signerKey),
          [],
          (url) => inbox,
        );
        final steady = _Relay('wss://steady.example');
        await withInbox.relayPool.add(steady);
        final subId = withInbox.subscribe(
          [
            {
              'kinds': [1059],
            },
          ],
          (Event event) {},
          tempRelays: ['wss://inbox.example'],
          onStoredEventsEnd: ends.add,
        );
        await pumpEventQueue();
        await inbox.deliver(['EVENT', subId, _event(1700000030)]);
        await steady.deliver(['EOSE', subId]);
        expect(ends, isEmpty);

        withInbox.relayPool.removeTempRelay('wss://inbox.example/');
        await pumpEventQueue();
        expect(ends, [1]);
      },
    );

    test('a relay rebuilt before it answered keeps it open while the '
        'replacement connects', () async {
      final steady = _Relay('wss://steady.example');
      final a = _Relay('wss://a.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(a);
      final subId = subscribe();
      await pumpEventQueue();
      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty);

      final gate = Completer<void>();
      final replacement = _Relay('wss://a.example', connectGate: gate);
      nostr.relayPool.remove(a.url);
      final added = nostr.relayPool.add(replacement, autoSubscribe: true);
      await pumpEventQueue();
      expect(ends, isEmpty, reason: 'the replacement is still connecting');

      gate.complete();
      await added;
      await pumpEventQueue();
      await replacement.deliver(['EOSE', subId]);
      expect(ends, [0]);
    });

    test('an answer from the previous connection does not count toward the '
        'next one', () async {
      final worker = _HeldVerifyWorker();
      nostr.relayPool.eventVerifyWorker = worker;
      final steady = _Relay('wss://steady.example');
      final relay = _Relay('wss://relay.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(relay);
      final subId = subscribe();
      await pumpEventQueue();
      await steady.deliver(['EOSE', subId]);

      // The old connection's batch is still queued behind the signature
      // check when the relay reconnects and authenticates.
      final frames = <Future<void>>[
        relay.deliver(['EVENT', subId, _event(1700000009)]),
        relay.deliver(['EOSE', subId]),
      ];
      await pumpEventQueue();
      relay.drop();
      await relay.reconnect();
      await relay.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await relay.deliver(['OK', relay.authEventId, true, '']);
      await pumpEventQueue();
      // The pool saw nothing from it before the drop, so the phase ended;
      // the queued batch reopens it before the subscription receives it.
      expect(ends, [0]);
      worker.release.complete();
      await Future.wait(frames);
      expect(starts, greaterThan(0));
      await relay.deliver(['EVENT', subId, _event(1700000008)]);
      await relay.deliver(['EOSE', subId]);
      expect(ends, [0], reason: 'the REQ re-sent after AUTH is owed');

      await relay.deliver(['EVENT', subId, _event(1700000007)]);
      await relay.deliver(['EOSE', subId]);
      expect(ends, [0, 3]);
    });

    test('a relay waiting on AUTH keeps it open past the window queries '
        'wait for it', () async {
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await gated.deliver(['CLOSED', subId, 'auth-required: sign in first']);
      // A remote signer, or a slow relay, takes longer than that window.
      await Future<void>.delayed(RelayPool.authHandshakeWindow * 1.2);
      await steady.deliver(['EOSE', subId]);
      expect(ends, isEmpty, reason: 'its replay after AUTH is still to come');

      await gated.deliver(['OK', gated.authEventId, true, '']);
      await pumpEventQueue();
      await gated.deliver(['EVENT', subId, _event(1700000050)]);
      await gated.deliver(['EOSE', subId]);
      expect(ends, [1]);
    });

    test('a relay that refused the REQ and then reconnects does not keep it '
        'open', () async {
      final steady = _Relay('wss://steady.example');
      final refusing = _Relay('wss://refusing.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(refusing);
      final subId = subscribe();
      await pumpEventQueue();
      await refusing.deliver(['CLOSED', subId, 'error: too many subs']);
      await steady.deliver(['EOSE', subId]);
      expect(ends, [0]);

      // Its own reconnect does not send the REQ it refused again.
      refusing.drop();
      await refusing.reconnect();
      steady.drop();
      await steady.reconnect();
      await steady.deliver(['EVENT', subId, _event(1700000010)]);
      await steady.deliver(['EOSE', subId]);
      expect(ends, [0, 1]);
    });

    test('a refusal after the relay already answered does not stand in for '
        'the REQ re-sent after AUTH', () async {
      final steady = _Relay('wss://steady.example');
      final gated = _Relay('wss://gated.example');
      await nostr.relayPool.add(steady);
      await nostr.relayPool.add(gated);
      final subId = subscribe();
      await pumpEventQueue();
      await gated.deliver(['EOSE', subId]);
      await steady.deliver(['EOSE', subId]);
      expect(ends, [0]);

      await gated.deliver(['AUTH', 'challenge-1']);
      await pumpEventQueue();
      await gated.deliver(['CLOSED', subId, 'auth-required: sign in first']);
      await gated.deliver(['OK', gated.authEventId, true, '']);
      await pumpEventQueue();
      await gated.deliver(['EVENT', subId, _event(1700000050)]);
      expect(starts, 1);
      await gated.deliver(['EOSE', subId]);
      expect(ends, [0, 1]);
    });

    test('a live event after the answer does not reopen it', () async {
      final relay = _Relay('wss://relay.example');
      await nostr.relayPool.add(relay);
      final subId = subscribe();
      await pumpEventQueue();
      await relay.deliver(['EOSE', subId]);

      await relay.deliver(['EVENT', subId, _event(1700000010)]);

      expect(starts, 0);
      expect(ends, [0]);
      expect(delivered, ['stored 1700000010']);
    });

    test('a CLOSED counts as that relay answering', () async {
      final answering = _Relay('wss://answering.example');
      final refusing = _Relay('wss://refusing.example');
      await nostr.relayPool.add(answering);
      await nostr.relayPool.add(refusing);
      final subId = subscribe();
      await pumpEventQueue();

      await answering.deliver(['EOSE', subId]);
      await refusing.deliver(['CLOSED', subId, 'error: refused']);

      expect(ends, [0]);
    });

    test('does not end while no relay has answered', () async {
      final dead = _Relay('wss://dead.example', reachable: false);
      await nostr.relayPool.add(dead);
      subscribe();
      await pumpEventQueue();

      dead.drop();

      expect(ends, isEmpty);
    });
  });
}
