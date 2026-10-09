// ABOUTME: #8363 — a queued DM addressed to its own sender is refused and
// ABOUTME: dropped by the retry paths instead of being published again.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _FakeEvent extends Fake implements Event {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _peer =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _privateKey =
    '5426e5b8b4b0e2a1f5e8d3c7a9b2f4e6d8c0a2b4f6e8d0c2a4b6f8e0d2c4a6b8';

const _baseCreatedAt = 1700000000;
const _rumorId =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _wrapId =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _videoAddress = '34236:$_owner:beach-post';

const _refusal = 'refused: a message cannot be addressed to its own sender';

typedef _WrapStates = ({OutgoingWrapStatus recipient, OutgoingWrapStatus self});

/// The wrap states a recovery call can find a queued send in.
const List<_WrapStates> _replayableStates = [
  (recipient: OutgoingWrapStatus.failed, self: OutgoingWrapStatus.failed),
  (recipient: OutgoingWrapStatus.pending, self: OutgoingWrapStatus.pending),
  (recipient: OutgoingWrapStatus.sent, self: OutgoingWrapStatus.failed),
  // Short-circuits before publishing in both functions: pins the check first.
  (recipient: OutgoingWrapStatus.sent, self: OutgoingWrapStatus.sent),
];

String _rumorJson(List<List<String>> tags) => jsonEncode({
  'id': _rumorId,
  'pubkey': _owner,
  'created_at': _baseCreatedAt,
  'kind': EventKind.privateDirectMessage,
  'tags': tags,
  'content': 'queued message',
  'sig': '',
});

/// A one-to-one send as `sendMessage` queues it: keyed by the rumor id, in the
/// conversation derived from [recipient] exactly as it was passed in.
OutgoingDm _queuedSend({
  required String recipient,
  OutgoingWrapStatus recipientWrap = OutgoingWrapStatus.failed,
  OutgoingWrapStatus selfWrap = OutgoingWrapStatus.failed,
  List<List<String>> additionalTags = const [],
}) => OutgoingDm(
  id: _rumorId,
  conversationId: DmRepository.computeConversationId(
    [_owner, recipient]..sort(),
  ),
  recipientPubkey: recipient,
  content: 'queued message',
  createdAt: _baseCreatedAt,
  rumorEventJson: _rumorJson([
    ['p', recipient],
    ...additionalTags,
  ]),
  recipientWrapStatus: recipientWrap,
  selfWrapStatus: selfWrap,
  queuedAt: DateTime.utc(2026, 10),
  ownerPubkey: _owner,
);

/// The sender's own row of a group send to the sender and [_peer]. A group
/// queues one row per recipient, all under the group's conversation id.
OutgoingDm _groupSiblingForSender({
  OutgoingWrapStatus recipientWrap = OutgoingWrapStatus.failed,
}) {
  final recipients = [_owner, _peer]..sort();
  return OutgoingDm(
    id: '$_rumorId:$_owner',
    conversationId: DmRepository.computeConversationId(
      [_owner, ...recipients]..sort(),
    ),
    recipientPubkey: _owner,
    content: 'queued message',
    createdAt: _baseCreatedAt,
    rumorEventJson: _rumorJson([
      for (final recipient in recipients) ['p', recipient],
    ]),
    recipientWrapStatus: recipientWrap,
    selfWrapStatus: OutgoingWrapStatus.failed,
    queuedAt: DateTime.utc(2026, 10),
    ownerPubkey: _owner,
  );
}

/// A collaborator invite whose creator named themself as the collaborator.
OutgoingDm _queuedSelfInvite() => _queuedSend(
  recipient: _owner,
  additionalTags: [
    [CollaboratorInviteTags.markerName, CollaboratorInviteTags.markerValue],
    [
      CollaboratorInviteTags.address,
      _videoAddress,
      'wss://relay.divine.video',
      'root',
    ],
    [CollaboratorInviteTags.pubkey, _owner],
    [CollaboratorInviteTags.role, CollaboratorInviteTags.collaboratorRole],
  ],
);

