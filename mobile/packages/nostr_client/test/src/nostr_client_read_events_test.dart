import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

class _MockRelayManager extends Mock implements RelayManager {}

class _MockAppDbClient extends Mock implements AppDbClient {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockNostrEventsDao extends Mock implements NostrEventsDao {}

class _FakeFilter extends Fake implements Filter {}

/// Hands the client one fixed walk, so the client's own handling of what the
/// pager returned can be exercised without a relay in the way.
class _StubPagerNostr extends Mock implements Nostr {
  _StubPagerNostr(this.walk);

  final PagedQueryResult walk;

  /// The deadline the client handed the pager, null until it has walked.
  DateTime? seenDeadline;

  @override
  Future<PagedQueryResult> readAllEvents(
    Map<String, dynamic> filter, {
    int pageSize = 500,
    int maxPages = 50,
    Duration pageTimeout = const Duration(seconds: 10),
    DateTime? deadline,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
  }) async {
    seenDeadline = deadline;
    return walk;
  }
}

/// A relay whose every frame the test writes by hand, so a read can be held
/// open past its deadline, closed mid-replay, or left silent on purpose.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url) : super(url, RelayStatus(url));

  /// Subscription ids of the `REQ`s this relay was sent, in order.
  final List<String> reqSubIds = [];

  /// The filters of each of those `REQ`s, in the same order.
  final List<List<Map<String, dynamic>>> reqFilters = [];

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
    if (message.isNotEmpty && message[0] == 'REQ' && message.length > 1) {
      reqSubIds.add(message[1] as String);
      reqFilters.add([
        for (final filter in message.skip(2)) filter as Map<String, dynamic>,
      ]);
    }
    return true;
  }

  Future<void> deliver(List<dynamic> json) async {
    final handler = onMessage;
    expect(handler, isNotNull, reason: 'RelayPool did not wire onMessage');
    final dynamic result = handler!(this, json);
    if (result is Future) await result;
  }

  /// Waits for the pool to register the [index]th `REQ` this relay was sent.
  Future<String> awaitReq(int index) async {
    for (var attempt = 0; attempt < 400; attempt++) {
      if (reqSubIds.length > index && checkQuery(reqSubIds[index])) {
        return reqSubIds[index];
      }
      await pumpEventQueue();
    }
    fail('RelayPool never registered a pending query at index $index');
  }
}

const _secretKey =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';

/// An author for events handed straight to the client by a stubbed pager.
/// Nothing verifies these, so only the shape has to be well-formed.
const _pubkey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Nostr _newNostr({RelayDiagnosticsSink? diagnosticsSink}) => Nostr(
  LocalNostrSigner(_secretKey),
  [],
  (url) => RelayBase(url, RelayStatus(url)),
  diagnosticsSink: diagnosticsSink,
);

Future<List<Event>> _signedNotes(Nostr nostr, int count) async {
  final pubkey = await nostr.ensurePublicKey();
  final base = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return [
    for (var i = 0; i < count; i++)
      (await nostr.nostrSigner.signEvent(
        Event(
          pubkey,
          EventKind.textNote,
          const [],
          'read-events-$i',
          createdAt: base - (i * 10),
        ),
      ))!,
  ];
}

NostrClient _clientOver(
  Nostr nostr, {
  required List<String> connectedRelays,
  AppDbClient? dbClient,
  RelayDiagnosticsSink? diagnosticsSink,
}) {
  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(connectedRelays);
  when(() => relayManager.diagnosticsSink).thenReturn(diagnosticsSink);
  when(relayManager.dispose).thenAnswer((_) async {});
  when(relayManager.retryDisconnectedRelays).thenAnswer((_) async {});
  return NostrClient.forTesting(
    nostr: nostr,
    relayManager: relayManager,
    dbClient: dbClient,
  );
}

Filter _textNotes() => Filter(kinds: const [EventKind.textNote]);

