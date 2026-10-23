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
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _HeldReadStore extends InMemorySharedPreferencesStore {
  _HeldReadStore(this.key, Map<String, Object> data, {this.refuse = true})
    : super.withData(data);
  final String key;
  final bool refuse;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (key == 'flutter.${this.key}' && !entered.isCompleted) {
      entered.complete();
      await release.future;
      if (refuse) return false;
    }
    return super.setValue(type, key, value);
  }
}

class _HeldPublicationDao extends ConversationsDao {
  _HeldPublicationDao(super.attachedDatabase);
  bool holdNext = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<ConversationRow>> getAllConversations({
    int? limit,
    int? offset,
    String? ownerPubkey,
  }) async {
    final rows = await super.getAllConversations(
      limit: limit,
      offset: offset,
      ownerPubkey: ownerPubkey,
    );
    if (holdNext) {
      holdNext = false;
      entered.complete();
      await release.future;
    }
    return rows;
  }
}

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
    for (final holdDao in [false, true]) {
      test(
        'publication excludes uncommitted journal while '
        '${holdDao ? 'DAO' : 'native write'} is held',
        () async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.test(NativeDatabase.memory());
          addTearDown(db.close);
          final owner = 'a' * 64;
          final peer = 'b' * 64;
          final tuple = '$owner,$peer';
          final sync = DmSyncState(prefs);
          final dao = _HeldPublicationDao(db);
          await sync.rememberReadCursors(owner, {tuple: 100});
          await db.conversationsDao.upsertConversation(
            id: 'thread',
            participantPubkeys: jsonEncode([owner, peer]),
            isGroup: false,
            createdAt: 100,
            lastMessageTimestamp: 200,
            isRead: false,
            ownerPubkey: owner,
          );
          final original = SharedPreferencesStorePlatform.instance;
          final native = _HeldReadStore(
            DmSyncState.readStateStorageKey(owner),
            await original.getAll(),
          );
          SharedPreferencesStorePlatform.instance = native;
          addTearDown(() => SharedPreferencesStorePlatform.instance = original);
          final sent = <Map<String, dynamic>>[];
          final service = _Service();
          when(
            () => service.publishSelfApplicationMarkerDetailed(
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((call) async {
            sent.add(
              jsonDecode(call.namedArguments[#content] as String)
                  as Map<String, dynamic>,
            );
            return SelfApplicationMarkerResult.published;
          });
          final repository = DmRepository(
            nostrClient: _Client(),
            directMessagesDao: db.directMessagesDao,
            conversationsDao: dao,
            userPubkey: owner,
            signer: LocalNostrSigner('1' * 64),
            messageService: service,
            syncState: sync,
          );
          Future<void>? publish;
          if (holdDao) {
            dao.holdNext = true;
            publish = repository.flushPendingReadState();
            await dao.entered.future;
          }
          final failedRead = expectLater(
            repository.markConversationAsRead('thread'),
            throwsStateError,
          );
          await native.entered.future;
          publish ??= repository.flushPendingReadState();
          if (holdDao) dao.release.complete();
          await pumpEventQueue();
          native.release.complete();
          await failedRead;
          await publish;
          expect(sent.single['read'], {tuple: 100});
          await prefs.reload();
          expect(sync.readCursors(owner), {tuple: 100});
          await repository.stopListening();
        },
      );
    }

    test(
      'owner erasure fences publication waiting for conversation rows',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final owner = 'a' * 64;
        final peer = 'b' * 64;
        final sync = DmSyncState(prefs);
        final dao = _HeldPublicationDao(db);
        await dao.upsertConversation(
          id: 'thread',
          participantPubkeys: jsonEncode([owner, peer]),
          isGroup: false,
          createdAt: 100,
          lastMessageTimestamp: 200,
          ownerPubkey: owner,
        );
        await dao.markAsRead('thread', ownerPubkey: owner);
        await sync.rememberReadCursors(owner, {'$owner,$peer': 200});
        final service = _Service();
        var published = false;
        when(
          () => service.publishSelfApplicationMarkerDetailed(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          published = true;
          return SelfApplicationMarkerResult.published;
        });
        final repository = DmRepository(
          nostrClient: _Client(),
          directMessagesDao: db.directMessagesDao,
          conversationsDao: dao,
          userPubkey: owner,
          signer: LocalNostrSigner('1' * 64),
          messageService: service,
          syncState: sync,
        );
        dao.holdNext = true;
        final publishing = repository.flushPendingReadState();
        await dao.entered.future;
        await repository.closeLocalReadState();
        await prefs.remove(DmSyncState.readStateStorageKey(owner));
        dao.release.complete();
        await publishing;
        expect(published, isFalse);
        await repository.stopListening();
      },
    );

    test(
      'owner erasure drains an issued native publication acknowledgment',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.test(NativeDatabase.memory());
        addTearDown(db.close);
        final owner = 'a' * 64;
        final other = 'c' * 64;
        final tuple = '$owner,${'b' * 64}';
        final sync = DmSyncState(prefs);
        await sync.rememberReadCursors(owner, {tuple: 200});
        final original = SharedPreferencesStorePlatform.instance;
        final native = _HeldReadStore(
          DmSyncState.readStateStorageKey(owner),
          await original.getAll(),
          refuse: false,
        );
        SharedPreferencesStorePlatform.instance = native;
        addTearDown(() => SharedPreferencesStorePlatform.instance = original);
        final service = _Service();
        when(
          () => service.publishSelfApplicationMarkerDetailed(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => SelfApplicationMarkerResult.published);
        final repository = DmRepository(
          nostrClient: _Client(),
          directMessagesDao: db.directMessagesDao,
          conversationsDao: db.conversationsDao,
          userPubkey: owner,
          signer: LocalNostrSigner('1' * 64),
          messageService: service,
          syncState: sync,
        );
        final publishing = repository.flushPendingReadState();
        await native.entered.future;
        var closed = false;
        final closing = repository.closeLocalReadState().then(
          (_) => closed = true,
        );
        await sync.rememberReadCursors(other, {tuple: 100});
        await pumpEventQueue();
        expect(closed, isFalse);
        native.release.complete();
        await publishing;
        await closing;
        await prefs.remove(DmSyncState.readStateStorageKey(owner));
        await prefs.reload();
        expect(sync.readCursors(owner), isEmpty);
        expect(sync.readCursors(other), {tuple: 100});
        await repository.stopListening();
      },
    );

    test('owner teardown never waits for signing or relay delivery', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.test(NativeDatabase.memory());
      addTearDown(db.close);
      final owner = 'a' * 64;
      final peer = 'b' * 64;
      final sync = DmSyncState(prefs);
      await sync.rememberReadCursors(owner, {'$owner,$peer': 200});
      final entered = Completer<void>();
      final release = Completer<SelfApplicationMarkerResult>();
      final service = _Service();
      when(
        () => service.publishSelfApplicationMarkerDetailed(
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) {
        entered.complete();
        return release.future;
      });
      late Future<void> Function() close;
      final repository = DmRepository(
        nostrClient: _Client(),
        directMessagesDao: db.directMessagesDao,
        conversationsDao: db.conversationsDao,
        userPubkey: owner,
        signer: LocalNostrSigner('1' * 64),
        messageService: service,
        syncState: sync,
        onReadOwnerCreated: (_, drain) => close = drain,
      );
      final publishing = repository.flushPendingReadState();
      await entered.future;
      await close().timeout(const Duration(seconds: 1));
      expect(sync.pendingReadRevision(owner), 1);
      await prefs.remove(DmSyncState.readStateStorageKey(owner));
      release.complete(SelfApplicationMarkerResult.published);
      await publishing;
      await prefs.reload();
      expect(sync.readCursors(owner), isEmpty);
      await repository.stopListening();
    });

    test(
      'signer refusal retains reads without an automatic prompt loop',
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
        final service = _Service();
        var calls = 0;
        var permitsSigning = false;
        when(
          () => service.publishSelfApplicationMarkerDetailed(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          calls++;
          return permitsSigning
              ? SelfApplicationMarkerResult.published
              : SelfApplicationMarkerResult.signerUnavailable;
        });
        final repository = DmRepository(
          nostrClient: _Client(),
          directMessagesDao: database.directMessagesDao,
          conversationsDao: database.conversationsDao,
          userPubkey: 'owner',
          signer: LocalNostrSigner('1' * 64),
          messageService: service,
          syncState: DmSyncState(await SharedPreferences.getInstance()),
          readStateRetryDelay: Duration.zero,
        );
        addTearDown(repository.stopListening);
        await repository.markConversationAsRead('thread');
        await repository.flushPendingReadState();
        await pumpEventQueue();
        expect(repository.hasPendingReadState, isTrue);
        expect(calls, 1);
        permitsSigning = true;
        await repository.flushPendingReadState();
        expect(calls, 2);
        expect(repository.hasPendingReadState, isFalse);
      },
    );

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
          () => service.publishSelfApplicationMarkerDetailed(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => accepts
              ? SelfApplicationMarkerResult.published
              : SelfApplicationMarkerResult.retryableFailure,
        );
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
          () => service.publishSelfApplicationMarkerDetailed(
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
          () => service.publishSelfApplicationMarkerDetailed(
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          if (online && !retried.isCompleted) retried.complete();
          return online
              ? SelfApplicationMarkerResult.published
              : SelfApplicationMarkerResult.retryableFailure;
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