void main() {
  late AppDatabase db;
  late OutgoingDmsDao outgoingDao;
  late _MockMessageService messageService;
  late DmRepository repository;

  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(Duration.zero);
  });

  /// A replay of both wraps, optionally narrowed to one recipient.
  Future<NIP17SendResult> fullSendPublish({String? to}) =>
      messageService.sendRumor(
        rumorEvent: any(named: 'rumorEvent'),
        recipientPubkey: to ?? any(named: 'recipientPubkey'),
        targetRelays: any(named: 'targetRelays'),
        selfWrapTargetRelays: any(named: 'selfWrapTargetRelays'),
        awaitRecipientOk: any(named: 'awaitRecipientOk'),
        selfWrapOnSoftUnconfirmed: any(named: 'selfWrapOnSoftUnconfirmed'),
        recipientWrapBuildTimeout: any(named: 'recipientWrapBuildTimeout'),
        selfWrapBuildTimeout: any(named: 'selfWrapBuildTimeout'),
      );

  /// A replay of the sender's own copy alone.
  Future<NIP17SendResult> selfWrapPublish() => messageService.publishSelfWrap(
    rumorEvent: any(named: 'rumorEvent'),
    targetRelays: any(named: 'targetRelays'),
  );

  // Real DAOs over a real database, as in dm_retry_rumor_identity_test.dart:
  // what is left in the queue and in the conversation tables is the assertion.
  // Only the relay-facing edges are mocked, and every relay accepts every
  // wrap, so a replay that reaches them delivers in full.
  Future<void> openHarness() async {
    db = AppDatabase.test(NativeDatabase.memory());
    outgoingDao = OutgoingDmsDao(db);
    final nostrClient = _MockNostrClient();
    messageService = _MockMessageService();

    // No kind-10050 anywhere. Left unstubbed, the lookup would read as a
    // failed one and score every delivery as unconfirmed.
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
    when(fullSendPublish).thenAnswer(
      (invocation) async => NIP17SendResult.success(
        rumorEventId: (invocation.namedArguments[#rumorEvent] as Event).id,
        messageEventId: _wrapId,
        recipientPubkey: invocation.namedArguments[#recipientPubkey] as String,
      ),
    );
    when(selfWrapPublish).thenAnswer(
      (invocation) async => NIP17SendResult.success(
        rumorEventId: (invocation.namedArguments[#rumorEvent] as Event).id,
        messageEventId: _wrapId,
        recipientPubkey: _owner,
      ),
    );

    repository = DmRepository(
      nostrClient: nostrClient,
      messageService: messageService,
      directMessagesDao: DirectMessagesDao(db),
      conversationsDao: ConversationsDao(db),
      outgoingDmsDao: outgoingDao,
      userPubkey: _owner,
      signer: LocalNostrSigner(_privateKey),
    );
  }

  Future<void> closeHarness() => db.close();

  group('recoverFullSend', () {
    setUp(openHarness);
    tearDown(closeHarness);

    // The control for every "published nothing" assertion in this file: the
    // same matchers and table reads do see a replay that goes out.
    test('republishes a queued send addressed to another pubkey', () async {
      await outgoingDao.enqueue(_queuedSend(recipient: _peer));

      final result = await repository.recoverFullSend(rumorId: _rumorId);

      expect(result.success, isTrue);
      verify(() => fullSendPublish(to: _peer)).called(1);
      expect(await outgoingDao.getById(_rumorId), isNull);
      expect(await db.select(db.directMessages).get(), hasLength(1));
      expect(await db.select(db.conversations).get(), hasLength(1));
    });

    // Whether a group send keeps its sender as a recipient is still open
    // (#8359), so the refusal must stop short of this row.
    test(
      'still republishes a group sibling row that names the sender',
      () async {
        final sibling = _groupSiblingForSender();
        await outgoingDao.enqueue(sibling);

        final result = await repository.recoverFullSend(rumorId: sibling.id);

        expect(result.success, isTrue);
        verify(() => fullSendPublish(to: _owner)).called(1);
      },
    );

    for (final state in _replayableStates) {
      test(
        'refuses a ${state.recipient.name}/${state.self.name} row addressed '
        'to its own sender without publishing',
        () async {
          await outgoingDao.enqueue(
            _queuedSend(
              recipient: _owner,
              recipientWrap: state.recipient,
              selfWrap: state.self,
            ),
          );
          expect(await outgoingDao.getById(_rumorId), isNotNull);

          final result = await repository.recoverFullSend(rumorId: _rumorId);

          verifyNever(fullSendPublish);
          verifyNever(selfWrapPublish);
          expect(result.success, isFalse);
          expect(result.blocked, isTrue);
          expect(result.error, equals(_refusal));
          expect(await outgoingDao.getById(_rumorId), isNull);
          expect(await db.select(db.directMessages).get(), isEmpty);
          expect(await db.select(db.conversations).get(), isEmpty);
        },
      );
    }

    // `validatePubkey` accepts upper-case hex, so an earlier build could
    // queue the sender's own key in a casing that `==` reads as a stranger.
    test(
      'refuses a row whose recipient is the sender in upper case',
      () async {
        await outgoingDao.enqueue(
          _queuedSend(recipient: _owner.toUpperCase()),
        );
        expect(await outgoingDao.getById(_rumorId), isNotNull);

        final result = await repository.recoverFullSend(rumorId: _rumorId);

        verifyNever(fullSendPublish);
        verifyNever(selfWrapPublish);
        expect(result.success, isFalse);
        expect(result.blocked, isTrue);
        expect(result.error, equals(_refusal));
        expect(await outgoingDao.getById(_rumorId), isNull);
        expect(await db.select(db.directMessages).get(), isEmpty);
        expect(await db.select(db.conversations).get(), isEmpty);
      },
    );
  });

  // A sibling group, not a nested one: nesting would turn `openHarness` into
  // a shared setUp and start its stubs counting against the #8399 ratchet.
  group('recoverSelfWrap', () {
    setUp(openHarness);
    tearDown(closeHarness);

    // The sweep calls this directly for a delivered row whose sender copy is
    // missing. Control for the self-copy matcher, as above.
    test(
      'republishes the sender copy of a send delivered to another pubkey',
      () async {
        await outgoingDao.enqueue(
          _queuedSend(recipient: _peer, recipientWrap: OutgoingWrapStatus.sent),
        );

        final result = await repository.recoverSelfWrap(rumorId: _rumorId);

        expect(result.success, isTrue);
        verify(selfWrapPublish).called(1);
        expect(await outgoingDao.getById(_rumorId), isNull);
      },
    );

    test(
      'still republishes the sender copy of a group sibling row that names '
      'the sender',
      () async {
        final sibling = _groupSiblingForSender(
          recipientWrap: OutgoingWrapStatus.sent,
        );
        await outgoingDao.enqueue(sibling);

        final result = await repository.recoverSelfWrap(rumorId: sibling.id);

        expect(result.success, isTrue);
        verify(selfWrapPublish).called(1);
      },
    );

    for (final state in _replayableStates) {
      test(
        'refuses a ${state.recipient.name}/${state.self.name} row addressed '
        'to its own sender without publishing',
        () async {
          await outgoingDao.enqueue(
            _queuedSend(
              recipient: _owner,
              recipientWrap: state.recipient,
              selfWrap: state.self,
            ),
          );
          expect(await outgoingDao.getById(_rumorId), isNotNull);

          final result = await repository.recoverSelfWrap(rumorId: _rumorId);

          verifyNever(selfWrapPublish);
          verifyNever(fullSendPublish);
          expect(result.success, isFalse);
          expect(result.blocked, isTrue);
          expect(result.error, equals(_refusal));
          expect(await outgoingDao.getById(_rumorId), isNull);
          expect(await db.select(db.directMessages).get(), isEmpty);
          expect(await db.select(db.conversations).get(), isEmpty);
        },
      );
    }

    test(
      'refuses a row whose recipient is the sender in upper case',
      () async {
        await outgoingDao.enqueue(
          _queuedSend(
            recipient: _owner.toUpperCase(),
            recipientWrap: OutgoingWrapStatus.sent,
          ),
        );
        expect(await outgoingDao.getById(_rumorId), isNotNull);

        final result = await repository.recoverSelfWrap(rumorId: _rumorId);

        verifyNever(selfWrapPublish);
        verifyNever(fullSendPublish);
        expect(result.success, isFalse);
        expect(result.blocked, isTrue);
        expect(result.error, equals(_refusal));
        expect(await outgoingDao.getById(_rumorId), isNull);
        expect(await db.select(db.directMessages).get(), isEmpty);
        expect(await db.select(db.conversations).get(), isEmpty);
      },
    );
  });

  group('retryPendingCollaboratorInvites', () {
    setUp(openHarness);
    tearDown(closeHarness);

    test(
      'counts an invite addressed to its own creator as blocked and drops it',
      () async {
        await outgoingDao.enqueue(_queuedSelfInvite());
        // Read back through the stream the retry banner uses, so the invite
        // handed to the retry is the one the stored row really parses into.
        final pending = await repository
            .watchPendingCollaboratorInviteGroups()
            .first;
        expect(pending.single.invites, hasLength(1));

        final summary = await repository.retryPendingCollaboratorInvites(
          pending.single.invites,
        );

        expect(
          summary,
          equals(
            const CollaboratorInviteRetrySummary(
              attemptedCount: 1,
              successCount: 0,
              failureCount: 0,
              blockedCount: 1,
            ),
          ),
        );
        verifyNever(fullSendPublish);
        expect(await outgoingDao.getById(_rumorId), isNull);
      },
    );
  });
}
