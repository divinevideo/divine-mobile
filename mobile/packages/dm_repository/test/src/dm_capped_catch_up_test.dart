// ABOUTME: A catch-up bigger than a relay's result cap must not strand the
// ABOUTME: oldest messages of its window below the next launch's (#10192).

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
import 'package:nostr_sdk/nip44/nip44_v2.dart';
import 'package:nostr_sdk/relay/relay_type.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Holds [addCatchUpDebt] until the test releases it, so the app can close
/// while the unread part of a window is still being recorded.
class _GatedDebtSyncState extends DmSyncState {
  _GatedDebtSyncState(super._prefs);

  final Completer<void> reached = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<void> addCatchUpDebt(
    String pubkey,
    Iterable<DmCatchUpDebt> debts,
  ) async {
    if (!reached.isCompleted) reached.complete();
    await release.future;
    return super.addCatchUpDebt(pubkey, debts);
  }
}

final String _ownerSecret = '1' * 64;
final String _aliceSecret = '2' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);

const _day = 86400;
const _relayUrl = 'wss://capped.example';
const _settleTimeout = Duration(seconds: 20);

const _storedSql = '''
SELECT EXISTS (SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1)
  OR EXISTS (SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1)
  AS stored
''';

bool _admits(nostr_filter.Filter filter, Event event) {
  final since = filter.since;
  if (since != null && event.createdAt < since) return false;
  final until = filter.until;
  if (until != null && event.createdAt > until) return false;
  final kinds = filter.kinds;
  if (kinds != null && !kinds.contains(event.kind)) return false;
  return true;
}

/// A relay that answers newest first and stops at [maxLimit], as a relay
/// applying its NIP-11 `max_limit` does, behind a pool that reports a stored
/// batch reaching that limit as possibly capped.
class _CappedRelay {
  _CappedRelay(this.stored, {required this.maxLimit});

  final List<Event> stored;
  final int maxLimit;
  final List<nostr_filter.Filter> reqFilters = [];
  final StreamController<Event> controller =
      StreamController<Event>.broadcast();
  void Function(StoredEventsEnd)? onEnd;
  int handedOver = 0;

  /// The pages asked of single relays, with the relays each named.
  final List<
    ({nostr_filter.Filter filter, List<String>? tempRelays, List<int> types})
  >
  relayPages = [];

  /// Single-relay pages from this one on are left unsettled.
  int unsettledFromPage = 1 << 30;

