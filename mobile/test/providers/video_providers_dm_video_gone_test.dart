// ABOUTME: Tests for dmVideoMessageGone: which kept video DMs prune deletes
// ABOUTME: because their message was retracted or removed with its chat.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

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

    test('flushes a pending cleanup when its listener closes', () async {
      var prunes = 0;
      final changes = StreamController<void>();
      final cleanup = DmVideoGoneCleanup(
        changes: changes.stream,
        prune: () async => prunes++,
        cleanupDelay: const Duration(minutes: 1),
      );
      changes.add(null);
      await pumpEventQueue();
      expect(prunes, isZero);

      await cleanup.close();

      expect(prunes, 1);
      await changes.close();
    });

    test('close is shared and waits for an already running cleanup', () async {
      final release = Completer<void>();
      final started = Completer<void>();
      var prunes = 0;
      final changes = StreamController<void>();
      final cleanup = DmVideoGoneCleanup(
        changes: changes.stream,
        cleanupDelay: Duration.zero,
        prune: () {
          prunes++;
          started.complete();
          return release.future;
        },
      );
      changes.add(null);
      await started.future;
      expect(prunes, 1);

      var closed = false;
      final closing = cleanup.close();
      expect(identical(closing, cleanup.close()), isTrue);
      unawaited(closing.then((_) => closed = true));
      await pumpEventQueue();
      expect(closed, isFalse);

      release.complete();
      await closing;
      expect(closed, isTrue);
      expect(prunes, 1);
      await changes.close();
    });

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
        unawaited(subscription.close());
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
        unawaited(subscription.close());
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
        unawaited(subscription.close());
      });
    });

    test('prunes nothing once cancelled', () {
      fakeAsync((async) {
        var prunes = 0;
        final subscription = pruneWhenDmVideoMessagesGo(
          db,
          () async => prunes++,
        );

        unawaited(subscription.close());
        async.elapse(Duration.zero);
        retract(async, 1);
        async.elapse(DmVideoStore.goneCleanupDelay * 2);

        expect(prunes, isZero);
      });
    });
  });

  group('dmVideoStoreProvider disposal', () {
    final owner = 'e' * 64;
    final messageId = '1' * 64;
    late AppDatabase db;
    late Directory cache;
    late PathProviderPlatform originalPaths;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      cache = Directory.systemTemp.createTempSync('dm_disposal_');
      originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationCachePath(cache.path);
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPaths;
      await db.close();
      cache.deleteSync(recursive: true);
    });

    test('flushes the pending retraction before disposing the store', () async {
      await db.directMessagesDao.insertMessage(
        id: messageId,
        conversationId: 'conversation',
        senderPubkey: 'b' * 64,
        content: 'https://media.example/blob',
        createdAt: 1757385263,
        giftWrapId: 'c' * 64,
        messageKind: 15,
        ownerPubkey: owner,
      );
      final video = File(
        '${cache.path}/${DmVideoStore.dirName}/$owner/$messageId.mp4',
      )..createSync(recursive: true);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          currentAccountIdProvider.overrideWithValue(owner),
        ],
      );
      var disposed = false;
      addTearDown(() {
        if (!disposed) container.dispose();
      });
      final store = container.read(dmVideoStoreProvider)!;
      await store.prune();
      expect(video.existsSync(), isTrue);
      final deleted = Completer<void>();
      final watch = video.parent.watch(events: FileSystemEvent.delete).listen((
        event,
      ) {
        if (event.path == video.path && !deleted.isCompleted)
          deleted.complete();
      });
      addTearDown(watch.cancel);
      await db.directMessagesDao.markMessageDeleted(
        messageId,
        ownerPubkey: owner,
      );
      await pumpEventQueue();

      disposed = true;
      container.dispose();
      await deleted.future.timeout(const Duration(seconds: 5));
      await store.prune();

      expect(video.existsSync(), isFalse);
    });
  });
}
