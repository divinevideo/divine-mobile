// ABOUTME: History restore must not complete past DMs a relay hides from a
// ABOUTME: request that mixes protected and unprotected kinds (#9468).

import 'dart:async';
import 'dart:convert';
import 'dart:math';

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
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

final String _ownerSecret = '3' * 64;
final String _aliceSecret = '4' * 64;
final String _owner = getPublicKey(_ownerSecret);
final String _alice = getPublicKey(_aliceSecret);

/// Whether a gift wrap left a message row or a processed-wrap ledger entry.
const _storedSql = '''
SELECT EXISTS (SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1)
  OR EXISTS (SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1)
  AS stored
''';

bool _admits(nostr_filter.Filter filter, Event event) {
  final ids = filter.ids;
  if (ids != null && !ids.contains(event.id)) return false;
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
  final since = filter.since;
  if (since != null && event.createdAt < since) return false;
  final until = filter.until;
  if (until != null && event.createdAt > until) return false;
  return true;
}

/// A relay with strfry's restricted reads (hoytech/strfry#250), which
/// Divine's relay gate (divine-funnelcake#1116) shares for a single filter.
///
/// A request whose every filter asks only for kinds 4 and 1059 reaches the
/// gate: the pool authenticates and the relay serves it. Any other request is
/// served with those kinds left out and ends like a complete answer, with no
/// challenge and no refusal. With [gated] false the relay serves everything.
/// [cap] is the relay's own result limit, which clamps a request's `limit`.
class _GatedRelay {
  _GatedRelay(
    this.stored, {
    required this.gated,
    this.cap,
    this.unsettledKinds = const {},
  });

  /// Kinds a request may not ask for and still be settled: the relay never
  /// ends such a request.
  final Set<int> unsettledKinds;

  bool settles(List<nostr_filter.Filter> filters) => !filters.any(
    (filter) => filter.kinds?.any(unsettledKinds.contains) ?? false,
  );

  static const Set<int> _protectedKinds = {
    EventKind.giftWrap,
    EventKind.directMessage,
  };

  final List<Event> stored;
  final bool gated;
  final int? cap;
  final List<List<nostr_filter.Filter>> requests = [];

  static bool _protectedOnly(List<nostr_filter.Filter> filters) =>
      filters.every(
        (filter) =>
            (filter.kinds?.isNotEmpty ?? false) &&
            filter.kinds!.every(_protectedKinds.contains),
      );

