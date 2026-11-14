// ABOUTME: A full-settlement read can wait for a relay that is still answering
// ABOUTME: and give up only on one whose socket has gone silent (#9472).

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

const _key = '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

/// When a relay starts answering a REQ, how far apart its events arrive, and
/// whether EOSE follows them.
typedef _Answer = ({Duration first, Duration every, bool eose});

/// A relay that answers every REQ with [events] on the [answer] schedule, and
/// can send a NOTICE every [busyEvery], standing in for the frames it sends
/// the client's other subscriptions on the same socket.
///
/// Like a real socket it delivers nothing once disconnected, and it reports
/// each connection change through [Relay.relayStatusCallback], as `RelayBase`
/// does.
class _ScheduledRelay extends Relay {
  _ScheduledRelay(
    String url, {
    required this.events,
    required this.answer,
    this.busyEvery,
  }) : super(url, RelayStatus(url));

  final List<Event> events;
  final _Answer answer;
  final Duration? busyEvery;
  final List<Timer> _timers = [];

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    relayStatusCallback?.call();
    final every = busyEvery;
    if (every != null) {
      _timers.add(Timer.periodic(every, (_) => _deliver(['NOTICE', 'busy'])));
    }
    return true;
  }

  @override
  Future<void> disconnect() async {
    stop();
    relayStatus.connected = ClientConnected.disconnect;
    relayStatusCallback?.call();
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.length > 1 && message[0] == 'REQ') {
      final subId = message[1] as String;
      var at = answer.first;
      for (final event in events) {
        final frame = ['EVENT', subId, event.toJson()];
        _timers.add(Timer(at, () => _deliver(frame)));
        at += answer.every;
      }
      if (answer.eose) {
        _timers.add(Timer(at, () => _deliver(['EOSE', subId])));
      }
    }
    return true;
  }

  void stop() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _deliver(List<dynamic> frame) {
    final dynamic result = onMessage!(this, frame);
    if (result is Future) unawaited(result);
  }
}

/// [count] signed kind-1 events, newest first.
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

/// A [Nostr] whose pool holds [relays], connected, inside [async].
Nostr _nostr(
  FakeAsync async,
  List<Relay> relays, {
  RelayDiagnosticsSink? diagnosticsSink,
}) {
  final nostr = Nostr(
    LocalNostrSigner(_key),
    [],
    (url) => throw StateError('no temp relays in this test: $url'),
    diagnosticsSink: diagnosticsSink,
  );
  for (final relay in relays) {
    unawaited(nostr.relayPool.add(relay));
  }
  async.flushMicrotasks();
  return nostr;
}

/// A read in progress: [result] and [took] fill in when it ends.
class _PendingRead {
  QueryResult? result;
  Duration? took;
}

/// Starts the read under test, a full-settlement read capped at 60 s.
_PendingRead _startRead(
  FakeAsync async,
  Nostr nostr, {
  Duration silentRelayTimeout = const Duration(seconds: 10),
}) {
  final read = _PendingRead();
  final start = async.elapsed;
  unawaited(
    nostr
        .readEvents(
          [
            Filter(kinds: const [EventKind.textNote]).toJson(),
          ],
          id: 'history_page',
          timeout: const Duration(seconds: 60),
          requireAllRelaysSettled: true,
          silentRelayTimeout: silentRelayTimeout,
        )
        .then((r) {
          read
            ..result = r
            ..took = async.elapsed - start;
        }),
  );
  return read;
}

/// Reads through a pool holding [relays] and reports how the read ended and
/// when.
({QueryResult result, Duration took}) _read(
  FakeAsync async,
  List<_ScheduledRelay> relays,
) {
  final read = _startRead(async, _nostr(async, relays));
  async.elapse(const Duration(seconds: 90));
  for (final relay in relays) {
    relay.stop();
  }
  return (result: read.result!, took: read.took!);
}

