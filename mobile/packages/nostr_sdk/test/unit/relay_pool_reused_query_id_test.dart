// ABOUTME: Pins what the pool does with a late answer: it settles a later read
// ABOUTME: that reuses the REQ's id, so a caller asking again needs a new id.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _FakeRelay extends Relay {
  _FakeRelay(String url) : super(url, RelayStatus(url));

  final sent = <List<dynamic>>[];

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
    sent.add(message);
    return true;
  }

  /// Hands [json] to the pool the way the socket listener does: without
  /// awaiting the frame's handling.
  void deliver(List<dynamic> json) => onMessage!(this, json);
}

/// Verifies every event at once, except those whose id has a gate: those
/// wait until the test completes it, like a verify isolate that is busy.
class _GatedVerifyWorker implements EventVerifyWorker {
  final gates = <String, Completer<bool>>{};

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) async {
    final gate = gates[eventJson['id']];
    if (gate != null) return gate.future;
    return true;
  }

  @override
  void close() {}
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

const _id = 'page_1';
const _filter = <String, dynamic>{
  'kinds': [EventKind.textNote],
  'limit': 3,
};

/// Starts a read of [_filter] under [id] that ends after five seconds unless
/// the pool completes it first, handing the result to [onResult].
void _startRead(Nostr nostr, String id, void Function(QueryResult) onResult) {
  unawaited(
    nostr
        .readEvents(
          [_filter],
          id: id,
          timeout: const Duration(seconds: 5),
          requireAllRelaysSettled: true,
        )
        .then(onResult),
  );
}

void main() {
  group('RelayPool read after an earlier read under the same id', () {
    late Event first;
    late Event second;
    late Event third;

    setUpAll(() async {
      first = await _signedEvent('first');
      second = await _signedEvent('second');
      third = await _signedEvent('third');
    });

    late _GatedVerifyWorker worker;
    late _FakeRelay relay;
    late Nostr nostr;
    QueryResult? firstRead;

    /// Starts a read under [_id] and lets its answer begin: [first] arrives,
    /// [second] is still being verified when the read's deadline ends it, and
    /// its verify finishes before anything asks again.
    void endFirstReadMidAnswer(FakeAsync async) {
      worker = _GatedVerifyWorker();
      nostr = Nostr(
        LocalNostrSigner(generatePrivateKey()),
        [],
        (url) => RelayBase(url, RelayStatus(url)),
      )..relayPool.eventVerifyWorker = worker;
      relay = _FakeRelay('wss://relay.a');
      unawaited(nostr.relayPool.add(relay));
      async.flushMicrotasks();
      firstRead = null;
      _startRead(nostr, _id, (r) => firstRead = r);
      async.flushMicrotasks();
      relay.deliver(['EVENT', _id, first.toJson()]);
      async.flushMicrotasks();
      worker.gates[second.id] = Completer<bool>();
      relay.deliver(['EVENT', _id, second.toJson()]);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 5));
      expect(firstRead, isNotNull, reason: 'the deadline ended the read');
      expect(firstRead!.isComplete, isFalse);
      worker.gates[second.id]!.complete(true);
      async.flushMicrotasks();
    }

    test('under the same id, the rest of the first answer settles the read '
        'and the event that was verifying reaches neither', () {
      fakeAsync((async) {
        endFirstReadMidAnswer(async);
        QueryResult? retry;
        _startRead(nostr, _id, (r) => retry = r);
        async.flushMicrotasks();

        relay
          ..deliver(['EVENT', _id, third.toJson()])
          ..deliver(['EOSE', _id]);
        async.flushMicrotasks();

        expect(retry, isNotNull);
        expect(retry!.isComplete, isTrue);
        expect(firstRead!.events.map((e) => e.id), [first.id]);
        expect(retry!.events.map((e) => e.id), [third.id]);
      });
    });

    test('under a fresh id, the late answer is ignored and the read settles '
        'on its own answer', () {
      fakeAsync((async) {
        endFirstReadMidAnswer(async);
        const retryId = '${_id}_retry';
        QueryResult? retry;
        _startRead(nostr, retryId, (r) => retry = r);
        async.flushMicrotasks();

        relay
          ..deliver(['EVENT', _id, third.toJson()])
          ..deliver(['EOSE', _id]);
        async.flushMicrotasks();
        expect(retry, isNull, reason: "the first REQ's EOSE does not end it");

        for (final event in [first, second, third]) {
          relay.deliver(['EVENT', retryId, event.toJson()]);
        }
        relay.deliver(['EOSE', retryId]);
        async.flushMicrotasks();

        expect(retry, isNotNull);
        expect(retry!.isComplete, isTrue);
        expect(
          retry!.events.map((e) => e.id),
          unorderedEquals([first.id, second.id, third.id]),
        );
      });
    });
  });
}
