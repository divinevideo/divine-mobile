import 'dart:async';

import 'package:clock/clock.dart';
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

/// Answers each one-shot read with the next scripted [QueryResult], so the
/// client's settlement of a read can be tested without a relay pool. Records
/// the deadline each read was given, and lets a test spend clock time inside a
/// read through [onRead].
class _ScriptedReadsNostr extends Mock implements Nostr {
  _ScriptedReadsNostr(this.results, {this.onRead});

  final List<QueryResult> results;
  final void Function()? onRead;
  final List<DateTime?> deadlines = [];

  @override
  Future<QueryResult> readEvents(
    List<Map<String, dynamic>> filters, {
    String? id,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    Duration timeout = const Duration(seconds: 5),
    DateTime? deadline,
    bool requireAllRelaysSettled = false,
  }) async {
    deadlines.add(deadline);
    onRead?.call();
    return results[deadlines.length - 1];
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
      'keeps a prompt CLOSED inconclusive for strict legacy callers',
      () async {
        final nostr = _newNostr();
        final relay = _ScriptedRelay('wss://refuses.example');
        expect(await nostr.relayPool.add(relay), isTrue);
        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://refuses.example'],
        );

        final pending = client.queryEventsDetailed(
          [_textNotes()],
          useCache: false,
          timeout: const Duration(seconds: 2),
          requireAllRelaysSettled: true,
        );
        final subId = await relay.awaitReq(0);
        await relay.deliver([
          'CLOSED',
          subId,
          'error: unsupported filter',
        ]);

        final result = await pending;

        expect(result.events, isEmpty);
        expect(
          result.timedOut,
          isTrue,
          reason:
              'prompt transport completion must not make a refusal '
              'authoritative for compatibility callers',
        );
        expect(result.noRelays, isFalse);
      },
    );

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

    group('with acceptRelayClosedWhenOthersAnswered', () {
      late Nostr nostr;
      late _ScriptedRelay answering;
      late _ScriptedRelay refusing;
      late NostrClient client;

      setUp(() async {
        nostr = _newNostr();
        answering = _ScriptedRelay('wss://answers.example');
        refusing = _ScriptedRelay('wss://refuses.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(refusing), isTrue);
        client = _clientOver(
          nostr,
          connectedRelays: ['wss://answers.example', 'wss://refuses.example'],
        );
      });

      Future<({List<Event> events, bool timedOut, bool noRelays})> read({
        bool optIn = true,
        Duration timeout = const Duration(seconds: 3),
      }) => client.queryEventsDetailed(
        [_textNotes()],
        useCache: false,
        timeout: timeout,
        requireAllRelaysSettled: true,
        acceptRelayClosedWhenOthersAnswered: optIn,
      );

      /// Has the answering relay send EOSE and the refusing relay [reason] for
      /// the [reqIndex]th REQ each of them was sent.
      Future<void> answerAndRefuse(int reqIndex, String reason) async {
        final answeringSub = await answering.awaitReq(reqIndex);
        final refusingSub = await refusing.awaitReq(reqIndex);
        await answering.deliver(['EOSE', answeringSub]);
        await refusing.deliver(['CLOSED', refusingSub, reason]);
      }

      test('keeps a CLOSED refusal timed out without the opt-in', () async {
        final pending = read(optIn: false);
        await answerAndRefuse(0, 'error: unsupported request');

        expect((await pending).timedOut, isTrue);
      });

      test('settles once the same relay repeats an error: refusal', () async {
        final pending = read();
        await answerAndRefuse(0, 'error: unsupported request');
        await answerAndRefuse(1, 'error: unsupported request');

        expect((await pending).timedOut, isFalse);
        expect(answering.reqSubIds, hasLength(2));
        expect(refusing.reqSubIds, hasLength(2));
      });

      test(
        'settles once a relay repeats the strfry-style ERROR: auth-required '
        'refusal',
        () async {
          // strfry prefixes every CLOSED reason with "ERROR: ", so its NIP-42
          // refusal is categorised `error`, not `auth-required`.
          const reason =
              'ERROR: auth-required: requested filter requires authentication';
          final pending = read();
          await answerAndRefuse(0, reason);
          await answerAndRefuse(1, reason);

          expect((await pending).timedOut, isFalse);
          expect(refusing.reqSubIds, hasLength(2));
        },
      );

      for (final reason in const [
        'restricted: members only',
        'blocked: not accepting reads',
        'unsupported: filter contains unknown elements',
      ]) {
        test(
          'settles on the first read when the other relay refuses with '
          '"$reason"',
          () async {
            final pending = read();
            await answerAndRefuse(0, reason);

            expect((await pending).timedOut, isFalse);
            expect(answering.reqSubIds, hasLength(1));
            expect(refusing.reqSubIds, hasLength(1));
          },
        );
      }

      test('keeps an auth-required refusal timed out', () async {
        // The pool parks the query for its post-AUTH replay, so the read
        // runs to its deadline rather than settling on the refusal.
        final pending = read(timeout: const Duration(milliseconds: 800));
        await answerAndRefuse(0, 'auth-required: authenticate first');

        expect((await pending).timedOut, isTrue);
        expect(refusing.reqSubIds, hasLength(1));
      });

      test(
        'keeps the read timed out when another relay newly refuses with '
        'error: on the confirmation read',
        () async {
          final third = _ScriptedRelay('wss://third.example');
          expect(await nostr.relayPool.add(third), isTrue);
          client = _clientOver(
            nostr,
            connectedRelays: [
              'wss://answers.example',
              'wss://refuses.example',
              'wss://third.example',
            ],
          );

          final pending = read();
          for (final reqIndex in [0, 1]) {
            final thirdSub = await third.awaitReq(reqIndex);
            await answerAndRefuse(reqIndex, 'error: temporary failure');
            await third.deliver(
              reqIndex == 0
                  ? ['EOSE', thirdSub]
                  : ['CLOSED', thirdSub, 'error: temporary failure'],
            );
          }

          expect((await pending).timedOut, isTrue);
        },
      );
    });

    group('with acceptRelayClosedWhenOthersAnswered and a scripted pool', () {
      final start = DateTime.utc(2026, 9, 23, 12);
      const refusedWithError = QueryResult(
        events: [],
        endedBy: QueryEnd.relayClosed,
        answeredNetworkRelayCount: 1,
        closedRelayReasons: {'wss://refuses.example': 'error'},
      );

      Future<({List<Event> events, bool timedOut, bool noRelays})> readWith(
        _ScriptedReadsNostr nostr,
      ) =>
          _clientOver(
            nostr,
            connectedRelays: ['wss://answers.example', 'wss://refuses.example'],
          ).queryEventsDetailed(
            [_textNotes()],
            useCache: false,
            requireAllRelaysSettled: true,
            acceptRelayClosedWhenOthersAnswered: true,
          );

      test('spends one deadline across the confirmation read', () async {
        var now = start;
        final nostr = _ScriptedReadsNostr(
          [refusedWithError, refusedWithError],
          onRead: () => now = now.add(const Duration(seconds: 2)),
        );

        final result = await withClock(
          Clock(() => now),
          () => readWith(nostr),
        );

        expect(result.timedOut, isFalse);
        expect(nostr.deadlines, hasLength(2));
        expect(nostr.deadlines[1], equals(nostr.deadlines[0]));
      });

      test(
        'keeps an unconfirmed error: refusal timed out once the first read '
        'spent the budget',
        () async {
          var now = start;
          final nostr = _ScriptedReadsNostr(
            [refusedWithError, refusedWithError],
            onRead: () => now = now.add(const Duration(seconds: 5)),
          );

          final result = await withClock(
            Clock(() => now),
            () => readWith(nostr),
          );

          expect(result.timedOut, isTrue);
          expect(nostr.deadlines, hasLength(1));
        },
      );

      test('keeps a read with an unanswered relay timed out', () async {
        final nostr = _ScriptedReadsNostr([
          const QueryResult(
            events: [],
            endedBy: QueryEnd.relayClosed,
            answeredNetworkRelayCount: 1,
            unansweredRelayCount: 1,
            closedRelayReasons: {'wss://refuses.example': 'restricted'},
          ),
        ]);

        final result = await withClock(
          Clock(() => start),
          () => readWith(nostr),
        );

        expect(result.timedOut, isTrue);
        expect(nostr.deadlines, hasLength(1));
      });
    });

    test(
      'keeps a full page of distinct events across the confirmation read',
      () async {
        final nostr = _newNostr();
        final answering = _ScriptedRelay('wss://answers.example');
        final refusing = _ScriptedRelay('wss://refuses.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(refusing), isTrue);
        final notes = await _signedNotes(nostr, 2);
        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://answers.example', 'wss://refuses.example'],
        );

        final pending = client.queryEventsDetailed(
          [
            Filter(kinds: const [EventKind.textNote], limit: 2),
          ],
          useCache: false,
          timeout: const Duration(seconds: 3),
          requireAllRelaysSettled: true,
          acceptRelayClosedWhenOthersAnswered: true,
        );
        // Both reads draw the same page from the answering relay: the
        // confirmation re-asks every relay, not only the one that refused.
        for (final reqIndex in [0, 1]) {
          final answeringSub = await answering.awaitReq(reqIndex);
          final refusingSub = await refusing.awaitReq(reqIndex);
          for (final note in notes) {
            await answering.deliver(['EVENT', answeringSub, note.toJson()]);
          }
          await answering.deliver(['EOSE', answeringSub]);
          await refusing.deliver([
            'CLOSED',
            refusingSub,
            'error: unsupported request',
          ]);
        }
        final result = await pending;

        expect(result.timedOut, isFalse);
        expect(
          result.events.map((event) => event.id),
          unorderedEquals(notes.map((note) => note.id)),
          reason: 'a repeated event must not take a second slot on the page',
        );
      },
    );

    test(
      'makes no confirmation read when the read was not held for full '
      'settlement',
      () async {
        final nostr = _newNostr();
        final answering = _ScriptedRelay('wss://answers.example');
        final refusing = _ScriptedRelay('wss://refuses.example');
        expect(await nostr.relayPool.add(answering), isTrue);
        expect(await nostr.relayPool.add(refusing), isTrue);
        final client = _clientOver(
          nostr,
          connectedRelays: ['wss://answers.example', 'wss://refuses.example'],
        );

        // Without full settlement a refusal never reports `timedOut`, so a
        // second read could only spend the budget and risk turning it on.
        final pending = client.queryEventsDetailed(
          [_textNotes()],
          useCache: false,
          timeout: const Duration(milliseconds: 800),
          acceptRelayClosedWhenOthersAnswered: true,
        );
        final answeringSub = await answering.awaitReq(0);
        final refusingSub = await refusing.awaitReq(0);
        await answering.deliver(['EOSE', answeringSub]);
        await refusing.deliver([
          'CLOSED',
          refusingSub,
          'error: unsupported request',
        ]);
        final result = await pending;

        expect(result.timedOut, isFalse);
        expect(answering.reqSubIds, hasLength(1));
        expect(refusing.reqSubIds, hasLength(1));
      },
    );

    test('keeps the events of both reads when they differ', () async {
      final nostr = _newNostr();
      final answering = _ScriptedRelay('wss://answers.example');
      final refusing = _ScriptedRelay('wss://refuses.example');
      expect(await nostr.relayPool.add(answering), isTrue);
      expect(await nostr.relayPool.add(refusing), isTrue);
      final notes = await _signedNotes(nostr, 2);
      final client = _clientOver(
        nostr,
        connectedRelays: ['wss://answers.example', 'wss://refuses.example'],
      );

      final pending = client.queryEventsDetailed(
        [_textNotes()],
        useCache: false,
        timeout: const Duration(seconds: 3),
        requireAllRelaysSettled: true,
        acceptRelayClosedWhenOthersAnswered: true,
      );
      for (final (reqIndex, note) in notes.indexed) {
        final answeringSub = await answering.awaitReq(reqIndex);
        final refusingSub = await refusing.awaitReq(reqIndex);
        await answering.deliver(['EVENT', answeringSub, note.toJson()]);
        await answering.deliver(['EOSE', answeringSub]);
        await refusing.deliver([
          'CLOSED',
          refusingSub,
          'error: unsupported request',
        ]);
      }
      final result = await pending;

      expect(result.timedOut, isFalse);
      expect(
        result.events.map((event) => event.id),
        unorderedEquals(notes.map((note) => note.id)),
      );
    });

    group('keeps an opted-in read timed out', () {
      late Nostr nostr;
      late _ScriptedRelay first;
      late _ScriptedRelay second;
      late NostrClient client;

      setUp(() async {
        nostr = _newNostr();
        first = _ScriptedRelay('wss://first.example');
        second = _ScriptedRelay('wss://second.example');
        expect(await nostr.relayPool.add(first), isTrue);
        expect(await nostr.relayPool.add(second), isTrue);
        client = _clientOver(
          nostr,
          connectedRelays: ['wss://first.example', 'wss://second.example'],
        );
      });

      /// Starts an opted-in read once both relays hold its `REQ`; the record
      /// wraps the pending `timedOut` so `await` cannot flatten it.
      Future<({Future<bool> timedOut})> optedInRead({
        Duration timeout = const Duration(seconds: 3),
      }) async {
        final pending = client.queryEventsDetailed(
          [_textNotes()],
          useCache: false,
          timeout: timeout,
          requireAllRelaysSettled: true,
          acceptRelayClosedWhenOthersAnswered: true,
        );
        await first.awaitReq(0);
        await second.awaitReq(0);
        return (timedOut: pending.then((result) => result.timedOut));
      }

      test('when the refusal is a rate limit', () async {
        final read = await optedInRead();
        await first.deliver(['EOSE', first.reqSubIds.single]);
        await second.deliver([
          'CLOSED',
          second.reqSubIds.single,
          'rate-limited: slow down',
        ]);

        expect(await read.timedOut, isTrue);
      });

      test('when every relay refused and none answered', () async {
        final read = await optedInRead();
        await first.deliver([
          'CLOSED',
          first.reqSubIds.single,
          'error: unsupported request',
        ]);
        await second.deliver([
          'CLOSED',
          second.reqSubIds.single,
          'error: unsupported request',
        ]);

        expect(await read.timedOut, isTrue);
        // Settled on the first read's own refusals, not on an unanswered
        // confirmation read running out the deadline.
        expect(first.reqSubIds, hasLength(1));
        expect(second.reqSubIds, hasLength(1));
      });

      test('when another relay dropped its socket', () async {
        final read = await optedInRead(
          timeout: const Duration(milliseconds: 400),
        );
        await first.deliver(['EOSE', first.reqSubIds.single]);
        second.onError('socket closed');

        expect(await read.timedOut, isTrue);
      });

      test(
        'when a different relay returns error on the confirmation read',
        () async {
          final read = await optedInRead();
          await first.deliver([
            'CLOSED',
            first.reqSubIds[0],
            'error: temporary failure',
          ]);
          await second.deliver(['EOSE', second.reqSubIds[0]]);

          await first.awaitReq(1);
          await second.awaitReq(1);
          await first.deliver(['EOSE', first.reqSubIds[1]]);
          await second.deliver([
            'CLOSED',
            second.reqSubIds[1],
            'error: temporary failure',
          ]);

          expect(await read.timedOut, isTrue);
        },
      );

      test('when another relay stayed silent', () async {
        final read = await optedInRead(
          timeout: const Duration(milliseconds: 400),
        );
        await first.deliver(['EOSE', first.reqSubIds.single]);

        expect(await read.timedOut, isTrue);
      });
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