void main() {
  late List<Event> events;

  setUpAll(() => events = _events(100));

  group('Nostr.readEvents silentRelayTimeout', () {
    test('ends the read once a relay has sent nothing at all for the '
        'silence bound, well before the deadline', () {
      fakeAsync((async) {
        final answering = _ScheduledRelay(
          'wss://answering.example',
          events: events,
          answer: (first: Duration.zero, every: Duration.zero, eose: true),
        );
        final silent = _ScheduledRelay(
          'wss://silent.example',
          events: const [],
          answer: (first: Duration.zero, every: Duration.zero, eose: false),
        );

        final read = _read(async, [answering, silent]);

        expect(read.result.isComplete, isFalse);
        expect(read.result.endedBy, QueryEnd.deadline);
        expect(read.took, lessThan(const Duration(seconds: 12)));
        expect(read.took, greaterThanOrEqualTo(const Duration(seconds: 10)));
      });
    });

    test('waits for a relay whose socket keeps delivering other frames, '
        'until it answers this read', () {
      fakeAsync((async) {
        final queued = _ScheduledRelay(
          'wss://queued.example',
          events: events,
          answer: (
            first: const Duration(seconds: 20),
            every: Duration.zero,
            eose: true,
          ),
          busyEvery: const Duration(seconds: 1),
        );

        final read = _read(async, [queued]);

        expect(read.result.isComplete, isTrue);
        expect(read.result.events, hasLength(100));
        expect(read.took, greaterThanOrEqualTo(const Duration(seconds: 20)));
      });
    });

    test('does not count a relay streaming this read as silent', () {
      fakeAsync((async) {
        final streaming = _ScheduledRelay(
          'wss://streaming.example',
          events: events.take(10).toList(),
          answer: (
            first: const Duration(seconds: 3),
            every: const Duration(seconds: 3),
            eose: true,
          ),
        );

        final read = _read(async, [streaming]);

        expect(read.result.isComplete, isTrue);
        expect(read.result.events, hasLength(10));
        expect(read.took, greaterThanOrEqualTo(const Duration(seconds: 30)));
      });
    });

    test('does not count a relay that already answered as silent while '
        'another is still streaming', () {
      fakeAsync((async) {
        final answered = _ScheduledRelay(
          'wss://answered.example',
          events: events.take(5).toList(),
          answer: (first: Duration.zero, every: Duration.zero, eose: true),
        );
        final streaming = _ScheduledRelay(
          'wss://streaming.example',
          events: events.skip(5).take(10).toList(),
          answer: (
            first: const Duration(seconds: 3),
            every: const Duration(seconds: 3),
            eose: true,
          ),
        );

        final read = _read(async, [answered, streaming]);

        expect(read.result.isComplete, isTrue);
        expect(read.result.events, hasLength(15));
        expect(read.took, greaterThanOrEqualTo(const Duration(seconds: 30)));
      });
    });

    test('counts a relay replaced in the pool before it answered as '
        'silent, even while its replacement keeps sending', () {
      fakeAsync((async) {
        const url = 'wss://replaced.example';
        // Streams until 8 s, so its own last frame would keep it inside the
        // bound until 18 s; leaving the pool at 9 s is what ends the read.
        final original = _ScheduledRelay(
          url,
          events: events.take(9).toList(),
          answer: (
            first: Duration.zero,
            every: const Duration(seconds: 1),
            eose: false,
          ),
        );
        final nostr = _nostr(async, [original]);
        final read = _startRead(async, nostr);
        async.elapse(const Duration(seconds: 9));
        // What the relay manager does on resume: drop the relay object and
        // add a fresh one for the url. The REQ stays with the old object.
        final replacement = _ScheduledRelay(
          url,
          events: const [],
          answer: (first: Duration.zero, every: Duration.zero, eose: false),
          busyEvery: const Duration(seconds: 1),
        );
        nostr.relayPool.remove(url);
        unawaited(nostr.relayPool.add(replacement));

        async.elapse(const Duration(seconds: 81));
        replacement.stop();

        expect(read.result!.isComplete, isFalse);
        expect(read.result!.events, hasLength(9));
        expect(read.took, lessThan(const Duration(seconds: 12)));
      });
    });

    test('restarts the silence bound when a relay reconnects and takes the '
        'read again', () {
      fakeAsync((async) {
        final flapping = _ScheduledRelay(
          'wss://flapping.example',
          events: events.take(5).toList(),
          answer: (
            first: const Duration(seconds: 6),
            every: Duration.zero,
            eose: true,
          ),
        );
        final read = _startRead(async, _nostr(async, [flapping]));
        async.elapse(const Duration(seconds: 2));
        unawaited(flapping.disconnect());
        async.elapse(const Duration(seconds: 7));
        // The reconnect re-issues the saved REQ, which the relay answers
        // 6 s later, at 15 s: past the bound counted from the read's start.
        unawaited(flapping.connect());

        async.elapse(const Duration(seconds: 81));
        flapping.stop();

        expect(read.result!.isComplete, isTrue);
        expect(read.result!.events, hasLength(5));
        expect(read.took, greaterThanOrEqualTo(const Duration(seconds: 15)));
      });
    });

    test('ends the read when its client begins closing', () {
      fakeAsync((async) {
        final streaming = _ScheduledRelay(
          'wss://streaming.example',
          events: events.take(10).toList(),
          answer: (
            first: const Duration(seconds: 3),
            every: const Duration(seconds: 3),
            eose: true,
          ),
        );
        final nostr = _nostr(async, [streaming]);
        final read = _startRead(async, nostr);
        async.elapse(const Duration(seconds: 5));

        nostr.beginClose();
        async.flushMicrotasks();

        expect(read.result, isNotNull);
        expect(read.result!.isComplete, isFalse);
        expect(read.result!.events, hasLength(1));
        expect(read.took, lessThan(const Duration(seconds: 6)));
        async.elapse(const Duration(seconds: 60));
        streaming.stop();
      });
    });

    test("names the silent relay and the bound in the read's completion "
        'line', () {
      fakeAsync((async) {
        final lines = <RelayDiagnostic>[];
        final answering = _ScheduledRelay(
          'wss://answering.example',
          events: events.take(5).toList(),
          answer: (first: Duration.zero, every: Duration.zero, eose: true),
        );
        final silent = _ScheduledRelay(
          'wss://silent.example',
          events: const [],
          answer: (first: Duration.zero, every: Duration.zero, eose: false),
        );
        final read = _startRead(
          async,
          _nostr(async, [answering, silent], diagnosticsSink: lines.add),
        );

        async.elapse(const Duration(seconds: 90));
        answering.stop();
        silent.stop();

        expect(read.result!.isComplete, isFalse);
        final completion = lines.where(
          (line) =>
              line.site == RelayDiagnosticSite.queryCompletion &&
              line.message.contains('history_page'),
        );
        expect(completion, hasLength(1));
        expect(
          completion.single.message,
          contains('silent: wss://silent.example sent nothing for 10000ms'),
        );
      });
    });

    test('leaves no silence timer behind once the read has finished', () {
      fakeAsync((async) {
        final answering = _ScheduledRelay(
          'wss://answering.example',
          events: events.take(5).toList(),
          answer: (
            first: const Duration(seconds: 2),
            every: Duration.zero,
            eose: true,
          ),
        );
        final nostr = _nostr(async, [answering]);
        final periodicBefore = async.periodicTimerCount;

        final read = _startRead(async, nostr);
        async.elapse(const Duration(seconds: 5));

        expect(read.result!.isComplete, isTrue);
        expect(async.periodicTimerCount, periodicBefore);
        answering.stop();
      });
    });

    test('still ends at the deadline when a relay never finishes', () {
      fakeAsync((async) {
        final endless = _ScheduledRelay(
          'wss://endless.example',
          events: events,
          answer: (
            first: Duration.zero,
            every: const Duration(seconds: 1),
            eose: false,
          ),
        );

        final read = _read(async, [endless]);

        expect(read.result.isComplete, isFalse);
        expect(read.result.endedBy, QueryEnd.deadline);
        expect(read.took, greaterThanOrEqualTo(const Duration(seconds: 60)));
        expect(read.took, lessThan(const Duration(seconds: 61)));
      });
    });

    test('rejects a silence bound that is not positive', () async {
      final nostr = Nostr(
        LocalNostrSigner(_key),
        [],
        (url) => throw StateError('no temp relays in this test: $url'),
      );

      await expectLater(
        nostr.readEvents([
          Filter(kinds: const [EventKind.textNote]).toJson(),
        ], silentRelayTimeout: Duration.zero),
        throwsArgumentError,
      );
    });
  });
}
