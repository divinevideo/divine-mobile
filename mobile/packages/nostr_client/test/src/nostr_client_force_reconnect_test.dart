// ABOUTME: A read, COUNT or awaited publish still waiting for its answer when
// ABOUTME: the relays are force-reconnected is sent again on the new
// ABOUTME: connection (#11343, #11446).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:test/test.dart';

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _poolUrl = 'wss://pool.example';
const _otherPoolUrl = 'wss://other-pool.example';
const _tempUrl = 'wss://temp.example';
const _readId = 'held-read';

/// How long every relay here holds its answer.
const _answerDelay = Duration(seconds: 4);

/// When the reconnect lands, measured from the start of the read.
const _reconnectAt = Duration(milliseconds: 1600);

/// The caller's own timeout.
const _timeout = Duration(seconds: 12);

/// The gap between two frames of one answer.
const _frameGap = Duration(milliseconds: 1);

/// When a relay's EOSE lands after it was asked.
final Duration _answered = _answerDelay + _frameGap;

final _filter = Filter(kinds: const [EventKind.textNote], limit: 10);

/// A note named after the relay that holds it.
Event _note(String url) => Event(
  getPublicKey(_key),
  EventKind.textNote,
  const [],
  Uri.parse(url).host,
  createdAt: 1700000000,
)..sign(_key);

/// The relay's side of one relay object: it answers every REQ with [stored]
/// and EOSE, every COUNT with 7, and every EVENT with `OK true`, [_answerDelay]
/// later, on the socket the request arrived on. A socket the client closed
/// meanwhile never delivers that answer.
class _Socket extends Relay {
  _Socket(String url, {required this.stored, this.connects = true})
    : super(url, RelayStatus(url));

  final Event stored;
  final bool connects;

  /// Every REQ id this object wrote to a socket, in order.
  final List<String> reqs = [];

  /// Every EVENT id this object wrote to a socket, in order.
  final List<String> events = [];

  bool _open = false;
  bool _disposed = false;
  int _socket = 0;

  @override
  Future<bool> doConnect() async {
    if (!connects) {
      relayStatus.connected = ClientConnected.disconnect;
      return false;
    }
    _socket++;
    _open = true;
    relayStatus.connected = ClientConnected.connected;
    _reportStatus();
    return true;
  }

  /// The client closing the socket, as `RelayPool.remove` does.
  @override
  Future<void> disconnect() async {
    _open = false;
    relayStatus.connected = ClientConnected.disconnect;
    _reportStatus();
  }

  @override
  void dispose() {
    _disposed = true;
  }

  /// `RelayBase` reports connection changes from an asynchronous stream that
  /// `dispose` cancels, so a disposed object reports nothing.
  void _reportStatus() {
    scheduleMicrotask(() {
      final callback = relayStatusCallback;
      if (!_disposed && callback is void Function()) callback();
    });
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (!_open) return false;
    final socket = _socket;
    bool stillOpen() => _open && !_disposed && socket == _socket;
    if (message.first == 'EVENT') {
      final id = (message[1] as Map<String, dynamic>)['id'] as String;
      events.add(id);
      Timer(_answerDelay, () {
        if (stillOpen()) _deliver(['OK', id, true, '']);
      });
      return true;
    }
    final subId = message.length > 1 ? message[1] : null;
    if (subId is! String) return true;
    if (message.first == 'COUNT') {
      Timer(_answerDelay, () {
        if (stillOpen()) {
          _deliver([
            'COUNT',
            subId,
            {'count': 7},
          ]);
        }
      });
    } else if (message.first == 'REQ') {
      reqs.add(subId);
      // One frame per timer, as a socket delivers them: the pool verifies an
      // EVENT asynchronously before the EOSE that follows it.
      Timer(_answerDelay, () {
        if (stillOpen()) _deliver(['EVENT', subId, stored.toJson()]);
      });
      Timer(_answered, () {
        if (stillOpen()) _deliver(['EOSE', subId]);
      });
    }
    return true;
  }

