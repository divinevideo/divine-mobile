// ABOUTME: Regression coverage for #7923: the unread-only conversation watches
// ABOUTME: the Messages badge counts from, against a real database.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';

String _peer(int i) => i.toRadixString(16).padLeft(64, '0');

void main() {
  group('unread-only conversation watches (#7923)', () {
    late AppDatabase db;
    late DmRepository repository;

    Future<String> seed(
      List<String> participants, {
      required bool sent,
      required bool isRead,
    }) async {
      final id = DmRepository.computeConversationId(participants);
      await db.conversationsDao.upsertConversation(
        id: id,
        participantPubkeys: '[${participants.map((p) => '"$p"').join(',')}]',
        isGroup: participants.length > 2,
        createdAt: 1700000000,
        lastMessageTimestamp: 1700000100,
        isRead: isRead,
        currentUserHasSent: sent,
        ownerPubkey: _owner,
      );
      return id;
    }

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      repository = DmRepository(
        nostrClient: _MockNostrClient(),
        directMessagesDao: db.directMessagesDao,
        conversationsDao: db.conversationsDao,
        userPubkey: _owner,
      );
    });

    tearDown(() async {
      await repository.stopListening();
      await db.close();
    });

    group('watchAcceptedConversations', () {
      test('emits only unread conversations', () async {
        await seed([_owner, _peer(1)], sent: true, isRead: true);
        final unread = await seed(
          [_owner, _peer(2)],
          sent: true,
          isRead: false,
        );

        final all = await repository.watchAcceptedConversations().first;
        expect(all, hasLength(2), reason: 'the read row is in the full set');

        final rows = await repository
            .watchAcceptedConversations(unreadOnly: true)
            .first;

        expect(rows.map((c) => c.id), equals([unread]));
      });
    });

    group('watchPotentialRequests', () {
      test('emits only unread potential requests', () async {
        await seed([_owner, _peer(3)], sent: false, isRead: true);
        final unread = await seed(
          [_owner, _peer(4)],
          sent: false,
          isRead: false,
        );

        final all = await repository.watchPotentialRequests().first;
        expect(all, hasLength(2), reason: 'the read row is in the full set');

        final rows = await repository
            .watchPotentialRequests(unreadOnly: true)
            .first;

        expect(rows.map((c) => c.id), equals([unread]));
      });
    });
  });
}
