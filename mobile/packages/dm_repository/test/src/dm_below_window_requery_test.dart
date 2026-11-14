// ABOUTME: A gift wrap that reaches a relay late, stamped below the live
// ABOUTME: since: window, is asked for again on a later inbox open (#8439).

import 'dart:async';
import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/nip04/nip04.dart';
import 'package:nostr_sdk/nip44/nip44_v2.dart';
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/live_dm_reads.dart';

class _MockNostrClient extends Mock implements NostrClient {
  _MockNostrClient() {
    stubQuietLiveDeletions(this);
  }
}

final String _ownerSecret = '1' * 64;
final String _aliceSecret = '2' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);

const _day = 86400;
const _hour = 3600;
const _settleTimeout = Duration(seconds: 20);
const _inboxUrl = 'wss://inbox.example.com';
const _refusingUrl = 'wss://refuses.example.com';

/// Whether a gift wrap left a message row or a processed-wrap ledger entry.
const _storedSql = '''
SELECT EXISTS (SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1)
  OR EXISTS (SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1)
  AS stored
''';

/// NIP-01: an event matches when `since <= created_at <= until` holds and
/// every other condition the filter sets.
bool _admits(nostr_filter.Filter filter, Event event) {
  final since = filter.since;
  if (since != null && event.createdAt < since) return false;
  final until = filter.until;
  if (until != null && event.createdAt > until) return false;
  final kinds = filter.kinds;
  if (kinds != null && !kinds.contains(event.kind)) return false;
  final authors = filter.authors;
  if (authors != null && !authors.contains(event.pubkey)) return false;
  final p = filter.p;
  if (p != null &&
      !event.tags.any(
        (tag) => tag.length > 1 && tag[0] == 'p' && p.contains(tag[1]),
      )) {
    return false;
  }
  return true;
}

/// The pool's relays, [stored] on [poolUrl] and [others] beside it, answering
/// REQs and queries the way NIP-01 says, so a wrap outside a filter's window
/// is simply never sent. Each test sets the caps, timeouts, failures and
/// refusals it needs.
class _Relay {
  _Relay(this.stored);

  /// What the pool relay [poolUrl] holds.
  final List<Event> stored;

  /// What other relays hold, by URL. They are pool relays too.
  final Map<String, List<Event>> others = {};

  /// The most events one answer from a relay carries, by URL.
  final Map<String, int> capFor = {};

  /// The `CLOSED` category a relay answers every read below the window
  /// with, by URL.
  final Map<String, String> refusesBelowWindow = {};

  static const poolUrl = 'wss://r';

  List<String> get relayUrls => [poolUrl, ...others.keys];

  final List<nostr_filter.Filter> reqFilters = [];
  final List<({List<nostr_filter.Filter> filters, List<String>? tempRelays})>
  queries = [];
  final StreamController<Event> controller =
      StreamController<Event>.broadcast();
  void Function(StoredEventsEnd)? onEnd;
  int handedOver = 0;

  /// The most events one answer carries from a relay with no entry in
  /// [capFor]: its result cap, newest first. `null` for no cap.
  int? cap;

  /// Whether a query asking a filter goes unanswered: no events, timed out.
  bool Function(nostr_filter.Filter filter)? timesOut;

  /// What an unanswered single-relay read still returned before its
  /// deadline; `null` for nothing.
  List<Event> Function(nostr_filter.Filter filter)? timedOutWith;

  /// What a query asking a filter throws instead of answering, as a dropped
  /// connection does; `null` to answer.
  Object? Function(nostr_filter.Filter filter)? failsWith;

  /// Everything every relay holds, each event once.
  List<Event> get everything => {
    for (final event in [stored, ...others.values].expand((e) => e))
      event.id: event,
  }.values.toList();

  /// What [filters] admit across every relay, newest first.
  List<Event> admitted(List<nostr_filter.Filter> filters) => _newestFirst(
    everything.where((e) => filters.any((f) => _admits(f, e))),
  );

