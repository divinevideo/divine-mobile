// ABOUTME: E2E regression for #8619 — a group DM sibling that JOINS a
// ABOUTME: recovery the retry sweep already owns must be charged for that one
// ABOUTME: attempt once, not twice. Drives a real DmRepository + NostrClient
// ABOUTME: over real sockets, and the real OutgoingDmRetryService in ARM B.
// ABOUTME: Requires: NO Docker stack — every dependency here is local.

@Tags(['service'])
library;

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/services/outgoing_dm_retry_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../helpers/fake_relay.dart';

/// Redirects every dial onto the in-process relay, the same way the #8434
/// suite does, so the harness stays identical across the group-send e2e
/// suites even though no arm here advertises an inbox host.
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
      '4444444444444444444444444444444444444444444444444444444444444444';
  // "Deliverable" — advertises no inbox (EOSE), so a pool OK is delivery.
  const deliverableKey =
      '5555555555555555555555555555555555555555555555555555555555555555';
  // "Unreadable" — the relay swallows every REQ naming this author, so each
  // attempt for this sibling ends soft-unconfirmed and keeps its row.
  const unreadableKey =
      '6666666666666666666666666666666666666666666666666666666666666666';
  final senderPubkey = getPublicKey(senderKey);
  final deliverablePubkey = getPublicKey(deliverableKey);
  final unreadablePubkey = getPublicKey(unreadableKey);

  final groupConversationId = DmRepository.computeConversationId([
    senderPubkey,
    deliverablePubkey,
    unreadablePubkey,
  ]);

  /// Long enough for the sweep to register the unreadable sibling's recovery
  /// while the group loop is still parked on the deliverable sibling's OK;
  /// well inside the OK-confirm window, so that sibling is still delivered.
  const deliverableOkDelay = Duration(seconds: 3);
  const recoveryOkDelay = Duration(seconds: 4);

  /// Builds the real stack the way `repository_providers.dart` does, with
  /// the durable queue wired — the retry budget under test lives on its rows.
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

  /// Completes with the batch's rows the moment both siblings are queued —
  /// the point at which the sweep can see them and the group loop has not
  /// yet reached the second sibling.
  Future<List<OutgoingDm>> bothRowsQueued(AppDatabase db) {
    final seen = Completer<List<OutgoingDm>>();
    late final StreamSubscription<List<OutgoingDm>> subscription;
    subscription = db.outgoingDmsDao.watchAllForOwner(senderPubkey).listen((
      rows,
    ) {
      if (rows.length == 2 && !seen.isCompleted) seen.complete(rows);
    });
    addTearDown(subscription.cancel);
    return seen.future;
  }

  /// How many kind-10050 lookups naming [author] the relay has received.
  ///
  /// Only a recovery that RAN its attempt re-resolves the recipient's inbox
  /// (`_recoverFullSendLocked`); a caller that joined an in-flight attempt
  /// never does. The delta across a send therefore says which side owned the
  /// sibling's attempt — the discriminator every arm needs, because the
  /// charge count alone cannot tell "joined and charged once" from "never
  /// joined at all".
  int inboxLookupsFor(FakeRelay relay, String author) {
    var count = 0;
    for (final frame in relay.receivedFrames) {
      if (frame.length < 3 || frame[0] != 'REQ') continue;
      for (final filter in frame.skip(2)) {
        if (filter is! Map) continue;
        final kinds = filter['kinds'];
        final authors = filter['authors'];
        if (kinds is List &&
            kinds.contains(EventKind.dmRelaysList) &&
            authors is List &&
            authors.contains(author)) {
          count++;
          break;
        }
      }
    }
    return count;
  }

  /// How many gift wraps addressed to [recipient] the relay was handed.
  int wrapsAddressedTo(FakeRelay relay, String recipient) {
    var count = 0;
    for (final frame in relay.receivedFrames) {
      if (frame.length < 2 || frame[0] != 'EVENT' || frame[1] is! Map) {
        continue;
      }
      final event = frame[1] as Map;
      if (event['kind'] != EventKind.giftWrap) continue;
      final tags = event['tags'];
      if (tags is! List) continue;
      final addressed = tags.any(
        (tag) =>
            tag is List &&
            tag.length >= 2 &&
            tag[0] == 'p' &&
            tag[1] == recipient,
      );
      if (addressed) count++;
    }
    return count;
  }

  /// One resolution's worth of lookups, measured rather than assumed: the
  /// client may fan a lookup out to more than one socket, and a literal here
  /// would silently stop discriminating the moment that shape changed.
  Future<int> lookupsPerResolution(
    FakeRelay relay,
    DmRepository repository,
  ) async {
    final before = inboxLookupsFor(relay, unreadablePubkey);
    final lookup = await repository.resolveDmInboxRelaysDetailed(
      unreadablePubkey,
    );
    expect(
      lookup.state,
      DmInboxResolution.unreadable,
      reason: 'precondition: this recipient must be UNREADABLE, not absent',
    );
    final perResolution = inboxLookupsFor(relay, unreadablePubkey) - before;
    expect(perResolution, greaterThan(0));
    return perResolution;
  }

  setUp(() {
    // This suite exercises retry-attempt ownership, not the production inbox
    // timeout. Keep the deliberately stalled lookup shorter than the delayed
    // deliverable OK so the intended owner/joiner ordering is deterministic
    // even when recipient reads require full relay settlement (#8630).
    DmRepository.inboxResolutionBudget = const Duration(seconds: 1);
  });
  tearDown(() {
    DmRepository.inboxResolutionBudget = DmSendBudget.inboxResolution;
  });

  group('#8619 group DM send overlapping the retry sweep', () {
    testWidgets(
      'ARM A: a sibling that joins a recovery the sweep already owns is '
      'charged for that one attempt once, and still hands back its handle',
      (tester) async {
        // The deliverable sibling's OK is delayed so the group loop is parked
        // on it while the sweep registers the unreadable sibling's recovery.
        // The unreadable sibling's REQ is swallowed, so every attempt for it
        // ends soft-unconfirmed with its row kept — the outcome #8619 is
        // about.
        final relay = await FakeRelay.start(
          stallReqForAuthors: {unreadablePubkey},
          okDelayForRecipients: {
            deliverablePubkey: deliverableOkDelay,
            unreadablePubkey: recoveryOkDelay,
          },
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        final perResolution = await lookupsPerResolution(
          relay,
          stack.repository,
        );

        final rowsQueued = bothRowsQueued(stack.db);
        final lookupsBeforeSend = inboxLookupsFor(relay, unreadablePubkey);
        final sendFuture = stack.repository.sendGroupMessage(
          recipientPubkeys: [deliverablePubkey, unreadablePubkey],
          content: 'group message joined by the sweep',
        );

        // The sweep reaches the unreadable sibling's row while the group is
        // still on the first publish: its recovery owns `full:<queueId>`.
        final rows = await rowsQueued;
        final queued = rows.firstWhere(
          (row) => row.recipientPubkey == unreadablePubkey,
        );
        final recoveryFuture = stack.repository.recoverFullSend(
          rumorId: queued.id,
        );

        final results = await sendFuture;
        final recovered = await recoveryFuture;

        expect(
          inboxLookupsFor(relay, unreadablePubkey) - lookupsBeforeSend,
          equals(2 * perResolution),
          reason:
              'precondition: the recovery RAN its own attempt (it re-resolved '
              'the inbox), so the group JOINED it rather than the reverse',
        );
        expect(
          wrapsAddressedTo(relay, unreadablePubkey),
          equals(1),
          reason: 'one attempt on the wire — the join prevented a duplicate',
        );

        expect(recovered.retryablePending, isTrue);
        expect(results, hasLength(2));
        expect(results[1].retryablePending, isTrue);

        final held = await queueRowFor(stack.db, unreadablePubkey);
        expect(held, isNotNull, reason: 'a soft-unconfirmed row survives');
        expect(
          held!.retryCount,
          equals(1),
          reason:
              'one underlying attempt charges the budget once; before #8619 '
              'the owner charged it and the joining group send charged it '
              'again',
        );
        expect(
          results[1].queuedRumorId,
          equals(held.id),
          reason: 'a joined sibling still hands the caller its durable handle',
        );

        // The deliverable sibling is untouched by the fix.
        expect(results[0].success, isTrue);
        expect(await queueRowFor(stack.db, deliverablePubkey), isNull);
      },
    );

    testWidgets(
      'ARM B: the real retry sweep that overlaps a group send joins the '
      'sibling in flight, then wins the next sibling, which is charged once',
      (tester) async {
        // Same relay shape as ARM A, but the sweep is the production
        // OutgoingDmRetryService, driven exactly as a foreground flip would
        // drive it. Its clock is skewed past the interrupted-send guard so
        // the batch's fresh rows are eligible — the guard is what normally
        // keeps a sweep off a live send; #8619 is about what happens once a
        // batch has outlived it.
        final relay = await FakeRelay.start(
          stallReqForAuthors: {unreadablePubkey},
          okDelayForRecipients: {
            deliverablePubkey: deliverableOkDelay,
            unreadablePubkey: recoveryOkDelay,
          },
        );
        addTearDown(relay.stop);
        final stack = await buildStack(relay);
        final perResolution = await lookupsPerResolution(
          relay,
          stack.repository,
        );

        final service = OutgoingDmRetryService(
          dmRepository: stack.repository,
          outgoingDmsDao: stack.db.outgoingDmsDao,
          userPubkey: senderPubkey,
          appForegroundStream: const Stream<bool>.empty(),
          isOffline: () async => false,
          now: () => DateTime.now().add(
            OutgoingDmRetryService.interruptedMinAge +
                const Duration(seconds: 10),
          ),
        );
        addTearDown(service.dispose);

        final rowsQueued = bothRowsQueued(stack.db);
        final lookupsBeforeSend = inboxLookupsFor(relay, unreadablePubkey);
        final sendFuture = stack.repository.sendGroupMessage(
          recipientPubkeys: [deliverablePubkey, unreadablePubkey],
          content: 'group message overlapped by the real sweep',
        );

        await rowsQueued;
        final sweepFuture = service.sweep();

        final results = await sendFuture;
        await sweepFuture;

        // The sweep processes rows in queue order. It joins the deliverable
        // sibling the group is parked on, and when both resume from that one
        // future it registers the unreadable sibling's recovery before the
        // group loop can — the group still has to re-read the row first. So
        // the sweep OWNS the second attempt, which is what its own inbox
        // re-resolution proves here.
        expect(
          inboxLookupsFor(relay, unreadablePubkey) - lookupsBeforeSend,
          equals(2 * perResolution),
          reason:
              'the sweep ran the unreadable sibling attempt itself; the '
              'group send joined it',
        );
        expect(wrapsAddressedTo(relay, deliverablePubkey), equals(1));
        expect(wrapsAddressedTo(relay, unreadablePubkey), equals(1));

        final held = await queueRowFor(stack.db, unreadablePubkey);
        expect(held, isNotNull);
        expect(
          held!.retryCount,
          equals(1),
          reason: 'one attempt, one charge, whichever side ran it (#8619)',
        );
        expect(results, hasLength(2));
        expect(results[1].retryablePending, isTrue);
        expect(results[1].queuedRumorId, equals(held.id));
        expect(results[0].success, isTrue);
        expect(await queueRowFor(stack.db, deliverablePubkey), isNull);
      },
    );
  });
}
