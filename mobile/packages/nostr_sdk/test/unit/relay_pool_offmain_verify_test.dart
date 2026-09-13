// ABOUTME: Tests RelayPool's off-main verify integration (#5863 P2).
// ABOUTME: Worker verify, per-subscription ordering, and inline fallback.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// Ceiling for a delivery this test expects to complete. Without it a
/// regression makes the awaited future hang to the framework's own timeout,
/// which reports a bare timeout instead of naming what stalled.
const _guard = Duration(seconds: 3);

class _FakeRelay extends Relay {
  _FakeRelay(String url) : super(url, RelayStatus(url));

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
  }) async => true;

  Future<void> deliver(List<dynamic> json) async {
    final dynamic result = onMessage!(this, json);
    if (result is Future) await result;
  }
}

/// A verify worker whose per-event decision (and optional delay) the test
/// controls, so ordering and fallback are deterministic.
class _FakeVerifyWorker implements EventVerifyWorker {
  _FakeVerifyWorker(this._decide);

  final FutureOr<bool> Function(Map<String, dynamic> json) _decide;
  int calls = 0;
  bool closed = false;

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async {
    if (closed) throw StateError('closed');
    calls++;
    return _decide(eventJson);
  }

  @override
  void close() => closed = true;
}

Future<Event> _signedEvent(String content) async {
  const privateKey =
      '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
  final signer = LocalNostrSigner(privateKey);
  final pubkey = await signer.getPublicKey();
  final event = Event(
    pubkey!,
    EventKind.textNote,
    [],
    content,
    createdAt: 1780000000,
  );
  await signer.signEvent(event);
  return event;
}

Nostr _nostr() => Nostr(
  LocalNostrSigner(generatePrivateKey()),
  [],
  (url) => RelayBase(url, RelayStatus(url)),
);

List<Event> _subscribe(Nostr nostr, {String id = 'sub'}) {
  final delivered = <Event>[];
  nostr.subscribe(
    [
      {
        'kinds': [EventKind.textNote],
      },
    ],
    delivered.add,
    id: id,
  );
  return delivered;
}

void main() {
  group('RelayPool off-main verify (#5863 P2)', () {
    test('routes verify to the worker and delivers accepted events', () async {
      final nostr = _nostr();
      final worker = _FakeVerifyWorker((_) => true);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      final event = await _signedEvent('accepted');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(delivered, hasLength(1));
      expect(worker.calls, 1, reason: 'verify ran on the worker, not inline');
    });

    test('drops events the worker rejects', () async {
      final nostr = _nostr();
      nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker((_) => false);
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      // A genuinely valid event, but the worker says no → dropped.
      final event = await _signedEvent('rejected-by-worker');
      await relay.deliver(['EVENT', 'sub', event.toJson()]);

      expect(delivered, isEmpty);
    });

    test('falls back to inline verify when the worker throws', () async {
      final nostr = _nostr();
      nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker(
        (_) => throw StateError('isolate died'),
      );
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      // Worker throws → inline check runs; the real signature is valid → kept.
      final valid = await _signedEvent('fallback-valid');
      await relay.deliver(['EVENT', 'sub', valid.toJson()]);
      expect(delivered, hasLength(1));

      // And a tampered event still fails the inline fallback → dropped.
      final tampered = (await _signedEvent('orig')).toJson()
        ..['content'] = 'tampered';
      await relay.deliver(['EVENT', 'sub', tampered]);
      expect(delivered, hasLength(1));
    });

    test(
      'preserves per-subscription delivery order despite out-of-order verify',
      () async {
        final nostr = _nostr();
        final gate = Completer<void>();
        // 'A' verifies slowly (gated); 'B' verifies immediately. Without ordering
        // B would dispatch first; the per-relay chain must still deliver A then B.
        nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker((json) async {
          if (json['content'] == 'A') await gate.future;
          return true;
        });
        final relay = _FakeRelay('wss://relay.a');
        expect(await nostr.relayPool.add(relay), isTrue);
        final delivered = _subscribe(nostr);

        final a = await _signedEvent('A');
        final b = await _signedEvent('B');
        final dA = relay.deliver(['EVENT', 'sub', a.toJson()]);
        final dB = relay.deliver(['EVENT', 'sub', b.toJson()]);
        await Future<void>.delayed(Duration.zero);

        expect(delivered, isEmpty, reason: 'A gated, B queued behind it');
        gate.complete();
        await Future.wait([dA, dB]);

        expect(delivered.map((e) => e.content), ['A', 'B']);
      },
    );

    test('delivers one subscription while another on the same relay is still '
        'verifying (#7301)', () async {
      final nostr = _nostr();
      final gate = Completer<void>();
      // The stored replay of a one-shot query verifies slowly; the feed
      // subscription's own event must not wait behind it. Before #7301 the
      // chain was per relay, so a feed the relay answered in 300ms reached
      // the app only after every other subscription's replay on that
      // socket had been verified — 16s on a flagship, past the app's 30s
      // feed-load fuse on slower hardware.
      nostr.relayPool.eventVerifyWorker = _FakeVerifyWorker((json) async {
        if (json['content'] == 'replay') await gate.future;
        return true;
      });
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final replayDelivered = _subscribe(nostr, id: 'query');
      final feedDelivered = _subscribe(nostr, id: 'feed');

      final replay = await _signedEvent('replay');
      final feed = await _signedEvent('feed');
      final dReplay = relay.deliver(['EVENT', 'query', replay.toJson()]);
      final dFeed = relay.deliver(['EVENT', 'feed', feed.toJson()]);
      await dFeed.timeout(
        _guard,
        onTimeout: () => fail(
          'the feed subscription was not delivered while another '
          'subscription on the same relay was still verifying',
        ),
      );

      expect(feedDelivered.map((e) => e.content), ['feed']);
      expect(replayDelivered, isEmpty, reason: 'still gated');
      gate.complete();
      await dReplay;
      expect(replayDelivered.map((e) => e.content), ['replay']);
    });

    test('does not spend a verify on a frame no subscription is listening to '
        '(#7301)', () async {
      final nostr = _nostr();
      final worker = _FakeVerifyWorker((_) => true);
      nostr.relayPool.eventVerifyWorker = worker;
      final relay = _FakeRelay('wss://relay.a');
      expect(await nostr.relayPool.add(relay), isTrue);
      final delivered = _subscribe(nostr);

      // A relay keeps streaming a stored replay after the query it answers
      // was released; every one of those frames used to be verified and
      // then dropped, ahead of the live subscriptions queued behind them.
      final orphan = await _signedEvent('orphan');
      await relay.deliver(['EVENT', 'released-query', orphan.toJson()]);
      expect(worker.calls, 0);
      expect(delivered, isEmpty);

      final live = await _signedEvent('live');
      await relay.deliver(['EVENT', 'sub', live.toJson()]);
      expect(worker.calls, 1);
      expect(delivered.map((e) => e.content), ['live']);
    });
  });
}
