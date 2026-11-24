// ABOUTME: Tests RelayPool's off-main verify integration (#5863 P2).
// ABOUTME: Worker verify, per-subscription ordering, and inline fallback.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
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

  group('RelayPool event still verifying when its read ends (#11048)', () {
    const filter = <String, dynamic>{
      'kinds': [EventKind.textNote],
    };

    late Event held;
    late Event prompt;

    setUpAll(() async {
      held = await _signedEvent('held');
      prompt = await _signedEvent('prompt');
    });

    late List<RelayDiagnostic> diagnostics;
    late Completer<bool> gate;
    late _FakeVerifyWorker worker;
    late Nostr nostr;

    /// Adds [relays] to a pool whose verify of [held] waits for [gate], like
    /// a busy verify isolate; every other event verifies at once.
    void startPool(FakeAsync async, List<_FakeRelay> relays) {
      diagnostics = [];
      gate = Completer<bool>();
      worker = _FakeVerifyWorker(
        (json) async => json['id'] == held.id ? await gate.future : true,
      );
      nostr = Nostr(
        LocalNostrSigner(generatePrivateKey()),
        [],
        (url) => RelayBase(url, RelayStatus(url)),
        diagnosticsSink: diagnostics.add,
      )..relayPool.eventVerifyWorker = worker;
      for (final relay in relays) {
        unawaited(nostr.relayPool.add(relay));
      }
      async.flushMicrotasks();
    }

    /// Starts a read of [filter] under [id], handing its result to [onResult].
    void startRead(
      String id,
      Duration timeout,
      void Function(QueryResult) onResult,
    ) {
      unawaited(
        nostr.readEvents([filter], id: id, timeout: timeout).then(onResult),
      );
    }

    List<RelayDiagnostic> diagnosticsNaming(Event event) =>
        diagnostics.where((d) => d.message.contains(event.id)).toList();

    /// Fails unless the sink already holds a diagnostic naming [readId], so a
    /// missing drop report below is an absence rather than an unwired sink.
    void expectSinkRecordsRead(String readId) => expect(
      diagnostics.where((d) => d.message.contains(readId)),
      isNotEmpty,
      reason: 'the sink records this read',
    );

    test('reports an event whose read reached its deadline mid-verify', () {
      fakeAsync((async) {
        final relay = _FakeRelay('wss://relay.a:8443/private?route=example');
        startPool(async, [relay]);
        QueryResult? result;
        startRead('read-1', const Duration(seconds: 5), (r) => result = r);
        async.flushMicrotasks();

        unawaited(relay.deliver(['EVENT', 'read-1', prompt.toJson()]));
        unawaited(relay.deliver(['EVENT', 'read-1', held.toJson()]));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));
        expect(result, isNotNull, reason: 'the deadline ended the read');
        expect(worker.calls, 2, reason: 'both events reached their verify');

        gate.complete(true);
        async.flushMicrotasks();

        expect(result!.events.map((e) => e.id), [prompt.id]);
        expectSinkRecordsRead('read-1');
        final drops = diagnosticsNaming(held);
        expect(drops, hasLength(1));
        expect(drops.single.site.name, 'inFlightEventDrop');
        expect(drops.single.level, RelayDiagnosticLevel.debug);
        expect(drops.single.relayUrl, 'wss://relay.a:8443');
        expect(
          drops.single.message,
          allOf(contains('query read-1'), contains('kind 1')),
        );
        expect(diagnosticsNaming(prompt), isEmpty);
      });
    });

    test('reports an event whose live subscription closed mid-verify', () {
      fakeAsync((async) {
        final relay = _FakeRelay('wss://relay.a');
        startPool(async, [relay]);
        final delivered = <Event>[];
        nostr.subscribe([filter], delivered.add, id: 'live-1');
        async.flushMicrotasks();

        unawaited(relay.deliver(['EVENT', 'live-1', held.toJson()]));
        async.flushMicrotasks();
        expect(worker.calls, 1, reason: 'the event reached its verify');

        nostr.unsubscribe('live-1');
        gate.complete(true);
        async.flushMicrotasks();

        expect(delivered, isEmpty);
        expectSinkRecordsRead('live-1');
        final drops = diagnosticsNaming(held);
        expect(drops, hasLength(1));
        expect(drops.single.site.name, 'inFlightEventDrop');
        expect(drops.single.level, RelayDiagnosticLevel.debug);
        expect(drops.single.message, contains('subscription live-1'));
      });
    });

    test('delivers the event and reports nothing when its verify ends before '
        'the read', () {
      fakeAsync((async) {
        final relay = _FakeRelay('wss://relay.a');
        startPool(async, [relay]);
        QueryResult? result;
        startRead('read-1', const Duration(seconds: 5), (r) => result = r);
        async.flushMicrotasks();

        unawaited(relay.deliver(['EVENT', 'read-1', held.toJson()]));
        async.flushMicrotasks();
        gate.complete(true);
        async
          ..flushMicrotasks()
          ..elapse(const Duration(seconds: 5));

        expect(result!.events.map((e) => e.id), [held.id]);
        expect(diagnosticsNaming(held), isEmpty);
      });
    });

    test('keeps a read open past the settle window while a relay that owes '
        'it is still verifying its event', () {
      fakeAsync((async) {
        final relayA = _FakeRelay('wss://relay.a');
        final relayB = _FakeRelay('wss://relay.b');
        startPool(async, [relayA, relayB]);
        QueryResult? result;
        startRead('settle-1', const Duration(seconds: 10), (r) => result = r);
        async.flushMicrotasks();

        // A answers with nothing, so the settle window now bounds B.
        unawaited(relayA.deliver(['EOSE', 'settle-1']));
        async.flushMicrotasks();
        unawaited(relayB.deliver(['EVENT', 'settle-1', held.toJson()]));
        async
          ..flushMicrotasks()
          ..elapse(RelayPool.querySettleWindow * 2);
        expect(result, isNull, reason: "B's event is still being verified");

        gate.complete(true);
        async.flushMicrotasks();
        unawaited(relayB.deliver(['EOSE', 'settle-1']));
        async.flushMicrotasks();

        expect(result, isNotNull);
        expect(result!.events.map((e) => e.id), [held.id]);
        expect(diagnosticsNaming(held), isEmpty);
      });
    });

    test('completes on the relays that answered when the other relay sends '
        'nothing within the settle window', () {
      fakeAsync((async) {
        final relayA = _FakeRelay('wss://relay.a');
        final relayB = _FakeRelay('wss://relay.b');
        startPool(async, [relayA, relayB]);
        QueryResult? result;
        startRead('settle-1', const Duration(seconds: 10), (r) => result = r);
        async.flushMicrotasks();

        unawaited(relayA.deliver(['EVENT', 'settle-1', prompt.toJson()]));
        unawaited(relayA.deliver(['EOSE', 'settle-1']));
        async
          ..flushMicrotasks()
          ..elapse(RelayPool.querySettleWindow * 2);

        expect(result, isNotNull, reason: 'B sent nothing in the window');
        expect(result!.events.map((e) => e.id), [prompt.id]);
      });
    });

    test('still ends the read at its deadline while a relay is verifying its '
        'event, and reports the event', () {
      fakeAsync((async) {
        final relayA = _FakeRelay('wss://relay.a');
        final relayB = _FakeRelay('wss://relay.b');
        startPool(async, [relayA, relayB]);
        QueryResult? result;
        startRead('settle-1', const Duration(seconds: 10), (r) => result = r);
        async.flushMicrotasks();

        unawaited(relayA.deliver(['EOSE', 'settle-1']));
        async.flushMicrotasks();
        unawaited(relayB.deliver(['EVENT', 'settle-1', held.toJson()]));
        async
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 9500));
        expect(result, isNull, reason: "B's event is still being verified");

        async.elapse(const Duration(seconds: 1));
        expect(result, isNotNull, reason: 'the deadline still ends the read');

        gate.complete(true);
        async.flushMicrotasks();
        expect(result!.events, isEmpty);
        expectSinkRecordsRead('settle-1');
        expect(diagnosticsNaming(held), hasLength(1));
      });
    });
  });
}