  void _deliver(List<dynamic> frame) {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

class _Harness {
  _Harness._(this.client, this.dialled, this.temps);

  /// Starts a client on [relays], each relay holding the note named after it.
  ///
  /// A relay in [failRedial] connects once and refuses every later dial.
  factory _Harness.start(
    FakeAsync async, {
    List<String> relays = const [_poolUrl],
    Set<String> failRedial = const {},
  }) {
    final dialled = <String, List<_Socket>>{};
    final temps = <_Socket>[];
    final nostr = Nostr(LocalNostrSigner(_key), [], (url) {
      final temp = _Socket(url, stored: _note(url));
      temps.add(temp);
      return temp;
    });
    final manager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relays.first,
        storage: InMemoryRelayStorage(relays),
      ),
      relayPool: nostr.relayPool,
      relayFactory: (url) {
        final redial = dialled[url]?.isNotEmpty ?? false;
        final socket = _Socket(
          url,
          stored: _note(url),
          connects: !(redial && failRedial.contains(url)),
        );
        (dialled[url] ??= []).add(socket);
        return socket;
      },
    );
    final client = NostrClient.forTesting(nostr: nostr, relayManager: manager);
    unawaited(manager.initialize());
    async.flushMicrotasks();
    return _Harness._(client, dialled, temps);
  }

  final NostrClient client;
  final Map<String, List<_Socket>> dialled;
  final List<_Socket> temps;

  _Socket latest(String url) => dialled[url]!.last;

  /// Force-reconnects [_reconnectAt] in, and runs past the caller's timeout.
  void reconnectMidway(FakeAsync async) {
    async.elapse(_reconnectAt);
    unawaited(client.forceReconnectAll());
    async.elapse(_timeout);
  }
}

/// One read of [_readId], with how long it took to return.
class _Read {
  QueryResult? result;
  Duration? tookFor;

  List<String> get contents => [
    for (final event in result!.events) event.content,
  ]..sort();
}

_Read _startRead(
  FakeAsync async,
  _Harness h, {
  bool full = false,
  List<String>? tempRelays,
}) {
  final started = clock.now();
  final read = _Read();
  unawaited(
    h.client
        .readEvents(
          [_filter],
          subscriptionId: _readId,
          tempRelays: tempRelays,
          useCache: false,
          timeout: _timeout,
          requireAllRelaysSettled: full,
        )
        .then((result) {
          read
            ..result = result
            ..tookFor = clock.now().difference(started);
        }),
  );
  async.flushMicrotasks();
  return read;
}

/// One awaited publish of a note, with how long it took to settle.
class _Publish {
  PublishOutcome? outcome;
  Duration? tookFor;
}

_Publish _startPublish(FakeAsync async, _Harness h) {
  final started = clock.now();
  final publish = _Publish();
  unawaited(
    h.client.publishEventAwaitOk(_note('published.example')).then((outcome) {
      publish
        ..outcome = outcome
        ..tookFor = clock.now().difference(started);
    }),
  );
  async.flushMicrotasks();
  return publish;
}

