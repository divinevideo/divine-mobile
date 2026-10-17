// ABOUTME: A catch-up cut short by the app closing must not strand the older
// ABOUTME: messages of its batch below the next launch's window (#10191).

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
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Holds the handling of one gift wrap until the test releases it, so the
/// app can close while the rest of an ended batch is still being handled.
class _GatedMessagesDao extends DirectMessagesDao {
  _GatedMessagesDao(super.attachedDatabase, {required this.gatedWrapId});

  final String gatedWrapId;
  final Completer<void> reached = Completer<void>();
  final Completer<void> release = Completer<void>();

  @override
  Future<bool> hasGiftWrap(String giftWrapId) async {
    if (giftWrapId == gatedWrapId && !reached.isCompleted) {
      reached.complete();
      await release.future;
    }
    return super.hasGiftWrap(giftWrapId);
  }
}

final String _ownerSecret = '1' * 64;
final String _aliceSecret = '2' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);

const _day = 86400;
const _settleTimeout = Duration(seconds: 20);

/// Whether a gift wrap left a message row or a processed-wrap ledger entry.
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

/// A relay holding [stored] behind a pool that reports the end of stored
/// events the way `RelayPool` does.
///
/// A REQ is answered with the admitted events, newest first, through an
/// asynchronous stream. The end-of-stored-events count is reported as soon
/// as the last one is handed over, which is before the subscriber has
/// received them, as with `NostrClient`'s broadcast stream.
class _Relay {
  _Relay(this.stored);

  final List<Event> stored;
  final List<nostr_filter.Filter> reqFilters = [];
  final List<nostr_filter.Filter> queryFilters = [];
  final StreamController<Event> controller =
      StreamController<Event>.broadcast();
  void Function()? onStart;
  void Function(StoredEventsEnd)? onEnd;
  int handedOver = 0;

  List<Event> admitted(List<nostr_filter.Filter> filters) =>
      stored.where((e) => filters.any((f) => _admits(f, e))).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Hands over the first [count] stored events of the last REQ (all when
  /// null). The batch ends only when all of them were handed over.
  void sendStored({int? count}) {
    final events = admitted(reqFilters);
    final toSend = count == null ? events : events.take(count);
    for (final event in toSend) {
      handedOver++;
      controller.add(event);
    }
    if (count == null) {
      onEnd?.call(StoredEventsEnd(deliveredEventCount: handedOver));
    }
  }

  /// A reconnect replays the REQ: the relay sends its stored events again.
  void replayStored({int? count}) {
    onStart?.call();
    sendStored(count: count);
  }

  void sendLive(Event event) {
    handedOver++;
    controller.add(event);
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
    when(() => client.configuredRelays).thenReturn(const ['wss://r']);
    when(
      () => client.queryEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      relay.queryFilters.addAll(filters);
      return relay.admitted(filters);
    });
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
      relay.queryFilters.addAll(filters);
      // Answered from the same store, so a drain that asked would get it.
      return (
        events: relay.admitted(filters),
        timedOut: false,
        noRelays: false,
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
      relay
        ..onStart =
            invocation.namedArguments[#onStoredEventsStart] as void Function()?
        ..onEnd =
            invocation.namedArguments[#onStoredEventsEnd]
                as void Function(StoredEventsEnd)?;
      return relay.controller.stream;
    });
    return client;
  }

  DmRepository launch(_Relay relay, {DirectMessagesDao? messagesDao}) {
    messagesDao ??= DirectMessagesDao(db);
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
    );
  }

