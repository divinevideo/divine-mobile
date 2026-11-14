// ABOUTME: NostrClient hands a read's silence bound to the relay pool, and a
// ABOUTME: long-capped read still reaches the relay after a query-slot wait.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MockRelayManager extends Mock implements RelayManager {}

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _answeringUrl = 'wss://answering.example';
const _otherUrl = 'wss://other.example';

/// A relay that answers a REQ for kind 1 with [events] and EOSE after
/// [answerAfter] (never, when null), and every other REQ after [othersAfter].
class _Relay extends Relay {
  _Relay(
    String url, {
    required this.events,
    this.answerAfter = const Duration(milliseconds: 10),
    this.othersAfter = Duration.zero,
  }) : super(url, RelayStatus(url));

  final List<Event> events;
  final Duration? answerAfter;
  final Duration othersAfter;
  final List<String> reqs = [];

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
    if (message.length > 2 && message[0] == 'REQ') {
      final subId = message[1] as String;
      reqs.add(subId);
      final kinds = (message[2] as Map)['kinds'] as List?;
      final isPage = kinds?.contains(EventKind.textNote) ?? false;
      final after = isPage ? answerAfter : othersAfter;
      if (after != null) {
        // One frame per timer, as a socket delivers them: the pool verifies
        // each EVENT asynchronously before the EOSE that follows it.
        if (isPage) {
          for (final event in events) {
            Timer(after, () => _deliver(['EVENT', subId, event.toJson()]));
          }
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

/// A relay that takes every REQ and never answers one, while its socket keeps
/// delivering a NOTICE every second, as one busy with other requests does.
class _BusyRelay extends Relay {
  _BusyRelay(String url) : super(url, RelayStatus(url));

  final List<String> reqs = [];
  Timer? _beat;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    _beat ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final dynamic result = onMessage!(this, ['NOTICE', 'busy']);
      if (result is Future) unawaited(result);
    });
    return true;
  }

  @override
  Future<void> disconnect() async {
    _beat?.cancel();
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
      reqs.add(message[1] as String);
    }
    return true;
  }
}

({NostrClient client, List<Relay> relays, RelayManager relayManager}) _client(
  FakeAsync async,
  List<Relay> relays,
) {
  final nostr = Nostr(LocalNostrSigner(_key), [], (url) {
    throw StateError('no temp relays in this test: $url');
  });
  for (final relay in relays) {
    unawaited(nostr.relayPool.add(relay));
  }
  async.flushMicrotasks();
  final urls = [for (final relay in relays) relay.url];
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(urls);
  when(() => relayManager.configuredRelays).thenReturn(urls);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  return (
    client: NostrClient.forTesting(nostr: nostr, relayManager: relayManager),
    relays: relays,
    relayManager: relayManager,
  );
}

final _page = Filter(kinds: const [EventKind.textNote]);

