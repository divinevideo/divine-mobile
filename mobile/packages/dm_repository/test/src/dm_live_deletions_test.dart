// ABOUTME: Deletions the live kind-5 REQ reads (#9468): early ones, a batch a
// ABOUTME: relay capped, and their handling across an account switch.

import 'dart:async';

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
import 'package:nostr_sdk/relay/query_result.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/subscription.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/live_dm_reads.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNip17MessageService extends Mock implements NIP17MessageService {}

final String _ownerSecret = '5' * 64;
final String _otherSecret = '6' * 64;
final String _aliceSecret = '7' * 64;
final String _bobSecret = '8' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _other = getPublicKey(_otherSecret);
final String _alice = getPublicKey(_aliceSecret);

const _day = 86400;
const _relayUrl = 'wss://relay.test';
const _settleTimeout = Duration(seconds: 10);

bool _admits(nostr_filter.Filter filter, Event event) {
  final kinds = filter.kinds;
  if (kinds != null && !kinds.contains(event.kind)) return false;
  final p = filter.p;
  if (p != null &&
      !event.tags.any(
        (tag) => tag.length > 1 && tag[0] == 'p' && p.contains(tag[1]),
      )) {
    return false;
  }
  final since = filter.since;
  if (since != null && event.createdAt < since) return false;
  final until = filter.until;
  if (until != null && event.createdAt > until) return false;
  return true;
}

/// One live REQ the repository opened, sent to by the test.
class _LiveReq {
  _LiveReq(this.onEnd, {this.onStart});

  final void Function(StoredEventsEnd)? onEnd;
  final void Function()? onStart;
  final StreamController<Event> controller = StreamController<Event>();
  int _sent = 0;

  void send(Event event) {
    _sent++;
    controller.add(event);
  }

  /// Ends the stored events, naming [capped] as relays whose batch may have
  /// stopped at their result limit.
  void end({Map<String, int?> capped = const {}}) => onEnd?.call(
    StoredEventsEnd(deliveredEventCount: _sent, possiblyCappedRelays: capped),
  );

  /// Sends the stored events again from the start, as after AUTH.
  void replay() => onStart?.call();

  /// Ends the REQ as NostrClient does when every relay refused it.
  void refuse(String reason) {
    controller.addError(RelaySubscriptionRefusedException(reason));
    unawaited(controller.close());
  }
}

/// Holds each lookup of a message id the test named until it is released, and
/// answers it with no row.
class _GatedMessagesDao extends DirectMessagesDao {
  _GatedMessagesDao(super.attachedDatabase);

  final Map<String, Completer<void>> _gates = {};

  /// Every id looked up so far, in order.
  final List<String> lookups = [];

  void hold(String id) => _gates[id] = Completer<void>();

  void release(String id) => _gates.remove(id)?.complete();

  void releaseAll() => _gates.keys.toList().forEach(release);

  @override
  Future<DirectMessageRow?> getMessageById(
    String id, {
    String? ownerPubkey,
  }) async {
    lookups.add(id);
    final gate = _gates[id];
    if (gate == null) return super.getMessageById(id, ownerPubkey: ownerPubkey);
    await gate.future;
    return null;
  }
}

/// The pool's one relay: the live REQs the repository opened, in order, and
/// the events a read of its history is answered from.
class _Relay {
  final List<_LiveReq> dmReqs = [];
  final List<_LiveReq> deletionReqs = [];
  final List<Event> stored = [];

  /// The relay's own result limit, which clamps a read's `limit`.
  int? cap;