  Future<bool> isStored(Event wrap) async {
    final row = await db
        .customSelect(
          _storedSql,
          variables: [Variable.withString(wrap.id)],
        )
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

  /// A real, fully signed NIP-59 wrap of a kind-14 from Alice whose outer
  /// stamp is [wire]. The receive pipeline checks the outer signature, so the
  /// stamp is chosen when the wrap is built rather than edited afterwards.
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

  /// A live NIP-04 direct message from Alice. It needs no unwrapping, so it
  /// is not handled behind the gift wraps queued ahead of it.
  Event nip04At({required int createdAt, required String content}) => Event(
    _alice,
    EventKind.directMessage,
    [
      ['p', _owner],
    ],
    NIP04.encrypt(content, NIP04.getAgreement(_aliceSecret), _owner),
    createdAt: createdAt,
  )..sign(_aliceSecret);

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

  group('catch-up after ten days away', () {
    late int lastWire;
    late Event newest;
    late Event middle;
    late Event oldest;
    late List<Event> stored;

    setUp(() async {
      final at = now();
      lastWire = at - 10 * _day;
      await establish(lastWire);
      newest = await wrapAt(wire: at - 3600, content: 'newest');
      middle = await wrapAt(wire: at - 36 * 3600, content: 'middle');
      // Below the newest stamp minus two days, above the window that opens.
      oldest = await wrapAt(wire: at - 5 * _day, content: 'oldest');
      stored = [newest, middle, oldest];
    });

    /// Runs the second launch, after the first ended however it ended, and
    /// returns the window it asked for.
    Future<int> relaunch() async {
      final relay = _Relay(stored);
      final repository = launch(relay);
      await repository.startListening();
      relay.sendStored();
      for (final wrap in relay.admitted(relay.reqFilters)) {
        await settled(wrap);
      }
      await repository.backfillHistoryIfNeeded();
      await pumpEventQueue();
      final asked = relay.reqFilters.single.since!;
      await repository.stopListening();
      return asked;
    }

    test(
      'keeps every message when the app closes after the first one',
      () async {
        final relay = _Relay(stored);
        final first = launch(relay);
        await first.startListening();
        expect(relay.reqFilters.single.since, lastWire - 2 * _day);

        relay.sendStored(count: 1);
        await settled(newest);
        // The app closes here: the rest of the batch never reaches it.
        await first.stopListening();

        final asked = await relaunch();

        expect(asked, lastWire - 2 * _day);
        expect(await isStored(oldest), isTrue);
        expect(await isStored(middle), isTrue);
      },
    );

    test('keeps every message when the app closes while an ended batch is '
        'still being handled', () async {
      final relay = _Relay(stored);
      final messagesDao = _GatedMessagesDao(db, gatedWrapId: middle.id);
      final first = launch(relay, messagesDao: messagesDao);
      await first.startListening();

      // The relay sends the whole batch and its end at once; handling it
      // takes longer.
      relay.sendStored();
      await settled(newest);
      await messagesDao.reached.future.timeout(_settleTimeout);
      final closing = first.stopListening();
      messagesDao.release.complete();
      await closing;

      final asked = await relaunch();

      expect(asked, lastWire - 2 * _day);
      expect(await isStored(oldest), isTrue);
    });

    test('a live message handled before the batch has been does not move the '
        'window past it', () async {
      final relay = _Relay(stored);
      final messagesDao = _GatedMessagesDao(db, gatedWrapId: middle.id);
      final first = launch(relay, messagesDao: messagesDao);
      await first.startListening();
      relay.sendStored();
      await settled(newest);
      await messagesDao.reached.future.timeout(_settleTimeout);

      final live = nip04At(createdAt: now() - 10, content: 'live');
      relay.sendLive(live);
      await settled(live);
      final closing = first.stopListening();
      messagesDao.release.complete();
      await closing;

      final asked = await relaunch();

      expect(asked, lastWire - 2 * _day);
      expect(await isStored(oldest), isTrue);
    });

    test('moves the window forward once the batch has ended', () async {
      final relay = _Relay(stored);
      final first = launch(relay);
      await first.startListening();

      relay.sendStored();
      for (final wrap in stored) {
        await settled(wrap);
      }
      await pumpEventQueue();
      await first.stopListening();

      final asked = await relaunch();

      expect(asked, newest.createdAt - 2 * _day);
      expect(await isStored(oldest), isTrue);
    });

    test('moves the window forward for a live message after the batch has '
        'ended', () async {
      final relay = _Relay(stored);
      final first = launch(relay);
      await first.startListening();
      relay.sendStored();
      for (final wrap in stored) {
        await settled(wrap);
      }
      final live = await wrapAt(wire: now() - 60, content: 'live');
      relay.sendLive(live);
      await settled(live);
      await pumpEventQueue();
      await first.stopListening();

      final asked = await relaunch();

      expect(asked, live.createdAt - 2 * _day);
    });

    test(
      'a reconnect replay holds the window until that replay has ended',
      () async {
        final relay = _Relay(stored);
        final first = launch(relay);
        await first.startListening();
        relay.sendStored();
        for (final wrap in stored) {
          await settled(wrap);
        }
        await pumpEventQueue();
        expect(
          DmSyncState(prefs).newestWireSyncedAt(_owner),
          newest.createdAt,
          reason: 'the first batch ended, so its newest stamp is saved',
        );

        final newer = await wrapAt(wire: now() - 30, content: 'newer');
        stored.add(newer);
        relay.replayStored(count: 1);
        await settled(newer);
        await pumpEventQueue();
        await first.stopListening();

        expect(
          DmSyncState(prefs).newestWireSyncedAt(_owner),
          newest.createdAt,
          reason: 'a replay that did not end must not move the window',
        );
      },
    );
  });
}
