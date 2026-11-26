// ABOUTME: Edges of a relay replacement taking over a read (#11343): a
// ABOUTME: dial in progress, late frames, a lost sibling, recounted answers.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _a = 'wss://a.example';
const _b = 'wss://b.example';

/// A relay that reports `connecting` for [dial], then answers every REQ with
/// [events], one every [every] from [first], and EOSE when [eose] is set or
/// CLOSED when [closeReason] is set.
class _Relay extends Relay {
  _Relay(
    String url, {
    this.events = const [],
    this.first = Duration.zero,
    this.every = Duration.zero,
    this.eose = false,
    this.closeReason,
    this.dial = Duration.zero,
    this.connects = true,
    this.reqWriteTakes = Duration.zero,
  }) : super(url, RelayStatus(url));

  final List<Event> events;
  final Duration first;
  final Duration every;
  final bool eose;
  final String? closeReason;
  final Duration dial;
  final bool connects;

  /// How long writing a `REQ` takes, as on a socket that is reconnecting.
  /// The write finishes even if the relay is disconnected meanwhile.
  final Duration reqWriteTakes;
  final List<String> reqs = [];
  final List<Timer> _timers = [];
  bool _open = false;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connecting;
    _report();
    if (dial > Duration.zero) {
      final dialled = Completer<void>();
      _timers.add(Timer(dial, dialled.complete));
      await dialled.future;
    }
    if (!connects) {
      relayStatus.connected = ClientConnected.disconnect;
      _report();
      return false;
    }
    _open = true;
    relayStatus.connected = ClientConnected.connected;
    _report();
    return true;
  }

  @override
  Future<void> disconnect() async {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    _open = false;
    relayStatus.connected = ClientConnected.disconnect;
    _report();
  }

  void _report() {
    final callback = relayStatusCallback;
    if (callback is void Function()) callback();
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (!_open) return false;
    if (message.length > 1 && message[0] == 'REQ') {
      final subId = message[1] as String;
      reqs.add(subId);
      if (reqWriteTakes > Duration.zero) {
        final written = Completer<void>();
        Timer(reqWriteTakes, written.complete);
        await written.future;
        return true;
      }
      var at = first;
      for (final event in events) {
        _timers.add(
          Timer(at, () => _deliver(['EVENT', subId, event.toJson()])),
        );
        at += every;
      }
      if (closeReason != null) {
        _timers.add(Timer(at, () => _deliver(['CLOSED', subId, closeReason!])));
      } else if (eose) {
        _timers.add(Timer(at, () => _deliver(['EOSE', subId])));
      }
    }
    return true;
  }

  void _deliver(List<dynamic> frame) {
    if (!_open) return;
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

/// Verifies every event, [delay] after it is asked to.
class _SlowWorker implements EventVerifyWorker {
  _SlowWorker(this.delay);

  final Duration delay;

  @override
  Future<bool> verify(Map<String, dynamic> eventJson) {
    final verified = Completer<bool>();
    Timer(delay, () => verified.complete(true));
    return verified.future;
  }

  @override
  void close() {}
}

List<Event> _events(int count) => [
  for (var i = 0; i < count; i++)
    Event(
      getPublicKey(_key),
      EventKind.textNote,
      const [],
      'note $i',
      createdAt: 1700000000 - i,
    )..sign(_key),
];

class _Rig {
  _Rig(this.async, List<Relay> relays) {
    nostr = Nostr(
      LocalNostrSigner(_key),
      [],
      (url) => throw StateError('no temp relays in this test: $url'),
      diagnosticsSink: lines.add,
    );
    for (final relay in relays) {
      unawaited(nostr.relayPool.add(relay));
    }
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final List<RelayDiagnostic> lines = [];
  late final Nostr nostr;
  QueryResult? result;
  Duration? tookFor;

  void read({
    int? limit,
    bool full = false,
    Duration? silentRelayTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) {
    unawaited(
      nostr
          .readEvents(
            [
              Filter(kinds: const [EventKind.textNote], limit: limit).toJson(),
            ],
            id: 'page',
            timeout: timeout,
            requireAllRelaysSettled: full,
            silentRelayTimeout: silentRelayTimeout,
          )
          .then((value) {
            result = value;
            tookFor = async.elapsed;
          }),
    );
    async.flushMicrotasks();
  }

  /// What `RelayManager` does on a forced reconnect, for one url.
  void replace(String url, Relay replacement) {
    nostr.relayPool.remove(url);
    unawaited(nostr.relayPool.add(replacement, autoSubscribe: true));
  }

  Iterable<String> get messages => lines.map((line) => line.message);
}

void main() {
  group('$RelayPool relay replacement taking over a read (#11343)', () {
    test(
      'a read bounded by silence waits for a replacement still dialling',
      () {
        fakeAsync((async) {
          final events = _events(15);
          final rig = _Rig(async, [
            _Relay(_a, events: events, every: const Duration(seconds: 1)),
          ])..read(full: true, silentRelayTimeout: const Duration(seconds: 10));
          async.elapse(const Duration(seconds: 15));
          expect(rig.result, isNull);

          final replacement = _Relay(
            _a,
            events: events,
            eose: true,
            dial: const Duration(seconds: 2),
          );
          rig.replace(_a, replacement);
          async.elapse(const Duration(seconds: 30));

          expect(replacement.reqs, ['page']);
          expect(rig.result?.endedBy, QueryEnd.complete);
          expect(rig.tookFor, const Duration(seconds: 17));
        });
      },
    );

    test('a frame from the old socket that lands after the replacement took '
        'over does not hand the read back to it', () {
      fakeAsync((async) {
        final events = _events(12);
        final rig = _Rig(async, [
          _Relay(_a, events: events, every: const Duration(seconds: 1)),
        ]);
        rig.nostr.relayPool.eventVerifyWorker = _SlowWorker(
          const Duration(milliseconds: 100),
        );
        rig.read(full: true, silentRelayTimeout: const Duration(seconds: 10));
        // The frame sent at 11 s is still being verified as the relay goes.
        async.elapse(const Duration(milliseconds: 11010));

        rig.replace(
          _a,
          _Relay(
            _a,
            events: events,
            first: const Duration(seconds: 3),
            eose: true,
          ),
        );
        async.elapse(const Duration(seconds: 30));

        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(
          rig.messages,
          isNot(contains(contains('left the pool before answering'))),
        );
      });
    });

    test('a REQ still being written by the replaced object when it leaves does '
        'not hand the read back to it', () {
      fakeAsync((async) {
        // A relay that challenged earlier in the session saves a read before
        // writing its REQ, so the read is handed over while the write is
        // still in flight on the old object.
        final old = _Relay(_a, reqWriteTakes: const Duration(seconds: 2))
          ..relayStatus.alwaysAuth = true;
        final rig = _Rig(async, [old])
          ..read(full: true, silentRelayTimeout: const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 500));

        final replacement = _Relay(
          _a,
          events: _events(3),
          first: const Duration(seconds: 10),
          eose: true,
        );
        rig.replace(_a, replacement);
        async.elapse(const Duration(seconds: 30));

        expect(replacement.reqs, ['page']);
        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(rig.result?.events, hasLength(3));
        expect(
          rig.messages,
          isNot(contains(contains('left the pool before answering'))),
        );
      });
    });

    test('a sibling whose redial fails does not cut short a replacement that '
        'answers later', () {
      fakeAsync((async) {
        final rig = _Rig(async, [_Relay(_a), _Relay(_b)])
          ..read(timeout: const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 1));

        rig
          ..replace(_a, _Relay(_a, connects: false))
          ..replace(
            _b,
            _Relay(
              _b,
              events: _events(3),
              first: const Duration(seconds: 2),
              eose: true,
            ),
          );
        async.elapse(const Duration(seconds: 20));

        expect(rig.result?.events, hasLength(3));
        expect(rig.tookFor, const Duration(seconds: 3));
      });
    });

    test('a sibling removed with nothing replacing it does not cut short a '
        'relay that answers later', () {
      fakeAsync((async) {
        final rig = _Rig(async, [
          _Relay(_a),
          _Relay(
            _b,
            events: _events(3),
            first: const Duration(seconds: 3),
            eose: true,
          ),
        ])..read(timeout: const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 1));

        rig.nostr.relayPool.remove(_a);
        async.elapse(const Duration(seconds: 20));

        expect(rig.result?.events, hasLength(3));
        expect(rig.tookFor, const Duration(seconds: 3));
      });
    });

    test('a re-asked read counts only the new socket answer', () {
      fakeAsync((async) {
        final events = _events(6);
        final rig = _Rig(async, [_Relay(_a, events: events)])
          ..read(limit: 10, full: true, timeout: const Duration(seconds: 10));
        async.elapse(const Duration(seconds: 1));

        rig.replace(_a, _Relay(_a, events: events, eose: true));
        async.elapse(const Duration(seconds: 5));

        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(rig.result?.events, hasLength(6));
        expect(rig.result?.possiblyCapped, isFalse);
      });
    });

    test('a silent replacement after an in-flight REQ takeover still hits '
        'silentRelayTimeout', () {
      fakeAsync((async) {
        final old = _Relay(_a, reqWriteTakes: const Duration(seconds: 2))
          ..relayStatus.alwaysAuth = true;
        final rig = _Rig(async, [old])
          ..read(
            full: true,
            silentRelayTimeout: const Duration(seconds: 10),
            timeout: const Duration(seconds: 60),
          );
        async.elapse(const Duration(milliseconds: 500));

        final replacement = _Relay(_a);
        rig.replace(_a, replacement);
        async.elapse(const Duration(seconds: 30));

        expect(replacement.reqs, ['page']);
        expect(rig.result?.endedBy, QueryEnd.deadline);
        expect(rig.tookFor, lessThan(const Duration(seconds: 12)));
        expect(
          rig.messages,
          contains(contains('silent: $_a sent nothing for 10000ms')),
        );
      });
    });

    test('a failed replacement after an in-flight REQ takeover reports '
        'socketDropped', () {
      fakeAsync((async) {
        final old = _Relay(_a, reqWriteTakes: const Duration(seconds: 2))
          ..relayStatus.alwaysAuth = true;
        final rig = _Rig(async, [old])
          ..read(full: true, timeout: const Duration(seconds: 60));
        async.elapse(const Duration(milliseconds: 500));

        rig.replace(_a, _Relay(_a, connects: false));
        async.elapse(const Duration(seconds: 2));

        expect(rig.result?.endedBy, QueryEnd.socketDropped);
        expect(rig.tookFor, const Duration(seconds: 2));
      });
    });

    test('a late EOSE from the replaced relay behind a verifying event does '
        'not cut short the replacement on a default read', () {
      fakeAsync((async) {
        final events = _events(3);
        final old = _Relay(_a, events: [events.first], eose: true);
        final rig = _Rig(async, [old])
          ..nostr.relayPool.eventVerifyWorker = _SlowWorker(
            const Duration(milliseconds: 100),
          )
          ..read(full: false, timeout: const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 10));

        rig.replace(
          _a,
          _Relay(
            _a,
            events: events,
            first: const Duration(seconds: 3),
            eose: true,
          ),
        );
        async.elapse(const Duration(seconds: 10));

        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(rig.result?.events, hasLength(3));
        expect(rig.tookFor, lessThan(const Duration(seconds: 4)));
      });
    });

    test('a late CLOSED from the replaced relay behind a verifying event does '
        'not cut short the replacement on a default read', () {
      fakeAsync((async) {
        final events = _events(3);
        final old = _Relay(
          _a,
          events: [events.first],
          closeReason: 'shutting-down',
        );
        final rig = _Rig(async, [old])
          ..nostr.relayPool.eventVerifyWorker = _SlowWorker(
            const Duration(milliseconds: 100),
          )
          ..read(full: false, timeout: const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 10));

        rig.replace(
          _a,
          _Relay(
            _a,
            events: events,
            first: const Duration(seconds: 3),
            eose: true,
          ),
        );
        async.elapse(const Duration(seconds: 10));

        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(rig.result?.events, hasLength(3));
      });
    });

    test('a late auth-required CLOSED from the replaced relay does not shut '
        'the replacement auth gate', () {
      fakeAsync((async) {
        final events = _events(3);
        final old = _Relay(
          _a,
          events: [events.first],
          closeReason: 'auth-required: sign in',
        );
        final sibling = _Relay(
          _b,
          first: const Duration(milliseconds: 200),
          eose: true,
        );
        final rig = _Rig(async, [old, sibling])
          ..nostr.relayPool.eventVerifyWorker = _SlowWorker(
            const Duration(milliseconds: 100),
          )
          ..read(full: false, timeout: const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 10));

        final replacement = _Relay(
          _a,
          events: events,
          first: const Duration(milliseconds: 500),
          eose: true,
        )..relayStatus.alwaysAuth = true;
        rig.replace(_a, replacement);
        async.elapse(const Duration(seconds: 10));

        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(rig.result?.events, hasLength(3));
      });
    });

    test('replacing a relay after a sibling already answered does not end '
        'the read before the replacement takes over', () {
      fakeAsync((async) {
        final events = _events(3);
        final rig = _Rig(async, [
          _Relay(_a),
          _Relay(_b, events: [events.first], eose: true),
        ])..read(full: false, timeout: const Duration(seconds: 10));
        async.elapse(const Duration(milliseconds: 200));

        rig.replace(
          _a,
          _Relay(
            _a,
            events: events,
            first: const Duration(milliseconds: 200),
            eose: true,
          ),
        );
        async.elapse(const Duration(seconds: 5));

        expect(rig.result?.endedBy, QueryEnd.complete);
        expect(rig.result?.events, hasLength(3));
      });
    });
  });
}