  /// Answers a read of [filter] newest first, possibly capped once it fills
  /// its limit, as the pool judges a single relay's page.
  QueryResult read(nostr_filter.Filter filter) {
    final asked = filter.limit;
    final relayCap = cap;
    final limit = asked == null || (relayCap != null && relayCap < asked)
        ? relayCap
        : asked;
    final matching = stored.where((event) => _admits(filter, event)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final events = limit == null ? matching : matching.take(limit).toList();
    return QueryResult(
      events: events,
      endedBy: QueryEnd.complete,
      answeredNetworkRelayCount: 1,
      possiblyCapped: limit != null && events.length >= limit,
    );
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
    when(() => client.configuredRelays).thenReturn(const [_relayUrl]);
    when(() => client.relayStatuses).thenReturn(const {});
    when(() => client.isRelayAllowed(any())).thenReturn(true);
    when(
      () => client.relayStatusStream,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => client.storedEventsPossiblyCapped(any()),
    ).thenReturn(const <String, int?>{});
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
    ).thenAnswer(
      (_) async => (events: <Event>[], timedOut: false, noRelays: false),
    );
    when(
      () => client.readEvents(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        relayTypes: any(named: 'relayTypes'),
        sendAfterAuth: any(named: 'sendAfterAuth'),
        useCache: any(named: 'useCache'),
        useQueryPool: any(named: 'useQueryPool'),
        timeout: any(named: 'timeout'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        maxCollectedEvents: any(named: 'maxCollectedEvents'),
        maxCollectedBytes: any(named: 'maxCollectedBytes'),
        silentRelayTimeout: any(named: 'silentRelayTimeout'),
      ),
    ).thenAnswer(
      (invocation) async => relay.read(
        (invocation.positionalArguments.first as List<nostr_filter.Filter>)
            .single,
      ),
    );
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    for (final (read, reqs) in [
      (isLiveDmRead, relay.dmReqs),
      (isLiveDeletionsRead, relay.deletionReqs),
    ]) {
      when(
        () => client.subscribe(
          any(that: read),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          onStoredEventsStart: any(named: 'onStoredEventsStart'),
          onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
        ),
      ).thenAnswer((invocation) {
        final req = _LiveReq(
          invocation.namedArguments[#onStoredEventsEnd]
              as void Function(StoredEventsEnd)?,
          onStart:
              invocation.namedArguments[#onStoredEventsStart]
                  as void Function()?,
        );
        reqs.add(req);
        return req.controller.stream;
      });
    }
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
      syncState: DmSyncState(prefs),
      userPubkey: _owner,
      signer: LocalNostrSigner(_ownerSecret),
    );
  }

  int now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// An account whose history is restored and whose newest message was
  /// stamped [wire], so the live REQs ask from two days before it.
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

  /// A NIP-04 message from Alice to [to].
  Event nip04(String content, {String? to, int? createdAt}) {
    final recipient = to ?? _owner;
    return Event(
      _alice,
      EventKind.directMessage,
      [
        ['p', recipient],
      ],
      NIP04.encrypt(content, NIP04.getAgreement(_aliceSecret), recipient),
      createdAt: createdAt ?? now() - 600,
    )..sign(_aliceSecret);
  }

  /// A NIP-09 deletion of [targets] signed with [secret], p-tagged to [p].
  Event deletionOf(
    List<String> targets, {
    String? secret,
    List<String>? p,
    int? createdAt,
  }) => Event(
    getPublicKey(secret ?? _aliceSecret),
    EventKind.eventDeletion,
    [
      for (final target in targets) ['e', target],
      for (final pubkey in p ?? [_owner]) ['p', pubkey],
    ],
    '',
    createdAt: createdAt ?? now() - 300,
  )..sign(secret ?? _aliceSecret);

  /// Waits until [message]'s row satisfies [done].
  Future<void> rowWhere(
    Event message,
    bool Function(QueryRow row) done,
    String failure,
  ) => db
      .customSelect(
        'SELECT is_deleted FROM direct_messages WHERE id = ?1',
        variables: [Variable.withString(message.id)],
        readsFrom: {db.directMessages},
      )
      .watch()
      .firstWhere((rows) => rows.isNotEmpty && done(rows.single))
      .timeout(_settleTimeout, onTimeout: () => fail(failure));

  Future<void> stored(Event message) => rowWhere(
    message,
    (_) => true,
    'message ${message.id} was never stored',
  );

  Future<void> deleted(Event message) => rowWhere(
    message,
    (row) => row.read<bool>('is_deleted'),
    'message ${message.id} was never deleted',
  );

  Future<DirectMessageRow?> rowOf(Event message, {String? owner}) =>
      DirectMessagesDao(
        db,
      ).getMessageById(message.id, ownerPubkey: owner ?? _owner);

  group('a deletion that arrives before the message it names', () {
    late _Relay relay;
    late DmRepository repository;

    /// A message already stored when the deletions arrive: deleting it last
    /// shows that every deletion sent before it has been handled.
    late Event marker;

    setUp(() async {
      relay = _Relay();
      repository = launch(relay);
      marker = nip04('marker');
      await repository.startListening();
      relay.dmReqs.single
        ..send(marker)
        ..end();
      await stored(marker);
    });

    tearDown(() async {
      await repository.stopListening();
    });

    /// Sends [deletions] on the live deletions REQ, followed by the marker's
    /// own deletion, and waits until all of them are handled.
    Future<void> deliverDeletions(List<Event> deletions) async {
      final live = relay.deletionReqs.single;
      deletions.forEach(live.send);
      live.send(deletionOf([marker.id]));
      await deleted(marker);
    }

    test('is applied once the message arrives on the live DM REQ', () async {
      final message = nip04('take this back');
      await deliverDeletions([
        deletionOf([message.id]),
      ]);
      expect(await rowOf(message), isNull, reason: 'it arrived first');

      relay.dmReqs.single.send(message);

      await deleted(message);
      expect((await rowOf(message))!.isDeleted, isTrue);
    });

    test(
      'is not applied when someone other than the sender signed it',
      () async {
        final message = nip04('mine to retract');
        await deliverDeletions([
          deletionOf([message.id], secret: _bobSecret),
        ]);

        final after = nip04('after it');
        relay.dmReqs.single
          ..send(message)
          ..send(after);
        // Messages are handled in turn, so the first is fully handled by now.
        await stored(after);

        expect((await rowOf(message))!.isDeleted, isFalse);
      },
    );

    test("is not displaced by another author's deletion of the same "
        'message', () async {
      final message = nip04('take this back');
      await deliverDeletions([
        deletionOf([message.id]),
        deletionOf([message.id], secret: _bobSecret),
      ]);

      relay.dmReqs.single.send(message);

      await deleted(message);
      expect((await rowOf(message))!.isDeleted, isTrue);
    });

    test('holds at most the cap, dropping the oldest first', () async {
      final oldest = nip04('oldest');
      final next = nip04('next');
      // One target more than the cap: the first one held is dropped.
      final targets = [
        oldest.id,
        next.id,
        for (var i = 0; i < DmRepository.maxHeldEarlyDeletions - 1; i++)
          i.toRadixString(16).padLeft(64, '0'),
      ];
      await deliverDeletions([deletionOf(targets)]);

      relay.dmReqs.single
        ..send(oldest)
        ..send(next);

      await deleted(next);
      expect(
        (await rowOf(oldest))!.isDeleted,
        isFalse,
        reason: 'the oldest held deletion was kept past the cap',
      );
    });

    test("keeps its place when the history restore's deletions name "
        'messages it never stored', () async {
      final message = nip04('take this back');
      await deliverDeletions([
        deletionOf([message.id]),
      ]);
      final restored = nip04('restored');
      relay.dmReqs.single.send(restored);
      await stored(restored);
      // A cap's worth of targets the restore never stored, after one it did.
      relay.stored.add(
        deletionOf([
          restored.id,
          for (var i = 0; i < DmRepository.maxHeldEarlyDeletions; i++)
            i.toRadixString(16).padLeft(64, '0'),
        ]),
      );

      await repository.backfillHistoryIfNeeded();
      expect(
        (await rowOf(restored))!.isDeleted,
        isTrue,
        reason: "the restore's deletion pass read the deletion",
      );
      relay.dmReqs.single.send(message);

      await deleted(message);
      expect((await rowOf(message))!.isDeleted, isTrue);
    });

    test('is forgotten when the repository stops listening', () async {
      final message = nip04('take this back');
      await deliverDeletions([
        deletionOf([message.id]),
      ]);

      await repository.stopListening();
      await repository.startListening();
      final after = nip04('after it');
      relay.dmReqs.last
        ..end()
        ..send(message)
        ..send(after);
      await stored(after);

      expect((await rowOf(message))!.isDeleted, isFalse);
    });

    test("is not applied to the next account's copy after an account "
        'switch', () async {
      // Alice retracts a message she sent the other account, naming both.
      final message = nip04('for the other account', to: _other);
      await deliverDeletions([
        deletionOf([message.id], p: [_owner, _other]),
      ]);

      repository.setCredentials(
        userPubkey: _other,
        signer: LocalNostrSigner(_otherSecret),
        messageService: _MockNip17MessageService(),
      );
      await repository.startListening();
      final after = nip04('after it', to: _other);
      relay.dmReqs.last
        ..end()
        ..send(message)
        ..send(after);
      await stored(after);

      final row = await rowOf(message, owner: _other);
      expect(row, isNotNull, reason: 'the other account stored its copy');
      expect(row!.isDeleted, isFalse);
    });
  });

  group('a capped live deletions batch', () {
    test('leaves the older deletions to the catch-up debt walk', () async {
      final at = now();
      await establish(at - 10 * _day);
      final message = nip04('take this back', createdAt: at - 5 * _day);
      final deletion = deletionOf([message.id], createdAt: at - 4 * _day);
      // The relay's two newest deletions name messages never received.
      final newest = deletionOf(['1' * 64], createdAt: at - 2 * _day);
      final next = deletionOf(['2' * 64], createdAt: at - 3 * _day);
      final relay = _Relay()
        ..cap = 2
        ..stored.addAll([message, deletion, newest, next]);
      final repository = launch(relay);
      addTearDown(repository.stopListening);

      await repository.startListening();
      relay.dmReqs.single
        ..send(message)
        ..end();
      await stored(message);
      await pumpEventQueue();
      expect(
        DmSyncState(prefs).newestWireSyncedAt(_owner),
        message.createdAt,
        reason: "the DMs' window is saved before the deletions end",
      );
      // All the relay's limit lets it send: the deletion of the message is
      // older than both.
      relay.deletionReqs.single
        ..send(newest)
        ..send(next)
        ..end(capped: {_relayUrl: next.createdAt});

      await deleted(message);
      expect((await rowOf(message))!.isDeleted, isTrue);
    });
  });

  group('a live deletions REQ every relay refuses', () {
    test('is asked for again when the DMs replay their stored events, and '
        'its deletion is applied', () async {
      final relay = _Relay();
      final repository = launch(relay);
      addTearDown(repository.stopListening);
      final message = nip04('take this back');

      await repository.startListening();
      relay.dmReqs.single
        ..send(message)
        ..end();
      await stored(message);
      relay.deletionReqs.single.refuse('restricted: sign in first');
      await pumpEventQueue();

      // After AUTH, the relay sends the DMs' stored events again.
      relay.dmReqs.single
        ..replay()
        ..end();
      expect(relay.deletionReqs, hasLength(2));
      relay.deletionReqs.last.send(deletionOf([message.id]));

      await deleted(message);
      expect(relay.dmReqs, hasLength(1), reason: 'the DM REQ was opened again');
    });

    test('leaves its window to the catch-up debt walk, which applies its '
        'deletion before the DMs replay', () async {
      final at = now();
      await establish(at - 10 * _day);
      final message = nip04('take this back', createdAt: at - 5 * _day);
      final deletion = deletionOf([message.id], createdAt: at - 4 * _day);
      final relay = _Relay()..stored.addAll([message, deletion]);
      final repository = launch(relay);
      addTearDown(repository.stopListening);

      await repository.startListening();
      relay.dmReqs.single
        ..send(message)
        ..end();
      await stored(message);
      await pumpEventQueue();
      expect(
        DmSyncState(prefs).newestWireSyncedAt(_owner),
        message.createdAt,
        reason: "the DMs' window is saved before the deletions are refused",
      );
      relay.deletionReqs.single.refuse('rate-limited: slow down');

      await deleted(message);
      expect(
        relay.deletionReqs,
        hasLength(1),
        reason: 'no replay of the DMs asked for the deletions again',
      );
    });
  });

  group('live deletions across an account switch', () {
    test("are handled one at a time while the previous account's last one "
        'finishes', () async {
      final relay = _Relay();
      final dao = _GatedMessagesDao(db);
      final repository = launch(relay, messagesDao: dao);
      addTearDown(repository.stopListening);
      addTearDown(dao.releaseAll);
      final previous = '1' * 64;
      final first = '2' * 64;
      final second = '3' * 64;
      dao
        ..hold(previous)
        ..hold(first);

      await repository.startListening();
      relay.dmReqs.single.end();
      relay.deletionReqs.single.send(deletionOf([previous]));
      await pumpEventQueue();
      expect(dao.lookups, contains(previous));

      repository.setCredentials(
        userPubkey: _other,
        signer: LocalNostrSigner(_otherSecret),
        messageService: _MockNip17MessageService(),
      );
      await repository.startListening();
      relay.dmReqs.last.end();
      final live = relay.deletionReqs.last
        ..send(deletionOf([first], p: [_other]));
      await pumpEventQueue();
      expect(dao.lookups, contains(first));

      // The previous account's handler ends while the next account's first
      // one is still under way.
      dao.release(previous);
      await pumpEventQueue();
      live.send(deletionOf([second], p: [_other]));
      await pumpEventQueue();
      expect(
        dao.lookups,
        isNot(contains(second)),
        reason: 'the next deletion ran beside the one still being handled',
      );

      dao.release(first);
      await pumpEventQueue();
      expect(dao.lookups, contains(second));
    });
  });
}
