// ABOUTME: E2E regression for #8434 — a group DM fans one rumor out as one gift
// ABOUTME: wrap per recipient, so a recipient whose kind-10050 inbox is
// ABOUTME: UNREADABLE must not have that recipient's fallback-pool OK scored as
// ABOUTME: delivery while a readable sibling in the same send still is; and
// ABOUTME: for #10012, once that member's retries run out the real retry
// ABOUTME: sweep stops it rather than failing it.
// ABOUTME: Drives a real DmRepository + NostrClient over real sockets.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
library;

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip19/pubkey_for_logs.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Redirects the public hostnames a relay list advertises onto the in-process
/// relay. A `ws://127.0.0.1` host can never *be* an admitted target
/// (`isRemoteSuppliedRelayUrlAllowed` refuses loopback by design), so an
/// advertised inbox has to be reached through a redirect like this one.
class _RedirectFactory implements WebSocketChannelFactory {
  _RedirectFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) => WebSocketChannel.connect(
    Uri.parse('ws://127.0.0.1:$port${uri.path}'),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  // "Readable" — the relay serves this one's kind-10050.
  const readableKey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  // "Unreadable" — the relay swallows every REQ naming this author.
  const unreadableKey =
      '3333333333333333333333333333333333333333333333333333333333333333';
  final senderPubkey = getPublicKey(senderKey);
  final readablePubkey = getPublicKey(readableKey);
  final unreadablePubkey = getPublicKey(unreadableKey);

  final groupConversationId = DmRepository.computeConversationId([
    senderPubkey,
    readablePubkey,
    unreadablePubkey,
  ]);

  /// A kind-10050 the readable recipient signs, advertising one admissible
  /// public host. `_RedirectFactory` lands the dial on the in-process relay.
  Map<String, dynamic> readableInbox() {
    final event = Event(
      readablePubkey,
      EventKind.dmRelaysList,
      [
        ['relay', 'wss://inbox-1.example'],
      ],
      '',
      createdAt: 1700000000,
    )..sign(readableKey);
    return event.toJson();
  }

  /// Builds the real stack the way `repository_providers.dart` does.
  ///
  /// `outgoingDmsDao` is wired deliberately: production never builds this
  /// repository without the queue, and the whole subject here is what happens
  /// to the durable row.
  Future<({DmRepository repository, AppDatabase db})> buildStack(
    FakeRelay relay,
  ) async {
    final factory = _RedirectFactory(relay.port);
    final signer = LocalNostrSigner(senderKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: relay.url,
        storage: InMemoryRelayStorage(),
      ),
      relayPool: nostr.relayPool,
    );
    final client = NostrClient.forTesting(
      nostr: nostr,
      relayManager: relayManager,
    );

    final db = AppDatabase.test(NativeDatabase.memory());
    addTearDown(db.close);

    final messageService = NIP17MessageService(
      signer: signer,
      senderPublicKey: senderPubkey,
      nostrService: client,
    );

    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: senderPubkey,
      signer: signer,
      messageService: messageService,
    );
    addTearDown(repository.stopListening);
    addTearDown(nostr.relayPool.removeAll);
    await client.initialize();

    return (repository: repository, db: db);
  }

  /// The surviving queue row for [recipient], or null once it was consumed.
  Future<OutgoingDm?> queueRowFor(AppDatabase db, String recipient) async {
    final rows = await db.outgoingDmsDao.getForConversation(
      conversationId: groupConversationId,
      ownerPubkey: senderPubkey,
    );
    for (final row in rows) {
      if (row.recipientPubkey == recipient) return row;
    }
    return null;
  }

  setUp(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });
  tearDown(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });

  group('#8434 group DM send on a partially unreadable fan-out', () {
    testWidgets(
      'ARM A: the recipient whose inbox could not be read is held pending '
      'with its row kept, while the readable sibling in the SAME send is '
      'still delivered and consumed',
      (tester) async {
        // The relay serves the readable recipient's kind-10050 and swallows
        // every REQ naming the unreadable one — neither EVENT nor EOSE, which
        // is the only shape that makes `queryEventsDetailed` report
        // `timedOut`. An EOSE would be a conclusive "nothing here", i.e.
        // `absent`, which is a fact about the recipient and correctly still
        // routes to the pool.
        final relay = await FakeRelay.start(
          reply: readableInbox(),
          replyForKinds: const {EventKind.dmRelaysList},
          stallReqForAuthors: {unreadablePubkey},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        expect(
          (await stack.repository.resolveDmInboxRelaysDetailed(
            readablePubkey,
          )).state,
          DmInboxResolution.found,
          reason: 'precondition: this recipient must be READABLE',
        );
        expect(
          (await stack.repository.resolveDmInboxRelaysDetailed(
            unreadablePubkey,
          )).state,
          DmInboxResolution.unreadable,
          reason: 'precondition: this recipient must be UNREADABLE, not absent',
        );

        final results = await stack.repository.sendGroupMessage(
          recipientPubkeys: [readablePubkey, unreadablePubkey],
          content: 'group message with one unreadable recipient',
        );

        expect(results, hasLength(2));

        // The readable sibling is untouched by this fix: its wrap went to the
        // inbox it advertises, so the OK is real delivery.
        expect(
          results[0].success,
          isTrue,
          reason: 'the readable recipient must still be delivered',
        );
        expect(
          await queueRowFor(stack.db, readablePubkey),
          isNull,
          reason: 'a delivered sibling consumes its durable row',
        );

        // Before #8434 this sibling ALSO reported success and its row was
        // deleted, so the batch read `delivered` for a recipient whose wrap
        // was written only to the fallback pool — and the handle that could
        // have re-resolved and republished was destroyed.
        expect(
          results[1].success,
          isFalse,
          reason:
              'a fallback-pool OK is not delivery when the inbox was '
              'unreadable',
        );
        expect(results[1].retryablePending, isTrue);
        final held = await queueRowFor(stack.db, unreadablePubkey);
        expect(
          held,
          isNotNull,
          reason: 'the sweep needs this row to re-resolve and re-drive',
        );
        expect(held!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(
          results[1].queuedRumorId,
          held.id,
          reason: 'the caller needs the durable handle to re-drive this row',
        );
      },
    );

    testWidgets(
      'ARM B: control — when every recipient is readable the fan-out is '
      'delivered and every row is consumed',
      (tester) async {
        // Same relay, no stall: this arm exists so ARM A cannot pass merely
        // because the send is broken for everyone.
        final relay = await FakeRelay.start(
          reply: readableInbox(),
          replyForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final results = await stack.repository.sendGroupMessage(
          recipientPubkeys: [readablePubkey, unreadablePubkey],
          content: 'group message with every inbox readable',
        );

        expect(results.every((r) => r.success), isTrue);
        expect(await queueRowFor(stack.db, readablePubkey), isNull);
        expect(await queueRowFor(stack.db, unreadablePubkey), isNull);
      },
    );

    testWidgets(
      'ARM C: a wholly unreadable fan-out holds every row, and the retry '
      'sweep does not consume what the send preserved',
      (tester) async {
        // Stalling the kind rather than the authors makes every recipient
        // unreadable at once. The second half is the failure #7317's review
        // round caught on the 1:1 path: a send-path fix the sweep then undoes
        // is worth one sweep interval and nothing else.
        final relay = await FakeRelay.start(
          stallReqForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final results = await stack.repository.sendGroupMessage(
          recipientPubkeys: [readablePubkey, unreadablePubkey],
          content: 'group message with no readable inbox',
        );

        expect(results, hasLength(2));
        expect(results.every((r) => r.retryablePending), isTrue);
        final rows = [
          await queueRowFor(stack.db, readablePubkey),
          await queueRowFor(stack.db, unreadablePubkey),
        ];
        expect(rows.every((r) => r != null), isTrue);

        final replayed = await stack.repository.recoverFullSend(
          rumorId: rows[0]!.id,
        );
        expect(
          replayed.success,
          isFalse,
          reason: 'the sweep re-resolves the same unreadable inbox',
        );
        expect(
          await queueRowFor(stack.db, readablePubkey),
          isNotNull,
          reason: 'the re-drive must not consume the row the send preserved',
        );
      },
    );
  });

  group('#10012 a held group member whose retries run out', () {
    /// Runs the real retry sweep, passes ten minutes apart, which outlasts
    /// the interrupted-send guard and every backoff, until the row of
    /// [member] leaves pending; returns it as that pass left it.
    Future<OutgoingDm?> sweepUntilRetriesRunOut(
      DmRepository repository,
      AppDatabase db,
      String member,
    ) async {
      var offset = Duration.zero;
      final service = OutgoingDmRetryService(
        dmRepository: repository,
        outgoingDmsDao: db.outgoingDmsDao,
        userPubkey: senderPubkey,
        appForegroundStream: const Stream<bool>.empty(),
        now: () => DateTime.now().add(offset),
      );
      for (var pass = 0; pass < 10; pass++) {
        offset += const Duration(minutes: 10);
        await service.sweep();
        final row = await queueRowFor(db, member);
        if (row?.recipientWrapStatus != OutgoingWrapStatus.pending) return row;
      }
      fail('the retries of ${pubkeyForLogs(member)} never ran out');
    }

    // A stored message with a stopped member reads "Not sent to everyone";
    // conversation_state_test.dart pins that ("a sibling the sender stopped:
    // notSentToEveryone", #8180). These arms pin what the sweep owns: which
    // rows it stops, and that the message stays stored.
    testWidgets(
      'ARM D: the member held on an unreadable inbox is stopped, not failed, '
      'and the message stays stored for the member who got it',
      (tester) async {
        final relay = await FakeRelay.start(
          reply: readableInbox(),
          replyForKinds: const {EventKind.dmRelaysList},
          stallReqForAuthors: {unreadablePubkey},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        // Each retry waits this long on the stalled inbox lookup.
        DmRepository.inboxResolutionBudget = const Duration(milliseconds: 300);
        final results = await stack.repository.sendGroupMessage(
          recipientPubkeys: [readablePubkey, unreadablePubkey],
          content: 'group message, one member unreadable',
        );
        expect(results[0].success, isTrue, reason: 'precondition');
        expect(results[1].retryablePending, isTrue, reason: 'precondition');
        final stored = await stack.repository
            .watchMessages(groupConversationId)
            .first;
        expect(stored, hasLength(1), reason: 'precondition: stored for one');

        final held = await sweepUntilRetriesRunOut(
          stack.repository,
          stack.db,
          unreadablePubkey,
        );

        expect(
          held?.recipientWrapStatus,
          OutgoingWrapStatus.cancelled,
          reason: 'stopped on the pass its retries ran out, never failed',
        );
        expect(held?.retryCount, greaterThanOrEqualTo(5));
        expect(
          (await stack.repository.watchMessages(groupConversationId).first).map(
            (message) => message.id,
          ),
          equals([stored.single.id]),
          reason: 'the bubble the stopped record describes is still there',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'ARM E: control — when no member got the message there is nothing to '
      'be not sent to everyone, so the held members end failed',
      (tester) async {
        final relay = await FakeRelay.start(
          stallReqForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        DmRepository.inboxResolutionBudget = const Duration(milliseconds: 300);
        final results = await stack.repository.sendGroupMessage(
          recipientPubkeys: [readablePubkey, unreadablePubkey],
          content: 'group message, no member readable',
        );
        expect(results.every((r) => r.retryablePending), isTrue);
        final held = await queueRowFor(stack.db, unreadablePubkey);
        expect(
          held?.recipientWrapEventId,
          isNotNull,
          reason: 'precondition: held on the wrap the pool accepted',
        );

        final ranOut = await sweepUntilRetriesRunOut(
          stack.repository,
          stack.db,
          unreadablePubkey,
        );

        expect(ranOut?.recipientWrapStatus, OutgoingWrapStatus.failed);
        expect(
          (await queueRowFor(stack.db, readablePubkey))?.recipientWrapStatus,
          OutgoingWrapStatus.failed,
        );
        expect(
          await stack.repository.watchMessages(groupConversationId).first,
          isEmpty,
          reason: 'no member has it, so nothing is stored',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
