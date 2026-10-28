// ABOUTME: #10012 — a send held because the recipient's kind-10050 inbox was
// ABOUTME: unreadable publishes no self-addressed copy on that attempt, so
// ABOUTME: the sender's other devices never show a message this one has not
// ABOUTME: counted as delivered. Found and absent inboxes are unchanged.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

// Real curve keys: the real message service encrypts every wrap, so each
// pubkey has to be a point the NIP-44 key agreement accepts.
const _ownerKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _peerBKey =
    '6a1f2e3d4c5b6a7980f1e2d3c4b5a69788f9e0d1c2b3a4958677f8e9d0c1b2a3';
const _peerCKey =
    '7b2e3f4a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1c2d3e4f5a6';

const _poolRelay = 'wss://relay.divine.video';
const _advertisedInbox = 'wss://inbox.example.com';

/// What a recipient's kind-10050 lookup comes back as.
enum _Inbox {
  /// The recipient's list is in hand.
  found,

  /// Every relay answered and none holds a list.
  absent,

  /// No relay took the REQ: we could not read it.
  unreadable,
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<nostr_filter.Filter>[]);
  });

  group('#10012 a send held on an unreadable inbox', () {
    final owner = getPublicKey(_ownerKey);
    final peerB = getPublicKey(_peerBKey);
    final peerC = getPublicKey(_peerCKey);

    late AppDatabase db;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late Map<String, _Inbox> inboxes;
    late List<Event> published;
    late DmRepository repository;

    /// Every gift wrap this device published addressed to the sender: the
    /// copies the sender's other devices ingest as their own sent message.
    List<Event> selfCopies() => [
      for (final event in published)
        if (event.kind == EventKind.giftWrap &&
            event.tags.any(
              (tag) => tag.length >= 2 && tag[0] == 'p' && tag[1] == owner,
            ))
          event,
    ];

    ({List<Event> events, bool timedOut, bool noRelays}) answerLookup(
      List<nostr_filter.Filter> filters,
    ) {
      final pubkey = filters.first.authors!.single;
      return switch (inboxes[pubkey] ?? _Inbox.absent) {
        _Inbox.found => (
          events: [
            Event(
              pubkey,
              EventKind.dmRelaysList,
              [
                ['relay', _advertisedInbox],
              ],
              '',
              createdAt: 1700000000,
            ),
          ],
          timedOut: false,
          noRelays: false,
        ),
        _Inbox.absent => (
          events: const <Event>[],
          timedOut: false,
          noRelays: false,
        ),
        _Inbox.unreadable => (
          events: const <Event>[],
          timedOut: false,
          noRelays: true,
        ),
      };
    }

    /// A repository on the real message service; [queue] null is a send
    /// with no durable row to hold.
    DmRepository buildRepository({required OutgoingDmsDao? queue}) {
      final signer = LocalNostrSigner(_ownerKey);
      return DmRepository(
        nostrClient: nostrClient,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: owner,
          nostrService: nostrClient,
        ),
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: ConversationsDao(db),
        outgoingDmsDao: queue,
        userPubkey: owner,
        signer: signer,
      );
    }

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      outgoingDao = OutgoingDmsDao(db);
      nostrClient = _MockNostrClient();
      inboxes = {};
      published = [];

      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelays).thenReturn(const [_poolRelay]);
      when(() => nostrClient.isRelayAllowed(any())).thenReturn(true);
      when(
        () => nostrClient.queryEventsDetailed(
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
      ).thenAnswer(
        (invocation) async => answerLookup(
          (invocation.positionalArguments.first as List)
              .cast<nostr_filter.Filter>(),
        ),
      );
      // Every relay confirms every recipient wrap: a confirmed pool `OK` on
      // an unreadable inbox is the exact case #7317 holds pending.
      when(
        () => nostrClient.publishEventAwaitOk(
          any(),
          targetRelays: any(named: 'targetRelays'),
          timeout: any(named: 'timeout'),
          diagnosticTag: any(named: 'diagnosticTag'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        return PublishOutcome(
          eventId: event.id,
          acceptedBy: const [_poolRelay],
          rejectedBy: const {},
          noResponseFrom: const [],
        );
      });
      when(
        () => nostrClient.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        final event = invocation.positionalArguments.first as Event;
        published.add(event);
        return PublishSuccess(event: event);
      });

      repository = buildRepository(queue: outgoingDao);
    });

    tearDown(() async {
      await db.close();
    });

    group('sendMessage', () {
      test('publishes the recipient wrap but no self-copy, and keeps the row '
          'pending for the full-send arm', () async {
        inboxes[peerB] = _Inbox.unreadable;

        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'held on an unreadable inbox',
        );

        expect(result.retryablePending, isTrue);
        expect(
          selfCopies(),
          isEmpty,
          reason:
              'a self-copy here shows the message as sent on every other '
              'device while this one holds it and may end it failed',
        );
        expect(
          published,
          hasLength(1),
          reason: 'the recipient wrap still goes to the fallback pool',
        );
        final row = await outgoingDao.getById(result.queuedRumorId!);
        expect(row, isNotNull);
        // Pending on both wraps: `recipient sent / self failed` would send
        // the row to the self-wrap-only arm, which never republishes the
        // recipient wrap the sweep exists to re-resolve.
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.selfWrapStatus, OutgoingWrapStatus.pending);
        expect(row.retryCount, equals(1));
      });

      test('still publishes one self-copy when the inbox is found', () async {
        inboxes[peerB] = _Inbox.found;

        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'routed to the advertised inbox',
        );

        expect(result.success, isTrue);
        expect(selfCopies(), hasLength(1));
        expect(await outgoingDao.getAllForOwner(owner), isEmpty);
      });

      test(
        'still publishes one self-copy when the recipient advertises no '
        'inbox',
        () async {
          inboxes[peerB] = _Inbox.absent;

          final result = await repository.sendMessage(
            recipientPubkey: peerB,
            content: 'the pool is where they read',
          );

          expect(result.success, isTrue);
          expect(selfCopies(), hasLength(1));
          expect(await outgoingDao.getAllForOwner(owner), isEmpty);
        },
      );
    });

    group('recoverFullSend', () {
      test('publishes no self-copy while the inbox stays unreadable', () async {
        inboxes[peerB] = _Inbox.unreadable;
        final held = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'still unreadable on the sweep',
        );
        final rumorId = held.queuedRumorId!;

        final retried = await repository.recoverFullSend(rumorId: rumorId);

        expect(retried.retryablePending, isTrue);
        expect(selfCopies(), isEmpty);
        expect(
          published,
          hasLength(1),
          reason:
              'the pool already holds the first recipient wrap, so the retry '
              'publishes no other while the inbox stays unreadable (#10012)',
        );
        final row = await outgoingDao.getById(rumorId);
        expect(row!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(row.selfWrapStatus, OutgoingWrapStatus.pending);
        expect(row.retryCount, equals(2));
      });

      test(
        'publishes the self-copy once when a later attempt finds the inbox',
        () async {
          inboxes[peerB] = _Inbox.unreadable;
          final held = await repository.sendMessage(
            recipientPubkey: peerB,
            content: 'found on the next sweep',
          );
          final rumorId = held.queuedRumorId!;
          inboxes[peerB] = _Inbox.found;

          final retried = await repository.recoverFullSend(rumorId: rumorId);

          expect(retried.success, isTrue);
          expect(selfCopies(), hasLength(1));
          expect(await outgoingDao.getById(rumorId), isNull);
        },
      );
    });

    group('sendGroupMessage', () {
      test('withholds the self-copy only on the unreadable member '
          'attempt', () async {
        inboxes[peerB] = _Inbox.found;
        inboxes[peerC] = _Inbox.unreadable;

        final results = await repository.sendGroupMessage(
          recipientPubkeys: [peerB, peerC],
          content: 'one readable member, one unreadable',
        );

        expect(results.first.success, isTrue);
        expect(results.last.retryablePending, isTrue);
        expect(
          selfCopies(),
          hasLength(1),
          reason:
              "B's attempt delivered and carries the copy; C's is held and "
              'must not add one',
        );
      });

      test('publishes no self-copy when every member is unreadable', () async {
        inboxes[peerB] = _Inbox.unreadable;
        inboxes[peerC] = _Inbox.unreadable;

        final results = await repository.sendGroupMessage(
          recipientPubkeys: [peerB, peerC],
          content: 'nobody readable',
        );

        expect(results.every((r) => r.retryablePending), isTrue);
        expect(selfCopies(), isEmpty);
        expect(published, hasLength(2));
      });
    });

    // Nothing holds a send with no durable row, so its pool `OK` stays
    // delivered and the copy has no later attempt to ride on.
    group('without the durable queue', () {
      test('sendMessage still publishes the self-copy on an unreadable '
          'inbox', () async {
        inboxes[peerB] = _Inbox.unreadable;

        final result = await buildRepository(queue: null).sendMessage(
          recipientPubkey: peerB,
          content: 'no row to hold',
        );

        expect(result.success, isTrue);
        expect(selfCopies(), hasLength(1));
      });

      test('sendGroupMessage still publishes the self-copy on an unreadable '
          'inbox', () async {
        inboxes[peerB] = _Inbox.unreadable;
        inboxes[peerC] = _Inbox.unreadable;

        final results = await buildRepository(queue: null).sendGroupMessage(
          recipientPubkeys: [peerB, peerC],
          content: 'no rows to hold',
        );

        expect(results.every((r) => r.success), isTrue);
        expect(
          selfCopies(),
          hasLength(2),
          reason: 'each member send publishes its own copy today',
        );
      });
    });
  });
}