void main() {
  late List<Event> events;

  setUpAll(() {
    events = [
      for (var i = 0; i < 3; i++)
        Event(
          getPublicKey(_key),
          EventKind.textNote,
          const [],
          'note $i',
          createdAt: 1700000000 - i,
        )..sign(_key),
    ];
  });

  group('silentRelayTimeout', () {
    test('queryEventsDetailed ends a capped read on a relay that stays '
        'silent', () {
      fakeAsync((async) {
        final h = _client(async, [
          _Relay(_answeringUrl, events: events),
          _Relay(_otherUrl, events: const [], answerAfter: null),
        ]);
        ({List<Event> events, bool timedOut, bool noRelays})? result;
        final start = async.elapsed;
        Duration? took;
        unawaited(
          h.client
              .queryEventsDetailed(
                [_page],
                useCache: false,
                timeout: const Duration(seconds: 60),
                requireAllRelaysSettled: true,
                silentRelayTimeout: const Duration(seconds: 10),
              )
              .then((r) {
                result = r;
                took = async.elapsed - start;
              }),
        );
        async.elapse(const Duration(seconds: 70));

        expect(result!.timedOut, isTrue);
        expect(result!.events, hasLength(3));
        expect(took, lessThan(const Duration(seconds: 12)));
      });
    });

    test('readEvents ends a capped read on a relay that stays silent', () {
      fakeAsync((async) {
        final h = _client(async, [
          _Relay(_answeringUrl, events: events),
          _Relay(_otherUrl, events: const [], answerAfter: null),
        ]);
        QueryResult? result;
        final start = async.elapsed;
        Duration? took;
        unawaited(
          h.client
              .readEvents(
                [_page],
                useCache: false,
                timeout: const Duration(seconds: 60),
                requireAllRelaysSettled: true,
                silentRelayTimeout: const Duration(seconds: 10),
              )
              .then((r) {
                result = r;
                took = async.elapsed - start;
              }),
        );
        async.elapse(const Duration(seconds: 70));

        expect(result!.isComplete, isFalse);
        expect(took, lessThan(const Duration(seconds: 12)));
      });
    });
  });

  group('query slot wait under a long cap', () {
    test('a capped read reaches the relay once feed reads free their slots, '
        'and completes, however long past its silence bound it waited', () {
      fakeAsync((async) {
        // Held past the 10 s bound: a slot wait counts against the cap, never
        // as a relay's silence.
        final relay = _Relay(
          _answeringUrl,
          events: events,
          othersAfter: const Duration(seconds: 15),
        );
        final h = _client(async, [relay]);
        for (var i = 0; i < NostrClient.maxConcurrentQueries; i++) {
          unawaited(
            h.client.readEvents(
              [
                Filter(kinds: const [EventKind.contactList]),
              ],
              useCache: false,
              timeout: const Duration(seconds: 30),
            ),
          );
        }
        async.flushMicrotasks();
        ({List<Event> events, bool timedOut, bool noRelays})? result;
        unawaited(
          h.client
              .queryEventsDetailed(
                [_page],
                subscriptionId: 'history_page',
                useCache: false,
                timeout: const Duration(seconds: 60),
                requireAllRelaysSettled: true,
                silentRelayTimeout: const Duration(seconds: 10),
              )
              .then((r) => result = r),
        );
        async.elapse(const Duration(seconds: 70));

        expect(relay.reqs, contains('history_page'));
        expect(result!.timedOut, isFalse);
        expect(result!.events, hasLength(3));
      });
    });
  });

  group('dispose with long reads in flight', () {
    test('completes at once, though one long read was still waiting for a '
        'query slot', () {
      fakeAsync((async) {
        final relay = _BusyRelay(_answeringUrl);
        final h = _client(async, [relay]);
        Future<void> longRead(String id) => h.client.queryEventsDetailed(
          [_page],
          subscriptionId: id,
          useCache: false,
          timeout: const Duration(seconds: 60),
          requireAllRelaysSettled: true,
          silentRelayTimeout: const Duration(seconds: 10),
        );
        for (var i = 0; i < NostrClient.maxConcurrentQueries; i++) {
          unawaited(longRead('in_flight_$i'));
        }
        async.flushMicrotasks();
        unawaited(longRead('queued'));
        async.elapse(const Duration(seconds: 2));

        var disposed = false;
        unawaited(h.client.dispose().then((_) => disposed = true));
        async.elapse(const Duration(seconds: 1));

        expect(disposed, isTrue);
        expect(relay.reqs, isNot(contains('queued')));
        async.elapse(const Duration(seconds: 70));
      });
    });
  });

  group('reads in a ReadScope', () {
    test('a read waiting for a query slot ends at once when its scope ends, '
        'and is never sent', () {
      fakeAsync((async) {
        // Feed reads outside the scope hold every slot for 30 s.
        final relay = _Relay(
          _answeringUrl,
          events: events,
          othersAfter: const Duration(seconds: 30),
        );
        final h = _client(async, [relay]);
        for (var i = 0; i < NostrClient.maxConcurrentQueries; i++) {
          unawaited(
            h.client.readEvents(
              [
                Filter(kinds: const [EventKind.contactList]),
              ],
              useCache: false,
              timeout: const Duration(seconds: 40),
            ),
          );
        }
        async.flushMicrotasks();
        final scope = ReadScope();
        Duration? took;
        final start = async.elapsed;
        unawaited(
          scope
              .run(
                () => h.client.readEvents(
                  [_page],
                  subscriptionId: 'queued',
                  useCache: false,
                  timeout: const Duration(seconds: 60),
                  requireAllRelaysSettled: true,
                  silentRelayTimeout: const Duration(seconds: 10),
                ),
              )
              .then((_) => took = async.elapsed - start),
        );
        async.elapse(const Duration(seconds: 2));

        scope.end();
        async.flushMicrotasks();

        expect(took, isNotNull);
        expect(took, lessThan(const Duration(seconds: 3)));
        async.elapse(const Duration(seconds: 70));
        expect(relay.reqs, isNot(contains('queued')));
      });
    });

    test('a read waiting for relays to reconnect ends at once when its scope '
        'ends', () {
      fakeAsync((async) {
        final relay = _Relay(_answeringUrl, events: events);
        final h = _client(async, [relay]);
        final relayManager = h.relayManager;
        when(() => relayManager.connectedRelays).thenReturn(const []);
        when(
          relayManager.retryDisconnectedRelays,
        ).thenAnswer((_) => Completer<void>().future);
        final scope = ReadScope();
        Duration? took;
        final start = async.elapsed;
        unawaited(
          scope
              .run(
                () => h.client.readEvents(
                  [_page],
                  subscriptionId: 'reconnecting',
                  useCache: false,
                  timeout: const Duration(seconds: 60),
                  requireAllRelaysSettled: true,
                  silentRelayTimeout: const Duration(seconds: 10),
                ),
              )
              .then((_) => took = async.elapsed - start),
        );
        async.elapse(const Duration(seconds: 2));

        scope.end();
        async.flushMicrotasks();

        expect(took, isNotNull);
        expect(took, lessThan(const Duration(seconds: 3)));
        async.elapse(const Duration(seconds: 70));
        expect(relay.reqs, isNot(contains('reconnecting')));
      });
    });
  });
}
