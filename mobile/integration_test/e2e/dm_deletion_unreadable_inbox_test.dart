// ABOUTME: E2E regression for #8515 — a delete-for-everyone published while the
// ABOUTME: recipient's kind-10050 inbox is UNREADABLE falls back to the default
// ABOUTME: pool and must stay `deletion_pending` with its rumor retained, never
// ABOUTME: be scored as `deletion_sent`; and for #10012 — once the retry sweep's
// ABOUTME: attempts run out it shows as failed, with one more try per launch.
// ABOUTME: Drives a real DmRepository + NostrClient over real sockets, wired as
// ABOUTME: repository_providers.dart wires them.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
library;

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
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
  final List<String> requested = [];

  @override
  WebSocketChannel create(Uri uri) {
    requested.add(uri.toString());
    return WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:$port${uri.path}'),
    );
  }
}

/// The real repository, counting the retry sweep's deletion attempts.
class _CountingDmRepository extends DmRepository {
  _CountingDmRepository({
    required super.nostrClient,
    required super.directMessagesDao,
    required super.conversationsDao,
    required super.outgoingDmsDao,
    required super.userPubkey,
    required super.signer,
    required super.messageService,
  });

  int deletionRetries = 0;

  @override
  Future<DmMessageDeletionOutcome> retryMessageDeletion({
    required String rumorId,
  }) {
    deletionRetries++;
    return super.retryMessageDeletion(rumorId: rumorId);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const recipientKey =
      '2222222222222222222222222222222222222222222222222222222222222222';
  final senderPubkey = getPublicKey(senderKey);
  final recipientPubkey = getPublicKey(recipientKey);

  final conversationId = DmRepository.computeConversationId([
    senderPubkey,
    recipientPubkey,
  ]);

  /// A kind-10050 the recipient signs, advertising one admissible public host.
  Map<String, dynamic> recipientInbox() {
    final event = Event(
      recipientPubkey,
      10050,
      [
        ['relay', 'wss://inbox-1.example'],
      ],
      '',
      createdAt: 1700000000,
    )..sign(recipientKey);
    return event.toJson();
  }

  /// Builds the real stack the way `repository_providers.dart` does. The
  /// deletion path resolves inboxes inside `DmRepository` itself, so unlike the
  /// reaction sibling (#8443) there is no resolver port to inject — the wiring
  /// under test is entirely internal to `_fanOutDeletion`.
  Future<({_CountingDmRepository repository, AppDatabase db, Nostr nostr})>
  buildStack(FakeRelay relay) async {
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

    // `outgoingDmsDao` is wired deliberately: production never builds this
    // repository without the queue, and a repository built without it can pin
    // behaviour that cannot occur (learned on #8519's e2e control).
    final repository = _CountingDmRepository(
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

    await db.conversationsDao.upsertConversation(
      id: conversationId,
      participantPubkeys: jsonEncode([senderPubkey, recipientPubkey]),
      isGroup: false,
      createdAt: 1700000000,
      ownerPubkey: senderPubkey,
    );

    return (repository: repository, db: db, nostr: nostr);
  }

  /// Seeds a retractable OWN message row directly through the DAO.
  ///
  /// Deliberately NOT `sendMessage`: a real send resolves the recipient's
  /// kind-10050 and the answer is cached, after which the deletion's own
  /// lookup is served from cache and reports `found` no matter how the relay
  /// behaves afterwards. That defeats every arm below. Seeding the row leaves
  /// the deletion as the FIRST resolution of this recipient, which is exactly
  /// the shape the device reproduction needs too.
  Future<String> seedOwnMessage(AppDatabase db, String rumorId) async {
    await db.directMessagesDao.insertMessage(
      id: rumorId,
      conversationId: conversationId,
      senderPubkey: senderPubkey,
      content: 'message that will be retracted',
      createdAt: 1700000100,
      giftWrapId: 'wrap-$rumorId',
      ownerPubkey: senderPubkey,
    );
    return rumorId;
  }

  /// `deleteMessageForEveryone` writes `deletion_pending` at its durability
  /// boundary BEFORE any wire attempt, then drives the first attempt
  /// unawaited. So "has a status" is true immediately and says nothing —
  /// this waits for a TERMINAL status instead, and returns the row still
  /// pending when the window elapses, which is itself the outcome under test.
  Future<DirectMessageRow?> settledDeletionRow(
    AppDatabase db,
    String rumorId, {
    Duration window = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(window);
    DirectMessageRow? row;
    while (DateTime.now().isBefore(deadline)) {
      row = await db.directMessagesDao.getMessageById(
        rumorId,
        ownerPubkey: senderPubkey,
      );
      final status = row?.deletionPublishStatus;
      if (status != null && status != 'deletion_pending') return row;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return row;
  }

  /// Restores the production budget after a test shortens it.
  setUp(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });
  tearDown(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });

  group('#8515 delete-for-everyone on an unreadable DM inbox', () {
    testWidgets(
      'ARM A: a deletion whose inbox lookup exceeded its budget stays '
      'deletion_pending and KEEPS its rumor, even though the pool confirmed '
      'the kind-5 wrap',
      (tester) async {
        // The relay accepts the kind-10050 REQ and never settles it, so the
        // 1ms budget expires into the `on TimeoutException` exit in
        // `_queryOwnDmInbox`, documented as "Deliberately `failed`, never
        // `absent`". The stall is what makes this deterministic: a short
        // budget alone races a relay that can still answer (see ARM B), and
        // the routing lookup inside `deleteMessageForEveryone` is unguarded,
        // so a race winner would route to the advertised inbox and settle the
        // row `deletion_sent` — red, and flaky.
        final relay = await FakeRelay.start(
          reply: recipientInbox(),
          stallReqForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final rumorId = await seedOwnMessage(
          stack.db,
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );

        DmRepository.inboxResolutionBudget = const Duration(milliseconds: 1);
        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(
          detailed.state,
          DmInboxResolution.unreadable,
          reason: 'precondition: the inbox must be UNREADABLE, not absent',
        );
        expect(detailed.relays, isNull);

        await stack.repository.deleteMessageForEveryone(rumorId);
        final row = await settledDeletionRow(stack.db, rumorId);

        // Before #8515 this was `deletion_sent` with `deletionRumorJson`
        // NULLed — a retraction the recipient never saw, and a row
        // `getRetryableOwnMessageDeletions` could never select again because
        // it requires BOTH `deletion_pending` AND a non-null rumor. That is
        // why the false positive here is unrepairable rather than merely
        // unconfirmed.
        expect(row?.deletionPublishStatus, 'deletion_pending');
        expect(
          row?.deletionRumorJson,
          isNotNull,
          reason: 'the sweep needs the stored rumor to re-resolve and re-drive',
        );
        expect(
          row?.isDeleted,
          isTrue,
          reason:
              'the bubble stays hidden either way — the fix is durable, not '
              'visual',
        );
      },
    );

    testWidgets(
      'ARM B: the retry sweep does not settle it either — a persistently '
      'unreadable inbox must not let retryMessageDeletion consume the row the '
      'first attempt preserved',
      (tester) async {
        // This arm's subject is the RETRY, not which route produced
        // `unreadable`, so it takes the deterministic one. A short budget
        // alone is a race against a relay that can still answer — at 1ms the
        // in-process socket sometimes wins, resolution comes back `found`,
        // and the arm silently stops testing anything. Stalling the kind-10050
        // REQ makes the budget expire every time.
        final relay = await FakeRelay.start(
          reply: recipientInbox(),
          stallReqForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final rumorId = await seedOwnMessage(
          stack.db,
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        );

        DmRepository.inboxResolutionBudget = const Duration(seconds: 1);
        expect(
          (await stack.repository.resolveDmInboxRelaysDetailed(
            recipientPubkey,
          )).state,
          DmInboxResolution.unreadable,
          reason: 'precondition: the inbox must be UNREADABLE, not absent',
        );

        await stack.repository.deleteMessageForEveryone(rumorId);
        await settledDeletionRow(stack.db, rumorId);

        // Same failure #7317's review round caught on `recoverFullSend`: a
        // send-path fix the sweep then undoes is worth one sweep and nothing
        // else. Pre-#8515 this returned `unavailable`, not `unconfirmed` —
        // the first drive had already cleared the stored rumor, so the retry
        // could not even attempt. That is the unrepairability, made visible.
        final outcome = await stack.repository.retryMessageDeletion(
          rumorId: rumorId,
        );
        expect(outcome, DmMessageDeletionOutcome.unconfirmed);

        final row = await stack.db.directMessagesDao.getMessageById(
          rumorId,
          ownerPubkey: senderPubkey,
        );
        expect(row?.deletionPublishStatus, 'deletion_pending');
        expect(row?.deletionRumorJson, isNotNull);

        final retryable = await stack.repository.retryableMessageDeletions();
        expect(
          retryable.map((t) => t.rumorId),
          contains(rumorId),
          reason: 'the row must remain on the sweep worklist',
        );
      },
    );

    testWidgets(
      'ARM C (control): a genuinely ABSENT inbox is still legitimately '
      'retracted — #8515 must not over-fire on absence',
      (tester) async {
        // EOSE with no event: the relays answered, the recipient advertises
        // nothing. Routing still falls back to the pool — the deliberate #570
        // deviation from NIP-17's "clients shouldn't try" — and that OK is
        // scored as delivery because we keep the deviation.
        final relay = await FakeRelay.start();
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final rumorId = await seedOwnMessage(
          stack.db,
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(
          detailed.state,
          DmInboxResolution.absent,
          reason: 'precondition: the inbox must be ABSENT, not unreadable',
        );

        await stack.repository.deleteMessageForEveryone(rumorId);
        final row = await settledDeletionRow(stack.db, rumorId);

        expect(row?.deletionPublishStatus, 'deletion_sent');
        expect(
          row?.deletionRumorJson,
          isNull,
          reason: 'a delivered retraction has nothing left to replay',
        );
      },
    );

    testWidgets(
      'ARM D: a relay that accepts the kind-10050 REQ and never settles it is '
      'the other route into unreadable, and holds the deletion the same way',
      (tester) async {
        // No budget hook: the relay accepts the REQ and never terminates it,
        // so `queryEventsDetailed` reports `timedOut` and the deletion path
        // maps it to `unreadable`. This is the shape the device patrol
        // reproduces with `docker pause`.
        final relay = await FakeRelay.start(
          reply: recipientInbox(),
          stallReqForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final rumorId = await seedOwnMessage(
          stack.db,
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        );

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(detailed.state, DmInboxResolution.unreadable);

        await stack.repository.deleteMessageForEveryone(rumorId);
        final row = await settledDeletionRow(stack.db, rumorId);

        expect(row?.deletionPublishStatus, 'deletion_pending');
        expect(row?.deletionRumorJson, isNotNull);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('#10012 a held delete-for-everyone whose retries run out', () {
    /// A launch: a fresh retry sweep over the same repository and store.
    /// [clockOffset] is read on every call, so a test steps past the backoff
    /// between passes instead of waiting it out.
    OutgoingDmRetryService launch(
      DmRepository repository,
      AppDatabase db,
      Duration Function() clockOffset,
    ) => OutgoingDmRetryService(
      dmRepository: repository,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: senderPubkey,
      appForegroundStream: const Stream<bool>.empty(),
      now: () => DateTime.now().add(clockOffset()),
    );

    /// Every gift wrap the relay received addressed to [pubkey].
    int wrapsTo(FakeRelay relay, String pubkey) => relay.receivedFrames
        .where(
          (frame) =>
              frame.length >= 2 &&
              frame[0] == 'EVENT' &&
              frame[1] is Map &&
              (frame[1] as Map)['kind'] == EventKind.giftWrap &&
              ((frame[1] as Map)['tags'] as List).any(
                (tag) =>
                    (tag as List).length >= 2 &&
                    tag[0] == 'p' &&
                    tag[1] == pubkey,
              ),
        )
        .length;

    Future<DmRetractionStatus?> retractionOf(
      DmRepository repository,
      String rumorId,
    ) async {
      for (final message
          in await repository.watchMessages(conversationId).first) {
        if (message.id == rumorId) return message.retractionStatus;
      }
      return null;
    }

    /// Deletes an own message for everyone while the recipient's inbox
    /// cannot be read, and returns once the first attempt is held.
    Future<
      ({
        _CountingDmRepository repository,
        AppDatabase db,
        FakeRelay relay,
        String rumorId,
      })
    >
    heldDeletion(String rumorId) async {
      final relay = await FakeRelay.start(
        stallReqForKinds: const {EventKind.dmRelaysList},
      );
      addTearDown(relay.stop);
      final stack = await buildStack(relay);
      // Each attempt waits this long on the stalled inbox lookup.
      DmRepository.inboxResolutionBudget = const Duration(milliseconds: 300);
      await seedOwnMessage(stack.db, rumorId);
      await stack.repository.deleteMessageForEveryone(rumorId);
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while ((await stack.db.directMessagesDao.getMessageById(
            rumorId,
            ownerPubkey: senderPubkey,
          ))?.heldDeletionWraps ==
          null) {
        if (DateTime.now().isAfter(deadline)) {
          fail('the first attempt never held');
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      return (
        repository: stack.repository,
        db: stack.db,
        relay: relay,
        rumorId: rumorId,
      );
    }

    testWidgets(
      'ARM E: once the sweep has spent its attempts the retraction reads '
      'failed, not pending, and the held wrap is all the recipient got',
      (tester) async {
        final held = await heldDeletion(
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        );
        expect(
          await retractionOf(held.repository, held.rumorId),
          DmRetractionStatus.pending,
          reason: 'precondition: the bubble shows progress while held',
        );
        var offset = Duration.zero;
        final sweep = launch(held.repository, held.db, () => offset);

        // Ten minutes apart outlasts every backoff, so each pass attempts it.
        for (var pass = 0; pass < 5; pass++) {
          offset += const Duration(minutes: 10);
          await sweep.sweep();
        }

        expect(held.repository.deletionRetries, 5);
        final row = await held.db.directMessagesDao.getMessageById(
          held.rumorId,
          ownerPubkey: senderPubkey,
        );
        expect(
          row?.deletionPublishStatus,
          DirectMessagesDao.deletionUnconfirmed,
        );
        expect(row?.deletionRumorJson, isNotNull);
        expect(
          await retractionOf(held.repository, held.rumorId),
          DmRetractionStatus.failed,
        );
        expect(wrapsTo(held.relay, recipientPubkey), 1);

        for (var pass = 0; pass < 3; pass++) {
          offset += const Duration(minutes: 10);
          await sweep.sweep();
        }
        expect(
          held.repository.deletionRetries,
          5,
          reason: 'the same launch tries it no more',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    testWidgets(
      'ARM F: a later launch gives it exactly one more attempt, and it reads '
      'failed again after it',
      (tester) async {
        final held = await heldDeletion(
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        );
        var offset = Duration.zero;
        final first = launch(held.repository, held.db, () => offset);
        for (var pass = 0; pass < 8; pass++) {
          offset += const Duration(minutes: 10);
          await first.sweep();
        }
        expect(held.repository.deletionRetries, 5, reason: 'precondition');

        final second = launch(held.repository, held.db, () => offset);
        for (var pass = 0; pass < 8; pass++) {
          offset += const Duration(minutes: 10);
          await second.sweep();
        }

        expect(held.repository.deletionRetries, 6);
        expect(
          await retractionOf(held.repository, held.rumorId),
          DmRetractionStatus.failed,
        );
        expect(wrapsTo(held.relay, recipientPubkey), 1);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
