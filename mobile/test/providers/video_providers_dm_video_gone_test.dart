// ABOUTME: Tests for dmVideoMessageGone: which kept video DMs prune deletes
// ABOUTME: because their message was retracted or removed with its chat.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dm_video_store.dart';

void main() {
  group('dmVideoMessageGone', () {
    final owner = 'e' * 64;
    final messageId = 'a' * 64;
    const conversationId = 'conversation';
    late AppDatabase db;

    setUp(() => db = AppDatabase.test(NativeDatabase.memory()));

    tearDown(() => db.close());

    Future<void> insertVideoMessage({String? sender}) async {
      final inserted = await db.directMessagesDao.insertMessage(
        id: messageId,
        conversationId: conversationId,
        senderPubkey: sender ?? 'b' * 64,
        content: 'https://media.example/blob',
        createdAt: 1757385263,
        giftWrapId: 'c' * 64,
        messageKind: 15,
        ownerPubkey: owner,
      );
      expect(inserted, isTrue);
    }

    test('counts a message its sender retracted as gone', () async {
      await insertVideoMessage();
      await db.directMessagesDao.markMessageDeleted(
        messageId,
        ownerPubkey: owner,
      );

      expect(await dmVideoMessageGone(db, owner)(messageId), isTrue);
    });

    test('counts a message removed with its conversation as gone', () async {
      await insertVideoMessage();
      await db.removedMessageIdsDao.captureForConversations(
        conversationIds: [conversationId],
        ownerPubkey: owner,
        removedAt: 1757385300,
      );
      await db.directMessagesDao.deleteConversationMessages(
        conversationId,
        ownerPubkey: owner,
      );

      expect(await dmVideoMessageGone(db, owner)(messageId), isTrue);
    });

    test(
      'keeps your own message while its retraction is undelivered, as the '
      'thread still shows it',
      () async {
        await insertVideoMessage(sender: owner);
        await db.directMessagesDao.markMessageDeletionPending(
          messageId,
          deletionRumorJson: '{"kind":5}',
          ownerPubkey: owner,
        );

        expect(await dmVideoMessageGone(db, owner)(messageId), isFalse);
      },
    );

    test('keeps a message that is shown', () async {
      await insertVideoMessage();

      expect(await dmVideoMessageGone(db, owner)(messageId), isFalse);
    });

    test(
      'keeps a message with no row, as while it downloads again after an '
      'account switch',
      () async {
        expect(await dmVideoMessageGone(db, owner)(messageId), isFalse);
      },
    );

    test('keeps a message gone only for another account', () async {
      await insertVideoMessage();
      await db.directMessagesDao.markMessageDeleted(
        messageId,
        ownerPubkey: owner,
      );

      expect(await dmVideoMessageGone(db, 'f' * 64)(messageId), isFalse);
    });
  });

  group('dmVideoConversationRemoved', () {
    final owner = 'e' * 64;
    const conversationId = 'conversation';
    const removedAt = 1757385300;
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      await db.removedConversationsDao.record(
        conversationId: conversationId,
        ownerPubkey: owner,
        removedAt: removedAt,
      );
    });

    tearDown(() => db.close());

    test('counts a message sent before its conversation was removed', () async {
      expect(
        await dmVideoConversationRemoved(db, owner)(conversationId, removedAt),
        isTrue,
      );
    });

    test('keeps a message sent after its conversation was removed', () async {
      expect(
        await dmVideoConversationRemoved(
          db,
          owner,
        )(conversationId, removedAt + 1),
        isFalse,
      );
    });

    test('keeps a message whose conversation was never removed', () async {
      expect(
        await dmVideoConversationRemoved(db, owner)('other', removedAt),
        isFalse,
      );
    });

    test('keeps a message whose conversation another account removed', () {
      expect(
        dmVideoConversationRemoved(db, 'f' * 64)(conversationId, removedAt),
        completion(isFalse),
      );
    });
  });

  group('dmVideoMessageChanges', () {
    final owner = 'e' * 64;
    final messageId = 'a' * 64;
    const conversationId = 'conversation';
    late AppDatabase db;

    setUp(() => db = AppDatabase.test(NativeDatabase.memory()));

    tearDown(() => db.close());

    Future<void> insertVideoMessage() => db.directMessagesDao.insertMessage(
      id: messageId,
      conversationId: conversationId,
      senderPubkey: 'b' * 64,
      content: 'https://media.example/blob',
      createdAt: 1757385263,
      giftWrapId: 'c' * 64,
      messageKind: 15,
      ownerPubkey: owner,
    );

    test(
      'stays quiet for a new message and speaks up for a retraction',
      () async {
        var changes = 0;
        final subscription = dmVideoMessageChanges(
          db,
        ).listen((_) => changes++);
        addTearDown(subscription.cancel);

        await insertVideoMessage();
        await pumpEventQueue();
        expect(changes, isZero);

        await db.directMessagesDao.markMessageDeleted(
          messageId,
          ownerPubkey: owner,
        );
        await pumpEventQueue();
        expect(changes, equals(1));
      },
    );

    test(
      'speaks up when a conversation is removed with no messages left',
      () async {
        final changed = dmVideoMessageChanges(db).first;

        await db.removedConversationsDao.record(
          conversationId: conversationId,
          ownerPubkey: owner,
          removedAt: 1757385300,
        );

        await expectLater(changed, completes);
      },
    );

    test('speaks up when a conversation is removed', () async {
      await insertVideoMessage();
      final changed = dmVideoMessageChanges(db).first;

      await db.removedMessageIdsDao.captureForConversations(
        conversationIds: [conversationId],
        ownerPubkey: owner,
        removedAt: 1757385300,
      );

      await expectLater(changed, completes);
    });
  });

  group('pruneWhenDmVideoMessagesGo', () {
    final owner = 'e' * 64;
    late AppDatabase db;

    setUp(() => db = AppDatabase.test(NativeDatabase.memory()));

    tearDown(() => db.close());

    /// Records message [n] from someone else, then its retraction.
    void retract(FakeAsync async, int n) {
      bool? inserted;
      unawaited(() async {
        inserted = await db.directMessagesDao.insertMessage(
          id: '$n' * 64,
          conversationId: 'conversation',
          senderPubkey: 'b' * 64,
          content: 'https://media.example/blob',
          createdAt: 1757385263,
          giftWrapId: '${'c' * 63}$n',
          messageKind: 15,
          ownerPubkey: owner,
        );
        await db.directMessagesDao.markMessageDeleted(
          '$n' * 64,
          ownerPubkey: owner,
        );
      }());
      async.elapse(Duration.zero);
      expect(inserted, isTrue);
    }

    test('prunes once, the cleanup delay after a retraction', () {
      fakeAsync((async) {
        var prunes = 0;
        final subscription = pruneWhenDmVideoMessagesGo(
          db,
          () async => prunes++,
        );

        retract(async, 1);
        async.elapse(
          DmVideoStore.goneCleanupDelay - const Duration(milliseconds: 1),
        );
        expect(prunes, isZero);
        async.elapse(const Duration(milliseconds: 1));
        expect(prunes, equals(1));

        async.elapse(DmVideoStore.goneCleanupDelay * 2);
        expect(prunes, equals(1));
        unawaited(subscription.cancel());
      });
    });

    test('prunes once for a burst of retractions', () {
      fakeAsync((async) {
        var prunes = 0;
        final subscription = pruneWhenDmVideoMessagesGo(
          db,
          () async => prunes++,
        );

        retract(async, 1);
        async.elapse(const Duration(seconds: 1));
        retract(async, 2);
        async.elapse(DmVideoStore.goneCleanupDelay * 2);

        expect(prunes, equals(1));
        unawaited(subscription.cancel());
      });
    });

    test('prunes within the cleanup delay while retractions keep coming', () {
      fakeAsync((async) {
        var prunes = 0;
        final subscription = pruneWhenDmVideoMessagesGo(
          db,
          () async => prunes++,
        );
        final step = DmVideoStore.goneCleanupDelay ~/ 2;

        for (var index = 1; index <= 3; index++) {
          retract(async, index);
          async.elapse(step);
        }

        expect(prunes, greaterThanOrEqualTo(1));
        unawaited(subscription.cancel());
      });
    });

    test('prunes nothing once cancelled', () {
      fakeAsync((async) {
        var prunes = 0;
        final subscription = pruneWhenDmVideoMessagesGo(
          db,
          () async => prunes++,
        );

        unawaited(subscription.cancel());
        async.elapse(Duration.zero);
        retract(async, 1);
        async.elapse(DmVideoStore.goneCleanupDelay * 2);

        expect(prunes, isZero);
      });
    });
  });
}
