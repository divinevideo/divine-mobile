// ABOUTME: Reproduction harness for #8407 — drives the historical startup dedup
// ABOUTME: pass against a real Drift DB to prove the damage and test recovery.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = '1111111111111111111111111111111111111111111111111111111111111111';
const _alice =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _carol =
    '4444444444444444444444444444444444444444444444444444444444444444';
const _dave =
    '5555555555555555555555555555555555555555555555555555555555555555';
const _bob = '3333333333333333333333333333333333333333333333333333333333333333';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockMessageService extends Mock implements NIP17MessageService {}

class _MockSigner extends Mock implements NostrSigner {}

class _MockReactionsRepository extends Mock implements DmReactionsRepository {}

void main() {
  group('#8407 reproduction', () {
    late AppDatabase db;
    late ConversationsDao conversations;
    late DirectMessagesDao messages;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      conversations = ConversationsDao(db);
      messages = DirectMessagesDao(db);
    });

    tearDown(() => db.close());

    // Verbatim replica of the DAO method PR #8401 deleted. It wrote exactly
    // one column, which is the whole reason tags_json survived the damage.
    Future<int> reassignConversation({
      required String fromConversationId,
      required String toConversationId,
    }) {
      return (db.update(db.directMessages)..where(
            (t) =>
                t.conversationId.equals(fromConversationId) &
                (t.ownerPubkey.equals(_me) |
                    t.ownerPubkey.isNull() |
                    t.ownerPubkey.equals('')),
          ))
          .write(
            DirectMessagesCompanion(conversationId: Value(toConversationId)),
          );
    }

    // Verbatim replica of _mergeDuplicateConversations as it stood at
    // 4efe1ea53b^ (the commit PR #8401 deleted it in).
    Future<void> runHistoricalPass() async {
      final all = await conversations.getAllConversations(ownerPubkey: _me);
      final peerGroups = <String, List<ConversationRow>>{};
      for (final conv in all) {
        final participants = (jsonDecode(conv.participantPubkeys) as List)
            .cast<String>();
        final peers = participants.where((pk) => pk != _me).toList()..sort();
        if (peers.isEmpty) continue;
        peerGroups.putIfAbsent(peers.first, () => []).add(conv);
      }
      for (final entry in peerGroups.entries) {
        if (entry.value.length <= 1) continue;
        final canonicalParticipants = [_me, entry.key]..sort();
        final canonicalId = DmRepository.computeConversationId(
          canonicalParticipants,
        );
        final hasCanonicalRow = entry.value.any((c) => c.id == canonicalId);
        await conversations.runInTransaction(() async {
          for (final conv in entry.value) {
            if (conv.id == canonicalId) continue;
            await reassignConversation(
              fromConversationId: conv.id,
              toConversationId: canonicalId,
            );
            await conversations.deleteConversation(conv.id, ownerPubkey: _me);
          }
          if (!hasCanonicalRow) {
            final source = entry.value.first;
            await conversations.upsertConversation(
              id: canonicalId,
              participantPubkeys: jsonEncode(canonicalParticipants),
              isGroup: false,
              createdAt: source.createdAt,
              ownerPubkey: source.ownerPubkey,
            );
          }
        });
      }
    }

    Future<String> seedConversation(
      List<String> participants, {
      int createdAt = 1700000000,
      String? dmProtocol,
    }) async {
      final id = DmRepository.computeConversationId(participants);
      await conversations.upsertConversation(
        id: id,
        participantPubkeys: jsonEncode(List<String>.from(participants)..sort()),
        isGroup: participants.length > 2,
        createdAt: createdAt,
        ownerPubkey: _me,
        dmProtocol: dmProtocol,
      );
      return id;
    }

    Future<void> seedMessage({
      required String id,
      required String conversationId,
      required String sender,
      required List<String> pTags,
      String? subject,
      String? replyToId,
      int createdAt = 1700000001,
    }) async {
      await messages.insertMessage(
        id: id,
        conversationId: conversationId,
        senderPubkey: sender,
        content: 'msg $id',
        createdAt: createdAt,
        giftWrapId: 'wrap_$id',
        ownerPubkey: _me,
        subject: subject,
        replyToId: replyToId,
        tagsJson: jsonEncode([
          for (final pk in pTags) ['p', pk],
          if (replyToId != null) ['e', replyToId],
          if (subject != null) ['subject', subject],
        ]),
      );
    }

    test(
      'REPRO A: the pass deletes the group row and re-parents its messages',
      () async {
        // A genuine 3-person room. buildGroupRumor omits the sender's own
        // pubkey from the p tags, so each message names the OTHER recipients.
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'g1',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          subject: 'Weekend trip',
        );
        await seedMessage(
          id: 'g2',
          conversationId: groupId,
          sender: _bob,
          pTags: [_me, _alice],
          subject: 'Weekend trip',
        );

        // A separate 1:1 whose peer is the group's alphabetically-first peer.
        final oneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'd1',
          conversationId: oneToOneId,
          sender: _alice,
          pTags: [_me],
        );

        await runHistoricalPass();

        expect(
          await conversations.getConversation(groupId, ownerPubkey: _me),
          isNull,
          reason: 'the group conversation row is destroyed',
        );
        final survivor = await conversations.getConversation(
          oneToOneId,
          ownerPubkey: _me,
        );
        expect(survivor, isNotNull);
        expect(
          (jsonDecode(survivor!.participantPubkeys) as List).cast<String>(),
          equals([_me, _alice]..sort()),
          reason: 'Bob is erased from the surviving row',
        );

        final reparented = await messages.getMessagesForConversation(
          oneToOneId,
          ownerPubkey: _me,
        );
        expect(
          reparented.map((m) => m.id).toSet(),
          equals({'g1', 'g2', 'd1'}),
          reason: 'the group messages are moved, not deleted',
        );
      },
    );

    test(
      'REPRO B: tags_json survives, so participants are reconstructible',
      () async {
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'g1',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          subject: 'Weekend trip',
        );
        final oneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'd1',
          conversationId: oneToOneId,
          sender: _alice,
          pTags: [_me],
        );

        await runHistoricalPass();

        final rows = await messages.getMessagesForConversation(
          oneToOneId,
          ownerPubkey: _me,
        );
        final byId = {for (final r in rows) r.id: r};

        // participants = p tags ∪ senderPubkey
        Set<String> reconstruct(DirectMessageRow row) {
          final tags = (jsonDecode(row.tagsJson!) as List)
              .cast<List<dynamic>>();
          return {
            for (final t in tags)
              if (t.isNotEmpty && t.first == 'p') t[1] as String,
            row.senderPubkey,
          };
        }

        expect(
          reconstruct(byId['g1']!),
          equals({_me, _alice, _bob}),
          reason:
              'the destroyed room is fully reconstructible from one message',
        );
        expect(byId['g1']!.subject, equals('Weekend trip'));
        // The 1:1's own message reconstructs to exactly the 1:1.
        expect(reconstruct(byId['d1']!), equals({_me, _alice}));
      },
    );

    // Faithful pre-#2741 ingest: participants = sender + p tags, so the
    // plain message and the mention-bearing message land in DIFFERENT
    // conversation rows. NIP-17 agrees — "if a new p tag is added ... a new
    // room is created with a clean message history".
    test('REPRO C: an inflated 1:1, ingested and damaged faithfully', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'i1',
        conversationId: oneToOneId,
        sender: _alice,
        pTags: [_me],
      );
      final inflatedId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'i2',
        conversationId: inflatedId,
        sender: _alice,
        pTags: [_me, _bob], // a reply that merely mentions Bob
        createdAt: 1700000002,
      );

      await runHistoricalPass();

      expect(
        await conversations.getConversation(inflatedId, ownerPubkey: _me),
        isNull,
      );
      final rows = await messages.getMessagesForConversation(
        oneToOneId,
        ownerPubkey: _me,
      );
      expect(
        {for (final r in rows) r.id: _reconstruct(r)},
        equals({
          'i1': {_me, _alice},
          'i2': {_me, _alice, _bob},
        }),
      );
    });

    test(
      'REPRO D: a real group with a SILENT member is byte-identical to C',
      () async {
        // Bob is a genuine member who never sends anything.
        final oneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'i1',
          conversationId: oneToOneId,
          sender: _alice,
          pTags: [_me],
        );
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'i2',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          createdAt: 1700000002,
        );

        await runHistoricalPass();

        final rows = await messages.getMessagesForConversation(
          oneToOneId,
          ownerPubkey: _me,
        );
        // Identical to REPRO C's post-damage state in every observable column.
        expect(
          {for (final r in rows) r.id: _reconstruct(r)},
          equals({
            'i1': {_me, _alice},
            'i2': {_me, _alice, _bob},
          }),
        );
        expect(
          rows.map((r) => r.senderPubkey).toSet(),
          equals({_alice}),
          reason: 'sender-count (#5478) cannot separate C from D either',
        );
      },
    );

    test(
      'REPRO E: the damage signature is detectable by a read-only query',
      () async {
        // Damaged: a real group folded into the 1:1 with its first peer.
        final damagedId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'd1',
          conversationId: damagedId,
          sender: _alice,
          pTags: [_me],
        );
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'g1',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          subject: 'Weekend trip',
        );
        await seedMessage(
          id: 'g2',
          conversationId: groupId,
          sender: _bob,
          pTags: [_me, _alice],
          createdAt: 1700000003,
        );

        // Undamaged control: an ordinary 1:1 that must NOT be flagged.
        final cleanId = await seedConversation([_me, _carol]);
        await seedMessage(
          id: 'c1',
          conversationId: cleanId,
          sender: _carol,
          pTags: [_me],
        );

        await runHistoricalPass();

        // --- the detection query, as a recovery pass would run it ---
        // Canonicalise as a sorted join: Dart `Set` has no value equality, so
        // a Set<Set<String>> never dedupes two equal participant sets. A real
        // recovery pass has to key on the canonical string for the same reason.
        final flagged = <String, Set<String>>{};
        for (final conv in await conversations.getAllConversations(
          ownerPubkey: _me,
        )) {
          final declared = (jsonDecode(conv.participantPubkeys) as List)
              .cast<String>()
              .toSet();
          if (conv.isGroup || declared.length != 2) continue;
          final rows = await messages.getMessagesForConversation(
            conv.id,
            ownerPubkey: _me,
          );
          final foreign = <String>{};
          for (final row in rows) {
            if (row.tagsJson == null) continue;
            final recon = _reconstruct(row);
            if (recon.difference(declared).isNotEmpty) {
              foreign.add((recon.toList()..sort()).join(','));
            }
          }
          if (foreign.isNotEmpty) flagged[conv.id] = foreign;
        }

        expect(
          flagged.keys.toSet(),
          equals({damagedId}),
          reason: 'flags the damaged 1:1 and nothing else',
        );
        expect(
          flagged[damagedId],
          equals({
            ([_me, _alice, _bob]..sort()).join(','),
          }),
          reason: 'and names exactly the room that was destroyed',
        );
        expect(flagged.containsKey(cleanId), isFalse);
      },
    );

    // #2740 names the real-world cause of an inflated 1:1 precisely:
    // "NIP-10 reply mentions". A reply carries an `e` tag, and `tags_json`
    // stores rumor.tags verbatim, so the `e` tag survived the damage too.
    test('REPRO F: the e-tag separates the realistic C from D', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'i1',
        conversationId: oneToOneId,
        sender: _alice,
        pTags: [_me],
      );
      // Inflated: a REPLY to the 1:1 message that merely mentions Bob.
      final inflatedId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'i2',
        conversationId: inflatedId,
        sender: _alice,
        pTags: [_me, _bob],
        replyToId: 'i1',
        createdAt: 1700000002,
      );

      // A genuine group in a SEPARATE thread, Bob silent, own reply chain.
      final carolOneToOne = await seedConversation([_me, _carol]);
      await seedMessage(
        id: 'c1',
        conversationId: carolOneToOne,
        sender: _carol,
        pTags: [_me],
      );
      final groupId = await seedConversation([_me, _carol, _bob]);
      await seedMessage(
        id: 'g1',
        conversationId: groupId,
        sender: _carol,
        pTags: [_me, _bob],
        subject: 'Weekend trip',
        createdAt: 1700000002,
      );
      await seedMessage(
        id: 'g2',
        conversationId: groupId,
        sender: _carol,
        pTags: [_me, _bob],
        replyToId: 'g1',
        createdAt: 1700000003,
      );

      await runHistoricalPass();

      Future<bool> looksInflated(String convId) async {
        final rows = await messages.getMessagesForConversation(
          convId,
          ownerPubkey: _me,
        );
        final recon = {for (final r in rows) r.id: _reconstruct(r)};
        final parent = {for (final r in rows) r.id: r.replyToId};
        for (final entry in recon.entries) {
          final p = parent[entry.key];
          if (p == null) continue;
          final parentRecon = recon[p];
          if (parentRecon == null) continue;
          // A widened message whose reply-parent is a strictly smaller room
          // is a mention, not a membership.
          if (entry.value.length > parentRecon.length &&
              parentRecon.every(entry.value.contains)) {
            return true;
          }
        }
        return false;
      }

      expect(
        await looksInflated(oneToOneId),
        isTrue,
        reason: 'i2 replies to i1 and adds a p tag => mention, not membership',
      );
      expect(
        await looksInflated(carolOneToOne),
        isFalse,
        reason: 'g2 replies to g1 within the same room => genuine group',
      );
    });

    // ---------------------------------------------------------------------
    // The fix: the recovery pass, driven through real production wiring.
    // ---------------------------------------------------------------------

    Future<DmRepository> recoverViaSetCredentials({
      DmSyncState? syncState,
      DmReactionsRepository? reactionsRepository,
    }) async {
      final nostrClient = _MockNostrClient();
      when(() => nostrClient.connectedRelayCount).thenReturn(1);
      when(() => nostrClient.configuredRelayCount).thenReturn(1);
      final repository =
          DmRepository(
            nostrClient: nostrClient,
            directMessagesDao: messages,
            conversationsDao: conversations,
            removedConversationsDao: db.removedConversationsDao,
            syncState: syncState,
            reactionsRepository:
                reactionsRepository ??
                DmReactionsRepository(
                  reactionsDao: db.dmReactionsDao,
                  conversationsDao: conversations,
                  directMessagesDao: messages,
                  userPubkey: _me,
                ),
          )..setCredentials(
            userPubkey: _me,
            signer: _MockSigner(),
            messageService: _MockMessageService(),
          );
      // getConversations awaits post-auth maintenance, which is where the
      // recovery pass runs.
      await repository.getConversations();
      return repository;
    }

    test(
      'restores an attested group and moves only its own messages',
      () async {
        final oneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'd1',
          conversationId: oneToOneId,
          sender: _alice,
          pTags: [_me],
        );
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'g1',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          subject: 'Weekend trip',
          createdAt: 1700000002,
        );
        await seedMessage(
          id: 'g2',
          conversationId: groupId,
          sender: _bob,
          pTags: [_me, _alice],
          createdAt: 1700000003,
        );

        await runHistoricalPass();
        expect(
          await conversations.getConversation(groupId, ownerPubkey: _me),
          isNull,
        );

        await recoverViaSetCredentials();

        final restored = await conversations.getConversation(
          groupId,
          ownerPubkey: _me,
        );
        expect(restored, isNotNull, reason: 'the group row is back');
        expect(restored!.isGroup, isTrue);
        expect(
          (jsonDecode(restored.participantPubkeys) as List).cast<String>(),
          equals([_me, _alice, _bob]..sort()),
          reason: 'Bob is restored',
        );
        expect(restored.subject, equals('Weekend trip'));

        expect(
          (await messages.getMessagesForConversation(
            groupId,
            ownerPubkey: _me,
          )).map((m) => m.id).toSet(),
          equals({'g1', 'g2'}),
        );
        expect(
          (await messages.getMessagesForConversation(
            oneToOneId,
            ownerPubkey: _me,
          )).map((m) => m.id).toSet(),
          equals({'d1'}),
          reason: "the 1:1's own message stays put",
        );
      },
    );

    test(
      'moves a post-damage fork after another 1:1 attests the room',
      () async {
        final aliceOneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'd1',
          conversationId: aliceOneToOneId,
          sender: _alice,
          pTags: [_me],
        );
        final bobOneToOneId = await seedConversation([_me, _bob]);
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'g1',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          createdAt: 1700000002,
        );
        await seedMessage(
          id: 'g2',
          conversationId: groupId,
          sender: _bob,
          pTags: [_me, _alice],
          createdAt: 1700000003,
        );

        await runHistoricalPass();
        await seedMessage(
          id: 'post-damage-bob',
          conversationId: bobOneToOneId,
          sender: _bob,
          pTags: [_me, _alice],
          createdAt: 1700000004,
        );

        await recoverViaSetCredentials();

        expect(
          (await messages.getMessagesForConversation(
            groupId,
            ownerPubkey: _me,
          )).map((m) => m.id).toSet(),
          equals({'g1', 'g2', 'post-damage-bob'}),
          reason:
              'the room restored from the Alice 1:1 attests the same room '
              'named by the single-sender fork in the Bob 1:1',
        );
        expect(
          await messages.getMessagesForConversation(
            bobOneToOneId,
            ownerPubkey: _me,
          ),
          isEmpty,
        );
      },
    );

    test('keeps the reply-mention veto during the second sweep', () async {
      final aliceOneToOneId = await seedConversation([_me, _alice]);
      final bobOneToOneId = await seedConversation([_me, _bob]);
      final groupId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'g1',
        conversationId: groupId,
        sender: _alice,
        pTags: [_me, _bob],
        createdAt: 1700000002,
      );
      await seedMessage(
        id: 'g2',
        conversationId: groupId,
        sender: _bob,
        pTags: [_me, _alice],
        createdAt: 1700000003,
      );
      await seedMessage(
        id: 'n1',
        conversationId: bobOneToOneId,
        sender: _bob,
        pTags: [_me],
        createdAt: 1700000004,
      );

      await runHistoricalPass();
      await seedMessage(
        id: 'n2',
        conversationId: bobOneToOneId,
        sender: _bob,
        pTags: [_me, _alice],
        replyToId: 'n1',
        createdAt: 1700000005,
      );

      await recoverViaSetCredentials();

      expect(
        (await messages.getMessagesForConversation(
          groupId,
          ownerPubkey: _me,
        )).map((m) => m.id).toSet(),
        equals({'g1', 'g2'}),
        reason: 'attestation must not override the reply-mention veto',
      );
      expect(
        (await messages.getMessagesForConversation(
          bobOneToOneId,
          ownerPubkey: _me,
        )).map((m) => m.id).toSet(),
        equals({'n1', 'n2'}),
        reason: 'the mention stays in the healthy 1:1 where the user saw it',
      );
      expect(
        await conversations.getConversation(
          aliceOneToOneId,
          ownerPubkey: _me,
        ),
        isNotNull,
      );
    });

    test('a malformed conversation does not block later recovery', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      final groupId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'g1',
        conversationId: groupId,
        sender: _alice,
        pTags: [_me, _bob],
        createdAt: 1700000002,
      );
      await seedMessage(
        id: 'g2',
        conversationId: groupId,
        sender: _bob,
        pTags: [_me, _alice],
        createdAt: 1700000003,
      );

      await runHistoricalPass();
      await conversations.upsertConversation(
        id: 'malformed',
        participantPubkeys: '{not json',
        isGroup: false,
        createdAt: 1700000000,
        lastMessageTimestamp: 1700000010,
        ownerPubkey: _me,
      );
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final syncState = DmSyncState(await SharedPreferences.getInstance());
      try {
        await recoverViaSetCredentials(syncState: syncState);
      } on FormatException {
        // Rendering the deliberately corrupt row is outside this recovery
        // pass. The maintenance work must still continue past it.
      }

      expect(
        await conversations.getConversation(groupId, ownerPubkey: _me),
        isNotNull,
        reason: 'one malformed row must not abort recovery for the account',
      );
      expect(
        syncState.groupRecoveryVersion(_me),
        DmSyncState.currentGroupRecoveryVersion,
        reason: 'the malformed row must not force this pass on every launch',
      );
      expect(
        (await messages.getMessagesForConversation(
          oneToOneId,
          ownerPubkey: _me,
        )).map((m) => m.id),
        isEmpty,
      );
    });

    test('a failed room does not block recovery of later rooms', () async {
      final failedGroupId = await seedConversation([_me, _alice, _bob]);
      await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'failed-g1',
        conversationId: failedGroupId,
        sender: _alice,
        pTags: [_me, _bob],
      );
      await seedMessage(
        id: 'failed-g2',
        conversationId: failedGroupId,
        sender: _bob,
        pTags: [_me, _alice],
      );

      final restoredGroupId = await seedConversation([_me, _carol, _dave]);
      await seedConversation([_me, _carol]);
      await seedMessage(
        id: 'restored-g1',
        conversationId: restoredGroupId,
        sender: _carol,
        pTags: [_me, _dave],
      );
      await seedMessage(
        id: 'restored-g2',
        conversationId: restoredGroupId,
        sender: _dave,
        pTags: [_me, _carol],
      );

      await runHistoricalPass();
      final reactionsRepository = _MockReactionsRepository();
      when(
        () => reactionsRepository.purgeStrandedByRemoval(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => reactionsRepository.backfillQueuedRecipients(
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => reactionsRepository.reassignForMovedMessages(
          targetMessageIds: any(named: 'targetMessageIds'),
          toConversationId: any(named: 'toConversationId'),
          ownerPubkey: any(named: 'ownerPubkey'),
        ),
      ).thenAnswer((invocation) async {
        final ids =
            invocation.namedArguments[#targetMessageIds]! as Iterable<String>;
        if (ids.contains('failed-g1')) throw StateError('injected failure');
        return 0;
      });
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final syncState = DmSyncState(await SharedPreferences.getInstance());

      await recoverViaSetCredentials(
        syncState: syncState,
        reactionsRepository: reactionsRepository,
      );

      expect(
        await conversations.getConversation(failedGroupId, ownerPubkey: _me),
        isNull,
      );
      expect(
        await conversations.getConversation(restoredGroupId, ownerPubkey: _me),
        isNotNull,
        reason: 'a failure in another conversation must not abort this room',
      );
      expect(
        syncState.groupRecoveryVersion(_me),
        0,
        reason: 'the failed room must remain eligible for a later retry',
      );
    });

    test(
      'derives group creation and protocol from the recovered room',
      () async {
        final oneToOneId = await seedConversation(
          [_me, _alice],
          createdAt: 1600000000,
          dmProtocol: 'nip04',
        );
        final groupId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'g1',
          conversationId: groupId,
          sender: _alice,
          pTags: [_me, _bob],
          createdAt: 1700000002,
        );
        await seedMessage(
          id: 'g2',
          conversationId: groupId,
          sender: _bob,
          pTags: [_me, _alice],
          createdAt: 1700000003,
        );

        await runHistoricalPass();
        await recoverViaSetCredentials();

        final restored = await conversations.getConversation(
          groupId,
          ownerPubkey: _me,
        );
        expect(restored, isNotNull);
        expect(restored!.createdAt, equals(1700000002));
        expect(restored.dmProtocol, equals('nip17'));
        expect(
          await conversations.getConversation(oneToOneId, ownerPubkey: _me),
          isNotNull,
        );
      },
    );

    test('leaves the unattested reply-mention shape alone', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'i1',
        conversationId: oneToOneId,
        sender: _alice,
        pTags: [_me],
      );
      final inflatedId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'i2',
        conversationId: inflatedId,
        sender: _alice,
        pTags: [_me, _bob],
        replyToId: 'i1',
        createdAt: 1700000002,
      );

      await runHistoricalPass();
      await recoverViaSetCredentials();

      expect(
        await conversations.getConversation(inflatedId, ownerPubkey: _me),
        isNull,
        reason: 'recovering this would resurrect the phantom #2741 removed',
      );
      expect(
        (await messages.getMessagesForConversation(
          oneToOneId,
          ownerPubkey: _me,
        )).map((m) => m.id).toSet(),
        equals({'i1', 'i2'}),
      );
    });

    test(
      'leaves a single-sender widened room alone (no e tag to veto on)',
      () async {
        // The widening message is NOT a reply, so the e-tag veto cannot
        // fire and the sender count is the only guard. Indistinguishable
        // from a real group whose other member never spoke, so the pass
        // declines to guess.
        final oneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'd1',
          conversationId: oneToOneId,
          sender: _alice,
          pTags: [_me],
        );
        final widenedId = await seedConversation([_me, _alice, _bob]);
        await seedMessage(
          id: 'w1',
          conversationId: widenedId,
          sender: _alice,
          pTags: [_me, _bob],
          createdAt: 1700000002,
        );

        await runHistoricalPass();
        await recoverViaSetCredentials();

        expect(
          await conversations.getConversation(widenedId, ownerPubkey: _me),
          isNull,
          reason:
              'one sender is not evidence of a room; restoring would risk '
              'a phantom conversation',
        );
        expect(
          (await messages.getMessagesForConversation(
            oneToOneId,
            ownerPubkey: _me,
          )).map((m) => m.id).toSet(),
          equals({'d1', 'w1'}),
          reason: 'and the messages stay exactly where the user sees them',
        );
      },
    );

    test('respects a removal tombstone for the reconstructed room', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'd1',
        conversationId: oneToOneId,
        sender: _alice,
        pTags: [_me],
      );
      final groupId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'g1',
        conversationId: groupId,
        sender: _alice,
        pTags: [_me, _bob],
        createdAt: 1700000002,
      );
      await seedMessage(
        id: 'g2',
        conversationId: groupId,
        sender: _bob,
        pTags: [_me, _alice],
        createdAt: 1700000003,
      );
      await db.removedConversationsDao.record(
        conversationId: groupId,
        ownerPubkey: _me,
        removedAt: 1700000009,
      );

      await runHistoricalPass();
      await recoverViaSetCredentials();

      expect(
        await conversations.getConversation(groupId, ownerPubkey: _me),
        isNull,
        reason: '#7811 — a deliberately removed room must not come back',
      );
    });

    test('is idempotent across a second run', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'd1',
        conversationId: oneToOneId,
        sender: _alice,
        pTags: [_me],
      );
      final groupId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'g1',
        conversationId: groupId,
        sender: _alice,
        pTags: [_me, _bob],
        createdAt: 1700000002,
      );
      await seedMessage(
        id: 'g2',
        conversationId: groupId,
        sender: _bob,
        pTags: [_me, _alice],
        createdAt: 1700000003,
      );

      await runHistoricalPass();
      await recoverViaSetCredentials();
      await recoverViaSetCredentials();

      expect(
        (await conversations.getAllConversations(
          ownerPubkey: _me,
        )).map((c) => c.id).toList()..sort(),
        equals([groupId, oneToOneId]..sort()),
        reason: 'no extra rows on a second pass',
      );
    });

    test('carries a reaction across with its target message', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await seedMessage(
        id: 'd1',
        conversationId: oneToOneId,
        sender: _alice,
        pTags: [_me],
      );
      final groupId = await seedConversation([_me, _alice, _bob]);
      await seedMessage(
        id: 'g1',
        conversationId: groupId,
        sender: _alice,
        pTags: [_me, _bob],
        createdAt: 1700000002,
      );
      await seedMessage(
        id: 'g2',
        conversationId: groupId,
        sender: _bob,
        pTags: [_me, _alice],
        createdAt: 1700000003,
      );

      await runHistoricalPass();
      // The historical pass moved the message but left the reaction keyed on
      // the 1:1 it was re-parented into, and queued for that 1:1 alone.
      await db.dmReactionsDao.insertOwnReactionSuperseding(
        placeholderId: 'r1',
        conversationId: oneToOneId,
        targetMessageId: 'g1',
        targetMessageAuthor: _alice,
        reactorPubkey: _me,
        emoji: '🔥',
        createdAt: 1700000004,
        ownerPubkey: _me,
        rumorEventJson: '{}',
        recipientPubkeys: jsonEncode([_alice]),
      );

      await recoverViaSetCredentials();

      final reaction = await (db.select(
        db.dmMessageReactions,
      )..where((t) => t.id.equals('r1'))).getSingle();
      expect(
        reaction.conversationId,
        equals(groupId),
        reason:
            'the render index is (conversation_id, target_message_id), so '
            'a reaction left behind stops rendering on the moved message',
      );
      expect(
        jsonDecode(reaction.recipientPubkeys!),
        unorderedEquals([_alice, _bob]),
        reason:
            'a reaction still waiting to be sent goes to the group it was '
            'moved into, not to the 1:1 it was queued in (#7880)',
      );
    });

    test('skips a row whose tags_json is null (legacy ADD COLUMN)', () async {
      final oneToOneId = await seedConversation([_me, _alice]);
      await messages.insertMessage(
        id: 'legacy',
        conversationId: oneToOneId,
        senderPubkey: _bob,
        content: 'no tags',
        createdAt: 1700000001,
        giftWrapId: 'wrap_legacy',
        ownerPubkey: _me,
      );

      await recoverViaSetCredentials();

      expect(
        (await conversations.getAllConversations(
          ownerPubkey: _me,
        )).map((c) => c.id).toList(),
        equals([oneToOneId]),
        reason: 'a null tags_json row cannot name a room',
      );
    });

    // The recorded version is the cost guard for the full scan: the same
    // attestable split is restored while an older version is recorded, and
    // left alone once the current one is.
    group('recorded recovery version', () {
      /// The one-to-one with Alice holds two senders' messages for the same
      /// wider room, the shape the pass can attest.
      Future<String> seedSplitRoom() async {
        final oneToOneId = await seedConversation([_me, _alice]);
        await seedMessage(
          id: 'split-alice',
          conversationId: oneToOneId,
          sender: _alice,
          pTags: [_me, _bob],
          createdAt: 1700000002,
        );
        await seedMessage(
          id: 'split-me',
          conversationId: oneToOneId,
          sender: _me,
          pTags: [_alice, _bob],
          createdAt: 1700000003,
        );
        return DmRepository.computeConversationId([_me, _alice, _bob]);
      }

      Future<DmSyncState> syncStateRecording(int version) async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final syncState = DmSyncState(await SharedPreferences.getInstance());
        await syncState.setGroupRecoveryVersion(_me, version);
        return syncState;
      }

      test('runs the pass while an older version is recorded', () async {
        final roomId = await seedSplitRoom();
        final syncState = await syncStateRecording(
          DmSyncState.currentGroupRecoveryVersion - 1,
        );

        await recoverViaSetCredentials(syncState: syncState);

        final restored = await conversations.getConversation(
          roomId,
          ownerPubkey: _me,
        );
        expect(restored, isNotNull);
        expect(restored!.isGroup, isTrue);
        expect(
          (await messages.getMessagesForConversation(
            roomId,
            ownerPubkey: _me,
          )).map((m) => m.id).toSet(),
          equals({'split-alice', 'split-me'}),
        );
        expect(
          syncState.groupRecoveryVersion(_me),
          DmSyncState.currentGroupRecoveryVersion,
        );
      });

      test('skips the pass once the current version is recorded', () async {
        final roomId = await seedSplitRoom();
        final syncState = await syncStateRecording(
          DmSyncState.currentGroupRecoveryVersion,
        );

        await recoverViaSetCredentials(syncState: syncState);

        expect(
          await conversations.getConversation(roomId, ownerPubkey: _me),
          isNull,
          reason: 'a recorded current version is the cost guard for the scan',
        );
      });
    });
  });
}

Set<String> _reconstruct(DirectMessageRow row) {
  final tags = (jsonDecode(row.tagsJson!) as List).cast<List<dynamic>>();
  return {
    for (final t in tags)
      if (t.isNotEmpty && t.first == 'p') t[1] as String,
    row.senderPubkey,
  };
}
