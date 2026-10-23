import 'dart:async';
import 'dart:convert';

import 'package:account_state_repository/account_state_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements NostrClient {}

class _Service extends Mock implements NIP17MessageService {}

class _BlockingReadState extends DmSyncState {
  _BlockingReadState(super._prefs);
  final captured = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> rememberReadCursors(
    String pubkey,
    Map<String, int> cursors, {
    Map<String, Set<String>> boundaryMessageIds = const {},
  }) async {
    captured.complete();
    await release.future;
    await super.rememberReadCursors(
      pubkey,
      cursors,
      boundaryMessageIds: boundaryMessageIds,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('flushPendingReadState', () {
    test(
      'failed read marker survives restart and retries without another read',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final dao = ConversationsDao(db);
        const owner = 'owner';
        await dao.upsertConversation(
          id: 'thread',
          participantPubkeys: jsonEncode(['owner', 'peer']),
          isGroup: false,
          createdAt: 100,
          lastMessageTimestamp: 200,
          isRead: false,
          ownerPubkey: owner,
        );
        final service = _Service();
        var accepts = false;
        when(
          () => service.publishSelfApplicationMarker(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => accepts);
        DmRepository create() => DmRepository(
          nostrClient: _Client(),
          directMessagesDao: DirectMessagesDao(db),
          conversationsDao: dao,
          userPubkey: owner,
          signer: LocalNostrSigner('1' * 64),
          messageService: service,
          syncState: DmSyncState(prefs),
        );
        final first = create();
        await first.markConversationAsRead('thread');
        await first.flushPendingReadState();
        expect(
          (await dao.getConversation('thread', ownerPubkey: owner))!.isRead,
          isTrue,
        );
        await first.stopListening();
        await dao.clearForAccountSwitch(owner);
        accepts = true;
        final restarted = create();
        await restarted.flushPendingReadState();
        await restarted.flushPendingReadState();
        verify(
          () => service.publishSelfApplicationMarker(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(2);
        expect(await dao.getConversation('thread', ownerPubkey: owner), isNull);
        await restarted.stopListening();
      },
    );
    test(
      'failed foreground publication retries without another user action',
      () async {
        SharedPreferences.setMockInitialValues({});
        final database = AppDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        await database.conversationsDao.upsertConversation(
          id: 'thread',
          participantPubkeys: '["owner","peer"]',
          isGroup: false,
          createdAt: 100,
          lastMessageTimestamp: 100,
          ownerPubkey: 'owner',
          isRead: false,
        );
        var online = false;
        final retried = Completer<void>();
        final service = _Service();
        when(
          () => service.publishSelfApplicationMarker(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          if (online && !retried.isCompleted) retried.complete();
          return online;
        });
        final repository = DmRepository(
          nostrClient: _Client(),
          directMessagesDao: database.directMessagesDao,
          conversationsDao: database.conversationsDao,
          userPubkey: 'owner',
          signer: LocalNostrSigner('1' * 64),
          messageService: service,
          syncState: DmSyncState(await SharedPreferences.getInstance()),
          readStateRetryDelay: const Duration(milliseconds: 5),
        );
        await repository.markConversationAsRead('thread');
        await repository.flushPendingReadState();
        expect(repository.hasPendingReadState, isTrue);
        online = true;
        await retried.future.timeout(const Duration(seconds: 1));
        await repository.flushPendingReadState();
        expect(repository.hasPendingReadState, isFalse);
        await repository.stopListening();
      },
    );
  });
  group('markConversationAsRead', () {
    test(
      'a message arriving during durable read persistence remains unread',
      () async {
        SharedPreferences.setMockInitialValues({});
        final state = _BlockingReadState(await SharedPreferences.getInstance());
        final database = AppDatabase.test(NativeDatabase.memory());
        addTearDown(database.close);
        Future<void> arrival(int timestamp) =>
            database.conversationsDao.upsertConversation(
              id: 'thread',
              participantPubkeys: '["owner","peer"]',
              isGroup: false,
              createdAt: 100,
              lastMessageTimestamp: timestamp,
              isRead: false,
              ownerPubkey: 'owner',
            );
        await arrival(100);
        final repository = DmRepository(
          nostrClient: _Client(),
          directMessagesDao: database.directMessagesDao,
          conversationsDao: database.conversationsDao,
          userPubkey: 'owner',
          syncState: state,
        );
        final read = repository.markConversationAsRead('thread');
        await state.captured.future;
        await arrival(200);
        state.release.complete();
        expect(await read, isTrue);
        final row = (await database.conversationsDao.getConversation(
          'thread',
          ownerPubkey: 'owner',
        ))!;
        expect(row.lastReadTimestamp, 100);
        expect(row.isRead, isFalse);
        await repository.stopListening();
      },
    );
  });
  group('setConversationDismissed', () {
    test(
      'dismissal follows the account and a new message restores visibility',
      () async {
        final signer = LocalNostrSigner('1' * 64);
        const owner =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const peer =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final tuple = [owner, peer]..sort();
        final id = DmRepository.computeConversationId(tuple);
        SharedPreferences.setMockInitialValues({});
        final firstState = AccountStateRepository(
          nostrClient: _Client(),
          sharedPreferences: await SharedPreferences.getInstance(),
          pubkey: owner,
          signer: () => signer,
          namespace: 'divine/dm-dismissals/v1',
        );
        SharedPreferences.setMockInitialValues({});
        final secondState = AccountStateRepository(
          nostrClient: _Client(),
          sharedPreferences: await SharedPreferences.getInstance(),
          pubkey: owner,
          signer: () => signer,
          namespace: 'divine/dm-dismissals/v1',
        );
        final firstDb = AppDatabase.test(NativeDatabase.memory());
        final secondDb = AppDatabase.test(NativeDatabase.memory());
        addTearDown(firstDb.close);
        addTearDown(secondDb.close);
        addTearDown(firstState.close);
        addTearDown(secondState.close);
        for (final db in [firstDb, secondDb]) {
          await db.directMessagesDao.insertMessage(
            id: 'known',
            conversationId: id,
            senderPubkey: peer,
            content: 'hello',
            createdAt: 100,
            giftWrapId: 'wrap-known',
            ownerPubkey: owner,
          );
          await db.conversationsDao.upsertConversation(
            id: id,
            participantPubkeys: jsonEncode(tuple),
            isGroup: false,
            createdAt: 100,
            lastMessageTimestamp: 100,
            isRead: false,
            ownerPubkey: owner,
          );
        }
        DmRepository create(AppDatabase db, AccountStateRepository state) =>
            DmRepository(
              nostrClient: _Client(),
              directMessagesDao: db.directMessagesDao,
              conversationsDao: db.conversationsDao,
              userPubkey: owner,
              accountStateRepository: state,
            );
        final first = create(firstDb, firstState);
        final second = create(secondDb, secondState);
        await first.setConversationDismissed(id, dismissed: true);
        // The shared engine's transport is tested in its own two-store suite;
        // deliver its reconciled field values to this repository consumer.
        await secondState.setValues(firstState.values);
        await second.flushPendingReadState();
        expect(
          (await secondDb.conversationsDao.getConversation(
            id,
            ownerPubkey: owner,
          ))!.isDismissed,
          isTrue,
        );
        await secondDb.directMessagesDao.insertMessage(
          id: 'new',
          conversationId: id,
          senderPubkey: peer,
          content: 'new',
          createdAt: 100,
          giftWrapId: 'wrap-new',
          ownerPubkey: owner,
        );
        await secondDb.conversationsDao.upsertConversation(
          id: id,
          participantPubkeys: jsonEncode(tuple),
          isGroup: false,
          createdAt: 100,
          lastMessageTimestamp: 100,
          isRead: false,
          isNewMessage: true,
          ownerPubkey: owner,
        );
        await second.flushPendingReadState();
        final row = (await secondDb.conversationsDao.getConversation(
          id,
          ownerPubkey: owner,
        ))!;
        expect(row.isDismissed, isFalse);
        expect(row.isRead, isFalse);
        await first.setConversationDismissed(id, dismissed: false);
        await secondState.setValues(firstState.values);
        await second.flushPendingReadState();
        expect(
          await secondDb.conversationsDao.getDismissal(id, ownerPubkey: owner),
          isNull,
        );
        await first.stopListening();
        await second.stopListening();
      },
    );
  });
}
