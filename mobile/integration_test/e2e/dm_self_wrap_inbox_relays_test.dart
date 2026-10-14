// ABOUTME: E2E for #7328 and #8446 — the sender's own gift-wrap copy of a
// ABOUTME: message or a reaction reaches the relays their own kind-10050
// ABOUTME: advertises, not just the connected pool, and only once.
// ABOUTME: Drives a real DmRepository + NostrClient over real sockets.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
library;

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
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

/// Redirects every advertised hostname onto the in-process relay and records
/// the address it was asked for.
///
/// The recording is the assertion. `isRemoteSuppliedRelayUrlAllowed` refuses
/// loopback hosts, so a `ws://127.0.0.1` entry could never *be* an admitted
/// inbox target — it has to be reached through a public-looking name, and
/// "this host was dialed" is then observed rather than inferred from a
/// publish result.
class _RecordingRedirectFactory implements WebSocketChannelFactory {
  _RecordingRedirectFactory(this.port, {this.routes = const {}});

  final int port;

  /// Hosts that land on a relay of their own rather than on [port], so a test
  /// can read what that one relay was sent.
  final Map<String, int> routes;
  final List<String> requested = [];

  @override
  WebSocketChannel create(Uri uri) {
    requested.add(uri.toString());
    final target = routes[uri.host] ?? port;
    return WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:$target${uri.path}'),
    );
  }
}

