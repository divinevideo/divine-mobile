// ABOUTME: Tests for dmVideoMessageGone: which kept video DMs prune deletes
// ABOUTME: because their message was retracted or removed with its chat.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks/mock_path_provider_platform.dart';

class _MockAuthService extends Mock implements AuthService {}

/// Says when something first asks for the cache folder, as a prune does
/// before anything else.
class _SignallingPathProvider extends MockPathProviderPlatform {
  _SignallingPathProvider(this.asked);

  final Completer<void> asked;

  @override
  Future<String?> getApplicationCachePath() {
    if (!asked.isCompleted) asked.complete();
    return super.getApplicationCachePath();
  }
}

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

      expect(prunes, equals(1));
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
      expect(prunes, equals(1));

      var closed = false;
      final closing = cleanup.close();
      expect(identical(closing, cleanup.close()), isTrue);
      unawaited(closing.then((_) => closed = true));
      await pumpEventQueue();
      expect(closed, isFalse);

      release.complete();
      await closing;
      expect(closed, isTrue);
      expect(prunes, equals(1));
      await changes.close();
    });

    test(
      'closes cleanly after a running cleanup failed, which reported its own '
      'failure',
      () async {
        final release = Completer<void>();
        final started = Completer<void>();
        final changes = StreamController<void>();
        final cleanup = DmVideoGoneCleanup(
          changes: changes.stream,
          cleanupDelay: Duration.zero,
          prune: () {
            started.complete();
            return release.future;
          },
        );
        changes.add(null);
        await started.future;

        final closing = cleanup.close();
        release.completeError(Exception('prune failed'));

        await expectLater(closing, completes);
        await changes.close();
      },
    );

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

  group('dmVideoStoreProvider', () {
    final owner = 'e' * 64;
    final messageId = '1' * 64;
    late AppDatabase db;
    late Directory cache;
    late PathProviderPlatform originalPaths;
    late _MockAuthService authService;
    late List<BeforeSessionTeardownCallback> beforeSignOut;

    setUpAll(() {
      Future<void> fallback() async {}
      registerFallbackValue(fallback);
    });

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      cache = Directory.systemTemp.createTempSync('dm_disposal_');
      originalPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setApplicationCachePath(cache.path);
      authService = _MockAuthService();
      beforeSignOut = [];
      when(
        () => authService.registerBeforeSessionTeardownCallback(any()),
      ).thenAnswer((invocation) {
        final callback =
            invocation.positionalArguments.single
                as BeforeSessionTeardownCallback;
        beforeSignOut.add(callback);
        return () => beforeSignOut.remove(callback);
      });
    });

    ProviderContainer accountContainer() => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        currentAccountIdProvider.overrideWithValue(owner),
        authServiceProvider.overrideWithValue(authService),
      ],
    );

    tearDown(() async {
      PathProviderPlatform.instance = originalPaths;
      await db.close();
      cache.deleteSync(recursive: true);
    });

    test(
      'conversation repair refreshes the kept record before old-room removal',
      () async {
        const sentAt = 1757385263;
        await db.directMessagesDao.insertMessage(
          id: messageId,
          conversationId: 'old-room',
          senderPubkey: 'b' * 64,
          content: 'https://media.example/blob',
          createdAt: sentAt,
          giftWrapId: 'c' * 64,
          messageKind: 15,
          ownerPubkey: owner,
        );
        final video = File(
          '${cache.path}/${DmVideoStore.dirName}/$owner/$messageId.mp4',
        )..createSync(recursive: true);
        final record = File('${video.parent.path}/$messageId.conversation')
          ..writeAsStringSync('old-room\n$sentAt');
        final container = accountContainer();
        final store = container.read(dmVideoStoreProvider)!;
        final closed = store.kept.drain<void>();
        addTearDown(() async {
          container.dispose();
          await closed;
        });
        await store.prune();
        expect(video.existsSync(), isTrue);

        await db.directMessagesDao.reassignMessages(
          messageIds: [messageId],
          toConversationId: 'repaired-group',
          ownerPubkey: owner,
        );
        await db.removedConversationsDao.record(
          conversationId: 'old-room',
          ownerPubkey: owner,
          removedAt: sentAt + 1,
        );
        await store.prune();

        expect(video.existsSync(), isTrue);
        expect(record.readAsStringSync(), 'repaired-group\n$sentAt');

        await db.directMessagesDao.clearForAccountSwitch(owner);
        await store.prune();
        expect(video.existsSync(), isTrue);
        await db.removedConversationsDao.record(
          conversationId: 'repaired-group',
          ownerPubkey: owner,
          removedAt: sentAt + 1,
        );
        await store.prune();
        expect(video.existsSync(), isFalse);
      },
    );

    test(
      'removal cleanup survives row clearing before account-store disposal',
      () async {
        const sentAt = 1757385263;
        await db.directMessagesDao.insertMessage(
          id: messageId,
          conversationId: 'conversation',
          senderPubkey: 'b' * 64,
          content: 'https://media.example/blob',
          createdAt: sentAt,
          giftWrapId: 'c' * 64,
          messageKind: 15,
          ownerPubkey: owner,
        );
        final video = File(
          '${cache.path}/${DmVideoStore.dirName}/$owner/$messageId.mp4',
        )..createSync(recursive: true);
        File('${video.parent.path}/$messageId.conversation')
            .writeAsStringSync('conversation\n$sentAt');
        final container = accountContainer();
        final store = container.read(dmVideoStoreProvider)!;
        final closed = store.kept.drain<void>();
        var disposed = false;
        addTearDown(() async {
          if (!disposed) container.dispose();
          await closed;
        });
        await store.prune();
        expect(video.existsSync(), isTrue);

        await db.removedConversationsDao.record(
          conversationId: 'conversation',
          ownerPubkey: owner,
          removedAt: sentAt + 1,
        );
        await db.directMessagesDao.clearForAccountSwitch(owner);
        await pumpEventQueue();
        disposed = true;
        container.dispose();
        await closed;

        expect(video.existsSync(), isFalse);
      },
    );

    test(
      'prunes at sign-out, while the rows that show a retraction are there',
      () async {
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
        final container = accountContainer();
        var disposed = false;
        addTearDown(() {
          if (!disposed) container.dispose();
        });
        final store = container.read(dmVideoStoreProvider)!;
        final closed = store.kept.drain<void>();
        await store.prune();
        expect(video.existsSync(), isTrue);

        await db.directMessagesDao.markMessageDeleted(
          messageId,
          ownerPubkey: owner,
        );
        // Sign-out runs these first, then clears the account's rows.
        for (final callback in List.of(beforeSignOut)) {
          await callback();
        }
        await db.directMessagesDao.clearForAccountSwitch(owner);
        disposed = true;
        container.dispose();
        await closed;

        expect(video.existsSync(), isFalse);
      },
    );

    group('foreground', () {
      /// The store of a new account container, closed after the test.
      DmVideoStore storeOf(ProviderContainer container) {
        final store = container.read(dmVideoStoreProvider)!;
        final closed = store.kept.drain<void>();
        addTearDown(() async {
          container.dispose();
          await closed;
        });
        return store;
      }

      test('tells its store when the app leaves and returns', () {
        final container = accountContainer();
        final store = storeOf(container);
        expect(store.appInForeground, isTrue);

        container.read(appForegroundProvider.notifier).setForeground(false);
        expect(store.appInForeground, isFalse);

        container.read(appForegroundProvider.notifier).setForeground(true);
        expect(store.appInForeground, isTrue);
      });

      test('starts a store made while the app is in the background there', () {
        final container = accountContainer();
        container.read(appForegroundProvider.notifier).setForeground(false);

        expect(storeOf(container).appInForeground, isFalse);
      });
    });

    test('prunes once its store is built', () async {
      final asked = Completer<void>();
      PathProviderPlatform.instance = _SignallingPathProvider(asked)
        ..setApplicationCachePath(cache.path);
      final container = accountContainer();
      final closed = container.read(dmVideoStoreProvider)!.kept.drain<void>();
      addTearDown(() async {
        container.dispose();
        await closed;
      });

      await expectLater(
        asked.future.timeout(const Duration(seconds: 2)),
        completes,
      );
    });

    test('stops pruning at sign-out once its store is gone', () async {
      final container = accountContainer();
      final closed = container.read(dmVideoStoreProvider)!.kept.drain<void>();
      expect(beforeSignOut, hasLength(1));

      container.dispose();
      await closed;

      expect(beforeSignOut, isEmpty);
    });
  });
}
