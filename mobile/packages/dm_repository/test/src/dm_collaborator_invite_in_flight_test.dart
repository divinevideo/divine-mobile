// ABOUTME: #10005 — a collaborator invite whose first send is still in flight
// ABOUTME: is not offered for retry, and a retry that overlaps it joins it.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _collaborator =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';
const _videoAddress = '34236:$_owner:beach-post';

/// The structured tags `CollaboratorInviteService.sendInvite` attaches.
const _inviteTags = <List<String>>[
  [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
  [
    CollaboratorInviteTags.address,
    _videoAddress,
    'wss://relay.divine.video',
    'root',
  ],
  [CollaboratorInviteTags.pubkey, _owner],
  [CollaboratorInviteTags.role, CollaboratorInviteTags.collaboratorRole],
  [CollaboratorInviteTags.title, 'Beach post'],
];

void main() {
  // Real database on purpose: the banner stream is a drift watch query, and
  // whether an in-flight invite shows depends on when that query re-runs
  // relative to the send, which a mocked DAO cannot reproduce.
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  late AppDatabase db;
  late OutgoingDmsDao outgoingDao;
  late _MockNostrClient nostrClient;
  late _MockMessageService messageService;
  late DmRepository repository;

  /// One completer per recipient-wrap publish, in call order. Each publish
  /// parks until the test completes its completer.
  late List<Completer<NIP17SendResult>> publishes;

  Future<NIP17SendResult> stubbedSendRumor() => messageService.sendRumor(
    rumorEvent: any(named: 'rumorEvent'),
    recipientPubkey: any(named: 'recipientPubkey'),
    targetRelays: any(named: 'targetRelays'),
    selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
    awaitRecipientOk: any(named: 'awaitRecipientOk'),
    selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
    recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
    selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
  );

  setUp(() async {
    db = AppDatabase.test(NativeDatabase.memory());
    outgoingDao = OutgoingDmsDao(db);
    nostrClient = _MockNostrClient();
    messageService = _MockMessageService();
    publishes = [];

    when(() => nostrClient.connectedRelayCount).thenReturn(1);
    when(() => nostrClient.configuredRelayCount).thenReturn(1);
    when(
      () => nostrClient.queryEventsDetailed(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        useCache: any(named: 'useCache'),
        tempRelays: any(named: 'tempRelays'),
        requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
        acceptRelayClosedWhenOthersAnswered: any(
          named: 'acceptRelayClosedWhenOthersAnswered',
        ),
        timeout: any(named: 'timeout'),
      ),
    ).thenAnswer(
      (_) async => (events: const <Event>[], timedOut: false, noRelays: false),
    );
    when(() => messageService.canSendTo(any())).thenAnswer((_) async => true);
    when(
      () => messageService.buildRumor(
        recipientPubkey: any(named: 'recipientPubkey'),
        content: any(named: 'content'),
        createdAt: any(named: 'createdAt'),
        additionalTags: any(named: 'additionalTags'),
      ),
    ).thenAnswer(
      (inv) => Event(
        _owner,
        14,
        [
          ['p', inv.namedArguments[#recipientPubkey] as String],
          ...inv.namedArguments[#additionalTags] as List<List<String>>,
        ],
        inv.namedArguments[#content] as String,
        createdAt: inv.namedArguments[#createdAt] as int?,
      ),
    );
    when(stubbedSendRumor).thenAnswer((_) {
      final publish = Completer<NIP17SendResult>();
      publishes.add(publish);
      return publish.future;
    });

    repository = DmRepository(
      nostrClient: nostrClient,
      messageService: messageService,
      directMessagesDao: DirectMessagesDao(db),
      conversationsDao: ConversationsDao(db),
      outgoingDmsDao: outgoingDao,
      userPubkey: _owner,
      signer: LocalNostrSigner(_privateKey),
    );
  });

  tearDown(() async {
    await db.close();
  });

  /// Starts the invite exactly as `CollaboratorInviteService.sendInvite` does
  /// and waits until its recipient publish is parked in flight.
  Future<({Future<NIP17SendResult> send, String rumorId})>
  startInviteInFlight() async {
    final send = repository.sendMessage(
      recipientPubkey: _collaborator,
      content: 'You are invited to collaborate on Beach post.',
      additionalTags: _inviteTags,
      skipNip04Fallback: true,
    );
    await pumpEventQueue();
    expect(publishes, hasLength(1), reason: 'the first publish is in flight');
    final rows = await outgoingDao.watchAllForOwner(_owner).first;
    expect(rows, hasLength(1));
    // Positive control: the row the banner reads is genuinely retry-eligible
    // while it is in flight, so only the in-flight signal can hide it.
    expect(rows.single.recipientWrapStatus, OutgoingWrapStatus.pending);
    return (send: send, rumorId: rows.single.id);
  }

  NIP17SendResult delivered(String rumorId) => NIP17SendResult.success(
    rumorEventId: rumorId,
    messageEventId:
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
    recipientPubkey: _collaborator,
  );

  Set<String> pendingInviteIds(List<PendingCollaboratorInviteGroup> groups) => {
    for (final g in groups) ...g.invites.map((i) => i.rumorId),
  };

  group('pending-invite banner while the first send is in flight (#10005)', () {
    for (final (label, outcome) in [
      (
        'held pending',
        const NIP17SendResult.failure(
          'frame written, no OK',
          retryablePending: true,
        ),
      ),
      ('failed', const NIP17SendResult.failure('relay rejected the wrap')),
    ]) {
      test('hides the invite until its first attempt ends $label, then shows '
          'it', () async {
        final emissions = <List<PendingCollaboratorInviteGroup>>[];
        final sub = repository.watchPendingCollaboratorInviteGroups().listen(
          emissions.add,
        );
        addTearDown(sub.cancel);

        final inFlight = await startInviteInFlight();
        await pumpEventQueue();

        expect(emissions, isNotEmpty);
        expect(
          emissions.map(pendingInviteIds),
          everyElement(isNot(contains(inFlight.rumorId))),
          reason: 'an invite being sent right now must not offer Retry',
        );
        expect(
          pendingInviteIds(
            await repository.watchPendingCollaboratorInviteGroups().first,
          ),
          isNot(contains(inFlight.rumorId)),
          reason: 'the snackbar retry reads the same filtered snapshot',
        );

        publishes.single.complete(outcome);
        await inFlight.send;
        await pumpEventQueue();

        expect(
          pendingInviteIds(emissions.last),
          equals({inFlight.rumorId}),
          reason: 'once the attempt ended without delivering, Retry is due',
        );
      });
    }

    test('never shows an invite whose first send delivers', () async {
      final emissions = <List<PendingCollaboratorInviteGroup>>[];
      final sub = repository.watchPendingCollaboratorInviteGroups().listen(
        emissions.add,
      );
      addTearDown(sub.cancel);

      final inFlight = await startInviteInFlight();
      publishes.single.complete(delivered(inFlight.rumorId));
      final result = await inFlight.send;
      await pumpEventQueue();

      expect(result.success, isTrue);
      expect(await outgoingDao.getById(inFlight.rumorId), isNull);
      expect(
        emissions.map(pendingInviteIds),
        everyElement(isNot(contains(inFlight.rumorId))),
        reason:
            'settling the in-flight state must not flash the invite from '
            'a queue snapshot taken before the row was finalized',
      );
    });
  });

  group('a retry overlapping the first send joins it (#10005)', () {
    test(
      'recoverFullSend during the in-flight sendMessage publishes exactly one '
      'recipient wrap and both callers get its outcome',
      () async {
        final inFlight = await startInviteInFlight();

        final retry = repository.recoverFullSend(rumorId: inFlight.rumorId);
        await pumpEventQueue();
        expect(
          publishes,
          hasLength(1),
          reason: 'the retry must join the live attempt, not publish again',
        );

        publishes.single.complete(delivered(inFlight.rumorId));
        final sent = await inFlight.send;
        final retried = await retry;

        expect(sent.success, isTrue);
        expect(retried.success, isTrue);
        verify(stubbedSendRumor).called(1);
        expect(await outgoingDao.getById(inFlight.rumorId), isNull);
      },
    );

    test(
      'a banner retry that joins a held first send charges the attempt once '
      'and reports it as still needing to send',
      () async {
        final inFlight = await startInviteInFlight();
        final row = await outgoingDao.getById(inFlight.rumorId);
        final invite = PendingCollaboratorInvite(
          rumorId: inFlight.rumorId,
          collaboratorPubkey: _collaborator,
          creatorPubkey: _owner,
          videoAddress: _videoAddress,
          recipientWrapStatus: row!.recipientWrapStatus,
          selfWrapStatus: row.selfWrapStatus,
          retryCount: row.retryCount,
          queuedAt: row.queuedAt,
        );

        final retry = repository.retryPendingCollaboratorInvites([invite]);
        await pumpEventQueue();
        expect(publishes, hasLength(1));

        publishes.single.complete(
          const NIP17SendResult.failure(
            'frame written, no OK',
            retryablePending: true,
          ),
        );
        final sent = await inFlight.send;
        final summary = await retry;

        expect(sent.retryablePending, isTrue);
        expect(sent.queuedRumorId, inFlight.rumorId);
        expect(summary.failureCount, 1);
        verify(stubbedSendRumor).called(1);
        final after = await outgoingDao.getById(inFlight.rumorId);
        expect(after!.recipientWrapStatus, OutgoingWrapStatus.pending);
        expect(
          after.retryCount,
          1,
          reason: 'one underlying attempt is charged once, by its owner',
        );
      },
    );
  });
}
