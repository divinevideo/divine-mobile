// ABOUTME: NostrClient.queryEventsOnFreshConnections reads over connections
// ABOUTME: opened for that read alone, so a busy shared socket cannot hold it.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MockRelayManager extends Mock implements RelayManager {}

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _homeUrl = 'wss://home.example';
const _otherUrl = 'wss://other.example';

/// A relay connection that answers every REQ with [events] and EOSE after
/// [answerAfter], or never when it is null. One that does not [takeReqs] fails
/// to send them, as a connection whose handshake never completes does.
class _Connection extends Relay {
  _Connection(
    String url, {
    required this.events,
    this.answerAfter,
    this.takeReqs = true,
  }) : super(url, RelayStatus(url));

  final List<Event> events;
  final Duration? answerAfter;
  final bool takeReqs;
  final List<String> reqs = [];
  bool disconnected = false;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.length > 2 && message[0] == 'REQ') {
      if (!takeReqs) return false;
      final subId = message[1] as String;
      reqs.add(subId);
      final after = answerAfter;
      if (after != null) {
        for (final event in events) {
          Timer(after, () => _deliver(['EVENT', subId, event.toJson()]));
        }
        Timer(
          after + const Duration(milliseconds: 1),
          () => _deliver(['EOSE', subId]),
        );
      }
    }
    return true;
  }

  void _deliver(List<dynamic> frame) {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

/// A signer that counts [close] calls.
class _SpySigner extends LocalNostrSigner {
  _SpySigner() : super(_key);

  int closes = 0;

  @override
  void close() => closes++;
}

/// A client whose pooled connections are [pooled], and whose relay factory
/// opens a new connection answering after [freshAnswerAfter] (never when
/// null), recorded in the returned `opened` list. A new connection to a url in
/// [silentFresh] never answers, and one to a url in [refusingFresh] cannot
/// send its REQ.
({NostrClient client, List<_Connection> opened}) _client(
  FakeAsync async, {
  required List<_Connection> pooled,
  required List<Event> events,
  Duration? freshAnswerAfter,
  Set<String> silentFresh = const {},
  Set<String> refusingFresh = const {},
  List<String>? connected,
  NostrSigner? signer,
}) {
  final opened = <_Connection>[];
  final nostr = Nostr(signer ?? LocalNostrSigner(_key), [], (url) {
    final bare = url.replaceFirst(RegExp(r'/$'), '');
    final connection = _Connection(
      url,
      events: events,
      answerAfter: silentFresh.contains(bare) ? null : freshAnswerAfter,
      takeReqs: !refusingFresh.contains(bare),
    );
    opened.add(connection);
    return connection;
  });
  for (final relay in pooled) {
    unawaited(nostr.relayPool.add(relay));
  }
  async.flushMicrotasks();
  final urls = connected ?? [for (final relay in pooled) relay.url];
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(urls);
  when(() => relayManager.configuredRelays).thenReturn(urls);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  return (
    client: NostrClient.forTesting(nostr: nostr, relayManager: relayManager),
    opened: opened,
  );
}

// The pool names a temp relay with a trailing slash (handleAddrList).
String _bare(_Connection connection) =>
    connection.url.replaceFirst(RegExp(r'/$'), '');

final _list = Filter(kinds: const [10003], authors: [getPublicKey(_key)]);

({List<Event> events, bool timedOut, bool noRelays, Duration took}) _read(
  FakeAsync async,
  NostrClient client, {
  Duration timeout = const Duration(seconds: 10),
  List<String> requiredRelays = const [],
}) {
  ({List<Event> events, bool timedOut, bool noRelays})? result;
  Duration? took;
  final start = async.elapsed;
  unawaited(
    client
        .queryEventsOnFreshConnections(
          [_list],
          timeout: timeout,
          requiredRelays: requiredRelays,
        )
        .then((r) {
          result = r;
          took = async.elapsed - start;
        }),
  );
  async.elapse(const Duration(seconds: 90));
  return (
    events: result!.events,
    timedOut: result!.timedOut,
    noRelays: result!.noRelays,
    took: took!,
  );
}

void main() {
  group('queryEventsOnFreshConnections', () {
    late Event list;

    setUpAll(() {
      list = Event(
        getPublicKey(_key),
        10003,
        const [
          [
            'e',
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ],
        ],
        '',
        createdAt: 1700000000,
      )..sign(_key);
    });

    test('answers from a new connection while the shared one is busy', () {
      fakeAsync((async) {
        final busy = _Connection(
          _homeUrl,
          events: [list],
          answerAfter: const Duration(seconds: 60),
        );
        final h = _client(
          async,
          pooled: [busy],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
        );

        final r = _read(async, h.client);

        expect(r.timedOut, isFalse);
        expect(r.noRelays, isFalse);
        expect(r.events.map((e) => e.id), [list.id]);
        expect(r.took, lessThan(const Duration(seconds: 1)));
        expect(busy.reqs, isEmpty);
        expect(h.opened.map(_bare), [_homeUrl]);
      });
    });

    test('opens one new connection per connected relay and needs them '
        'all to settle', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
            _Connection(_otherUrl, events: const []),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
        );

        final r = _read(async, h.client);

        expect(r.timedOut, isFalse);
        expect(
          h.opened.map(_bare),
          unorderedEquals([_homeUrl, _otherUrl]),
        );
        expect(h.opened.every((c) => c.reqs.length == 1), isTrue);
      });
    });

    test('reports timedOut when a relay does not settle on its new '
        'connection either', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
        );

        final r = _read(async, h.client);

        expect(r.timedOut, isTrue);
        expect(r.noRelays, isFalse);
        expect(r.took, greaterThanOrEqualTo(const Duration(seconds: 10)));
      });
    });

    test('closes the new connections once the read ends', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
        );

        _read(async, h.client);

        expect(h.opened, hasLength(1));
        expect(h.opened.single.disconnected, isTrue);
      });
    });

    test('reports timedOut when one relay stays silent on its new '
        'connection while the other answers', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
            _Connection(_otherUrl, events: const []),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
          silentFresh: {_homeUrl},
        );

        final r = _read(async, h.client);

        expect(r.timedOut, isTrue);
        expect(h.opened.every((c) => c.disconnected), isTrue);
      });
    });

    test('reports timedOut when one new connection cannot send the REQ '
        'while the other answers', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
            _Connection(_otherUrl, events: const []),
          ],
          events: const [],
          freshAnswerAfter: const Duration(milliseconds: 300),
          refusingFresh: {_homeUrl},
        );

        final r = _read(async, h.client);

        expect(h.opened.map(_bare), unorderedEquals([_homeUrl, _otherUrl]));
        expect(r.timedOut, isTrue);
      });
    });

    test("leaves the client's signer open", () {
      fakeAsync((async) {
        final signer = _SpySigner();
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
          signer: signer,
        );

        _read(async, h.client);

        expect(h.opened, hasLength(1));
        expect(signer.closes, 0);
      });
    });

    test('reports noRelays and opens nothing when no relay is connected', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
          connected: const [],
        );

        final r = _read(async, h.client);

        expect(r.noRelays, isTrue);
        expect(r.events, isEmpty);
        expect(h.opened, isEmpty);
      });
    });

    test('asks a required relay even after its shared connection drops', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
          connected: const [],
        );

        final r = _read(async, h.client, requiredRelays: [_homeUrl]);

        expect(r.timedOut, isFalse);
        expect(r.noRelays, isFalse);
        expect(r.events.map((event) => event.id), [list.id]);
        expect(h.opened.map(_bare), [_homeUrl]);
      });
    });

    test('reports noRelays and opens nothing while the client is being '
        'disposed', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
        );
        // Not flushed: the read starts before dispose reaches its first await.
        unawaited(h.client.dispose());

        final r = _read(async, h.client);

        expect(r.noRelays, isTrue);
        expect(h.opened, isEmpty);
      });
    });

    test('reports noRelays and opens nothing once the client is disposed', () {
      fakeAsync((async) {
        final h = _client(
          async,
          pooled: [
            _Connection(_homeUrl, events: [list]),
          ],
          events: [list],
          freshAnswerAfter: const Duration(milliseconds: 300),
        );
        unawaited(h.client.dispose());
        async.flushMicrotasks();

        final r = _read(async, h.client);

        expect(r.noRelays, isTrue);
        expect(h.opened, isEmpty);
      });
    });
  });
}