  static List<Event> _newestFirst(Iterable<Event> events) =>
      events.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// One relay's answer to [filter]: its newest admitted events, up to the
  /// filter's `limit` and that relay's cap.
  QueryResult relayAnswer(String url, nostr_filter.Filter filter) {
    final held = url == poolUrl ? stored : others[url] ?? const <Event>[];
    var events = _newestFirst(held.where((e) => _admits(filter, e)));
    final bound = [
      capFor[url] ?? cap,
      filter.limit,
    ].whereType<int>().fold<int?>(null, (a, b) => a == null || b < a ? b : a);
    if (bound != null && events.length > bound) {
      events = events.take(bound).toList();
    }
    return QueryResult(
      events: events,
      endedBy: QueryEnd.complete,
      possiblyCapped: bound != null && events.length >= bound,
    );
  }

  /// What a pool query for [filters] returns: every relay's own answer, each
  /// capped by that relay, merged. The pool does not trim the merged list.
  List<Event> answer(List<nostr_filter.Filter> filters) => _newestFirst(
    {
      for (final url in relayUrls)
        for (final filter in filters)
          for (final event in relayAnswer(url, filter).events) event.id: event,
    }.values,
  );

  List<nostr_filter.Filter> get queryFilters => [
    for (final query in queries) ...query.filters,
  ];

  /// Every filter this relay was asked, live or as a query.
  List<nostr_filter.Filter> get everyFilter => [...reqFilters, ...queryFilters];

