// ABOUTME: Durable background sends release the composer before network work.
// ABOUTME: Real SQLite, signing and held discovery cover delivery safety.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Holds the first real SQLite conversation read across an account switch.
class _HeldConversationDao extends ConversationsDao {
  _HeldConversationDao(super.attachedDatabase);

  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<ConversationRow?> getConversation(
    String id, {
    String? ownerPubkey,
  }) async {
    if (!started.isCompleted) {
      started.complete();
      await resume.future;
    }
    return super.getConversation(id, ownerPubkey: ownerPubkey);
  }
}

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

  group('background message delivery', () {
    final owner = getPublicKey(_ownerKey);
    final peerB = getPublicKey(_peerBKey);
    final peerC = getPublicKey(_peerCKey);

    late AppDatabase db;
    late OutgoingDmsDao outgoingDao;
    late _MockNostrClient nostrClient;
    late Map<String, _Inbox> inboxes;
    late List<Event> published;
    late DmRepository repository;
    late Completer<void> discovery;
    late List<String> lookups;
    late bool failPublishes;

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
    DmRepository buildRepository({
      required OutgoingDmsDao? queue,
      ConversationsDao? conversationStore,
      DmSendPolicy? sendPolicy,
    }) {
      final signer = LocalNostrSigner(_ownerKey);
      return DmRepository(
        nostrClient: nostrClient,
        messageService: NIP17MessageService(
          signer: signer,
          senderPublicKey: owner,
          nostrService: nostrClient,
          sendPolicy: sendPolicy,
        ),
        directMessagesDao: DirectMessagesDao(db),
        conversationsDao: conversationStore ?? ConversationsDao(db),
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
      discovery = Completer<void>();
      lookups = [];
      failPublishes = false;

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
        (invocation) async {
          final filters = (invocation.positionalArguments.first as List)
              .cast<nostr_filter.Filter>();
          lookups.addAll(filters.expand((f) => f.authors ?? <String>[]));
          await discovery.future;
          return answerLookup(
            (invocation.positionalArguments.first as List)
                .cast<nostr_filter.Filter>(),
          );
        },
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
          acceptedBy: failPublishes ? const [] : const [_poolRelay],
          rejectedBy: failPublishes
              ? const {_poolRelay: 'error: temporarily unavailable'}
              : const {},
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
      await repository.stopListening();
      await db.close();
    });

    test(
      'returns a durable visible message while discovery is unresolved',
      () async {
        final send = repository.sendMessage(
          recipientPubkey: peerB,
          content: 'fast note',
          backgroundDelivery: true,
        );
        final NIP17SendResult result;
        try {
          result = await send.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          // Drain the held transport before rethrowing a regression failure.
          discovery.complete();
          await send;
          rethrow;
        }
        expect(result.success, isFalse);
        expect(result.retryablePending, isTrue);
        final row = await outgoingDao.getById(result.queuedRumorId!);
        expect(row, isNotNull);
        expect(row!.content, 'fast note');
        expect(published, isEmpty);
        expect(
          await ConversationsDao(
            db,
          ).getConversation(row.conversationId, ownerPubkey: owner),
          isNotNull,
        );
        final echo = await repository.watchOutgoing(row.conversationId).first;
        expect(echo.single.content, 'fast note');
        final finished = repository.recoverFullSend(rumorId: row.id);
        discovery.complete();
        expect((await finished).success, isTrue);
        expect(await outgoingDao.getById(row.id), isNull);
        final messages = await repository.getMessages(row.conversationId);
        expect(messages.single.id, row.rumorId);
      },
    );

    test('queues every group recipient before network discovery', () async {
      final results = await repository
          .sendGroupMessage(
            recipientPubkeys: [peerB, peerC],
            content: 'group note',
            backgroundDelivery: true,
          )
          .timeout(const Duration(seconds: 2));
      expect(results.every((r) => r.retryablePending), isTrue);
      final rows = await Future.wait([
        for (final r in results) outgoingDao.getById(r.queuedRumorId!),
      ]);
      expect(rows.every((r) => r != null), isTrue);
      expect(rows.map((r) => r!.rumorId).toSet(), hasLength(1));
      expect(published, isEmpty);
      discovery.complete();
      await repository
          .watchOutgoing(rows.first!.conversationId)
          .firstWhere((rows) => rows.isEmpty);
      expect(
        await repository.getMessages(rows.first!.conversationId),
        hasLength(1),
      );
    });

    test(
      'cancelling during discovery does not publish the queued note',
      () async {
        final result = await repository
            .sendMessage(
              recipientPubkey: peerB,
              content: 'cancel this',
              backgroundDelivery: true,
            )
            .timeout(const Duration(seconds: 2));
        final id = result.queuedRumorId!;
        final finished = repository.recoverFullSend(rumorId: id);
        await repository.cancelOutgoingSend(rumorId: id);
        discovery.complete();
        expect((await finished).success, isFalse);
        expect(published, isEmpty);
      },
    );
    test(
      'queues a second note without starting a concurrent transport',
      () async {
        final first = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'first',
          backgroundDelivery: true,
        );
        final second = await repository.sendMessage(
          recipientPubkey: peerC,
          content: 'second',
          backgroundDelivery: true,
        );
        expect(second.retryablePending, isTrue);
        expect(lookups, isNot(contains(peerC)));
        final finished = [
          repository.recoverFullSend(rumorId: first.queuedRumorId!),
          repository.recoverFullSend(rumorId: second.queuedRumorId!),
        ];
        discovery.complete();
        expect((await Future.wait(finished)).every((r) => r.success), isTrue);
      },
    );

    test('a failed durable write never accepts or publishes a note', () async {
      await db.customStatement(
        'CREATE TRIGGER refuse_queue BEFORE INSERT ON outgoing_dms '
        "BEGIN SELECT RAISE(FAIL, 'test disk full'); END",
      );
      await expectLater(
        repository.sendMessage(
          recipientPubkey: peerB,
          content: 'not saved',
          backgroundDelivery: true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(published, isEmpty);
      expect(lookups, isEmpty);
      final rows = await db
          .customSelect('SELECT COUNT(*) AS n FROM outgoing_dms')
          .getSingle();
      expect(rows.read<int>('n'), 0);
    });

    test(
      'cancelling a note waiting its background turn prevents publication',
      () async {
        final first = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'first',
          backgroundDelivery: true,
        );
        final second = await repository.sendMessage(
          recipientPubkey: peerC,
          content: 'cancel waiting',
          backgroundDelivery: true,
        );
        final finished = [
          repository.recoverFullSend(rumorId: first.queuedRumorId!),
          repository.recoverFullSend(rumorId: second.queuedRumorId!),
        ];
        await repository.cancelOutgoingSend(rumorId: second.queuedRumorId!);
        discovery.complete();
        final results = await Future.wait(finished);
        expect(results.first.success, isTrue);
        expect(results.last.success, isFalse);
        expect(
          published.where(
            (e) => e.tags.any(
              (t) => t.length >= 2 && t[0] == 'p' && t[1] == peerC,
            ),
          ),
          isEmpty,
        );
      },
    );

    test(
      'account switching fences both active discovery and queued transport',
      () async {
        final first = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'old account active',
          backgroundDelivery: true,
        );
        final second = await repository.sendMessage(
          recipientPubkey: peerC,
          content: 'old account waiting',
          backgroundDelivery: true,
        );
        final finished = [
          repository.recoverFullSend(rumorId: first.queuedRumorId!),
          repository.recoverFullSend(rumorId: second.queuedRumorId!),
        ];
        final signer = LocalNostrSigner(_peerCKey);
        repository.setCredentials(
          userPubkey: peerC,
          signer: signer,
          messageService: NIP17MessageService(
            signer: signer,
            senderPublicKey: peerC,
            nostrService: nostrClient,
          ),
        );
        discovery.complete();
        expect(
          (await Future.wait(finished)).every((r) => r.retryablePending),
          isTrue,
        );
        expect(published, isEmpty);
        for (final result in [first, second]) {
          expect(
            (await outgoingDao.getById(result.queuedRumorId!))!.ownerPubkey,
            owner,
          );
        }
      },
    );

    test(
      'failed delivery replays the stored rumor without a new intent',
      () async {
        failPublishes = true;
        final result = await repository.sendMessage(
          recipientPubkey: peerB,
          content: 'retry me',
          backgroundDelivery: true,
        );
        final id = result.queuedRumorId!;
        final finished = repository.recoverFullSend(rumorId: id);
        discovery.complete();
        expect((await finished).success, isFalse);
        final failedRow = await outgoingDao.getById(id);
        expect(failedRow!.recipientWrapStatus, OutgoingWrapStatus.failed);
        failPublishes = false;
        final retry = await repository.recoverFullSend(rumorId: id);
        expect(retry.success, isTrue);
        expect(await outgoingDao.getById(id), isNull);
        final messages = await repository.getMessages(failedRow.conversationId);
        expect(messages.single.id, failedRow.rumorId);
      },
    );
    test(
      'switching accounts during conversation visibility cannot cross owners',
      () async {
        final held = _HeldConversationDao(db);
        repository = buildRepository(
          queue: outgoingDao,
          conversationStore: held,
        );
        final send = repository.sendMessage(
          recipientPubkey: peerB,
          content: 'old account private note',
          backgroundDelivery: true,
        );
        await held.started.future;
        final signer = LocalNostrSigner(_peerCKey);
        repository.setCredentials(
          userPubkey: peerC,
          signer: signer,
          messageService: NIP17MessageService(
            signer: signer,
            senderPublicKey: peerC,
            nostrService: nostrClient,
          ),
        );
        held.resume.complete();
        final result = await send;
        final row = await outgoingDao.getById(result.queuedRumorId!);
        expect(row!.ownerPubkey, owner);
        expect(
          await ConversationsDao(
            db,
          ).getConversation(row.conversationId, ownerPubkey: peerC),
          isNull,
        );
        expect(published, isEmpty);
        discovery.complete();
      },
    );
    for (final groupSend in [false, true]) {
      test(
        'account switch during policy cannot enqueue under the next owner '
        '(group=$groupSend)',
        () async {
          final policyStarted = Completer<void>();
          final policy = Completer<DmSendPolicyDecision>();
          repository = buildRepository(
            queue: outgoingDao,
            sendPolicy: (_) {
              if (!policyStarted.isCompleted) policyStarted.complete();
              return policy.future;
            },
          );
          final send = groupSend
              ? repository.sendGroupMessage(
                  recipientPubkeys: [peerB, peerC],
                  content: 'private old account intent',
                  backgroundDelivery: true,
                )
              : repository
                    .sendMessage(
                      recipientPubkey: peerB,
                      content: 'private old account intent',
                      backgroundDelivery: true,
                    )
                    .then((r) => [r]);
          await policyStarted.future;
          final signer = LocalNostrSigner(_peerCKey);
          repository.setCredentials(
            userPubkey: peerC,
            signer: signer,
            messageService: NIP17MessageService(
              signer: signer,
              senderPublicKey: peerC,
              nostrService: nostrClient,
            ),
          );
          policy.complete(DmSendPolicyDecision.allowed);
          final results = await send;
          expect(
            results.every((r) => !r.success && !r.retryablePending),
            isTrue,
          );
          final rows = await db
              .customSelect('SELECT COUNT(*) AS n FROM outgoing_dms')
              .getSingle();
          expect(rows.read<int>('n'), 0);
          expect(published, isEmpty);
          discovery.complete();
        },
      );
    }
  });
}
