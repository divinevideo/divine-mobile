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
              hasUnread: true,
            ),
          }),
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
