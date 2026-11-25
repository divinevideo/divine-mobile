// ABOUTME: A DmRepository on real SQLite and real signing for share delivery
// ABOUTME: tests, over a mocked relay client whose answers each test steers.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

/// Registers what the harness's matchers need. Call it from `setUpAll`.
void registerShareHarnessFallbacks() {
  registerFallbackValue(_FakeEvent());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(<nostr_filter.Filter>[]);
}

/// The outbox, with a hook that runs once a batch has committed.
class ShareQueue extends OutgoingDmsDao {
  ShareQueue(super.attachedDatabase);

  /// Runs after [enqueueAll] commits, before the batch starts delivery.
  Future<void> Function()? afterCommit;

  @override
  Future<void> enqueueAll(
    List<OutgoingDm> rows, {
    required bool Function() isCurrent,
  }) async {
    await super.enqueueAll(rows, isCurrent: isCurrent);
    await afterCommit?.call();
  }
}

/// One in-memory database, one relay client and the repositories built on
/// them. Every key is derived from a private key, so it is a point on the
/// curve and every gift wrap is really built and encrypted.
class ShareDeliveryHarness {
  ShareDeliveryHarness() {
    when(() => client.connectedRelayCount).thenReturn(1);
    when(() => client.configuredRelayCount).thenReturn(1);
    when(() => client.configuredRelays).thenReturn(const [poolRelay]);
    when(() => client.isRelayAllowed(any())).thenReturn(true);
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
        silentRelayTimeout: any(named: 'silentRelayTimeout'),
      ),
    ).thenAnswer((_) async {
      await inboxLookups?.future;
      // Every relay answered and none holds a kind-10050: the pool is where
      // the recipient reads, so a pool `OK` is delivery.
      return (events: const <Event>[], timedOut: false, noRelays: false);
    });
    when(
      () => client.publishEventAwaitOk(
        any(),
        targetRelays: any(named: 'targetRelays'),
        timeout: any(named: 'timeout'),
        diagnosticTag: any(named: 'diagnosticTag'),
      ),
    ).thenAnswer((invocation) async {
      final wrap = invocation.positionalArguments.first as Event;
      recipientPublishes.add(wrap);
      await holdRecipientPublish?.call();
      return answerRecipient(
        wrap,
        invocation.namedArguments[#targetRelays] as List<String>?,
      );
    });
    when(
      () => client.publishEvent(
        any(),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer((invocation) async {
      final wrap = invocation.positionalArguments.first as Event;
      selfPublishes.add(wrap);
      return PublishSuccess(event: wrap);
    });
  }

  static final String ownerKey = '11' * 32;
  static final String otherOwnerKey = '22' * 32;
  static final String owner = getPublicKey(ownerKey);
  static final String otherOwner = getPublicKey(otherOwnerKey);
  static final String recipient = getPublicKey('33' * 32);
  static final String secondRecipient = getPublicKey('44' * 32);
  static const String poolRelay = 'wss://relay.divine.video';

  final AppDatabase db = AppDatabase.test(NativeDatabase.memory());
  late final ShareQueue queue = ShareQueue(db);
  final NostrClient client = _MockNostrClient();

  /// Recipient wraps, in publish order.
  final List<Event> recipientPublishes = [];

  /// The sender's own copies, in publish order.
  final List<Event> selfPublishes = [];

  /// While set and not complete, every kind-10050 lookup waits on it.
  Completer<void>? inboxLookups;

  /// Awaited after a recipient wrap is recorded and before it is answered.
  Future<void> Function()? holdRecipientPublish;

  /// What the relays answer for a recipient wrap. Defaults to an `OK` from
  /// every relay it was sent to.
  PublishOutcome Function(Event wrap, List<String>? targets) answerRecipient =
      acceptedByTargets;

  final List<DmRepository> _built = [];

  /// An `OK` from every relay the wrap was sent to, or from the pool.
  static PublishOutcome acceptedByTargets(
    Event wrap,
    List<String>? targets,
  ) => PublishOutcome(
    eventId: wrap.id,
    acceptedBy: targets ?? const [poolRelay],
    rejectedBy: const {},
    noResponseFrom: const [],
  );

  /// A repository signed in as [owner] in [environment].
  DmRepository build({
    String? environment = 'staging',
    bool Function(String recipient)? isHidden,
    OfflineProbe? isOffline,
    DmRepositoryErrorReporter? errorReporter,
    ConversationsDao? conversations,
    DirectMessagesDao? messages,
  }) {
    final signer = LocalNostrSigner(ownerKey);
    final repository = DmRepository(
      nostrClient: client,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: owner,
        nostrService: client,
        isOffline: isOffline,
      ),
      directMessagesDao: messages ?? DirectMessagesDao(db),
      conversationsDao: conversations ?? ConversationsDao(db),
      outgoingDmsDao: queue,
      isShareRecipientHidden: isHidden,
      errorReporter: errorReporter,
      signer: signer,
      userPubkey: owner,
      environment: environment,
    );
    _built.add(repository);
    return repository;
  }

  /// Signs [repository] in as [otherOwner].
  void switchAccount(DmRepository repository) {
    final signer = LocalNostrSigner(otherOwnerKey);
    repository.setCredentials(
      userPubkey: otherOwner,
      signer: signer,
      messageService: NIP17MessageService(
        signer: signer,
        senderPublicKey: otherOwner,
        nostrService: client,
      ),
    );
  }

  /// Shares one video with [recipients] through the share sheet's batch.
  Future<Map<String, ShareEnqueueOutcome>> share(
    DmRepository repository,
    List<String> recipients,
  ) => repository.enqueueSharedVideoBatch(
    recipientPubkeys: recipients,
    baseContent: 'See https://divine.video/video',
    videoAuthorPubkey: owner,
    videoKind: 34236,
    videoDTag: 'shared-video',
  );

  /// Queues a share to [to] and ends that session at the commit, the app
  /// closing at the handoff, so only a retry can deliver it. Returns its id.
  Future<String> parkShare(String to) async {
    final parking = build();
    queue.afterCommit = parking.stopListening;
    try {
      final outcomes = await share(parking, [to]);
      return (outcomes[to]! as ShareEnqueueQueued).rumorId;
    } finally {
      queue.afterCommit = null;
    }
  }

  /// Stops every repository built here and closes the database.
  Future<void> dispose() async {
    for (final repository in _built) {
      await repository.stopListening();
    }
    await db.close();
  }
}