  List<Event> answer(List<nostr_filter.Filter> filters) {
    final filter = filters.single;
    final admitted = stored.where((e) => _admits(filter, e)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final limit = filter.limit;
    final cap = limit == null || limit > maxLimit ? maxLimit : limit;
    return admitted.take(cap).toList();
  }

  /// Hands over the stored batch of the last REQ, without its end.
  List<Event> sendBatch() {
    final batch = answer(reqFilters);
    for (final event in batch) {
      handedOver++;
      controller.add(event);
    }
    return batch;
  }

  /// Reports the end of the stored batch, naming this relay as possibly
  /// capped when its batch reached [maxLimit].
  void endBatch() {
    final batch = answer(reqFilters);
    onEnd?.call(
      StoredEventsEnd(
        deliveredEventCount: handedOver,
        possiblyCappedRelays: {
          if (batch.length >= maxLimit) _relayUrl: batch.last.createdAt,
        },
      ),
    );
  }

  ({List<Event> events, bool timedOut, bool noRelays}) relayPage(
    nostr_filter.Filter filter,
    List<String>? tempRelays,
    List<int> types,
  ) {
    // Other single-relay reads, such as the inbox-relay lookup, find nothing.
    if (!(filter.kinds?.contains(EventKind.giftWrap) ?? false)) {
      return (events: const <Event>[], timedOut: false, noRelays: false);
    }
    relayPages.add((filter: filter, tempRelays: tempRelays, types: types));
    if (relayPages.length >= unsettledFromPage) {
      return (events: const <Event>[], timedOut: true, noRelays: false);
    }
    return (events: answer([filter]), timedOut: false, noRelays: false);
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

  _MockNostrClient clientFor(_CappedRelay relay) {
    final client = _MockNostrClient();
    when(() => client.connectedRelayCount).thenReturn(1);
    when(() => client.configuredRelayCount).thenReturn(1);
    when(() => client.configuredRelays).thenReturn(const [_relayUrl]);
    when(
      () => client.storedEventsPossiblyCapped(any()),
    ).thenReturn(const <String, int?>{});
    when(
      () => client.queryEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer(
      (invocation) async => relay.answer(
        invocation.positionalArguments.first as List<nostr_filter.Filter>,
      ),
    );
    when(
      () => client.queryEventsDetailed(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
        tempRelays: any(named: 'tempRelays'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        acceptRelayClosedWhenOthersAnswered: any(
          named: 'acceptRelayClosedWhenOthersAnswered',
        ),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      return (events: relay.answer(filters), timedOut: false, noRelays: false);
    });
    when(
      () => client.queryEventsDetailed(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      return relay.relayPage(
        filters.single,
        invocation.namedArguments[#tempRelays] as List<String>?,
        invocation.namedArguments[#relayTypes] as List<int>,
      );
    });
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    when(
      () => client.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
        onStoredEventsStart: any(named: 'onStoredEventsStart'),
        onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
      ),
    ).thenAnswer((invocation) {
      relay.reqFilters.addAll(
        invocation.positionalArguments.first as List<nostr_filter.Filter>,
      );
      relay.onEnd =
          invocation.namedArguments[#onStoredEventsEnd]
              as void Function(StoredEventsEnd)?;
      return relay.controller.stream;
    });
    return client;
  }

  DmRepository launch(_CappedRelay relay, {DmSyncState? syncState}) {
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
      syncState: syncState ?? DmSyncState(prefs),
      userPubkey: _owner,
      signer: LocalNostrSigner(_ownerSecret),
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

  Future<Event> wrapAt({required int wire, required String content}) async {
    final rumor = Event(
      _alice,
      EventKind.privateDirectMessage,
      [
        ['p', _owner],
      ],
      content,
      createdAt: wire + 600,
    );
    final seal = Event(
      _alice,
      EventKind.sealEventKind,
      [],
      await NIP44V2.encrypt(
        jsonEncode(rumor.toJson()..remove('sig')),
        NIP44V2.shareSecret(_aliceSecret, _owner),
      ),
      createdAt: wire,
    )..sign(_aliceSecret);
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

  group('catch-up after ten days away', () {
    late int lastWire;
    late Event newest;
    late Event third;
    late Event fourth;
    late Event oldest;
    late List<Event> stored;

    setUp(() async {
      final at = now();
      lastWire = at - 10 * _day;
      await establish(lastWire);
      newest = await wrapAt(wire: at - 3600, content: 'newest');
      third = await wrapAt(wire: at - 36 * 3600, content: 'third');
      fourth = await wrapAt(wire: at - 3 * _day, content: 'fourth');
      oldest = await wrapAt(wire: at - 5 * _day - 3600, content: 'oldest');
      stored = [
        newest,
        await wrapAt(wire: at - 12 * 3600, content: 'second'),
        third,
        fourth,
        oldest,
      ];
    });

    /// Starts listening and lets [relay] send its stored batch and then its
    /// end, then waits until each of [waitFor] is stored.
    Future<DmRepository> listen(
      _CappedRelay relay, {
      DmSyncState? syncState,
      List<Event> waitFor = const [],
    }) async {
      final repository = launch(relay, syncState: syncState);
      await repository.startListening();
      for (final wrap in relay.sendBatch()) {
        await settled(wrap);
      }
      relay.endBatch();
      for (final wrap in waitFor) {
        await settled(wrap);
      }
      await pumpEventQueue();
      return repository;
    }

    test('keeps every message when the window holds more than the relay '
        'returns at once', () async {
      final relay = _CappedRelay(stored, maxLimit: 3);
      final repository = await listen(relay, waitFor: [fourth, oldest]);
      await pumpEventQueue();
      await repository.stopListening();

      for (final wrap in stored) {
        expect(await isStored(wrap), isTrue, reason: wrap.createdAt.toString());
      }
      expect(DmSyncState(prefs).catchUpDebt(_owner), isEmpty);
    });

    test(
      'reads nothing more when the window fits under the relay cap',
      () async {
        // A batch that reaches the cap exactly may be capped, so the window
        // fits only with room to spare.
        final relay = _CappedRelay(stored, maxLimit: 6);
        final repository = await listen(relay);
        await repository.stopListening();

        expect(relay.relayPages, isEmpty);
        expect(DmSyncState(prefs).catchUpDebt(_owner), isEmpty);
      },
    );

    test('reads the capped relay alone, from its oldest stamp down to the '
        'window', () async {
      final relay = _CappedRelay(stored, maxLimit: 3);
      final repository = await listen(relay, waitFor: [oldest]);
      await repository.stopListening();

      final page = relay.relayPages.first;
      expect(page.tempRelays, [_relayUrl]);
      expect(page.types, [RelayType.temp]);
      expect(page.filter.since, lastWire - 2 * _day);
      expect(page.filter.until, third.createdAt);
      expect(page.filter.p, [_owner]);
    });

    test('saves the window once the unread part is recorded, and reads that '
        'part on the next launch', () async {
      final first = _CappedRelay(stored, maxLimit: 3)..unsettledFromPage = 1;
      final repository = await listen(first);
      await repository.stopListening();

      final sync = DmSyncState(prefs);
      expect(sync.newestWireSyncedAt(_owner), newest.createdAt);
      expect(sync.catchUpDebt(_owner), [
        DmCatchUpDebt(
          relay: _relayUrl,
          floor: lastWire - 2 * _day,
          until: third.createdAt,
        ),
      ]);
      expect(await isStored(oldest), isFalse);

      final second = _CappedRelay(stored, maxLimit: 6);
      final next = await listen(second, waitFor: [fourth, oldest]);
      await pumpEventQueue();
      await next.stopListening();

      expect(sync.catchUpDebt(_owner), isEmpty);
    });

    test('resumes reading where the last launch stopped', () async {
      final first = _CappedRelay(stored, maxLimit: 3)..unsettledFromPage = 2;
      final repository = await listen(first, waitFor: [oldest]);
      await pumpEventQueue();
      await repository.stopListening();
      expect(
        DmSyncState(prefs).catchUpDebt(_owner).single.until,
        oldest.createdAt,
      );

      final second = _CappedRelay(stored, maxLimit: 6);
      final next = await listen(second);
      await pumpEventQueue();
      await next.stopListening();

      expect(second.relayPages.first.filter.until, oldest.createdAt);
    });

    test('records the unread part before it saves the window', () async {
      final relay = _CappedRelay(stored, maxLimit: 3);
      final syncState = _GatedDebtSyncState(prefs);
      final repository = await listen(relay, syncState: syncState);
      await syncState.reached.future.timeout(_settleTimeout);

      expect(DmSyncState(prefs).newestWireSyncedAt(_owner), lastWire);

      syncState.release.complete();
      await pumpEventQueue();
      expect(DmSyncState(prefs).newestWireSyncedAt(_owner), newest.createdAt);
      await repository.stopListening();
    });

    test('drops the stamps when the session ends while the unread part is '
        'recorded', () async {
      final relay = _CappedRelay(stored, maxLimit: 3);
      final syncState = _GatedDebtSyncState(prefs);
      final repository = await listen(relay, syncState: syncState);
      await syncState.reached.future.timeout(_settleTimeout);

      final closing = repository.stopListening();
      syncState.release.complete();
      await closing;

      expect(DmSyncState(prefs).newestWireSyncedAt(_owner), lastWire);
    });
  });

  group('first open', () {
    test(
      'leaves the history below a capped batch to the history drain',
      () async {
        final at = now();
        final stored = [
          await wrapAt(wire: at - 3600, content: 'newest'),
          await wrapAt(wire: at - 2 * 3600, content: 'older'),
        ];
        final relay = _CappedRelay(stored, maxLimit: 1);
        final repository = launch(relay);
        await repository.startListening();
        expect(relay.reqFilters.single.since, isNull);
        relay.sendBatch();
        await settled(stored.first);
        relay.endBatch();
        await pumpEventQueue();
        // A reconnect replays the same capped batch after the first save.
        relay.endBatch();
        await pumpEventQueue();
        await repository.stopListening();

        expect(relay.relayPages, isEmpty);
        expect(DmSyncState(prefs).catchUpDebt(_owner), isEmpty);
      },
    );
  });
}