void main() {
  group('$NostrClient forceReconnectAll (#11343, #11446)', () {
    test(
      'preserves write access when the default relay is recreated',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final url = 'ws://127.0.0.1:${server.port}';
        final sockets = <WebSocket>[];
        final events = <List<String>>[];
        final firstWrite = Completer<void>();
        final replacementBarrier = Completer<void>();
        server.listen((request) async {
          if (!WebSocketTransformer.isUpgradeRequest(request)) {
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }
          final socket = await WebSocketTransformer.upgrade(request);
          final socketEvents = <String>[];
          sockets.add(socket);
          events.add(socketEvents);
          socket.listen((raw) {
            final frame = jsonDecode(raw as String) as List<dynamic>;
            if (frame.first == 'EVENT') {
              final event = frame[1] as Map<String, dynamic>;
              socketEvents.add(event['id'] as String);
              if (!firstWrite.isCompleted) firstWrite.complete();
            } else if (frame.first == 'CLOSE' && frame[1] == 'test-barrier') {
              replacementBarrier.complete();
            }
          });
        });

        final nostr = Nostr(
          LocalNostrSigner(_key),
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        final manager = RelayManager(
          config: RelayManagerConfig(defaultRelayUrl: url),
          relayPool: nostr.relayPool,
        );
        final client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: manager,
        );
        addTearDown(() async {
          await client.dispose();
          for (final socket in sockets) {
            await socket.close();
          }
          await server.close(force: true);
        });

        await manager.initialize();
        final event = _note(url);
        final publish = client.publishEventAwaitOk(event, timeout: _timeout);
        await firstWrite.future.timeout(_answerDelay);
        final old = nostr.relayPool.getRelay(url)!;
        old.relayStatus.writeAccess = false;

        expect(
          await client.forceReconnectAll(),
          ForceReconnectOutcome.completed,
        );
        final replacement = nostr.relayPool.getRelay(url)!;
        expect(replacement, isNot(same(old)));
        // This frame follows any replay on the same socket, so the server can
        // confirm absence without waiting for the publish deadline.
        expect(await replacement.send(['CLOSE', 'test-barrier']), isTrue);
        await replacementBarrier.future.timeout(_answerDelay);

        expect(events, [
          [event.id],
          isEmpty,
        ]);
        expect(replacement.relayStatus.writeAccess, isFalse);
        expect((await publish).noResponseFrom, [url]);
      },
    );

    group('a read still waiting for its answer', () {
      test('is answered when nothing reconnects, as a control', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final read = _startRead(async, h);
          async.elapse(_timeout);

          expect(read.result!.endedBy, QueryEnd.complete);
          expect(read.contents, ['pool.example']);
          expect(read.tookFor, _answered);
        });
      });

      test('is asked again on the new connection, which answers it', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final read = _startRead(async, h);
          h.reconnectMidway(async);

          expect(h.dialled[_poolUrl], hasLength(2));
          expect(h.latest(_poolUrl).reqs, [_readId]);
          expect(read.result!.endedBy, QueryEnd.complete);
          expect(read.contents, ['pool.example']);
          expect(read.tookFor, _reconnectAt + _answered);
        });
      });

      test('requiring every relay to settle, is answered on the new '
          'connection', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final read = _startRead(async, h, full: true);
          h.reconnectMidway(async);

          expect(read.result!.endedBy, QueryEnd.complete);
          expect(read.contents, ['pool.example']);
          expect(read.tookFor, _reconnectAt + _answered);
        });
      });

      test('with two pool relays, is answered on both new connections', () {
        fakeAsync((async) {
          final h = _Harness.start(async, relays: [_poolUrl, _otherPoolUrl]);
          final read = _startRead(async, h, full: true);
          h.reconnectMidway(async);

          expect(read.result!.endedBy, QueryEnd.complete);
          expect(read.contents, ['other-pool.example', 'pool.example']);
        });
      });

      test('beside a temp relay the reconnect leaves alone, keeps the '
          'redialled relay answer', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final read = _startRead(async, h, full: true, tempRelays: [_tempUrl]);
          h.reconnectMidway(async);

          expect(h.temps.single.reqs, [_readId]);
          expect(read.result!.endedBy, QueryEnd.complete);
          expect(read.contents, ['pool.example', 'temp.example']);
        });
      });

      test('ends at once, unanswered, when the redial fails', () {
        fakeAsync((async) {
          final h = _Harness.start(async, failRedial: {_poolUrl});
          final read = _startRead(async, h, full: true);
          h.reconnectMidway(async);

          expect(read.result!.endedBy, QueryEnd.socketDropped);
          expect(read.tookFor, _reconnectAt);
        });
      });
    });

    group('a COUNT still waiting for its answer', () {
      test('is answered by the new connection', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final started = clock.now();
          CountResult? result;
          Duration? tookFor;
          unawaited(
            h.client.countEvents([_filter], timeout: _timeout).then((value) {
              result = value;
              tookFor = clock.now().difference(started);
            }),
          );
          async.flushMicrotasks();
          h.reconnectMidway(async);

          expect(result?.count, 7);
          expect(tookFor, _reconnectAt + _answerDelay);
        });
      });
    });

    group('an awaited publish still waiting for its OK', () {
      test('is answered when nothing reconnects, as a control', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final publish = _startPublish(async, h);
          async.elapse(_timeout);

          expect(publish.outcome!.acceptedBy, [_poolUrl]);
          expect(publish.tookFor, _answerDelay);
        });
      });

      test('is sent again on the new connection, which answers it', () {
        fakeAsync((async) {
          final h = _Harness.start(async);
          final publish = _startPublish(async, h);
          h.reconnectMidway(async);

          expect(h.dialled[_poolUrl], hasLength(2));
          expect(h.dialled[_poolUrl]!.first.events, hasLength(1));
          expect(h.latest(_poolUrl).events, h.dialled[_poolUrl]!.first.events);
          expect(publish.outcome!.acceptedBy, [_poolUrl]);
          expect(publish.outcome!.noResponseFrom, isEmpty);
          expect(publish.tookFor, _reconnectAt + _answerDelay);
        });
      });

      test('ends at once, unanswered, when the redial fails', () {
        fakeAsync((async) {
          final h = _Harness.start(async, failRedial: {_poolUrl});
          final publish = _startPublish(async, h);
          h.reconnectMidway(async);

          expect(publish.outcome!.acceptedBy, isEmpty);
          expect(publish.outcome!.noResponseFrom, [_poolUrl]);
          expect(publish.tookFor, _reconnectAt);
        });
      });
    });
  });
}
