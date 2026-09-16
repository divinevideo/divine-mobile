// ABOUTME: E2E regression for #8443 — a DM reaction published while the
// ABOUTME: recipient's kind-10050 inbox is UNREADABLE falls back to the default
// ABOUTME: pool and must stay pending, never be scored as delivered. Drives a
// ABOUTME: real DmRepository + DmReactionsRepository + NostrClient over real
// ABOUTME: sockets, wired exactly as repository_providers.dart wires them.
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
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
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
  const targetMessageId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

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

  /// Builds the real stack the way `repository_providers.dart` does, including
  /// the line under test: the reactions repository is handed
  /// `DmRepository.resolveDmInboxRelaysDetailed`, so the resolution state
  /// travels with the relays and "absent" and "unreadable" stay distinct.
  Future<
    ({
      DmRepository repository,
      DmReactionsRepository reactions,
      AppDatabase db,
      Nostr nostr,
    })
  >
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

    final reactions =
        DmReactionsRepository(
          reactionsDao: db.dmReactionsDao,
          conversationsDao: db.conversationsDao,
          directMessagesDao: db.directMessagesDao,
        )..setCredentials(
          userPubkey: senderPubkey,
          messageService: messageService,
        );
    // The production wiring under test (repository_providers.dart).
    reactions.setDmInboxRelayResolver(repository.resolveDmInboxRelaysDetailed);

    addTearDown(nostr.relayPool.removeAll);
    await client.initialize();

    await db.conversationsDao.upsertConversation(
      id: conversationId,
      participantPubkeys: jsonEncode([senderPubkey, recipientPubkey]),
      isGroup: false,
      createdAt: 1700000000,
      ownerPubkey: senderPubkey,
    );

    return (repository: repository, reactions: reactions, db: db, nostr: nostr);
  }

  Future<DmReactionPublishResult> publishReaction(
    DmReactionsRepository reactions,
  ) => reactions.publish(
    conversationId: conversationId,
    targetMessageId: targetMessageId,
    targetMessageAuthor: recipientPubkey,
    emoji: '🔥',
  );

  /// Restores the production budget after a test shortens it.
  setUp(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });
  tearDown(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });

  group('#8443 reaction on an unreadable DM inbox', () {
    testWidgets(
      'ARM A: a reaction whose inbox lookup exceeded its budget stays pending '
      'and keeps its rumor, even though the pool confirmed the wrap',
      (tester) async {
        // The relay serves the inbox, but resolution is abandoned before it
        // can answer — the `on TimeoutException` exit in `_queryOwnDmInbox`,
        // which is documented as "Deliberately `failed`, never `absent`".
        final relay = await FakeRelay.start(reply: recipientInbox());
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
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

        final result = await publishReaction(stack.reactions);

        final row = await stack.db.dmReactionsDao.getById(
          id: result.rumorId,
          ownerPubkey: senderPubkey,
        );
        // Before #8443 this was `success=true` / `sent` with the rumor JSON
        // cleared — a delivered chip for a reaction the recipient never saw,
        // and a row the sweep could never select again.
        expect(result.success, isFalse);
        expect(row?.publishStatus, 'pending');
        expect(
          row?.rumorEventJson,
          isNotNull,
          reason: 'the sweep needs the stored rumor to re-resolve and re-drive',
        );
      },
    );

    testWidgets(
      'ARM B (control): the MESSAGE path on the same unreadable inbox does '
      'not report delivery either (#7317, PR #8436)',
      (tester) async {
        final relay = await FakeRelay.start(reply: recipientInbox());
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        DmRepository.inboxResolutionBudget = const Duration(milliseconds: 1);

        final sent = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'control message',
        );

        // The reaction path now matches this: a soft failure whose durable
        // row survives for the sweep.
        expect(sent.success, isFalse);
        expect(sent, isA<NIP17SendFailure>());
        expect((sent as NIP17SendFailure).retryablePending, isTrue);
      },
    );

    testWidgets(
      'ARM C (control): a genuinely ABSENT inbox is still legitimately sent',
      (tester) async {
        // EOSE with no event: the relays answered, the recipient advertises
        // nothing. The default pool IS where they read, so the OK is real.
        final relay = await FakeRelay.start();
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(
          detailed.state,
          DmInboxResolution.absent,
          reason: 'precondition: the inbox must be ABSENT, not unreadable',
        );

        final result = await publishReaction(stack.reactions);

        final row = await stack.db.dmReactionsDao.getById(
          id: result.rumorId,
          ownerPubkey: senderPubkey,
        );
        expect(result.success, isTrue);
        expect(row?.publishStatus, 'sent');
      },
    );

    testWidgets(
      'ARM D: a relay that accepts the kind-10050 REQ and never settles it '
      'is the other route into unreadable, and holds the reaction the same way',
      (tester) async {
        // No budget hook: the relay accepts the REQ and never terminates it,
        // so `queryEventsDetailed` reports `timedOut` and the send path maps
        // it to `unreadable`.
        final relay = await FakeRelay.start(
          reply: recipientInbox(),
          stallReqForKinds: const {10050},
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(detailed.state, DmInboxResolution.unreadable);

        final result = await publishReaction(stack.reactions);

        final row = await stack.db.dmReactionsDao.getById(
          id: result.rumorId,
          ownerPubkey: senderPubkey,
        );
        expect(result.success, isFalse);
        expect(row?.publishStatus, 'pending');
        expect(row?.rumorEventJson, isNotNull);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