  List<Event> answer(List<nostr_filter.Filter> filters) {
    requests.add(filters);
    final reachesGate = _protectedOnly(filters);
    final served = [
      for (final event in stored)
        if (filters.any((filter) => _admits(filter, event)) &&
            (!gated || reachesGate || !_protectedKinds.contains(event.kind)))
          event,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final asked = filters
        .map((f) => f.limit)
        .nonNulls
        .fold<int?>(
          null,
          (worst, l) => worst == null || l > worst ? l : worst,
        );
    final relayCap = cap;
    final limit = asked == null
        ? relayCap
        : relayCap == null
        ? asked
        : min(asked, relayCap);
    return limit == null ? served : served.take(limit).toList();
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

  _MockNostrClient clientFor(_GatedRelay relay) {
    final client = _MockNostrClient();
    when(() => client.connectedRelayCount).thenReturn(1);
    when(() => client.configuredRelayCount).thenReturn(1);
    when(() => client.configuredRelays).thenReturn(const ['wss://inbox.test']);
    when(() => client.relayStatuses).thenReturn(const {});
    when(
      () => client.relayStatusStream,
    ).thenAnswer((_) => const Stream.empty());
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
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      final events = relay.answer(filters);
      return relay.settles(filters)
          ? (events: events, timedOut: false, noRelays: false)
          : (events: const <Event>[], timedOut: true, noRelays: false);
    });
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
      ),
    ).thenAnswer((invocation) async {
      final filters =
          invocation.positionalArguments.first as List<nostr_filter.Filter>;
      final events = relay.answer(filters);
      return relay.settles(filters)
          ? QueryResult(
              events: events,
              endedBy: QueryEnd.complete,
              answeredNetworkRelayCount: 1,
            )
          : const QueryResult(
              events: [],
              endedBy: QueryEnd.deadline,
              unansweredRelayCount: 1,
            );
    });
    when(() => client.unsubscribe(any())).thenAnswer((_) async {});
    return client;
  }

  DmRepository launch(_GatedRelay relay) {
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
      syncState: DmSyncState(prefs),
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

  /// A real, fully signed NIP-59 wrap of a kind-14 from Alice to the owner.
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

  /// A NIP-04 direct message from Alice to the owner.
  Event nip04At({required int createdAt, required String content}) => Event(
    _alice,
    EventKind.directMessage,
    [
      ['p', _owner],
    ],
    NIP04.encrypt(content, NIP04.getAgreement(_aliceSecret), _owner),
    createdAt: createdAt,
  )..sign(_aliceSecret);

  /// Alice's NIP-09 deletion of her message [target], p-tagged to the owner.
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

  int now() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  group('history restore against a relay that gates DMs behind AUTH', () {
    test(
      'reads a gift wrap the relay hides from a request that mixes kinds',
      () async {
        final wrap = await wrapAt(wire: now() - 3600, content: 'hidden');
        final relay = _GatedRelay([wrap], gated: true);
        final repository = launch(relay);

        await repository.backfillHistoryIfNeeded();

        // The drain ran to its end against this relay.
        expect(DmSyncState(prefs).historyDrainComplete(_owner), isTrue);
        expect(
          await isStored(wrap),
          isTrue,
          reason:
              'history was marked complete, but the drain never read the '
              'gift wrap the relay held; requests sent: '
              '${relay.requests.map((r) => r.map((f) => f.kinds).toList())}',
        );
        await repository.stopListening();
      },
    );

    test('reads the same gift wrap from a relay with no gate', () async {
      final wrap = await wrapAt(wire: now() - 3600, content: 'open');
      final relay = _GatedRelay([wrap], gated: false);
      final repository = launch(relay);

      await repository.backfillHistoryIfNeeded();

      expect(DmSyncState(prefs).historyDrainComplete(_owner), isTrue);
      expect(await isStored(wrap), isTrue);
      await repository.stopListening();
    });
  });

  group('history restore paging protected kinds apart from deletions', () {
    test(
      'reads every gift wrap when the deletions reach further back than a '
      'capped page of wraps',
      () async {
        final at = now();
        final wraps = [
          await wrapAt(wire: at - 1000, content: 'newest'),
          await wrapAt(wire: at - 2000, content: 'middle'),
          await wrapAt(wire: at - 3000, content: 'oldest'),
        ];
        // Deletions from Alice of messages the owner never received: they
        // land nowhere, but their stamps reach below the second wrap.
        final deletions = [
          nip04DeletionAt(createdAt: at - 1500, target: '1' * 64),
          nip04DeletionAt(createdAt: at - 9000, target: '2' * 64),
        ];
        // The relay returns two events per read, whatever the drain asks.
        final relay = _GatedRelay(
          [...wraps, ...deletions],
          gated: false,
          cap: 2,
        );
        final repository = launch(relay);

        await repository.backfillHistoryIfNeeded();

        expect(DmSyncState(prefs).historyDrainComplete(_owner), isTrue);
        for (final wrap in wraps) {
          expect(
            await isStored(wrap),
            isTrue,
            reason: 'a page moved past a gift wrap the relay never sent',
          );
        }
        await repository.stopListening();
      },
    );

    test(
      'applies a deletion read on an earlier page than the message it names',
      () async {
        final at = now();
        final message = nip04At(
          createdAt: at - 2000,
          content: 'take this back',
        );
        final deletion = nip04DeletionAt(
          createdAt: at - 1000,
          target: message.id,
        );
        // One event per read: the newer deletion arrives a page before the
        // message it names.
        final relay = _GatedRelay([message, deletion], gated: false, cap: 1);
        final repository = launch(relay);

        await repository.backfillHistoryIfNeeded();

        final row = await DirectMessagesDao(
          db,
        ).getMessageById(message.id, ownerPubkey: _owner);
        expect(row, isNotNull, reason: 'the message itself was restored');
        expect(row!.isDeleted, isTrue);
        await repository.stopListening();
      },
    );

    test(
      'does not complete while no relay has settled the deletions',
      () async {
        final wrap = await wrapAt(wire: now() - 3600, content: 'kept');
        final relay = _GatedRelay(
          [wrap],
          gated: false,
          unsettledKinds: {EventKind.eventDeletion},
        );
        final repository = launch(relay);

        await repository.backfillHistoryIfNeeded();

        // The wraps were read, so the drain reached the deletions.
        expect(await isStored(wrap), isTrue);
        expect(DmSyncState(prefs).historyDrainComplete(_owner), isFalse);
        await repository.stopListening();
      },
    );
  });
}
