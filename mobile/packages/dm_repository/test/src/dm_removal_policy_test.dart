// ABOUTME: Coverage for the injected conversation-removal policy (#8391) — the
// ABOUTME: repository-level guard that stops any caller destroying a protected
// ABOUTME: thread, which #8302 had guarded in one cubit only.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _protectedPeer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _ordinaryPeer =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _otherPeer =
    '4444444444444444444444444444444444444444444444444444444444444444';

/// Sorts after [_owner] and before [_protectedPeer], so a group holding both
/// lists the protected peer second among its members.
const _earlyPeer =
    '1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a';

bool _protectsTheProtectedPeer(String pubkeyHex) => pubkeyHex == _protectedPeer;

// Real key pairs for the receive-path tests: those gift wraps are sealed,
// signed and decrypted for real, so each pubkey has to belong to its secret.
final String _receiverSecret = '5' * 64;
final String _strangerSecret = '6' * 64;
final String _protectedAuthorSecret = '7' * 64;
final String _receiver = getPublicKey(_receiverSecret);
final String _stranger = getPublicKey(_strangerSecret);
final String _protectedAuthor = getPublicKey(_protectedAuthorSecret);

/// Watchdog for a wrap the receive path never settles; nothing waits this
/// long on a passing run.
const _settleTimeout = Duration(seconds: 20);

