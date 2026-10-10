// ABOUTME: E2E for #8188 — a group DM must carry ONE shared rumor id, so
// ABOUTME: delete-for-everyone reaches every participant and a reaction from
// ABOUTME: one member lands for the rest. Also #7880 — a reaction queued
// ABOUTME: offline still lands for the rest after an account switch. Three
// ABOUTME: real DmRepository stacks over real sockets. Requires: NO Docker
// ABOUTME: stack — everything is local.

@Tags(['service'])
library;

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Sends every socket to the in-process relay, whatever host was asked for.
///
/// `isRemoteSuppliedRelayUrlAllowed` refuses loopback by design, so the fake
/// relay can never *be* an admitted target — it has to be reached through one.
class _RedirectFactory implements WebSocketChannelFactory {
  _RedirectFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
}

/// One participant's complete stack.
typedef _Party = ({
  String pubkey,
  DmRepository repository,
  DmReactionsRepository reactions,
  DirectMessagesDao messages,
  DmReactionsDao reactionsDao,
  AppDatabase db,
  Nostr nostr,
});

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const keyA =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const keyB =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const keyC =
      '3333333333333333333333333333333333333333333333333333333333333333';
  final pubA = getPublicKey(keyA);
  final pubB = getPublicKey(keyB);
  final pubC = getPublicKey(keyC);

  Future<_Party> buildParty(
    FakeRelay relay,
    String privateKey, {
    OfflineProbe? isOffline,
  }) async {
    final factory = _RedirectFactory(relay.port);
    final signer = LocalNostrSigner(privateKey);
    final pubkey = getPublicKey(privateKey);

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
      senderPublicKey: pubkey,
      nostrService: client,
      isOffline: isOffline,
    );
    final reactions = DmReactionsRepository(
      reactionsDao: db.dmReactionsDao,
      messageService: messageService,
      userPubkey: pubkey,
      conversationsDao: db.conversationsDao,
      directMessagesDao: db.directMessagesDao,
    );
    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      processedGiftWrapsDao: db.processedGiftWrapsDao,
      userPubkey: pubkey,
      signer: signer,
      messageService: messageService,
      reactionsRepository: reactions,
    );
    addTearDown(repository.stopListening);
    addTearDown(nostr.relayPool.removeAll);

    await client.initialize();
    return (
      pubkey: pubkey,
      repository: repository,
      reactions: reactions,
      messages: db.directMessagesDao,
      reactionsDao: db.dmReactionsDao,
      db: db,
      nostr: nostr,
    );
  }

  /// Polls until [predicate] holds or the budget runs out, so the test waits
  /// on the observable outcome rather than a fixed sleep.
  Future<bool> waitFor(
    Future<bool> Function() predicate, {
    Duration budget = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(budget);
    while (DateTime.now().isBefore(deadline)) {
      if (await predicate()) return true;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return predicate();
  }

  group('#8188 group delete-for-everyone', () {
    testWidgets(
      'every participant stores the message under ONE shared rumor id, and '
      'delete-for-everyone retracts it for all of them',
      (tester) async {
        final relay = await FakeRelay.start(broadcast: true);
        addTearDown(relay.stop);

        final sender = await buildParty(relay, keyA);
        final peerB = await buildParty(relay, keyB);
        final peerC = await buildParty(relay, keyC);

        await peerB.repository.startListening();
        await peerC.repository.startListening();
        // Both DM subscriptions must be registered before the send, or the
        // broadcast has nowhere to land.
        await waitFor(
          () async =>
              relay.receivedFrames
                  .where(
                    (f) =>
                        f.isNotEmpty &&
                        f[0] == 'REQ' &&
                        f.length >= 2 &&
                        (f[1] as String).startsWith('dm_inbox_'),
                  )
                  .length >=
              2,
        );

        final results = await sender.repository.sendGroupMessage(
          recipientPubkeys: [peerB.pubkey, peerC.pubkey],
          content: 'group message for #8188',
        );
        expect(results.where((r) => r.success), hasLength(2));

        final senderRow = await sender.messages.getMessagesForConversation(
          DmRepository.computeConversationId([pubA, pubB, pubC]),
          ownerPubkey: sender.pubkey,
        );
        expect(senderRow, hasLength(1));
        final sharedId = senderRow.single.id;

        // THE INVARIANT (#8188). Each recipient is looked up by the id the
        // SENDER holds. Before the fix each party held a different rumor id —
        // `buildRumor` prepends the addressee, so the siblings carried the
        // same p-tag SET in a rotated ORDER and a NIP-01 id hashes the tags
        // array — and this lookup could only ever resolve for one of them.
        //
        // Deliberately NOT keyed on the conversation id: which conversation
        // an inbound group DM is filed under is #7338's concern. Message
        // identity is what #8188 is about, and it is what a retraction names.
        final bothHoldIt = await waitFor(() async {
          final b = await peerB.messages.getMessageById(
            sharedId,
            ownerPubkey: peerB.pubkey,
          );
          final c = await peerC.messages.getMessageById(
            sharedId,
            ownerPubkey: peerC.pubkey,
          );
          return b != null && c != null;
        });
        expect(
          bothHoldIt,
          isTrue,
          reason:
              'every participant must store the message under the SAME rumor '
              'id — a per-recipient id makes it unaddressable by everyone but '
              'its own holder',
        );

        await sender.repository.deleteMessageForEveryone(sharedId);

        final retracted = await waitFor(() async {
          final b = await peerB.messages.getMessageById(
            sharedId,
            ownerPubkey: peerB.pubkey,
          );
          final c = await peerC.messages.getMessageById(
            sharedId,
            ownerPubkey: peerC.pubkey,
          );
          return (b?.isDeleted ?? false) && (c?.isDeleted ?? false);
        });

        expect(
          retracted,
          isTrue,
          reason:
              'delete-for-everyone must retract the message on EVERY '
              'participant, not just the one whose sibling id the sender '
              'happened to persist',
        );

        // The sender's own copy is retracted too.
        final own = await sender.messages.getMessageById(
          sharedId,
          ownerPubkey: sender.pubkey,
        );
        expect(own?.isDeleted, isTrue);
      },
    );

    testWidgets(
      'a reaction on the group message lands for EVERY participant, because '
      'they all hold the id it names',
      (tester) async {
        final relay = await FakeRelay.start(broadcast: true);
        addTearDown(relay.stop);

        final sender = await buildParty(relay, keyA);
        final peerB = await buildParty(relay, keyB);
        final peerC = await buildParty(relay, keyC);

        await peerB.repository.startListening();
        await peerC.repository.startListening();
        await waitFor(
          () async =>
              relay.receivedFrames
                  .where(
                    (f) =>
                        f.isNotEmpty &&
                        f[0] == 'REQ' &&
                        f.length >= 2 &&
                        (f[1] as String).startsWith('dm_inbox_'),
                  )
                  .length >=
              2,
        );

        final groupId = DmRepository.computeConversationId([pubA, pubB, pubC]);
        final sent = await sender.repository.sendGroupMessage(
          recipientPubkeys: [peerB.pubkey, peerC.pubkey],
          content: 'react to me',
        );
        expect(sent.where((r) => r.success), hasLength(2));

        final senderRow = await sender.messages.getMessagesForConversation(
          groupId,
          ownerPubkey: sender.pubkey,
        );
        final sharedId = senderRow.single.id;

        await waitFor(() async {
          final b = await peerB.messages.getMessageById(
            sharedId,
            ownerPubkey: peerB.pubkey,
          );
          final c = await peerC.messages.getMessageById(
            sharedId,
            ownerPubkey: peerC.pubkey,
          );
          return b != null && c != null;
        });

        // The reaction's `e` tag names the reactor's LOCAL id for the target.
        // On a mismatch the receiver cannot resolve the conversation and
        // `persistIncoming` returns `deferred` — the reaction is never stored
        // at all, and its wrap re-decrypts forever. So this lands for both
        // recipients only because the id is now shared.
        final published = await sender.reactions.publish(
          conversationId: groupId,
          targetMessageId: sharedId,
          targetMessageAuthor: sender.pubkey,
          emoji: '🔥',
        );
        expect(published.success, isTrue);

        // Each recipient files the inbound group DM under the room its rumor
        // names (#7338), so the reaction lands in that room too.
        Future<int> reactionCount(_Party party) async =>
            (await party.reactionsDao
                    .watchForConversation(
                      conversationId: groupId,
                      ownerPubkey: party.pubkey,
                    )
                    .first)
                .where((row) => row.targetMessageId == sharedId)
                .length;

        final landed = await waitFor(
          () async =>
              await reactionCount(peerB) > 0 && await reactionCount(peerC) > 0,
        );

        expect(
          landed,
          isTrue,
          reason:
              'a group reaction must reach every participant — with a '
              'per-recipient rumor id it resolved for at most one of them',
        );
      },
    );
  });

  group('#7880 queued group reaction after an account switch', () {
    testWidgets(
      'a reaction queued offline still lands for EVERY participant once the '
      'reactor has switched account and back',
      (tester) async {
        final relay = await FakeRelay.start(broadcast: true);
        addTearDown(relay.stop);

        var reactorOffline = false;
        final reactor = await buildParty(
          relay,
          keyA,
          isOffline: () async => reactorOffline,
        );
        final author = await buildParty(relay, keyB);
        final bystander = await buildParty(relay, keyC);

        await reactor.repository.startListening();
        await author.repository.startListening();
        await bystander.repository.startListening();
        await waitFor(
          () async =>
              relay.receivedFrames
                  .where(
                    (f) =>
                        f.isNotEmpty &&
                        f[0] == 'REQ' &&
                        f.length >= 2 &&
                        (f[1] as String).startsWith('dm_inbox_'),
                  )
                  .length >=
              3,
        );

        // The reactor has never written to this room. It files the author's
        // message under the room because the rumor names all three (#7338).
        final groupId = DmRepository.computeConversationId([pubA, pubB, pubC]);

        final sent = await author.repository.sendGroupMessage(
          recipientPubkeys: [reactor.pubkey, bystander.pubkey],
          content: 'react to me',
        );
        expect(sent.where((r) => r.success), hasLength(2));
        // Every member's wrap carries the same rumor (#8188).
        final targetId = sent.first.rumorEventId!;

        final everyoneHoldsTheMessage = await waitFor(() async {
          final r = await reactor.messages.getMessageById(
            targetId,
            ownerPubkey: reactor.pubkey,
          );
          final c = await bystander.messages.getMessageById(
            targetId,
            ownerPubkey: bystander.pubkey,
          );
          return r?.conversationId == groupId && c != null;
        });
        expect(
          everyoneHoldsTheMessage,
          isTrue,
          reason: 'precondition: the reactor holds the message in the group',
        );

        Future<bool> holdsTheReaction(_Party party) async =>
            (await party.db.select(party.db.dmMessageReactions).get()).any(
              (row) =>
                  row.ownerPubkey == party.pubkey &&
                  row.targetMessageId == targetId &&
                  row.reactorPubkey == reactor.pubkey,
            );

        reactorOffline = true;
        final queued = await reactor.reactions.publish(
          conversationId: groupId,
          targetMessageId: targetId,
          targetMessageAuthor: author.pubkey,
          emoji: '🔥',
        );
        expect(queued.success, isFalse);
        expect(await reactor.reactions.retryableReactions(), hasLength(1));

        // The database half of what the incoming account runs for the one
        // that left (`social_providers.dart`): its messages and conversations
        // go, and every reaction row except the ones still waiting to be sent.
        await reactor.db.transaction(() async {
          await reactor.messages.clearForAccountSwitch(reactor.pubkey);
          await reactor.db.conversationsDao.clearForAccountSwitch(
            reactor.pubkey,
          );
        });
        await reactor.reactionsDao.deleteNonRetryableForOwner(reactor.pubkey);
        expect(
          await reactor.db.conversationsDao.getConversation(
            groupId,
            ownerPubkey: reactor.pubkey,
          ),
          isNull,
          reason: 'precondition: the switch removed the group conversation',
        );
        expect(
          await holdsTheReaction(author) || await holdsTheReaction(bystander),
          isFalse,
          reason: 'precondition: the offline reaction reached nobody',
        );

        reactorOffline = false;
        final retried = await reactor.reactions.retry(
          rumorId: queued.rumorId,
          targetMessageAuthor: author.pubkey,
        );

        final landed = await waitFor(
          () async =>
              await holdsTheReaction(author) &&
              await holdsTheReaction(bystander),
        );

        expect(
          landed,
          isTrue,
          reason:
              'the retry must send the reaction to the people it was queued '
              'for — with the conversation gone it went to the author of the '
              'message alone and was recorded as delivered',
        );
        expect(retried.success, isTrue);
        expect(await reactor.reactions.retryableReactions(), isEmpty);
      },
    );
  });
}
