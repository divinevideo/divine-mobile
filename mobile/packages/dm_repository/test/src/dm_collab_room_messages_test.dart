// ABOUTME: watchCollabRoomMessages serves both directions of the owner's
// ABOUTME: one-to-one room history and nothing else.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _sam = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _roomId = '0123456789abcdef0123456789abcdef';

void main() {
  group('watchCollabRoomMessages', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
      final conversationId = DmRepository.computeConversationId([
        _author,
        _sam,
      ]);
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: jsonEncode([_author, _sam]),
        isGroup: false,
        createdAt: 1,
        ownerPubkey: _author,
      );
      final join = collabRoomTags(
        roomId: _roomId,
        type: CollabRoomMessageType.join,
        recipientPubkey: _author,
      );
      final invite = collabRoomTags(
        roomId: _roomId,
        type: CollabRoomMessageType.invite,
        recipientPubkey: _sam,
        snapshot: const CollabRoomSnapshot(
          revision: 0,
          phase: CollabRoomPhase.lobby,
          members: [
            CollabRoomMember(
              pubkey: _author,
              status: CollabRoomMemberStatus.joined,
            ),
            CollabRoomMember(
              pubkey: _sam,
              status: CollabRoomMemberStatus.invited,
            ),
          ],
        ),
      );
      for (final (id, sender, tags) in [
        ('invite', _author, invite),
        ('join', _sam, join),
        (
          'sound',
          _sam,
          [
            ['divine', 'sound-request', '1'],
          ],
        ),
        ('chat', _sam, <List<String>>[]),
      ]) {
        await messagesDao.insertMessage(
          id: id,
          conversationId: conversationId,
          senderPubkey: sender,
          content: id,
          createdAt: id == 'invite' ? 1 : 2,
          giftWrapId: 'wrap-$id',
          tagsJson: jsonEncode(tags),
          ownerPubkey: _author,
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    DmRepository repositoryFor(String userPubkey) => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      userPubkey: userPubkey,
    );

    test('returns both directions of the room history, oldest first', () async {
      final messages = await repositoryFor(
        _author,
      ).watchCollabRoomMessages().first;
      expect(messages.map((m) => m.id), ['invite', 'join']);
      expect(messages.first.tags.first, ['divine', 'collab-room', '1']);
    });

    test('returns nothing without an account', () async {
      expect(await repositoryFor('').watchCollabRoomMessages().first, isEmpty);
    });
  });
}