/// The `queryCompletion` entries in [lines], whoever filed them. The relay
/// pool also reports connection and dispatch activity into the same sink.
List<RelayDiagnostic> _completionLines(List<RelayDiagnostic> lines) => [
  for (final line in lines)
    if (line.site == RelayDiagnosticSite.queryCompletion) line,
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Event>[]);
  });

  group('NostrClient.readEvents', () {
    test(
      'keeps the events a relay already sent when the deadline fires',
      () async {
        final nostr = _newNostr();
        final relay = _ScriptedRelay('wss://slow.example');
        expect(await nostr.relayPool.add(relay), isTrue);
        final notes = await _signedNotes(nostr, 3);
        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://slow.example'],
        );

        final read = client.readEvents(
          [_textNotes()],
          useCache: false,
          timeout: const Duration(milliseconds: 400),
        );
        final subId = await relay.awaitReq(0);
        for (final note in notes) {
          await relay.deliver(['EVENT', subId, note.toJson()]);
        }

        final result = await read;

        expect(result.endedBy, QueryEnd.deadline);
        expect(result.isComplete, isFalse);
        expect(
          result.events.map((event) => event.id),
          unorderedEquals(notes.map((note) => note.id)),
          reason: 'the read was cut short, not emptied',
        );
      },
    );

    test('reports a CLOSED after a partial replay as relayClosed', () async {
      final nostr = _newNostr();
      final relay = _ScriptedRelay('wss://budget.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final notes = await _signedNotes(nostr, 3);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://budget.example'],
      );

      final read = client.readEvents(
        [_textNotes()],
        useCache: false,
        timeout: const Duration(seconds: 3),
      );
      final subId = await relay.awaitReq(0);
      for (final note in notes) {
        await relay.deliver(['EVENT', subId, note.toJson()]);
      }
      await relay.deliver(['CLOSED', subId, 'error: stored replay timed out']);

      final result = await read;

      expect(result.endedBy, QueryEnd.relayClosed);
      expect(result.events, hasLength(3));
    });

    test(
      'reports a relay skipped past the settle window as settledEarly',
      () async {
        final nostr = _newNostr();
        final answering = _ScriptedRelay('wss://answers.example');
        final silent = _ScriptedRelay('wss://silent.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(silent), isTrue);
        final notes = await _signedNotes(nostr, 2);
        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://answers.example', 'wss://silent.example'],
        );

        // Comfortably past RelayPool.querySettleWindow, so the silent relay
        // is skipped past rather than the whole read timing out.
        final read = client.readEvents(
          [_textNotes()],
          useCache: false,
          timeout: const Duration(seconds: 3),
        );
        final subId = await answering.awaitReq(0);
        await silent.awaitReq(0);
        for (final note in notes) {
          await answering.deliver(['EVENT', subId, note.toJson()]);
        }
        await answering.deliver(['EOSE', subId]);

        final result = await read;

        expect(result.endedBy, QueryEnd.settledEarly);
        expect(result.events, hasLength(2));
      },
    );

    test(
      'merges a cached row without making a cut-short read complete',
      () async {
        final nostr = _newNostr();
        final relay = _ScriptedRelay('wss://slow.example');
        expect(await nostr.relayPool.add(relay), isTrue);
        final notes = await _signedNotes(nostr, 2);
        final fromRelay = notes.first;
        final fromCache = notes.last;

        final dbClient = _MockAppDbClient();
        final database = _MockAppDatabase();
        final dao = _MockNostrEventsDao();
        when(() => dbClient.database).thenReturn(database);
        when(() => database.nostrEventsDao).thenReturn(dao);
        when(
          () => dao.getEventsByFilter(any()),
        ).thenAnswer((_) async => [fromCache]);
        when(() => dao.upsertEventsBatch(any())).thenAnswer((_) async {});

        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://slow.example'],
          dbClient: dbClient,
        );

        final read = client.readEvents(
          [_textNotes()],
          timeout: const Duration(milliseconds: 400),
        );
        final subId = await relay.awaitReq(0);
        await relay.deliver(['EVENT', subId, fromRelay.toJson()]);

        final result = await read;

        expect(
          result.endedBy,
          QueryEnd.deadline,
          reason: 'a cached row cannot finish a read the relays never finished',
        );
        expect(result.confirmedExhaustive, isFalse);
        expect(
          result.events.map((event) => event.id),
          unorderedEquals([fromRelay.id, fromCache.id]),
        );
      },
    );

    for (final settled in [false, true]) {
      test(
        'keeps the relays own ending when the snapshot listed none '
        '(requireAllRelaysSettled: $settled)',
        () async {
          // The pre-flight snapshot can be stale — a relay whose socket came
          // up since is still asked, and answers. Calling that read `noRelay`
          // would be untrue, and would make a full-settlement caller read a
          // settled answer as a timeout.
          final nostr = _newNostr();
          final relay = _ScriptedRelay('wss://late.example');
          expect(await nostr.relayPool.add(relay), isTrue);
          final notes = await _signedNotes(nostr, 1);
          final client = _clientOver(nostr, connectedRelays: const []);

          final read = client.readEvents(
            [_textNotes()],
            useCache: false,
            requireAllRelaysSettled: settled,
            timeout: const Duration(seconds: 3),
          );
          final detailed = client.queryEventsDetailed(
            [_textNotes()],
            useCache: false,
            requireAllRelaysSettled: settled,
            timeout: const Duration(seconds: 3),
          );
          for (final index in [0, 1]) {
            final subId = await relay.awaitReq(index);
            await relay.deliver(['EVENT', subId, notes.single.toJson()]);
            await relay.deliver(['EOSE', subId]);
          }

          expect((await read).endedBy, QueryEnd.complete);
          final flags = await detailed;
          expect(
            flags.noRelays,
            isTrue,
            reason: 'this client still knew of no connected relay',
          );
          expect(
            flags.timedOut,
            isFalse,
            reason: 'the relays answered and settled inside the budget',
          );
          expect(flags.events, hasLength(1));
        },
      );
    }

    test('maps a disposed client to noRelay', () async {
      final nostr = _newNostr();
      final client = _clientOver(nostr, connectedRelays: ['wss://a.example']);
      await client.dispose();

      final result = await client.readEvents([_textNotes()]);

      expect(result.endedBy, QueryEnd.noRelay);
      expect(result.events, isEmpty);
    });

    test('maps a query pool closed mid-call to deadline', () async {
      final nostr = _newNostr();
      final dbClient = _MockAppDbClient();
      final database = _MockAppDatabase();
      final dao = _MockNostrEventsDao();
      when(() => dbClient.database).thenReturn(database);
      when(() => database.nostrEventsDao).thenReturn(dao);
      final cacheGate = Completer<List<Event>>();
      when(
        () => dao.getEventsByFilter(any()),
      ).thenAnswer((_) => cacheGate.future);

      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://a.example'],
        dbClient: dbClient,
      );

      final pending = client.readEvents([_textNotes()]);
      await pumpEventQueue();
      await client.dispose();
      cacheGate.complete(const []);

      final result = await pending;

      expect(
        result.endedBy,
        QueryEnd.deadline,
        reason: 'the relays were reachable; only this one read was dropped',
      );
    });
  });

  group('NostrClient.queryEventsDetailed', () {
    test(
      'keeps the events a deadline cut short and still reports timedOut',
      () async {
        final nostr = _newNostr();
        final relay = _ScriptedRelay('wss://slow.example');
        expect(await nostr.relayPool.add(relay), isTrue);
        final notes = await _signedNotes(nostr, 3);
        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://slow.example'],
        );

        final read = client.queryEventsDetailed(
          [_textNotes()],
          useCache: false,
          timeout: const Duration(milliseconds: 400),
        );
        final subId = await relay.awaitReq(0);
        for (final note in notes) {
          await relay.deliver(['EVENT', subId, note.toJson()]);
        }

        final result = await read;

        expect(result.timedOut, isTrue);
        expect(result.noRelays, isFalse);
        expect(
          result.events.map((event) => event.id),
          unorderedEquals(notes.map((note) => note.id)),
          reason: '#6238: a timed-out read used to return an empty list',
        );
      },
    );

    test(
      'leaves a display read unflagged when the query pool closed',
      () async {
        // `endedBy` calls this a deadline because the read never ran, but the
        // flag has always told a display read that its cached fallback stands.
        final nostr = _newNostr();
        final dbClient = _MockAppDbClient();
        final database = _MockAppDatabase();
        final dao = _MockNostrEventsDao();
        when(() => dbClient.database).thenReturn(database);
        when(() => database.nostrEventsDao).thenReturn(dao);
        final cacheGate = Completer<List<Event>>();
        when(
          () => dao.getEventsByFilter(any()),
        ).thenAnswer((_) => cacheGate.future);

        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://a.example'],
          dbClient: dbClient,
        );

        final pending = client.queryEventsDetailed([_textNotes()]);
        await pumpEventQueue();
        await client.dispose();
        cacheGate.complete(const []);

        final result = await pending;

        expect(result.timedOut, isFalse);
        expect(result.noRelays, isFalse);
      },
    );

    test('reports a CLOSED-ended read as not timed out', () async {
      final nostr = _newNostr();
      final relay = _ScriptedRelay('wss://budget.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final notes = await _signedNotes(nostr, 1);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://budget.example'],
      );

      final read = client.queryEventsDetailed(
        [_textNotes()],
        useCache: false,
        timeout: const Duration(seconds: 3),
      );
      final subId = await relay.awaitReq(0);
      await relay.deliver(['EVENT', subId, notes.single.toJson()]);
      await relay.deliver(['CLOSED', subId, 'error: stored replay timed out']);

      final result = await read;

      expect(result.timedOut, isFalse);
      expect(result.noRelays, isFalse);
      expect(result.events, hasLength(1));
    });
  });

  group('NostrClient.queryEvents', () {
    test('returns the events a deadline cut short', () async {
      final nostr = _newNostr();
      final relay = _ScriptedRelay('wss://slow.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final notes = await _signedNotes(nostr, 3);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://slow.example'],
      );

      final read = client.queryEvents(
        [_textNotes()],
        useCache: false,
        timeout: const Duration(milliseconds: 400),
      );
      final subId = await relay.awaitReq(0);
      for (final note in notes) {
        await relay.deliver(['EVENT', subId, note.toJson()]);
      }

      expect(
        (await read).map((event) => event.id),
        unorderedEquals(notes.map((note) => note.id)),
      );
    });
  });

  group('NostrClient queryCompletion diagnostics', () {
    test('files one line for a read the relay pool never saw', () async {
      final lines = <RelayDiagnostic>[];
      final nostr = _newNostr(diagnosticsSink: lines.add);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://a.example'],
        diagnosticsSink: lines.add,
      );
      await client.dispose();

      await client.readEvents([_textNotes()]);

      final completions = _completionLines(lines);
      expect(completions, hasLength(1));
      expect(completions.single.relayUrl, 'nostr-client');
      expect(completions.single.level, RelayDiagnosticLevel.warning);
      expect(completions.single.message, contains('noRelay'));
      expect(completions.single.message, contains('kinds: [1]'));
    });

    test('files no line for a read the relay pool judged itself', () async {
      // Both the pool and the client report into this one sink, so a client
      // line for a read the pool already judged would show up as a second
      // entry rather than going unseen.
      final lines = <RelayDiagnostic>[];
      final nostr = _newNostr(diagnosticsSink: lines.add);
      final relay = _ScriptedRelay('wss://slow.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://slow.example'],
        diagnosticsSink: lines.add,
      );

      final read = client.readEvents(
        [_textNotes()],
        useCache: false,
        timeout: const Duration(milliseconds: 400),
      );
      await relay.awaitReq(0);
      final result = await read;

      expect(result.endedBy, QueryEnd.deadline);
      final completions = _completionLines(lines);
      expect(
        completions,
        hasLength(1),
        reason: 'the pool files this read; a client line double-counts it',
      );
      expect(
        completions.single.relayUrl,
        isNot('nostr-client'),
        reason: "the one line is the relay pool's own",
      );
    });
  });

  group('NostrClient.readAllEvents', () {
    test('walks two pages and stops on the empty page', () async {
      final nostr = _newNostr();
      final relay = _ScriptedRelay('wss://pages.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final notes = await _signedNotes(nostr, 2);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://pages.example'],
      );

      final walk = client.readAllEvents(_textNotes(), pageSize: 10);

      final firstPage = await relay.awaitReq(0);
      for (final note in notes) {
        await relay.deliver(['EVENT', firstPage, note.toJson()]);
      }
      await relay.deliver(['EOSE', firstPage]);

      final secondPage = await relay.awaitReq(1);
      await relay.deliver(['EOSE', secondPage]);

      final result = await walk;

      expect(result.pages, 2);
      expect(result.isComplete, isTrue);
      expect(result.stoppedBy, isNull);
      expect(
        result.events.map((event) => event.id),
        unorderedEquals(notes.map((note) => note.id)),
      );
      expect(
        relay.reqFilters[1].single['until'],
        notes.last.createdAt,
        reason: 'the second page resumes at the oldest event of the first',
      );
    });

    test('settles the relay set before the first page', () async {
      final nostr = _newNostr();
      final relay = _ScriptedRelay('wss://cold.example');
      expect(await nostr.relayPool.add(relay), isTrue);

      final relayManager = _MockRelayManager();
      var connected = false;
      when(
        () => relayManager.connectedRelays,
      ).thenAnswer((_) => connected ? ['wss://cold.example'] : <String>[]);
      when(() => relayManager.diagnosticsSink).thenReturn(null);
      when(relayManager.dispose).thenAnswer((_) async {});
      when(relayManager.retryDisconnectedRelays).thenAnswer((_) async {
        connected = true;
      });
      final client = NostrClient.forTesting(
        nostr: nostr,
        relayManager: relayManager,
      );

      final walk = client.readAllEvents(_textNotes(), pageSize: 10);
      final page = await relay.awaitReq(0);
      await relay.deliver(['EOSE', page]);

      final result = await walk;

      verify(relayManager.retryDisconnectedRelays).called(1);
      expect(result.pages, 1);
      expect(result.isComplete, isTrue);
    });

    test('drops a walked event that does not match the filter', () async {
      // The relay pool gates on the page filter, so a relay cannot put an
      // off-filter event into a walk; this pins the client's own re-check of
      // what the pager handed back, as the one-shot read leg is pinned too.
      final matching = Event(_pubkey, EventKind.textNote, const [], 'kept');
      final offFilter = Event(_pubkey, EventKind.reaction, const [], 'dropped');
      final nostr = _StubPagerNostr(
        PagedQueryResult(
          events: [offFilter, matching],
          isComplete: false,
          pages: 3,
          stoppedBy: QueryEnd.relayClosed,
        ),
      );
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://pages.example'],
      );

      final result = await client.readAllEvents(_textNotes());

      expect(
        result.events.map((event) => event.id),
        [matching.id],
        reason: 'the reaction was never asked for',
      );
      expect(
        (result.pages, result.isComplete, result.stoppedBy),
        (3, false, QueryEnd.relayClosed),
        reason: "how the walk went is the pager's account, not a re-derivation",
      );
    });

    test('bounds a walk given no timeout with a default budget', () async {
      // The walk holds a query-pool slot for its whole length, so omitting a
      // timeout must not leave it unbounded.
      final nostr = _StubPagerNostr(
        const PagedQueryResult(events: [], isComplete: true, pages: 1),
      );
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://pages.example'],
      );
      final before = DateTime.now();

      await client.readAllEvents(_textNotes());

      final deadline = nostr.seenDeadline;
      expect(deadline, isNotNull, reason: 'an omitted timeout still bounds it');
      expect(
        deadline!.difference(before).inSeconds,
        // The budget starts at the client's own `now`, so any stall between
        // the two lands above 120; the upper bound leaves room rather than
        // sitting on the expected value.
        inInclusiveRange(60, 180),
        reason: 'the default budget is minutes, not unbounded and not a page',
      );
    });

    test('leaves a walk asked for no bound unbounded', () async {
      final nostr = _StubPagerNostr(
        const PagedQueryResult(events: [], isComplete: true, pages: 1),
      );
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://pages.example'],
      );

      final result = await client.readAllEvents(_textNotes(), timeout: null);

      // Without this the test passes on a walk that never happened:
      // `seenDeadline` starts null, and every early return leaves it that way.
      expect(
        (result.pages, result.isComplete),
        (1, true),
        reason: 'the pager ran, so a null deadline is its account, not a skip',
      );
      expect(
        nostr.seenDeadline,
        isNull,
        reason: 'an explicit null still asks for maxPages and pageTimeout only',
      );
    });

    test('maps a disposed client to a noRelay stop', () async {
      final nostr = _newNostr();
      final client = _clientOver(nostr, connectedRelays: ['wss://a.example']);
      await client.dispose();

      final result = await client.readAllEvents(_textNotes());

      expect(result.pages, 0);
      expect(result.isComplete, isFalse);
      expect(result.stoppedBy, QueryEnd.noRelay);
      expect(result.events, isEmpty);
    });

    test('maps a query pool closed mid-walk to a deadline stop', () async {
      final nostr = _newNostr();
      final relayManager = _MockRelayManager();
      when(() => relayManager.connectedRelays).thenReturn(const []);
      when(() => relayManager.diagnosticsSink).thenReturn(null);
      when(relayManager.dispose).thenAnswer((_) async {});
      final reconnectGate = Completer<void>();
      when(
        relayManager.retryDisconnectedRelays,
      ).thenAnswer((_) => reconnectGate.future);
      final client = NostrClient.forTesting(
        nostr: nostr,
        relayManager: relayManager,
      );

      final walk = client.readAllEvents(_textNotes());
      await pumpEventQueue();
      await client.dispose();
      reconnectGate.complete();

      final result = await walk;

      expect(result.stoppedBy, QueryEnd.deadline);
      expect(result.pages, 0);
    });

    test('stops on the deadline when no query slot arrives in time', () async {
      final originalMax = NostrClient.maxConcurrentQueries;
      NostrClient.maxConcurrentQueries = 1;
      addTearDown(() => NostrClient.maxConcurrentQueries = originalMax);

      final nostr = _newNostr();
      final relay = _ScriptedRelay('wss://busy.example');
      expect(await nostr.relayPool.add(relay), isTrue);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://busy.example'],
      );

      // Holds the pool's only slot until its own deadline.
      final holding = client.readEvents(
        [_textNotes()],
        useCache: false,
        timeout: const Duration(milliseconds: 300),
      );
      await relay.awaitReq(0);

      final result = await client.readAllEvents(
        _textNotes(),
        timeout: Duration.zero,
      );

      expect(result.stoppedBy, QueryEnd.deadline);
      expect(result.pages, 0);
      expect(
        relay.reqSubIds,
        hasLength(1),
        reason: 'the walk that never got a slot must not have asked anything',
      );
      await holding;
    });

    test(
      'stops without asking when the budget is gone before page 1',
      () async {
        final nostr = _newNostr();
        final relay = _ScriptedRelay('wss://cold.example');
        expect(await nostr.relayPool.add(relay), isTrue);
        final relayManager = _MockRelayManager();
        when(() => relayManager.connectedRelays).thenReturn(const []);
        when(() => relayManager.diagnosticsSink).thenReturn(null);
        when(relayManager.dispose).thenAnswer((_) async {});
        final stalledReconnect = Completer<void>();
        addTearDown(() {
          if (!stalledReconnect.isCompleted) stalledReconnect.complete();
        });
        when(
          relayManager.retryDisconnectedRelays,
        ).thenAnswer((_) => stalledReconnect.future);
        final client = NostrClient.forTesting(
          nostr: nostr,
          relayManager: relayManager,
        );

        final result = await client.readAllEvents(
          _textNotes(),
          timeout: Duration.zero,
        );

        expect(result.pages, 0);
        expect(result.isComplete, isFalse);
        expect(
          result.stoppedBy,
          isNull,
          reason:
              'the pager itself saw the spent deadline and opened no page. '
              'A deadline stop here would mean the slot wait timed out first, '
              'which is the other test',
        );
        expect(
          relay.reqSubIds,
          isEmpty,
          reason: 'a walk with no budget left must not open a page',
        );
      },
    );
  });
}