void main() {
  group('DmRepository removal policy', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
    });

    tearDown(() => db.close());

    DmRepository buildRepository({
      DmConversationRemovalPolicy? removalPolicy,
      String owner = _owner,
    }) => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      removedConversationsDao: db.removedConversationsDao,
      userPubkey: owner,
      removalPolicy: removalPolicy,
    );

    Future<String> seedConversation(
      List<String> participants, {
      String owner = _owner,
    }) async {
      final conversationId = DmRepository.computeConversationId(participants);
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: '["${participants.join('","')}"]',
        isGroup: participants.length > 2,
        createdAt: 1700000000,
        ownerPubkey: owner,
      );
      return conversationId;
    }

    group('removeConversation', () {
      test('refuses a protected peer and leaves the row on disk', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _protectedPeer]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.refused));
        expect(await repository.getConversation(conversationId), isNotNull);
      });

      test('removes an ordinary conversation', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _ordinaryPeer]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
        expect(await repository.getConversation(conversationId), isNull);
      });

      test('removes a group that includes a protected peer', () async {
        // A group's members are whoever its author listed, so naming a
        // protected account does not make the room that account's thread
        // (#10151).
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([
          _owner,
          _ordinaryPeer,
          _protectedPeer,
        ]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
        expect(await repository.getConversation(conversationId), isNull);
      });

      test('excludes self, so a protected account can clear its own '
          'threads', () async {
        // Signed in AS the protected identity: its own threads stay removable.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
          owner: _protectedPeer,
        );
        final conversationId = await seedConversation([
          _protectedPeer,
          _ordinaryPeer,
        ], owner: _protectedPeer);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
      });

      test('fails open for a conversation that is not on disk', () async {
        // A stale id must never become an undeletable row.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );

        final outcome = await repository.removeConversation('no-such-id');

        expect(outcome, equals(ConversationRemovalOutcome.removed));
      });

      test('removes a protected peer when no policy is injected', () async {
        // The default is permissive, so a fixture wiring nothing behaves
        // exactly as it did before the policy existed.
        final repository = buildRepository();
        final conversationId = await seedConversation([_owner, _protectedPeer]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
        expect(await repository.getConversation(conversationId), isNull);
      });
    });

    group('removeConversations', () {
      test('sweeps the ordinary rows and keeps the protected one', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);
        final ordinaryId = await seedConversation([_owner, _ordinaryPeer]);
        final otherId = await seedConversation([_owner, _otherPeer]);
        const missingId = 'missing-conversation';

        final outcome = await repository.removeConversations([
          protectedId,
          ordinaryId,
          otherId,
          missingId,
        ]);

        expect(outcome.removed, equals(2));
        expect(outcome.refused, equals(1));
        expect(await repository.getConversation(protectedId), isNotNull);
        expect(await repository.getConversation(ordinaryId), isNull);
        expect(await repository.getConversation(otherId), isNull);
      });

      test('removes a group that includes a protected peer and keeps the '
          'protected one-to-one', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);
        final groupId = await seedConversation([
          _owner,
          _protectedPeer,
          _ordinaryPeer,
        ]);

        final outcome = await repository.removeConversations([
          protectedId,
          groupId,
        ]);

        expect(outcome.removed, equals(1));
        expect(outcome.refused, equals(1));
        expect(await repository.getConversation(protectedId), isNotNull);
        expect(await repository.getConversation(groupId), isNull);
      });

      test('reports the refusal when every row is protected', () async {
        // The path that read as a broken button before #8347: nothing to
        // remove, so the caller needs a signal rather than silence.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);

        final outcome = await repository.removeConversations([protectedId]);

        expect(outcome.removed, equals(0));
        expect(outcome.refused, equals(1));
        expect(await repository.getConversation(protectedId), isNotNull);
      });

      test('returns zero counts for an empty list', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );

        final outcome = await repository.removeConversations([]);

        expect(outcome.removed, equals(0));
        expect(outcome.refused, equals(0));
      });
    });

    group('removal tombstones', () {
      Future<int?> tombstoneFor(String conversationId) =>
          db.removedConversationsDao.removedAtFor(
            conversationId: conversationId,
            ownerPubkey: _owner,
          );

      test('records a tombstone for a conversation that IS on disk', () async {
        // The control. Suppression of replayed history is the whole point of
        // the marker, so the absent-row tests below only mean something if
        // this one proves the present-row path still writes it.
        final repository = buildRepository();
        final conversationId = await seedConversation([_owner, _ordinaryPeer]);

        await repository.removeConversation(conversationId);

        expect(await tombstoneFor(conversationId), isNotNull);
      });

      test(
        'writes NO tombstone for a conversation that is not on disk',
        () async {
          // #7850. The guard fails open on a missing row so a stale id never
          // becomes undeletable — but the tombstone used to be written anyway,
          // and ingest drops every message at or before `removedAt`. A
          // moderation notice's created_at is always in the past, so one marker
          // for an id this device never held suppressed that notice on every
          // future relay replay, permanently and silently.
          //
          // Nothing local was removed, so there is no local history to
          // suppress.
          final repository = buildRepository(
            removalPolicy: _protectsTheProtectedPeer,
          );
          const absentId = 'conversation-this-device-never-had';

          final outcome = await repository.removeConversation(absentId);

          expect(outcome, equals(ConversationRemovalOutcome.removed));
          expect(await tombstoneFor(absentId), isNull);
        },
      );

      test('writes no tombstone for the absent members of a batch', () async {
        // `removeConversations` collects ids when the list renders and acts on
        // them later, so a row that disappears in between reaches the batch
        // absent. That is the reachable form of the single-path bug above.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final ordinaryId = await seedConversation([_owner, _ordinaryPeer]);
        const absentId = 'vanished-between-render-and-tap';

        final outcome = await repository.removeConversations([
          ordinaryId,
          absentId,
        ]);

        expect(outcome.removed, equals(1));
        expect(outcome.refused, equals(0));
        expect(await tombstoneFor(ordinaryId), isNotNull);
        expect(await tombstoneFor(absentId), isNull);
      });

      test('writes no tombstone for a refused conversation', () async {
        // A refusal deletes nothing, so it must also suppress nothing.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);

        await repository.removeConversation(protectedId);

        expect(await tombstoneFor(protectedId), isNull);
      });
    });

    group('isRemovalProtected', () {
      test('answers for a peer the policy protects', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _protectedPeer]);
        final conversation = await repository.getConversation(conversationId);

        expect(repository.isRemovalProtected(conversation!), isTrue);
      });

      test('answers false for an ordinary peer', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _ordinaryPeer]);
        final conversation = await repository.getConversation(conversationId);

        expect(repository.isRemovalProtected(conversation!), isFalse);
      });

      test('answers for a one-to-one while no account is signed in', () {
        // No self to exclude, so "exactly one other member" would see two
        // and drop the protection; two distinct members is still a one-to-one.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
          owner: '',
        );
        final conversation = DmConversation(
          id: DmRepository.computeConversationId([_owner, _protectedPeer]),
          participantPubkeys: const [_owner, _protectedPeer],
          isGroup: false,
          createdAt: 1700000000,
        );

        expect(repository.isRemovalProtected(conversation), isTrue);
      });

      test('answers false for a group that includes a protected peer, '
          'wherever it sorts', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedFirstId = await seedConversation([
          _owner,
          _protectedPeer,
          _ordinaryPeer,
        ]);
        final protectedSecondId = await seedConversation([
          _owner,
          _earlyPeer,
          _protectedPeer,
        ]);
        final protectedFirst = await repository.getConversation(
          protectedFirstId,
        );
        final protectedSecond = await repository.getConversation(
          protectedSecondId,
        );

        expect(
          protectedFirst!.participantPubkeys,
          containsAllInOrder([_owner, _protectedPeer, _ordinaryPeer]),
        );
        expect(
          protectedSecond!.participantPubkeys,
          containsAllInOrder([_owner, _earlyPeer, _protectedPeer]),
        );
        expect(repository.isRemovalProtected(protectedFirst), isFalse);
        expect(repository.isRemovalProtected(protectedSecond), isFalse);
      });
    });

    // Real gift wraps through the real receive path: the room's membership is
    // whatever its author put in the p tags, which is the point under test.
    group('on the receive path', () {
      late _MockNostrClient nostrClient;
      late StreamController<Event> relay;
      late DmRepository repository;

      setUpAll(() {
        // queryEventsDetailed takes a `Duration timeout`, so a stub matching
        // on it needs a fallback (#8212).
        registerFallbackValue(Duration.zero);
      });

      setUp(() async {
        nostrClient = _MockNostrClient();
        relay = StreamController<Event>();
        when(() => nostrClient.connectedRelayCount).thenReturn(1);
        when(() => nostrClient.configuredRelayCount).thenReturn(1);
        // The own kind-10050 resolve, answered and empty.
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
          (_) async => (
            events: const <Event>[],
            timedOut: false,
            noRelays: false,
          ),
        );
        when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) => relay.stream);

        repository = DmRepository(
          nostrClient: nostrClient,
          directMessagesDao: messagesDao,
          conversationsDao: conversationsDao,
          processedGiftWrapsDao: ProcessedGiftWrapsDao(db),
          removedConversationsDao: db.removedConversationsDao,
          userPubkey: _receiver,
          signer: LocalNostrSigner(_receiverSecret),
          receivesPeerRooms: () => true,
          removalPolicy: (pubkeyHex) => pubkeyHex == _protectedAuthor,
        );
        await repository.startListening();
      });

      tearDown(() async {
        // stopListening() before closing the stream: onDone would otherwise
        // arm a reconnect timer that outlives this test.
        await repository.stopListening();
        await relay.close();
      });

      /// Completes once the receive path has stored the gift wrap [id] as a
      /// message or recorded it in the processed ledger.
      Future<void> settled(String id) => db
          .customSelect(
            '''
            SELECT EXISTS (
              SELECT 1 FROM direct_messages WHERE gift_wrap_id = ?1
            ) OR EXISTS (
              SELECT 1 FROM processed_gift_wraps WHERE gift_wrap_id = ?1
            ) AS settled
            ''',
            variables: [Variable.withString(id)],
            readsFrom: {db.directMessages, db.processedGiftWraps},
          )
          .watchSingle()
          .firstWhere((row) => row.read<bool>('settled'))
          .timeout(
            _settleTimeout,
            onTimeout: () => fail('gift wrap $id was never settled'),
          );

      /// Seals a kind-14 rumor by the holder of [authorSecret], naming
      /// [pTags], gift-wraps it to the receiver and waits for it to settle.
      Future<void> deliver({
        required String authorSecret,
        required List<String> pTags,
      }) async {
        final rumor = Event(
          getPublicKey(authorSecret),
          EventKind.privateDirectMessage,
          [
            for (final pubkey in pTags) ['p', pubkey],
          ],
          'a message',
          createdAt: 1700000000,
        );
        final wrap = await buildGiftWrapFromHex(
          senderPrivateKeyHex: authorSecret,
          rumorJson: rumor.toJson(),
          receiverPublicKey: _receiver,
        );
        relay.add(wrap!);
        await settled(wrap.id);
      }

      test('removes a room a stranger opened with a protected account in '
          'it', () async {
        await deliver(
          authorSecret: _strangerSecret,
          pTags: [_receiver, _protectedAuthor],
        );
        final roomId = DmRepository.computeConversationId([
          _receiver,
          _stranger,
          _protectedAuthor,
        ]);
        final room = await repository.getConversation(roomId);
        expect(room?.isGroup, isTrue);

        final outcome = await repository.removeConversation(roomId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
        expect(await repository.getConversation(roomId), isNull);
      });

      test("still refuses the protected account's own one-to-one", () async {
        await deliver(
          authorSecret: _protectedAuthorSecret,
          pTags: [_receiver],
        );
        final oneToOneId = DmRepository.computeConversationId([
          _receiver,
          _protectedAuthor,
        ]);
        expect(await repository.getConversation(oneToOneId), isNotNull);

        final outcome = await repository.removeConversation(oneToOneId);

        expect(outcome, equals(ConversationRemovalOutcome.refused));
        expect(await repository.getConversation(oneToOneId), isNotNull);
      });
    });
  });
}