  /// Hands over what every REQ so far admits, from every relay, then ends
  /// the batch.
  void sendStored() {
    for (final event in admitted(reqFilters)) {
      handedOver++;
      controller.add(event);
    }
    onEnd?.call(StoredEventsEnd(deliveredEventCount: handedOver));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Duration.zero);
  });

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.test(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  _MockNostrClient clientFor(_Relay relay) {
    final client = _MockNostrClient();
    when(() => client.connectedRelayCount).thenReturn(1);
    when(() => client.configuredRelayCount).thenReturn(1);
    when(() => client.configuredRelays).thenAnswer((_) => relay.relayUrls);
    when(() => client.relayStatuses).thenReturn(const {});
    when(() => client.isRelayAllowed(any())).thenReturn(true);
    when(
      () => client.relayStatusStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => client.queryEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      relay.queries.add((filters: filters, tempRelays: null));
      return relay.answer(filters);
    });
    when(
      () => client.queryEventsDetailed(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        sendAfterAuth: any(named: 'sendAfterAuth'),
        useCache: any(named: 'useCache'),
        useQueryPool: any(named: 'useQueryPool'),
        timeout: any(named: 'timeout'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        acceptRelayClosedWhenOthersAnswered: any(
          named: 'acceptRelayClosedWhenOthersAnswered',
        ),
        silentRelayTimeout: any(named: 'silentRelayTimeout'),
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      relay.queries.add((
        filters: filters,
        tempRelays: invocation.namedArguments[#tempRelays] as List<String>?,
      ));
      for (final filter in filters) {
        final failure = relay.failsWith?.call(filter);
        if (failure != null) {
          Error.throwWithStackTrace(failure, StackTrace.current);
        }
      }
      final timedOut = filters.any((f) => relay.timesOut?.call(f) ?? false);
      return (
        events: timedOut ? const <Event>[] : relay.answer(filters),
        timedOut: timedOut,
        noRelays: false,
      );
    });
    when(
      () => client.readEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        timeout: any(named: 'timeout'),
        silentRelayTimeout: any(named: 'silentRelayTimeout'),
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      final tempRelays =
          invocation.namedArguments[#tempRelays] as List<String>?;
      relay.queries.add((filters: filters, tempRelays: tempRelays));
      for (final filter in filters) {
        final failure = relay.failsWith?.call(filter);
        if (failure != null) {
          Error.throwWithStackTrace(failure, StackTrace.current);
        }
      }
      if (filters.any((f) => relay.timesOut?.call(f) ?? false)) {
        return relay.timedOutWith == null
            ? const QueryResult(events: [], endedBy: QueryEnd.deadline)
            : QueryResult(
                events: relay.timedOutWith!(filters.single),
                endedBy: QueryEnd.deadline,
              );
      }
      final url = tempRelays!.single.replaceFirst(RegExp(r'/$'), '');
      final refusal = relay.refusesBelowWindow[url];
      if (refusal != null && filters.single.since != null) {
        return QueryResult(
          events: const [],
          endedBy: QueryEnd.relayClosed,
          closedRelayReasons: {url: refusal},
        );
      }
      return relay.relayAnswer(url, filters.single);
    });
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    when(
      () => client.subscribe(
        any(that: isLiveDmRead),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
        onStoredEventsStart: any(named: 'onStoredEventsStart'),
        onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
      ),
    ).thenAnswer((invocation) {
      relay
        ..handedOver = 0
        ..reqFilters.addAll(
          invocation.positionalArguments.first as List<nostr_filter.Filter>,
        )
        ..onEnd =
            invocation.namedArguments[#onStoredEventsEnd]
                as void Function(StoredEventsEnd)?;
      return relay.controller.stream;
    });
    return client;
  }

  DmRepository launch(
    _Relay relay, {
    DmRepositoryErrorReporter? errorReporter,
  }) {
    final messagesDao = DirectMessagesDao(db);
    final conversationsDao = ConversationsDao(db);
    return DmRepository(
      nostrClient: clientFor(relay),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
      removedConversationsDao: RemovedConversationsDao(db),
      outgoingDmsDao: OutgoingDmsDao(db),
      reactionsRepository: DmReactionsRepository(
        reactionsDao: DmReactionsDao(db),
        conversationsDao: conversationsDao,
        directMessagesDao: messagesDao,
        userPubkey: _owner,
      ),
      // A fresh instance per launch, over the same stored preferences.
      syncState: DmSyncState(prefs),
      userPubkey: _owner,
      signer: LocalNostrSigner(_ownerSecret),
      errorReporter: errorReporter,
    );
  }

  Future<bool> isStored(Event wrap) async {
    final row = await db
        .customSelect(_storedSql, variables: [Variable.withString(wrap.id)])
        .getSingle();
    return row.read<bool>('stored');
  }

  Future<void> settled(Event wrap) => db
      .customSelect(
        _storedSql,
        variables: [Variable.withString(wrap.id)],
        readsFrom: {db.directMessages, db.processedGiftWraps},
      )
      .watchSingle()
      .firstWhere((row) => row.read<bool>('stored'))
      .timeout(
        _settleTimeout,
        onTimeout: () => fail('gift wrap ${wrap.id} was never settled'),
      );

  /// A real, fully signed NIP-59 wrap of [rumor], sealed with [sealSecret],
  /// whose outer stamp is [wire]. The receive pipeline checks the outer
  /// signature, so the stamp is chosen when the wrap is built rather than
  /// edited afterwards.
  Future<Event> wrapRumor(
    Event rumor, {
    required String sealSecret,
    required int wire,
  }) async {
    final seal = Event(
      getPublicKey(sealSecret),
      EventKind.sealEventKind,
      [],
      await NIP44V2.encrypt(
        jsonEncode(rumor.toJson()..remove('sig')),
        NIP44V2.shareSecret(sealSecret, _owner),
      ),
      createdAt: wire,
    )..sign(sealSecret);
    final ephemeral = generatePrivateKey();
    return Event(
      getPublicKey(ephemeral),
      EventKind.giftWrap,
      [
        ['p', _owner],
      ],
      await NIP44V2.encrypt(
        jsonEncode(seal.toJson()),
        NIP44V2.shareSecret(ephemeral, _owner),
      ),
      createdAt: wire,
    )..sign(ephemeral);
  }

  /// A wrapped kind-14 from Alice whose outer stamp is [wire].
  Future<Event> wrapAt({required int wire, required String content}) =>
      wrapRumor(
        Event(
          _alice,
          EventKind.privateDirectMessage,
          [
            ['p', _owner],
          ],
          content,
          createdAt: wire + 600,
        ),
        sealSecret: _aliceSecret,
        wire: wire,
      );

  /// The owner's own read marker (#4977) for the conversation with Alice,
  /// gift-wrapped to themselves, whose outer stamp is [wire].
  Future<Event> readMarkerAt({required int wire, required int cursor}) {
    final tupleKey = ([_owner, _alice]..sort()).join(',');
    return wrapRumor(
      Event(
        _owner,
        EventKind.appSpecificData,
        [
          ['d', 'divine/dm-read/v1'],
        ],
        jsonEncode({
          'v': 1,
          'read': {tupleKey: cursor},
        }),
        createdAt: wire + 600,
      ),
      sealSecret: _ownerSecret,
      wire: wire,
    );
  }

  Event nip04At({required int createdAt, required String content}) => Event(
    _alice,
    EventKind.directMessage,
    [
      ['p', _owner],
    ],
    NIP04.encrypt(content, NIP04.getAgreement(_aliceSecret), _owner),
    createdAt: createdAt,
  )..sign(_aliceSecret);

  Event nip04DeletionAt({required int createdAt, required String target}) =>
      Event(
        _alice,
        EventKind.eventDeletion,
        [
          ['e', target],
          ['p', _owner],
        ],
        '',
        createdAt: createdAt,
      )..sign(_aliceSecret);

  /// The owner's kind-10050 naming [_inboxUrl] as their DM inbox.
  Event ownInboxList() => Event(
    _owner,
    EventKind.dmRelaysList,
    [
      ['relay', _inboxUrl],
    ],
    '',
  )..sign(_ownerSecret);

  /// An established install: history drain complete at the current version,
  /// own-inbox coverage recorded, newest processed wire stamp [wire].
  Future<void> establish(int wire) async {
    final sync = DmSyncState(prefs);
    await sync.recordSeen(_owner, createdAt: wire);
    await sync.recordWireSeen(_owner, createdAt: wire);
    await sync.markHistoryDrainComplete(_owner);
    await sync.setDrainVersion(_owner, DmSyncState.currentDrainVersion);
    await sync.setDrainCoveredOwnInbox(_owner);
    await sync.setGroupRecoveryVersion(
      _owner,
      DmSyncState.currentGroupRecoveryVersion,
    );
  }

  int now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  group('a gift wrap that reaches a relay late, below the window', () {
    late int lastWire;
    late int windowStart;
    late Event inWindow;

    setUp(() async {
      lastWire = now() - _day;
      windowStart = lastWire - 2 * _day;
      await establish(lastWire);
      inWindow = await wrapAt(wire: lastWire - 3600, content: 'in window');
    });

    /// A read that reaches below the live window: the live REQ starts at
    /// [windowStart], and the history drain pages with no `since:` at all.
    bool belowWindow(nostr_filter.Filter filter) =>
        filter.since != null && filter.since! < windowStart;

    /// Opens the inbox the way the app does on launch: the live subscription,
    /// then the history call the inbox screens make on every open.
    Future<void> openInbox(_Relay relay, {DmRepository? repository}) async {
      final opened = repository ?? launch(relay);
      await opened.startListening();
      expect(relay.reqFilters.last.since, windowStart);
      relay.sendStored();
      // Everything the relay sent is handled before the inbox closes, the
      // wrap inside the window included: the relay was read.
      for (final wrap in relay.admitted(relay.reqFilters)) {
        await settled(wrap);
      }
      await opened.backfillHistoryIfNeeded();
      await pumpEventQueue();
      await opened.stopListening();
    }

    test('is stored on the next inbox open', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final relay = _Relay([inWindow, late]);

      await openInbox(relay);

      expect(
        await isStored(late),
        isTrue,
        reason: 'asked: ${relay.everyFilter.map((f) => f.toJson()).toList()}',
      );
    });

    test('is read from seven days below the window and no further', () async {
      final deepest = await wrapAt(
        wire: windowStart - 7 * _day,
        content: 'seven days below',
      );
      final tooDeep = await wrapAt(
        wire: windowStart - 7 * _day - 1,
        content: 'past seven days',
      );
      final relay = _Relay([inWindow, deepest, tooDeep]);

      await openInbox(relay);

      expect(await isStored(deepest), isTrue);
      expect(await isStored(tooDeep), isFalse);
      expect(relay.everyFilter.where((f) => _admits(f, tooDeep)), isEmpty);
    });

    test(
      'reads a week below the last finished run when it read lower',
      () async {
        final lastTop = windowStart - 10 * _day;
        await DmSyncState(
          prefs,
        ).recordBelowWindowRequery(_owner, at: now() - 2 * _day, top: lastTop);
        // Between the band that run read and the one this window alone gives.
        final between = await wrapAt(
          wire: windowStart - 8 * _day,
          content: 'between two runs',
        );
        final relay = _Relay([inWindow, between]);

        await openInbox(relay);

        expect(await isStored(between), isTrue);
        expect(
          relay.queryFilters.where(belowWindow).map((f) => f.since).toSet(),
          {lastTop - 7 * _day},
        );
      },
    );

    test('reads at most thirty days below the window', () async {
      await DmSyncState(prefs).recordBelowWindowRequery(
        _owner,
        at: now() - 2 * _day,
        top: windowStart - 100 * _day,
      );
      final relay = _Relay([inWindow]);

      await openInbox(relay);

      expect(
        relay.queryFilters.where(belowWindow).map((f) => f.since).toSet(),
        {windowStart - 30 * _day},
      );
    });

    test('remembers the window start a finished run read below', () async {
      final relay = _Relay([inWindow]);

      await openInbox(relay);

      expect(DmSyncState(prefs).belowWindowRequeryTop(_owner), windowStart);
    });

    test("asks the account's own inbox relays too", () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final relay = _Relay([inWindow, late, ownInboxList()]);

      await openInbox(relay);

      final relaysReadBelowWindow = {
        for (final query in relay.queries)
          if (query.filters.any(belowWindow)) ...?query.tempRelays,
      };
      expect(relaysReadBelowWindow, anyElement(startsWith(_inboxUrl)));
      expect(relaysReadBelowWindow, anyElement(startsWith(_Relay.poolUrl)));
      expect(
        DmSyncState(prefs).belowWindowRequeryAt(_owner),
        isNotNull,
        reason: 'reading the inbox list and every page is a finished run',
      );
    });

    test('pages past a relay that caps each answer', () async {
      final late = [
        for (var i = 1; i <= 5; i++)
          await wrapAt(wire: windowStart - 10 * i, content: 'late $i'),
      ];
      final relay = _Relay([inWindow, ...late])..cap = 2;

      await openInbox(relay);

      for (final wrap in late) {
        expect(await isStored(wrap), isTrue, reason: wrap.content);
      }
    });

    test(
      'reads every relay to the floor when one relay caps its answers',
      () async {
        final dense = [
          for (var i = 1; i <= 5; i++)
            await wrapAt(wire: windowStart - 10 * i, content: 'dense $i'),
        ];
        final sparse = await wrapAt(
          wire: windowStart - 6 * _day,
          content: 'sparse',
        );
        final relay = _Relay([inWindow])
          ..others['wss://dense.example.com'] = dense
          ..others['wss://sparse.example.com'] = [sparse]
          ..capFor['wss://dense.example.com'] = 2;

        await openInbox(relay);

        for (final wrap in [...dense, sparse]) {
          expect(await isStored(wrap), isTrue, reason: wrap.content);
        }
      },
    );

    test('asks at most once a day', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final relay = _Relay([inWindow, late]);
      final sync = DmSyncState(prefs);
      int belowWindowReads() => relay.queryFilters.where(belowWindow).length;

      await openInbox(relay);
      final afterFirst = belowWindowReads();
      expect(afterFirst, greaterThan(0));
      expect(await isStored(late), isTrue);

      // Past the hourly retry, but within a day of a finished run.
      await sync.setBelowWindowRequeryAttemptAt(_owner, now() - 2 * _hour);
      await sync.recordBelowWindowRequery(
        _owner,
        at: now() - _day + 60,
        top: windowStart,
      );
      await openInbox(relay);
      expect(belowWindowReads(), afterFirst);

      await sync.recordBelowWindowRequery(
        _owner,
        at: now() - _day - 1,
        top: windowStart,
      );
      await openInbox(relay);
      expect(belowWindowReads(), greaterThan(afterFirst));
    });

    test('asks again an hour later when a relay did not answer', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      var relayAnswers = false;
      final relay = _Relay([inWindow, late])
        ..timesOut = (filter) => belowWindow(filter) && !relayAnswers;
      final sync = DmSyncState(prefs);
      int belowWindowReads() => relay.queryFilters.where(belowWindow).length;

      await openInbox(relay);
      final afterFirst = belowWindowReads();
      expect(afterFirst, greaterThan(0));
      expect(await isStored(late), isFalse);
      expect(sync.belowWindowRequeryAt(_owner), isNull);
      expect(sync.belowWindowRequeryTop(_owner), isNull);

      relayAnswers = true;
      await openInbox(relay);
      expect(belowWindowReads(), afterFirst, reason: 'the run just started');

      await sync.setBelowWindowRequeryAttemptAt(_owner, now() - _hour + 60);
      await openInbox(relay);
      expect(belowWindowReads(), afterFirst, reason: 'within the hour');

      await sync.setBelowWindowRequeryAttemptAt(_owner, now() - _hour - 1);
      await openInbox(relay);
      expect(await isStored(late), isTrue);
    });

    test('asks again an hour later when a relay read fails', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      var relayWorks = false;
      final relay = _Relay([inWindow, late])
        ..failsWith = (filter) => belowWindow(filter) && !relayWorks
            ? Exception('relay connection lost')
            : null;
      final reported = <String>[];

      await openInbox(
        relay,
        repository: launch(
          relay,
          errorReporter: (_, _, {required site}) => reported.add(site),
        ),
      );
      expect(relay.queryFilters.where(belowWindow), isNotEmpty);
      expect(await isStored(late), isFalse);
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
      expect(reported, isEmpty, reason: 'a lost connection is expected');

      relayWorks = true;
      await DmSyncState(
        prefs,
      ).setBelowWindowRequeryAttemptAt(_owner, now() - _hour - 1);
      await openInbox(relay);
      expect(await isStored(late), isTrue);
    });

    test('asks again when its last run is stamped in the future', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final sync = DmSyncState(prefs);
      // Written while the device clock ran a year fast.
      await sync.recordBelowWindowRequery(
        _owner,
        at: now() + 365 * _day,
        top: windowStart,
      );
      await sync.setBelowWindowRequeryAttemptAt(_owner, now() + 365 * _day);
      final relay = _Relay([inWindow, late]);

      await openInbox(relay);

      expect(await isStored(late), isTrue);
    });

    test('records a run when a relay refuses for good', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final relay = _Relay([inWindow, late])
        ..others[_refusingUrl] = const []
        ..refusesBelowWindow[_refusingUrl] = 'restricted';

      await openInbox(relay);

      expect(await isStored(late), isTrue);
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNotNull);
    });

    test('does not record a run when a relay asks to authenticate', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final relay = _Relay([inWindow, late])
        ..others[_refusingUrl] = const []
        ..refusesBelowWindow[_refusingUrl] = 'auth-required';

      await openInbox(relay);

      expect(await isStored(late), isTrue);
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
    });

    test('does not record a run that every relay refused', () async {
      final relay = _Relay([inWindow])
        ..refusesBelowWindow[_Relay.poolUrl] = 'restricted';

      await openInbox(relay);

      expect(relay.queryFilters.where(belowWindow), isNotEmpty);
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
    });

    test('does not record a run whose message reads went unanswered', () async {
      final relay = _Relay([inWindow])
        ..timesOut = (filter) =>
            belowWindow(filter) &&
            !(filter.kinds?.contains(EventKind.eventDeletion) ?? false);

      await openInbox(relay);

      expect(
        relay.queryFilters.where(
          (f) =>
              belowWindow(f) &&
              (f.kinds?.contains(EventKind.eventDeletion) ?? false),
        ),
        isNotEmpty,
        reason: 'the deletion reads were asked and answered',
      );
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
    });

    test(
      'does not record a run whose deletion reads went unanswered',
      () async {
        final late = await wrapAt(wire: windowStart - 1, content: 'late');
        final relay = _Relay([inWindow, late])
          ..timesOut = (filter) =>
              belowWindow(filter) &&
              (filter.kinds?.contains(EventKind.eventDeletion) ?? false);

        await openInbox(relay);

        expect(await isStored(late), isTrue);
        expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
      },
    );

    test(
      'does not record a run whose inbox-list read went unanswered',
      () async {
        final late = await wrapAt(wire: windowStart - 1, content: 'late');
        final relay = _Relay([inWindow, late])
          ..timesOut = (filter) =>
              filter.kinds?.contains(EventKind.dmRelaysList) ?? false;

        await openInbox(relay);

        expect(await isStored(late), isTrue);
        expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
      },
    );

    test(
      'keeps what an unanswered page carried, without recording the run',
      () async {
        final late = await wrapAt(wire: windowStart - 1, content: 'late');
        final relay = _Relay([inWindow, late]);
        relay
          ..timesOut = belowWindow
          ..timedOutWith = (filter) =>
              relay.relayAnswer(_Relay.poolUrl, filter).events;

        await openInbox(relay);

        expect(await isStored(late), isTrue);
        expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
      },
    );

    test('records a run that stops at the page budget', () async {
      // Two per answer, so each page past the first adds one message and the
      // budget runs out above the oldest of them.
      final messages = [
        for (var i = 1; i <= DmHistoryDrainConfig.maxPages + 10; i++)
          nip04At(createdAt: windowStart - 60 * i, content: 'message $i'),
      ];
      final relay = _Relay([inWindow, ...messages])..capFor[_Relay.poolUrl] = 2;

      await openInbox(relay);

      final messagePages = relay.queries.where(
        (query) =>
            query.filters.any(belowWindow) &&
            !query.filters.any(
              (f) => f.kinds?.contains(EventKind.eventDeletion) ?? false,
            ),
      );
      expect(messagePages, hasLength(DmHistoryDrainConfig.maxPages));
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNotNull);
    });

    test('reports a read that fails with a programming error', () async {
      final relay = _Relay([inWindow])
        ..failsWith = (filter) =>
            belowWindow(filter) ? StateError('invariant broken') : null;
      final reported = <String>[];

      await openInbox(
        relay,
        repository: launch(
          relay,
          errorReporter: (_, _, {required site}) => reported.add(site),
        ),
      );

      expect(reported, [
        DmRepositoryReportableSites.belowWindowRequeryUnexpectedFailure,
      ]);
      expect(DmSyncState(prefs).belowWindowRequeryAt(_owner), isNull);
    });

    test('runs without showing restore progress', () async {
      final late = await wrapAt(wire: windowStart - 1, content: 'late');
      final relay = _Relay([inWindow, late]);
      final repository = launch(relay);
      final progress = <bool>[];
      final subscription = repository.historyRecoveryStream.listen(
        progress.add,
      );
      addTearDown(subscription.cancel);

      await openInbox(relay, repository: repository);

      expect(await isStored(late), isTrue);
      expect(progress, isNot(contains(true)));
    });

    test('applies a deletion that reached the relay late, after the message '
        'it names', () async {
      final message = nip04At(
        createdAt: windowStart - 7200,
        content: 'retract me',
      );
      final deletion = nip04DeletionAt(
        createdAt: windowStart - 3600,
        target: message.id,
      );
      final relay = _Relay([inWindow, message, deletion]);

      await openInbox(relay);

      final row = await DirectMessagesDao(
        db,
      ).getMessageById(message.id, ownerPubkey: _owner);
      expect(row, isNotNull);
      expect(row!.isDeleted, isTrue);
    });

    test('applies a deletion stamped above the window to a late message it '
        'names', () async {
      final message = nip04At(
        createdAt: windowStart - 7200,
        content: 'retract me',
      );
      // Handled live before the message existed, so the live path dropped it.
      final deletion = nip04DeletionAt(
        createdAt: windowStart + 3600,
        target: message.id,
      );
      final relay = _Relay([inWindow, message, deletion]);

      await openInbox(relay);

      final row = await DirectMessagesDao(
        db,
      ).getMessageById(message.id, ownerPubkey: _owner);
      expect(row, isNotNull);
      expect(row!.isDeleted, isTrue);
    });

    test('pages deletions past a relay that caps each answer', () async {
      final messages = [
        for (var i = 1; i <= 5; i++)
          nip04At(
            createdAt: windowStart - 7200 - 100 * i,
            content: 'retract me $i',
          ),
      ];
      final deletions = [
        for (final message in messages)
          nip04DeletionAt(
            createdAt: message.createdAt + 3600,
            target: message.id,
          ),
      ];
      final relay = _Relay([inWindow, ...messages, ...deletions])..cap = 2;

      await openInbox(relay);

      for (final message in messages) {
        final row = await DirectMessagesDao(
          db,
        ).getMessageById(message.id, ownerPubkey: _owner);
        expect(row, isNotNull, reason: message.id);
        expect(row!.isDeleted, isTrue, reason: message.id);
      }
    });

    test('applies a read marker stranded below the window', () async {
      final cursor = inWindow.createdAt + 600;
      final marker = await readMarkerAt(
        wire: windowStart - 3600,
        cursor: cursor,
      );
      final relay = _Relay([inWindow, marker]);

      await openInbox(relay);

      final conversations = await ConversationsDao(
        db,
      ).getAllConversations(ownerPubkey: _owner);
      expect(conversations, hasLength(1));
      expect(conversations.single.lastReadTimestamp, cursor);
    });
  });
}
