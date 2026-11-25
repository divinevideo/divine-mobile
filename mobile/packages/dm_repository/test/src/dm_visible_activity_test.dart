// ABOUTME: Real-database coverage for DmRepository.visibleActivityExcluding:
// ABOUTME: what a group's inbox row shows once the senders a viewer hides are
// ABOUTME: set aside (#10150).

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';
const _visibleMember =
    'b1c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0';
const _hiddenMember =
    'c2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8f9a0b1';

const _createdAt = 1700000000;

void main() {
  group('DmRepository.visibleActivityExcluding (#10150)', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;
    final roomId = DmRepository.computeConversationId([
      _owner,
      _visibleMember,
      _hiddenMember,
    ]);

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    DmRepository buildRepository({String userPubkey = _owner}) => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      userPubkey: userPubkey,
    );

    /// Stores the room for [ownerPubkey], its preview on the hidden member's
    /// newest message, as ingest leaves it.
    Future<void> seedRoom({
      String ownerPubkey = _owner,
      bool withVisibleMessage = true,
    }) async {
      await conversationsDao.upsertConversation(
        id: roomId,
        participantPubkeys: '["$_owner","$_visibleMember","$_hiddenMember"]',
        isGroup: true,
        createdAt: _createdAt,
        lastMessageContent: 'from the hidden member',
        lastMessageTimestamp: _createdAt + 200,
        lastMessageSenderPubkey: _hiddenMember,
        isRead: false,
        currentUserHasSent: true,
        ownerPubkey: ownerPubkey,
      );
      if (withVisibleMessage) {
        await messagesDao.insertMessage(
          id: 'visible-$ownerPubkey',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'from the visible member',
          createdAt: _createdAt + 100,
          giftWrapId: 'wrap-visible-$ownerPubkey',
          ownerPubkey: ownerPubkey,
        );
      }
      await messagesDao.insertMessage(
        id: 'hidden-$ownerPubkey',
        conversationId: roomId,
        senderPubkey: _hiddenMember,
        content: 'from the hidden member',
        createdAt: _createdAt + 200,
        giftWrapId: 'wrap-hidden-$ownerPubkey',
        ownerPubkey: ownerPubkey,
      );
    }

    test(
      'legacy identical same-second rows do not borrow a citation',
      () async {
        final repository = buildRepository();
        await repository.getConversation(roomId);
        for (final id in ['first', 'second']) {
          await messagesDao.insertMessage(
            id: id,
            conversationId: roomId,
            senderPubkey: _visibleMember,
            content: 'ambiguous',
            createdAt: _createdAt,
            giftWrapId: 'wrap-$id',
            ownerPubkey: _owner,
            tagsJson: id == 'second'
                ? '[["q","34236:$_owner:clip","","$_owner"]]'
                : null,
          );
        }
        await conversationsDao.upsertConversation(
          id: roomId,
          participantPubkeys: '["$_owner","$_visibleMember"]',
          isGroup: false,
          createdAt: _createdAt,
          lastMessageContent: 'ambiguous',
          lastMessageTimestamp: _createdAt,
          lastMessageSenderPubkey: _visibleMember,
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isFalse,
        );
      },
    );

    test(
      'legacy file preview cannot borrow tags from identical text',
      () async {
        final repository = buildRepository();
        await repository.getConversation(roomId);
        await messagesDao.insertMessage(
          id: 'file',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'attachment',
          createdAt: _createdAt,
          giftWrapId: 'file-wrap',
          messageKind: 15,
          fileType: 'image/png',
          ownerPubkey: _owner,
        );
        await messagesDao.insertMessage(
          id: 'text',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'Sent a photo',
          createdAt: _createdAt,
          giftWrapId: 'text-wrap',
          tagsJson: '[["q","34236:$_owner:clip","","$_owner"]]',
          ownerPubkey: _owner,
        );
        await conversationsDao.upsertConversation(
          id: roomId,
          participantPubkeys: '["$_owner","$_visibleMember"]',
          isGroup: false,
          createdAt: _createdAt,
          lastMessageContent: 'Sent a photo',
          lastMessageTimestamp: _createdAt,
          lastMessageSenderPubkey: _visibleMember,
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isFalse,
        );
      },
    );

    for (final higherIdFirst in [true, false]) {
      for (final firstIsShare in [true, false]) {
        for (final sameText in [true, false]) {
          test(
            'same-second inbox keeps first message citation '
            '(share first: $firstIsShare, identical text: $sameText, '
            'higher ID first: $higherIdFirst)',
            () async {
              final repository = buildRepository();
              await repository.getConversation(roomId);
              for (final first in [true, false]) {
                final id = first == higherIdFirst ? 'z' : 'a';
                final content = first || sameText ? 'same note' : 'second note';
                await messagesDao.insertMessage(
                  id: id,
                  conversationId: roomId,
                  senderPubkey: _visibleMember,
                  content: content,
                  createdAt: _createdAt,
                  giftWrapId: 'wrap-$id',
                  ownerPubkey: _owner,
                  tagsJson: first == firstIsShare
                      ? '[["q","34236:$_owner:clip","","$_owner"]]'
                      : null,
                );
                await conversationsDao.upsertConversation(
                  id: roomId,
                  participantPubkeys: '["$_owner","$_visibleMember"]',
                  isGroup: false,
                  createdAt: _createdAt,
                  lastMessageId: id,
                  lastMessageContent: content,
                  lastMessageTimestamp: _createdAt,
                  lastMessageSenderPubkey: _visibleMember,
                  ownerPubkey: _owner,
                );
              }
              final preview = await repository.getConversation(roomId);
              expect(preview?.lastMessageContent, 'same note');
              expect(preview?.lastMessageIsVideoShare, firstIsShare);
            },
          );
        }
      }
    }

    test(
      "maps the newest visible message and the room's unread state",
      () async {
        await seedRoom();

        final activity = await buildRepository().visibleActivityExcluding({
          roomId: {_hiddenMember},
        });

        expect(
          activity,
          equals({
            roomId: (
              lastMessageContent: 'from the visible member',
              lastMessageTimestamp: _createdAt + 100,
              lastMessageSenderPubkey: _visibleMember,
              lastMessageIsVideoShare: false,
              hasUnread: true,
            ),
          }),
        );
      },
    );

    test(
      'uses the newest visible non-reply citation after deletion',
      () async {
        await seedRoom();
        final repository = buildRepository();
        const tags = '[["q","34236:$_owner:clip","","$_owner"]]';
        await messagesDao.insertMessage(
          id: 'shared-clip',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'my note',
          createdAt: _createdAt + 300,
          giftWrapId: 'wrap-clip',
          ownerPubkey: _owner,
          tagsJson: tags,
        );
        await conversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isTrue,
        );
        expect(
          (await repository.visibleActivityExcluding({
            roomId: {_hiddenMember},
          }))[roomId]?.lastMessageIsVideoShare,
          isTrue,
        );
        await messagesDao.insertMessage(
          id: 'reply',
          conversationId: roomId,
          senderPubkey: _visibleMember,
          content: 'my reply',
          createdAt: _createdAt + 400,
          giftWrapId: 'wrap-reply',
          ownerPubkey: _owner,
          tagsJson: tags,
          replyToId: 'shared-clip',
        );
        await conversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isFalse,
        );
        await messagesDao.markMessageDeleted('reply', ownerPubkey: _owner);
        await conversationsDao.backfillLatestMessagePreviews(
          ownerPubkey: _owner,
        );
        expect(
          (await repository.getConversation(roomId))?.lastMessageIsVideoShare,
          isTrue,
        );
      },
    );

    test(
      'maps a room nobody visible wrote in to an empty, read preview',
      () async {
        await seedRoom(withVisibleMessage: false);

        final activity = await buildRepository().visibleActivityExcluding({
          roomId: {_hiddenMember},
        });

        expect(
          activity,
          equals({
            roomId: (
              lastMessageContent: null,
              lastMessageTimestamp: null,
              lastMessageSenderPubkey: null,
              lastMessageIsVideoShare: false,
              hasUnread: false,
            ),
          }),
        );
      },
    );

    test('reads nothing, not a legacy ownerless row, while no owner is '
        'known', () async {
      // A row from before multi-account support carries the empty owner, so
      // an unguarded read with the empty pubkey would serve it (#8187).
      await seedRoom(ownerPubkey: '');
      final legacy = await conversationsDao.getConversation(
        roomId,
        ownerPubkey: '',
      );
      expect(legacy, isNotNull);

      final activity =
          await buildRepository(
            userPubkey: '',
          ).visibleActivityExcluding({
            roomId: {_hiddenMember},
          });

      expect(activity, isEmpty);
    });
  });
}
