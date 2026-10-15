// ABOUTME: E2E regression for #8519 — a thread latched to 'nip04' published a
// ABOUTME: cleartext kind 4 on every outbound message forever, even though the
// ABOUTME: send path had already resolved the peer's kind-10050 to `found`.
// ABOUTME: Also #8506: on a thread that keeps the kind 4, a relay that refuses
// ABOUTME: or never confirms it must not lose the legacy peer's only copy.
// ABOUTME: Asserts on the wire: what the relay was actually handed, not on a
// ABOUTME: mock. The #8519 arms differ ONLY in the resolution state.
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
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Redirects the public hostname the recipient's kind-10050 advertises onto
/// the in-process relay. A `ws://127.0.0.1` host can never *be* an admitted
/// target — `isRemoteSuppliedRelayUrlAllowed` refuses loopback by design, and
/// an inbox whose every relay is refused resolves `absent`, not `found` — so
/// reaching a `found` state at all requires a redirect like this one.
class _RedirectFactory implements WebSocketChannelFactory {
  _RedirectFactory(this.port);

  final int port;

  @override
  WebSocketChannel create(Uri uri) =>
      WebSocketChannel.connect(Uri.parse('ws://127.0.0.1:$port${uri.path}'));
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
      EventKind.dmRelaysList,
      [
        ['relay', 'wss://inbox-1.example'],
      ],
      '',
      createdAt: 1700000000,
    )..sign(recipientKey);
    return event.toJson();
  }

  /// The real stack, wired as `repository_providers.dart` wires it, over real
  /// sockets — and seeded with a thread already latched to `'nip04'`, which is
  /// the state an inbound kind 4 leaves behind (`_handleNip04Event`'s
  /// `existing?.dmProtocol ?? 'nip04'`).
  Future<({DmRepository repository, AppDatabase db})> buildLatchedStack(
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

    final repository = DmRepository(
      nostrClient: client,
      directMessagesDao: db.directMessagesDao,
      conversationsDao: db.conversationsDao,
      outgoingDmsDao: db.outgoingDmsDao,
      userPubkey: senderPubkey,
      signer: signer,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: senderPubkey,
        nostrService: client,
      ),
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
      dmProtocol: 'nip04',
    );

    return (repository: repository, db: db);
  }

  /// Kinds the relay was actually handed. The whole point of this file: the
  /// leak is a real event on a real socket, so the assertion is on the wire.
  List<int> publishedKinds(FakeRelay relay) => [
    for (final frame in relay.receivedFrames)
      if (frame.isNotEmpty &&
          frame[0] == 'EVENT' &&
          frame.length >= 2 &&
          frame[1] is Map)
        (frame[1] as Map)['kind'] as int,
  ];

  /// Whether [kind] reaches the relay inside [timeout].
  ///
  /// The NIP-04 leg is fired `unawaited` at its call site, so `sendMessage`
  /// returning proves nothing about it in either direction — asserting on the
  /// relay the moment the send resolves reports "no kind 4" even when the leg
  /// is about to publish one. ARM B pins the positive case, and that is what
  /// makes ARM A's negative one an assertion rather than a race it wins.
  Future<bool> reachesRelay(
    FakeRelay relay,
    int kind, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (publishedKinds(relay).contains(kind)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return false;
  }

  Future<String?> storedProtocol(AppDatabase db) async =>
      (await db.conversationsDao.getConversation(
        conversationId,
        ownerPubkey: senderPubkey,
      ))?.dmProtocol;

  setUp(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });
  tearDown(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });

  group('#8519 one-way latched thread', () {
    testWidgets(
      'ARM A: an advertised kind-10050 unlatches the thread, and THIS send '
      'already publishes no cleartext kind 4',
      (tester) async {
        final relay = await FakeRelay.start(reply: recipientInbox());
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(
          detailed.state,
          DmInboxResolution.found,
          reason: 'precondition: the peer must advertise a readable inbox',
        );

        final _ = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'outbound on a latched thread',
        );

        expect(await storedProtocol(stack.db), 'nip17');
        expect(
          publishedKinds(relay),
          contains(EventKind.giftWrap),
          reason: 'the NIP-17 leg must still have gone out',
        );
        // The leak is the assertion. Before #8519 a kind 4 whose `p` tag names
        // the recipient in the clear reached this relay — on a socket with no
        // NIP-42, which is what `04.md:51` says must not happen, and what
        // voids NIP-17's "No Metadata Leak" (17.md:97).
        expect(
          await reachesRelay(relay, EventKind.directMessage),
          isFalse,
          reason:
              'the peer can read a gift wrap; the cleartext twin buys them '
              'nothing and leaks who is talking to whom',
        );
      },
    );

    testWidgets(
      'ARM B (control): a peer who advertises NO inbox stays latched and still '
      'gets the cleartext kind 4',
      (tester) async {
        // The one variable is the resolution state. This relay answers the
        // kind-10050 REQ with EOSE and nothing else, which is a conclusive
        // "they advertise none" — the state that still means the pool is where
        // this peer reads, so the legacy copy is genuinely their only readable
        // one and must keep going out.
        final relay = await FakeRelay.start();
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(
          detailed.state,
          DmInboxResolution.absent,
          reason: 'precondition: the peer must advertise no inbox',
        );

        final _ = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'outbound on a latched thread',
        );

        expect(await storedProtocol(stack.db), 'nip04');
        expect(
          await reachesRelay(relay, EventKind.directMessage),
          isTrue,
          reason: 'no advertised inbox is not evidence the peer reads NIP-17',
        );
      },
    );

    testWidgets(
      'ARM C: an unreadable lookup is not evidence and leaves the thread '
      'latched (#7317)',
      (tester) async {
        // Stalling the kind-10050 REQ is the only shape that makes the read
        // inconclusive rather than empty; racing a short budget against an
        // in-process loopback relay is a coin flip and resolved `found`.
        //
        // This arm deliberately asserts nothing about the kind 4. With the
        // outgoing queue wired — as production wires it — `unreadable` makes
        // `downgradeFallbackPoolDelivery` hold the send soft-unconfirmed, and
        // the whole persist block (the kind-4 gate included) is skipped. So a
        // kind 4 is absent here for a #7317 reason, not a #8519 one, and
        // claiming it either way would pin the wrong mechanism.
        final relay = await FakeRelay.start(
          reply: recipientInbox(),
          stallReqForKinds: const {EventKind.dmRelaysList},
        );
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);
        DmRepository.inboxResolutionBudget = const Duration(milliseconds: 800);

        final detailed = await stack.repository.resolveDmInboxRelaysDetailed(
          recipientPubkey,
        );
        expect(
          detailed.state,
          DmInboxResolution.unreadable,
          reason: 'precondition: the lookup must be inconclusive',
        );

        final _ = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'outbound on a latched thread',
        );

        // Collapsing a failed read onto `found` is the mistake #7317 exists to
        // prevent: it would permanently cut a genuine legacy peer off from
        // their only readable copy on the strength of a lookup that failed.
        expect(await storedProtocol(stack.db), 'nip04');
      },
    );
  });

  // #8506: on a thread still latched to NIP-04 the kind-4 copy is the only one
  // a legacy peer can read, so a relay hiccup on it must not lose the message.
  // Every arm uses a peer who advertises NO inbox (`absent`), the one state in
  // which the copy is still published (ARM B above).
  group('#8506 the legacy kind-4 copy survives a relay hiccup', () {
    List<Map<dynamic, dynamic>> kind4Events(FakeRelay relay) => [
      for (final frame in relay.receivedFrames)
        if (frame.length >= 2 &&
            frame[0] == 'EVENT' &&
            frame[1] is Map &&
            (frame[1] as Map)['kind'] == EventKind.directMessage)
          frame[1] as Map,
    ];

    Set<Object?> kind4Ids(FakeRelay relay) => {
      for (final event in kind4Events(relay)) event['id'],
    };

    /// The verdicts of the `OK`s the relay sent for [eventId], in order.
    List<Object?> okVerdicts(FakeRelay relay, Object? eventId) => [
      for (final ok in relay.sentOks)
        if (ok.length >= 3 && ok[1] == eventId) ok[2],
    ];

    bool addressedTo(Map<String, dynamic> event, String pubkey) {
      final tags = event['tags'];
      return tags is List &&
          tags.any(
            (tag) =>
                tag is List &&
                tag.length >= 2 &&
                tag[0] == 'p' &&
                tag[1] == pubkey,
          );
    }

    /// Waits until the relay was handed [count] kind-4 events or [timeout]
    /// passes, and returns when each one was first seen.
    ///
    /// Asking for one more event than an arm expects is how the arm waits out
    /// a retry that must not come.
    Future<List<DateTime>> kind4Arrivals(
      FakeRelay relay,
      int count, {
      required Duration timeout,
    }) async {
      final seen = <DateTime>[];
      final deadline = DateTime.now().add(timeout);
      while (true) {
        final now = DateTime.now();
        while (seen.length < kind4Events(relay).length) {
          seen.add(now);
        }
        if (seen.length >= count || !now.isBefore(deadline)) return seen;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    Future<bool> eventually(
      Future<bool> Function() check, {
      required Duration timeout,
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (true) {
        if (await check()) return true;
        if (!DateTime.now().isBefore(deadline)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }

    /// The one send still queued, which is what the retry sweep re-drives.
    Future<String> queuedRumorId(AppDatabase db) async {
      final queued = await db.outgoingDmsDao.getAllForOwner(senderPubkey);
      expect(queued, hasLength(1), reason: 'precondition: one queued send');
      return queued.single.id;
    }

    testWidgets(
      'CONTROL: a relay that accepts the copy is handed it exactly once',
      (tester) async {
        final relay = await FakeRelay.start();
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);

        final result = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'accepted on the first attempt',
        );
        expect(result.success, isTrue);

        final arrivals = await kind4Arrivals(
          relay,
          2,
          timeout: const Duration(seconds: 5),
        );
        expect(
          arrivals,
          hasLength(1),
          reason: 'an accepted copy is not published again',
        );
        expect(okVerdicts(relay, kind4Ids(relay).single), [true]);
      },
    );

    testWidgets(
      'a relay that refuses the copy once is handed the same signed event '
      'again, and the copy is delivered',
      (tester) async {
        var refusals = 1;
        final relay = await FakeRelay.start(
          okFor: (event) =>
              event['kind'] == EventKind.directMessage && refusals-- > 0
              ? const FakeOk.refuse('error: refused once by the test relay')
              : null,
        );
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);

        final result = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'refused once',
        );
        expect(result.success, isTrue, reason: 'the NIP-17 leg was accepted');

        final first = await kind4Arrivals(
          relay,
          1,
          timeout: const Duration(seconds: 3),
        );
        expect(first, hasLength(1), reason: 'precondition: the copy went out');
        // The send is already final for the sender when the copy leaves: the
        // message is stored and its queue row is gone, so nothing durable is
        // left that a later sweep could retry the copy from.
        final rumorId = result.rumorEventId!;
        expect(
          await stack.db.directMessagesDao.getMessageById(
            rumorId,
            ownerPubkey: senderPubkey,
          ),
          isNotNull,
        );
        expect(await stack.db.outgoingDmsDao.getById(rumorId), isNull);

        final arrivals = await kind4Arrivals(
          relay,
          3,
          timeout: const Duration(seconds: 6),
        );
        expect(
          arrivals,
          hasLength(2),
          reason: 'a refused copy is published again rather than lost',
        );
        expect(
          kind4Ids(relay),
          hasLength(1),
          reason: 'the retry republishes the same signed event, not a new one',
        );
        expect(okVerdicts(relay, kind4Ids(relay).single), [false, true]);
        expect(await storedProtocol(stack.db), 'nip04');
      },
    );

    testWidgets(
      'a copy no relay accepts is published three times, 2 s and then 4 s '
      'apart, and then given up',
      (tester) async {
        final relay = await FakeRelay.start(
          okFor: (event) => event['kind'] == EventKind.directMessage
              ? const FakeOk.refuse('error: refused every time by the relay')
              : null,
        );
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);

        final result = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'refused every time',
        );
        expect(result.success, isTrue);

        final arrivals = await kind4Arrivals(
          relay,
          4,
          timeout: const Duration(seconds: 11),
        );
        expect(arrivals, hasLength(3), reason: 'three attempts, then no more');
        expect(kind4Ids(relay), hasLength(1));
        expect(
          arrivals[1].difference(arrivals[0]),
          greaterThanOrEqualTo(const Duration(milliseconds: 1900)),
        );
        expect(
          arrivals[2].difference(arrivals[1]),
          greaterThanOrEqualTo(const Duration(milliseconds: 3900)),
        );
      },
    );

    testWidgets(
      'a copy whose OK comes after the deadline is published again under the '
      'same id',
      (tester) async {
        // The copy is published with publishEventAwaitOk's default 15 s wait.
        // A relay that stores it but confirms only at 16 s has, as far as the
        // client can tell, lost it, so the client republishes. Only the same
        // signed event lets the relay answer `duplicate:` (01.md:169) instead
        // of storing a second message.
        var lateConfirmations = 1;
        final relay = await FakeRelay.start(
          okFor: (event) =>
              event['kind'] == EventKind.directMessage &&
                  lateConfirmations-- > 0
              ? const FakeOk.accept(delay: Duration(seconds: 16))
              : null,
        );
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);

        final result = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: 'confirmed too late',
        );
        expect(result.success, isTrue);

        final arrivals = await kind4Arrivals(
          relay,
          3,
          timeout: const Duration(seconds: 24),
        );
        expect(
          arrivals,
          hasLength(2),
          reason: 'a copy the client never heard confirmed is published again',
        );
        expect(kind4Ids(relay), hasLength(1));
        expect(okVerdicts(relay, kind4Ids(relay).single), [true, true]);
      },
      timeout: const Timeout(Duration(minutes: 1)),
    );

    testWidgets('a message the retry sweep delivers gets its copy too', (
      tester,
    ) async {
      var refusals = 1;
      final relay = await FakeRelay.start(
        okFor: (event) =>
            event['kind'] == EventKind.giftWrap &&
                addressedTo(event, recipientPubkey) &&
                refusals-- > 0
            ? const FakeOk.refuse('error: refused once by the test relay')
            : null,
      );
      addTearDown(relay.stop);
      final stack = await buildLatchedStack(relay);

      final failed = await stack.repository.sendMessage(
        recipientPubkey: recipientPubkey,
        content: 'delivered by the retry sweep',
      );
      expect(failed.success, isFalse, reason: 'precondition: the send failed');
      final rumorId = await queuedRumorId(stack.db);

      // What OutgoingDmRetryService does with the failed row.
      final recovered = await stack.repository.recoverFullSend(
        rumorId: rumorId,
      );
      expect(recovered.success, isTrue);

      final arrivals = await kind4Arrivals(
        relay,
        2,
        timeout: const Duration(seconds: 5),
      );
      expect(
        arrivals,
        hasLength(1),
        reason:
            'the legacy peer gets the copy of a message the sweep delivered',
      );
    });

    testWidgets(
      'our own echo of a send held on an unreadable inbox keeps the thread '
      'latched',
      (tester) async {
        // The recipient's kind-10050 lookup stalls, so the send is held
        // (#7317) and stores nothing. The relay then hands our own self-wrap
        // back on our subscription, as a real relay does, and the receive
        // path is the first to store the message.
        const content = 'held on an unreadable inbox';
        final relay = await FakeRelay.start(
          stallReqForAuthors: {recipientPubkey},
          echoToPublisher: true,
        );
        addTearDown(relay.stop);
        final stack = await buildLatchedStack(relay);
        DmRepository.inboxResolutionBudget = const Duration(milliseconds: 800);
        await stack.repository.startListening();

        final held = await stack.repository.sendMessage(
          recipientPubkey: recipientPubkey,
          content: content,
        );
        expect(
          held.retryablePending,
          isTrue,
          reason: 'precondition: the send is held',
        );
        await queuedRumorId(stack.db);

        // The receive path writes the protocol in the same upsert as the
        // preview, so the preview is what says the echo has been stored.
        final echoStored = await eventually(
          () async =>
              (await stack.db.conversationsDao.getConversation(
                conversationId,
                ownerPubkey: senderPubkey,
              ))?.lastMessageContent ==
              content,
          timeout: const Duration(seconds: 5),
        );
        expect(echoStored, isTrue, reason: 'precondition: the echo was stored');
        expect(
          await storedProtocol(stack.db),
          'nip04',
          reason: 'our own NIP-17 message proves nothing about the peer',
        );
      },
    );
  });
}