/// A DM inbox relay the SENDER advertises and the pool does not contain.
///
/// This models divine's own shape since #8378: every account's kind-10050
/// names `nos.lol` and `relay.primal.net` on top of the divine relay, and
/// neither joins the pool unless NIP-65 discovery came back empty.
const _senderOnlyInbox = 'wss://sender-inbox.example';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const senderKey =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const recipientKey =
      '4444444444444444444444444444444444444444444444444444444444444444';
  final senderPubkey = getPublicKey(senderKey);
  final recipientPubkey = getPublicKey(recipientKey);

  /// Gift wraps [relay] was asked to store that are addressed to [pubkey].
  List<String> giftWrapsTo(FakeRelay relay, String pubkey) => [
    for (final frame in relay.receivedFrames)
      if (frame.length >= 2 &&
          frame[0] == 'EVENT' &&
          frame[1] is Map &&
          (frame[1] as Map)['kind'] == 1059 &&
          ((frame[1] as Map)['tags'] as List).any(
            (tag) =>
                tag is List &&
                tag.length >= 2 &&
                tag[0] == 'p' &&
                tag[1] == pubkey,
          ))
        (frame[1] as Map)['id'] as String,
  ];

  /// Polls [condition] on real time. A `publishEvent` returns once the frame
  /// is handed to the socket, before the relay has read it.
  Future<void> waitUntil(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('timed out: $reason');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// A kind-10050 signed by the SENDER.
  ///
  /// [FakeRelay] serves one reply for every `REQ` regardless of filter, and
  /// that is exactly what makes this test able to attribute a dial. The
  /// repository only accepts a relay list whose `event.pubkey` matches the
  /// author it asked about, so this same event resolves `found` for the
  /// sender's own lookup and is discarded as off-filter for the recipient's.
  /// The recipient therefore has no advertised inbox, their wrap goes to the
  /// plain pool, and any connection to [_senderOnlyInbox] can only have come
  /// from the self-addressed wrap.
  Map<String, dynamic> senderInbox([
    List<String> relays = const [_senderOnlyInbox],
  ]) {
    final event = Event(
      senderPubkey,
      10050,
      [
        for (final relay in relays) ['relay', relay],
      ],
      '',
      createdAt: 1700000000,
    )..sign(senderKey);
    return event.toJson();
  }

  /// Builds the real stack: Nostr → RelayPool → RelayManager → NostrClient →
  /// NIP17MessageService → DmRepository, with every socket landing on [relay].
  Future<
    ({
      DmRepository repository,
      DmReactionsRepository reactions,
      AppDatabase db,
      Nostr nostr,
      _RecordingRedirectFactory factory,
    })
  >
  buildStack(
    FakeRelay relay, {
    String? poolUrl,
    Map<String, int> routes = const {},
  }) async {
    final factory = _RecordingRedirectFactory(relay.port, routes: routes);
    final signer = LocalNostrSigner(senderKey);

    RelayBase gen(String url) =>
        RelayBase(url, RelayStatus(url), channelFactory: factory);
    final nostr = Nostr(signer, [], gen, channelFactory: factory);

    final relayManager = RelayManager(
      config: RelayManagerConfig(
        defaultRelayUrl: poolUrl ?? relay.url,
        storage: InMemoryRelayStorage(),
      ),
      relayPool: nostr.relayPool,
      // Without it a pooled relay is built with the default channel factory
      // and dialed through real DNS, which only a loopback pool URL survives.
      relayFactory: gen,
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

    // Wired the way `dmRepositoryProvider` wires it.
    final reactions =
        DmReactionsRepository(
          reactionsDao: db.dmReactionsDao,
          conversationsDao: db.conversationsDao,
          directMessagesDao: db.directMessagesDao,
        )..setCredentials(
          userPubkey: senderPubkey,
          messageService: messageService,
        );
    reactions
      ..setDmInboxRelayResolver(repository.resolveDmInboxRelaysDetailed)
      ..setSelfWrapRelayResolver(repository.resolveSelfWrapTargetRelays);
    // `addTearDown` is LIFO and `relay.stop` was registered first, so this
    // closes every socket ahead of it — otherwise in-flight connects fail
    // after the test completes and get attributed to it.
    addTearDown(nostr.relayPool.removeAll);

    // Through the manager, not RelayPool.add: a publish with no explicit
    // targets checks `connectedRelays`, which only the manager populates.
    await client.initialize();

    return (
      repository: repository,
      reactions: reactions,
      db: db,
      nostr: nostr,
      factory: factory,
    );
  }

  group('#7328 self-wrap inbox relays', () {
    testWidgets('dials the sender own advertised inbox on a send', (
      tester,
    ) async {
      final relay = await FakeRelay.start(reply: senderInbox());
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      // The discriminator, asserted rather than assumed: the recipient has no
      // admitted inbox, so their wrap goes to the plain pool and cannot be
      // what reaches _senderOnlyInbox.
      expect(
        (await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        )).relays,
        isNull,
        reason:
            'the served kind-10050 is authored by the sender, so it must be '
            'discarded as off-filter for the recipient',
      );

      final result = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'self-wrap destination probe',
      );

      // Positive control. Without it every "was dialed" assertion below could
      // pass on a harness that never sent anything.
      expect(result.success, isTrue, reason: result.toString());
      expect(result.selfWrapPublished, isTrue, reason: result.toString());

      final host = Uri.parse(_senderOnlyInbox).host;
      expect(
        stack.factory.requested.where((u) => u.contains(host)),
        isNotEmpty,
        reason:
            'the sender advertises $_senderOnlyInbox as a DM inbox, so their '
            'own copy of an outgoing message has to reach it — publishing to '
            'the connected pool alone leaves their replies missing from the '
            'relay their own kind-10050 points every other client at',
      );
    });

    testWidgets('still delivers when the sender advertises no inbox', (
      tester,
    ) async {
      // The `absent` fallback. An account with no kind-10050 keeps the plain
      // pool publish, and nothing outside the pool is contacted.
      final relay = await FakeRelay.start();
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      final result = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'no-inbox fallback probe',
      );

      expect(result.success, isTrue, reason: result.toString());
      expect(result.selfWrapPublished, isTrue, reason: result.toString());
      expect(relay.publishedEventIds, isNotEmpty);

      final host = Uri.parse(_senderOnlyInbox).host;
      expect(
        stack.factory.requested.where((u) => u.contains(host)),
        isEmpty,
        reason: 'nothing advertised this host, so nothing may dial it',
      );
    });
  });

  group('#8446 reaction own copy', () {
    const memberKeys = [
      '5555555555555555555555555555555555555555555555555555555555555555',
      '6666666666666666666666666666666666666666666666666666666666666666',
      '7777777777777777777777777777777777777777777777777777777777777777',
    ];
    final memberPubkeys = memberKeys.map(getPublicKey).toList();
    final groupId = DmRepository.computeConversationId([
      senderPubkey,
      ...memberPubkeys,
    ]);
    const targetMessageId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

    Future<DmReactionPublishResult> reactInGroup(
      ({DmReactionsRepository reactions, AppDatabase db}) stack,
    ) async {
      await stack.db.conversationsDao.upsertConversation(
        id: groupId,
        participantPubkeys: jsonEncode([senderPubkey, ...memberPubkeys]),
        isGroup: true,
        createdAt: 1700000000,
        ownerPubkey: senderPubkey,
      );
      return stack.reactions.publish(
        conversationId: groupId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: memberPubkeys.first,
        emoji: '🔥',
      );
    }

    testWidgets('a group reaction leaves one copy addressed to the sender', (
      tester,
    ) async {
      final relay = await FakeRelay.start();
      addTearDown(relay.stop);
      final stack = await buildStack(relay);

      final result = await reactInGroup((
        reactions: stack.reactions,
        db: stack.db,
      ));

      // Positive control: every member got their own wrap, so the count below
      // is measured on a fan-out that actually ran.
      expect(result.success, isTrue, reason: result.errorMessage);
      for (final member in memberPubkeys) {
        expect(giftWrapsTo(relay, member), hasLength(1));
      }
      // The copy goes out last, after the row is marked sent, and every wrap
      // shares the pool socket: once it has arrived, any copy published
      // before it has arrived too.
      await waitUntil(
        () => giftWrapsTo(relay, senderPubkey).isNotEmpty,
        reason: 'the sender own copy never reached the relay',
      );
      expect(
        giftWrapsTo(relay, senderPubkey),
        hasLength(1),
        reason:
            'the sender needs one copy of their reaction for their other '
            'devices; one per member multiplies it by the size of the group',
      );
    });

    /// Reacts to [recipientPubkey]'s message in their 1:1 conversation.
    Future<DmReactionPublishResult> reactOneToOne(
      ({DmReactionsRepository reactions, AppDatabase db}) stack,
    ) async {
      final conversationId = DmRepository.computeConversationId([
        senderPubkey,
        recipientPubkey,
      ]);
      await stack.db.conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: jsonEncode([senderPubkey, recipientPubkey]),
        isGroup: false,
        createdAt: 1700000000,
        ownerPubkey: senderPubkey,
      );
      return stack.reactions.publish(
        conversationId: conversationId,
        targetMessageId: targetMessageId,
        targetMessageAuthor: recipientPubkey,
        emoji: '🔥',
      );
    }

    // The two shapes a sender's kind-10050 takes. Divine's default names its
    // own relay, which is in the pool, beside two that are not; the loss is
    // total only for an inbox that names no pool relay at all.
    for (final shape in [
      (name: 'an inbox outside the pool', namesPool: false),
      (name: 'an inbox that also names the pool relay', namesPool: true),
    ]) {
      testWidgets(
        "a reaction's own copy reaches ${shape.name} as well as the pool",
        (tester) async {
          const poolUrl = 'wss://pool.example';
          final inboxRelay = await FakeRelay.start();
          addTearDown(inboxRelay.stop);
          final pool = await FakeRelay.start(
            reply: senderInbox([
              if (shape.namesPool) poolUrl,
              _senderOnlyInbox,
            ]),
          );
          addTearDown(pool.stop);
          final stack = await buildStack(
            pool,
            poolUrl: poolUrl,
            routes: {
              Uri.parse(poolUrl).host: pool.port,
              Uri.parse(_senderOnlyInbox).host: inboxRelay.port,
            },
          );

          final result = await reactOneToOne((
            reactions: stack.reactions,
            db: stack.db,
          ));

          // Positive control: the recipient's wrap went through the pool, so
          // the reaction really was sent before its copy is looked for.
          expect(result.success, isTrue, reason: result.errorMessage);
          expect(giftWrapsTo(pool, recipientPubkey), hasLength(1));
          await waitUntil(
            () => giftWrapsTo(pool, senderPubkey).isNotEmpty,
            reason: 'the sender own copy never reached the pool',
          );
          await waitUntil(
            () => giftWrapsTo(inboxRelay, senderPubkey).isNotEmpty,
            reason:
                'the sender advertises $_senderOnlyInbox as a DM inbox, so '
                'their own copy of a reaction has to reach it, as their '
                'message copies do since #7328',
          );
          expect(
            giftWrapsTo(inboxRelay, senderPubkey),
            giftWrapsTo(pool, senderPubkey),
            reason: 'one copy, published to both',
          );
        },
      );
    }
  });
}
