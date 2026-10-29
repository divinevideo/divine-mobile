import 'dart:async';
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/chat/chat_mention_repository.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

class _Room extends Mock implements ConcordRepository {}

class _FailingStore extends InMemoryConcordStore {
  _FailingStore(super.pubkey);
  bool fail = false;
  @override
  Future<void> put(String key, String value) async {
    if (fail) {
      fail = false;
      throw StateError('write refused');
    }
    await super.put(key, value);
  }
}

/// Holds the next write until [held] completes, then refuses it.
class _RefusedLaterStore extends InMemoryConcordStore {
  _RefusedLaterStore(super.pubkey);
  Completer<void>? held;
  @override
  Future<void> put(String key, String value) async {
    if (held case final gate?) {
      held = null;
      await gate.future;
      throw StateError('write refused');
    }
    await super.put(key, value);
  }
}

/// Holds every read until [gate] completes and counts writes.
class _GatedStore extends InMemoryConcordStore {
  _GatedStore(super.pubkey);
  final gate = Completer<void>();
  int puts = 0;
  @override
  Future<String?> get(String key) async {
    await gate.future;
    return super.get(key);
  }

  @override
  Future<void> put(String key, String value) async {
    puts++;
    await super.put(key, value);
  }
}

void main() {
  final me = 'a' * 64;
  final friend = 'b' * 64;
  final stranger = 'c' * 64;
  ChatMessage message(
    String author,
    int time, {
    bool tagged = true,
    String? id,
  }) => ChatMessage(
    id: id ?? '$time$author'.substring(0, 64),
    channelId: 'general',
    author: author,
    body: tagged ? 'hello nostr:${NostrKeyUtils.encodePubKey(me)}' : 'hello',
    createdAt: time,
    mentionedPubkeys: tagged ? [me] : [],
  );
  group(ChatMentionRepository, () {
    group('reevaluate', () {
      test(
        'only explicit recent mentions from trusted senders produce a grouped row',
        () async {
          var blocked = false;
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: InMemoryConcordStore(me),
            now: () => 1000,
            canNotify: (author) => author == friend && !blocked,
          );
          addTearDown(repo.close);
          await repo.initialize();
          await repo.enroll('general');
          repo.updateRoom('general', [
            message(stranger, 1001),
            message(me, 1001),
            message(friend, 999),
            message(friend, 1400),
            message(friend, 1001, tagged: false),
          ]);
          expect(repo.items, isEmpty);
          repo.updateRoom('general', [
            message(friend, 1000),
            message(friend, 1001),
          ]);
          expect(repo.items, hasLength(1));
          expect(repo.items.single.isRead, isFalse);
          expect((repo.items.single as ActorNotification).commentText, isNull);
          await repo.markSeen([repo.items.single.id]);
          expect(repo.items.single.isRead, isTrue);
          repo.updateRoom('general', [
            message(friend, 1000),
            message(friend, 1001),
          ]);
          expect(repo.items.single.isRead, isTrue);
          blocked = true;
          repo.reevaluate();
          expect(repo.items, isEmpty);
        },
      );
    });
    group('reevaluate rules', () {
      late int clock;
      late ChatMentionRepository repo;

      setUp(() async {
        clock = 1000;
        repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: InMemoryConcordStore(me),
          now: () => clock,
          canNotify: (_) => true,
        );
        addTearDown(repo.close);
        await repo.enroll('general');
      });

      ChatMessage sent(
        String author,
        int time, {
        int ms = 0,
        String? id,
        int? expiresAt,
        String? editedBody,
      }) => ChatMessage(
        id: id ?? '$time$ms$author'.substring(0, 64),
        channelId: 'general',
        author: author,
        body: 'hello nostr:${NostrKeyUtils.encodePubKey(me)}',
        createdAt: time,
        ms: ms,
        expiresAt: expiresAt,
        editedBody: editedBody,
        mentionedPubkeys: [me],
      );

      test('the newest mention from a sender decides its row', () {
        final newest = sent(friend, 1003, ms: 7, id: '7' * 64);
        repo.updateRoom('general', [
          sent(friend, 1001),
          newest,
          sent(friend, 1003, ms: 5, id: 'f' * 64),
          sent(friend, 1002),
        ]);
        expect(repo.items.single.sourceEventIds, [newest.id]);
      });

      test('a timestamp tie goes to the higher event id', () {
        repo.updateRoom('general', [
          sent(friend, 1003, ms: 7, id: 'e' * 64),
          sent(friend, 1003, ms: 7, id: 'a' * 64),
        ]);
        expect(repo.items.single.sourceEventIds, ['e' * 64]);
      });

      test(
        'a later mention from a sender is unread again after a read',
        () async {
          repo.updateRoom('general', [sent(friend, 1001)]);
          await repo.markSeen([repo.items.single.id]);
          repo.updateRoom('general', [sent(friend, 1001), sent(friend, 1002)]);
          expect(repo.items.single.isRead, isFalse);
        },
      );

      test('a self mention never alerts, even when the owner is trusted', () {
        repo.updateRoom('general', [sent(me, 1001)]);
        expect(repo.items, isEmpty);
      });

      test('a mention older than the age window is history', () {
        clock = 1000 + ChatMentionLimits.maxAgeSeconds + 100;
        repo.updateRoom('general', [
          sent(friend, 1001),
          sent(stranger, clock - 5),
        ]);
        expect(
          repo.items.map((item) => (item as ActorNotification).actor.pubkey),
          [stranger],
        );
      });

      test('an expired message does not alert', () {
        clock = 1010;
        repo.updateRoom('general', [
          sent(friend, 1001, expiresAt: 1005),
          sent(stranger, 1001, expiresAt: 1020),
        ]);
        expect(
          repo.items.map((item) => (item as ActorNotification).actor.pubkey),
          [stranger],
        );
      });

      test('a tagged message that shows no mention does not alert', () {
        // NIP-22 replies carry a p tag for the parent's author.
        repo.updateRoom('general', [
          ChatMessage(
            id: 'e' * 64,
            channelId: 'general',
            author: friend,
            body: 'agreed',
            createdAt: 1001,
            threadRootId: 'f' * 64,
            mentionedPubkeys: [me],
          ),
          sent(stranger, 1001),
        ]);
        expect(
          repo.items.map((item) => (item as ActorNotification).actor.pubkey),
          [stranger],
        );
      });

      test('an edit that removes the mention withdraws its row', () {
        final kept = 'still nostr:${NostrKeyUtils.encodePubKey(me)}';
        repo.updateRoom('general', [
          sent(friend, 1001, editedBody: 'hello again'),
          sent(stranger, 1001, editedBody: kept),
        ]);
        expect(
          repo.items.map((item) => (item as ActorNotification).actor.pubkey),
          [stranger],
        );
      });

      test('keeps the newest rows up to the cap, newest first', () {
        final senders = [
          for (var i = 0; i <= ChatMentionLimits.maxRows; i++)
            i.toRadixString(16).padLeft(64, '0'),
        ];
        repo.updateRoom('general', [
          for (final (i, sender) in senders.indexed) sent(sender, 1001 + i),
        ]);
        final shown = [
          for (final item in repo.items)
            (item as ActorNotification).actor.pubkey,
        ];
        expect(shown, hasLength(ChatMentionLimits.maxRows));
        expect(shown.first, senders.last);
        expect(shown, isNot(contains(senders.first)));
      });
    });

    group('sender names', () {
      test(
        'rows show a loaded sender name, only for trusted senders',
        () async {
          final requested = <Set<String>>[];
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: InMemoryConcordStore(me),
            now: () => 1000,
            canNotify: (author) => author == friend,
            loadActors: (authors) async {
              requested.add(authors);
              return [ActorInfo(pubkey: friend, displayName: 'Friend')];
            },
          );
          addTearDown(repo.close);
          await repo.enroll('general');
          repo.updateRoom('general', [
            message(friend, 1001),
            message(stranger, 1001),
          ]);
          await pumpEventQueue();
          expect(requested, [
            {friend},
          ]);
          expect(
            (repo.items.single as ActorNotification).actor.displayName,
            'Friend',
          );
        },
      );

      test(
        'a sender trusted after their mention arrived gets a name',
        () async {
          var trusted = false;
          final requested = <Set<String>>[];
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: InMemoryConcordStore(me),
            now: () => 1000,
            canNotify: (_) => trusted,
            loadActors: (authors) async {
              requested.add(authors);
              return [ActorInfo(pubkey: friend, displayName: 'Friend')];
            },
          );
          addTearDown(repo.close);
          await repo.enroll('general');
          repo.updateRoom('general', [message(friend, 1001)]);
          await pumpEventQueue();
          expect(repo.items, isEmpty);
          trusted = true;
          repo.reevaluate();
          await pumpEventQueue();
          expect(requested, [
            {friend},
          ]);
          expect(
            (repo.items.single as ActorNotification).actor.displayName,
            'Friend',
          );
        },
      );

      test(
        'a failed load keeps the fallback name and the next update retries',
        () async {
          var attempts = 0;
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: InMemoryConcordStore(me),
            now: () => 1000,
            canNotify: (_) => true,
            loadActors: (authors) async {
              if (++attempts == 1) throw Exception('cache unavailable');
              return [ActorInfo(pubkey: friend, displayName: 'Friend')];
            },
          );
          addTearDown(repo.close);
          await repo.enroll('general');
          repo.updateRoom('general', [message(friend, 1001)]);
          await pumpEventQueue();
          expect(
            (repo.items.single as ActorNotification).actor.displayName,
            UserProfile.defaultDisplayNameFor(friend),
          );
          repo.updateRoom('general', [message(friend, 1001)]);
          await pumpEventQueue();
          expect(attempts, 2);
          expect(
            (repo.items.single as ActorNotification).actor.displayName,
            'Friend',
          );
        },
      );
    });

    group('initialize', () {
      test(
        'enrollment and read state survive restart without plaintext copies',
        () async {
          final store = InMemoryConcordStore(me);
          ChatMentionRepository make() => ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
          );
          final first = make();
          await first.initialize();
          await first.enroll('general');
          first.updateRoom('general', [message(friend, 1001)]);
          await first.markSeen([first.items.single.id]);
          await first.close();
          final next = make();
          addTearDown(next.close);
          await next.initialize();
          next.updateRoom('general', [message(friend, 1001)]);
          expect(next.items.single.isRead, isTrue);
          next.updateRoom('introductions', [message(friend, 1002)]);
          expect(next.items, hasLength(1));
          expect(await store.get('mention-state'), isNot(contains('hello')));
        },
      );

      for (final unreadable in [
        'not json',
        '{"rooms":{"general":"soon"},"seen":{}}',
        '{"rooms":{}}',
      ]) {
        test(
          'an unreadable record starts empty and the next write replaces it: '
          '$unreadable',
          () async {
            final store = InMemoryConcordStore(me);
            await store.put('mention-state', unreadable);
            final repo = ChatMentionRepository(
              owner: me,
              communityId: 'community-test',
              store: store,
              now: () => 1000,
              canNotify: (_) => true,
            );
            addTearDown(repo.close);
            await repo.initialize();
            await repo.enroll('general');
            repo.updateRoom('general', [message(friend, 1001)]);
            expect(repo.items, hasLength(1));
            expect(
              jsonDecode((await store.get('mention-state'))!),
              {
                'rooms': {'general': 1000},
                'seen': <String, String>{},
              },
            );
          },
        );
      }

      test('a room that fails to start leaves the rest of the state loaded '
          'and refresh retries it', () async {
        final store = InMemoryConcordStore(me);
        await store.put(
          'mention-state',
          '{"rooms":{"general":900},"seen":{}}',
        );
        final room = _Room();
        when(room.close).thenAnswer((_) async {});
        when(() => room.changes).thenAnswer((_) => const Stream.empty());
        when(() => room.timeline(now: 1000)).thenReturn(FoldedThread([], {}));
        var starts = 0;
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (_) => room,
          startRoom: (_, _) async {
            if (++starts == 1) throw StateError('offline');
          },
        );
        addTearDown(repo.close);
        await repo.initialize();
        expect(starts, 1);
        repo.updateRoom('general', [message(friend, 1001)]);
        expect(repo.items, hasLength(1));
        await repo.refresh();
        expect(starts, 2);
      });
    });
    group('enroll while saved rooms start', () {
      test(
        'a saved room still starting does not delay stamping another',
        () async {
          final store = InMemoryConcordStore(me);
          await store.put(
            'mention-state',
            '{"rooms":{"general":900},"seen":{}}',
          );
          final held = Completer<void>();
          var clock = 1000;
          ConcordRepository room() {
            final room = _Room();
            when(room.close).thenAnswer((_) async {});
            when(() => room.changes).thenAnswer((_) => const Stream.empty());
            when(
              () => room.timeline(now: any(named: 'now')),
            ).thenReturn(FoldedThread([], {}));
            return room;
          }

          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => clock,
            canNotify: (_) => true,
            createRoom: (_) => room(),
            startRoom: (channel, _) async {
              if (channel == 'general') await held.future;
            },
          );
          addTearDown(() async {
            if (!held.isCompleted) held.complete();
            await repo.close();
          });
          final enrolling = repo.enroll('introductions');
          await pumpEventQueue();
          clock = 1100;
          held.complete();
          await enrolling;
          final saved = jsonDecode(
            (await store.get('mention-state'))!,
          ) as Map<String, dynamic>;
          expect((saved['rooms'] as Map)['introductions'], 1000);
        },
      );
    });

    group('enroll', () {
      test('a refresh skips a room whose enrollment failed mid-loop', () async {
        final store = _RefusedLaterStore(me);
        await store.put(
          'mention-state',
          '{"rooms":{"general":900},"seen":{}}',
        );
        final restarting = Completer<void>();
        final room = _Room();
        when(room.close).thenAnswer((_) async {});
        when(() => room.changes).thenAnswer((_) => const Stream.empty());
        when(
          () => room.timeline(now: any(named: 'now')),
        ).thenReturn(FoldedThread([], {}));
        final created = <String>[];
        var generalStarts = 0;
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (channel) {
            created.add(channel);
            return room;
          },
          startRoom: (channel, _) async {
            if (channel != 'general') return;
            if (++generalStarts == 1) throw StateError('offline');
            await restarting.future;
          },
        );
        addTearDown(repo.close);
        await repo.initialize();
        await pumpEventQueue();
        final write = store.held = Completer<void>();
        final enrolling = expectLater(
          repo.enroll('introductions'),
          throwsStateError,
        );
        await pumpEventQueue();
        final refreshing = repo.refresh();
        await pumpEventQueue();
        write.complete();
        await enrolling;
        restarting.complete();
        await refreshing;
        expect(created, ['general', 'general']);
      });

      test(
        'close waits for an observer a refused enrollment stopped',
        () async {
          final store = _RefusedLaterStore(me);
          final closing = Completer<void>();
          final room = _Room();
          when(room.close).thenAnswer((_) => closing.future);
          when(() => room.changes).thenAnswer((_) => const Stream.empty());
          when(
            () => room.timeline(now: any(named: 'now')),
          ).thenReturn(FoldedThread([], {}));
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
            createRoom: (_) => room,
            startRoom: (_, _) async {},
          );
          await repo.initialize();
          final write = store.held = Completer<void>();
          final enrolling = expectLater(
            repo.enroll('general'),
            throwsStateError,
          );
          await pumpEventQueue();
          await repo.refresh();
          write.complete();
          await enrolling;
          var closed = false;
          unawaited(repo.close().then((_) => closed = true));
          await pumpEventQueue();
          expect(closed, isFalse);
          closing.complete();
          await pumpEventQueue();
          expect(closed, isTrue);
        },
      );

      test(
        'an observer still starting when its enrollment fails stays down',
        () async {
          final store = _RefusedLaterStore(me);
          final starting = Completer<void>();
          final room = _Room();
          when(room.close).thenAnswer((_) async {});
          when(() => room.changes).thenAnswer((_) => const Stream.empty());
          when(
            () => room.timeline(now: any(named: 'now')),
          ).thenReturn(FoldedThread([message(friend, 1001)], {}));
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
            createRoom: (_) => room,
            startRoom: (_, _) => starting.future,
          );
          addTearDown(repo.close);
          await repo.initialize();
          final write = store.held = Completer<void>();
          final enrolling = expectLater(
            repo.enroll('general'),
            throwsStateError,
          );
          await pumpEventQueue();
          final refreshing = repo.refresh();
          await pumpEventQueue();
          write.complete();
          await enrolling;
          starting.complete();
          await refreshing;
          await pumpEventQueue();
          verify(room.close).called(1);
          verifyNever(() => room.changes);
          expect(repo.items, isEmpty);
        },
      );

      test(
        'a stopped observer failing late keeps the retried room tracked',
        () async {
          final store = _RefusedLaterStore(me);
          final starting = Completer<void>();
          final first = _Room();
          final second = _Room();
          for (final room in [first, second]) {
            when(room.close).thenAnswer((_) async {});
            when(() => room.changes).thenAnswer((_) => const Stream.empty());
            when(
              () => room.timeline(now: any(named: 'now')),
            ).thenReturn(FoldedThread([], {}));
          }
          final rooms = [first, second];
          var starts = 0;
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
            createRoom: (_) => rooms.removeAt(0),
            startRoom: (_, _) async {
              if (++starts == 1) {
                await starting.future;
                throw StateError('offline');
              }
            },
          );
          await repo.initialize();
          final write = store.held = Completer<void>();
          final enrolling = expectLater(
            repo.enroll('general'),
            throwsStateError,
          );
          await pumpEventQueue();
          final refreshing = repo.refresh();
          await pumpEventQueue();
          write.complete();
          await enrolling;
          await repo.enroll('general');
          starting.complete();
          await refreshing;
          await repo.close();
          expect(rooms, isEmpty);
          verify(second.close).called(1);
        },
      );

      test('a refused enrollment withdraws rows a refresh published', () async {
        final store = _RefusedLaterStore(me);
        final room = _Room();
        when(room.close).thenAnswer((_) async {});
        when(() => room.changes).thenAnswer((_) => const Stream.empty());
        when(
          () => room.timeline(now: any(named: 'now')),
        ).thenReturn(FoldedThread([message(friend, 1001)], {}));
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (_) => room,
          startRoom: (_, _) async {},
        );
        addTearDown(repo.close);
        await repo.initialize();
        final write = store.held = Completer<void>();
        final enrolling = expectLater(repo.enroll('general'), throwsStateError);
        await pumpEventQueue();
        await repo.refresh();
        expect(repo.items, hasLength(1));
        write.complete();
        await enrolling;
        expect(repo.items, isEmpty);
        await pumpEventQueue();
        verify(room.close).called(1);
      });

      test('failed enrollment and observer start can retry', () async {
        final store = _FailingStore(me)..fail = true;
        final room = _Room();
        when(room.close).thenAnswer((_) async {});
        when(() => room.changes).thenAnswer((_) => const Stream.empty());
        when(() => room.timeline(now: 1000)).thenReturn(FoldedThread([], {}));
        var starts = 0;
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (_) => room,
          startRoom: (_, _) async {
            if (++starts == 1) throw StateError('offline');
          },
        );
        addTearDown(repo.close);
        await expectLater(repo.enroll('general'), throwsStateError);
        await expectLater(repo.enroll('general'), throwsStateError);
        await repo.enroll('general');
        expect(starts, 2);
      });
    });
    group('close', () {
      test('a room still starting when the source closes stays down', () async {
        final store = InMemoryConcordStore(me);
        await store.put(
          'mention-state',
          '{"rooms":{"general":900},"seen":{}}',
        );
        final starting = Completer<void>();
        final room = _Room();
        when(room.close).thenAnswer((_) async {});
        when(() => room.changes).thenAnswer((_) => const Stream.empty());
        when(
          () => room.timeline(now: any(named: 'now')),
        ).thenReturn(FoldedThread([], {}));
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (_) => room,
          startRoom: (_, _) => starting.future,
        );
        await repo.initialize();
        await repo.close();
        starting.complete();
        await pumpEventQueue();
        verify(room.close).called(1);
        verifyNever(() => room.changes);
      });
    });

    group('refresh', () {
      test('close waits for a failed room a refresh is taking down', () async {
        final store = InMemoryConcordStore(me);
        await store.put(
          'mention-state',
          '{"rooms":{"general":900},"seen":{}}',
        );
        final changes = StreamController<void>.broadcast();
        addTearDown(changes.close);
        final closing = Completer<void>();
        final room = _Room();
        when(room.close).thenAnswer((_) => closing.future);
        when(() => room.changes).thenAnswer((_) => changes.stream);
        when(
          () => room.timeline(now: any(named: 'now')),
        ).thenReturn(FoldedThread([], {}));
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (_) => room,
          startRoom: (_, _) async {},
        );
        await repo.initialize();
        await pumpEventQueue();
        changes.addError(StateError('relay gave up'));
        await pumpEventQueue();
        unawaited(repo.refresh());
        await pumpEventQueue();
        var closed = false;
        unawaited(repo.close().then((_) => closed = true));
        await pumpEventQueue();
        expect(closed, isFalse);
        closing.complete();
        await pumpEventQueue();
        expect(closed, isTrue);
      });

      test(
        'observer stream errors preserve snapshots and later updates work',
        () async {
          final room = _Room();
          final changes = StreamController<void>.broadcast();
          addTearDown(changes.close);
          when(room.close).thenAnswer((_) async {});
          when(() => room.changes).thenAnswer((_) => changes.stream);
          var messages = <ChatMessage>[];
          when(() => room.timeline(now: 1000))
              .thenAnswer((_) => FoldedThread(messages, {}));
          var starts = 0;
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: InMemoryConcordStore(me),
            now: () => 1000,
            canNotify: (_) => true,
            createRoom: (_) => room,
            startRoom: (_, _) async {
              starts++;
            },
          );
          addTearDown(repo.close);
          await repo.enroll('general');
          changes.addError(StateError('offline'));
          messages = [message(friend, 1001)];
          final received = repo.watchSnapshot().firstWhere(
            (items) => items.isNotEmpty,
          );
          changes.add(null);
          expect(await received, hasLength(1));
          await repo.refresh();
          expect(starts, 2);
          expect(repo.items, hasLength(1));
        },
      );

      test('one failing room neither stops the others nor breaks on a room '
          'enrolled mid-refresh', () async {
        final store = InMemoryConcordStore(me);
        await store.put(
          'mention-state',
          '{"rooms":{"general":900,"introductions":900},"seen":{}}',
        );
        final starts = <String, int>{};
        final held = Completer<void>();
        ConcordRepository room() {
          final room = _Room();
          when(room.close).thenAnswer((_) async {});
          when(() => room.changes).thenAnswer((_) => const Stream.empty());
          when(() => room.timeline(now: 1000)).thenReturn(FoldedThread([], {}));
          return room;
        }

        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
          createRoom: (_) => room(),
          startRoom: (channel, _) async {
            final attempt = starts[channel] = (starts[channel] ?? 0) + 1;
            if (channel == 'general') {
              if (attempt == 2) await held.future;
              throw StateError('offline');
            }
            if (channel == 'introductions' && attempt == 1) {
              throw StateError('offline');
            }
          },
        );
        addTearDown(repo.close);
        await repo.initialize();
        final refreshing = repo.refresh();
        await pumpEventQueue();
        await repo.enroll('third');
        held.complete();
        await refreshing;
        expect(starts, {'general': 2, 'introductions': 2, 'third': 1});
      });
    });
    group('enroll and markSeen together', () {
      test(
        'a failed write never reaches disk through a concurrent one',
        () async {
          final store = _FailingStore(me);
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
          );
          addTearDown(repo.close);
          await repo.enroll('general');
          repo.updateRoom('general', [message(friend, 1001)]);
          final id = repo.items.single.id;
          store.fail = true;
          Future<bool> succeeded(Future<void> write) =>
              write.then((_) => true, onError: (Object _) => false);
          final enrolled = succeeded(repo.enroll('introductions'));
          final marked = succeeded(repo.markSeen([id]));
          final (enrollWorked, markWorked) = (await enrolled, await marked);
          expect(
            enrollWorked != markWorked,
            isTrue,
            reason: 'one write failed',
          );
          final saved = jsonDecode(
            (await store.get('mention-state'))!,
          ) as Map<String, dynamic>;
          expect(
            (saved['rooms'] as Map).keys,
            enrollWorked
                ? contains('introductions')
                : isNot(contains('introductions')),
          );
          expect(
            (saved['seen'] as Map).keys,
            markWorked ? contains(id) : isNot(contains(id)),
          );
        },
      );
    });

    group('markSeen', () {
      test('a refused read republishes the row as unread', () async {
        final store = _RefusedLaterStore(me);
        final repo = ChatMentionRepository(
          owner: me,
          communityId: 'community-test',
          store: store,
          now: () => 1000,
          canNotify: (_) => true,
        );
        addTearDown(repo.close);
        await repo.enroll('general');
        repo.updateRoom('general', [message(friend, 1001)]);
        final write = store.held = Completer<void>();
        final marking = expectLater(
          repo.markSeen([repo.items.single.id]),
          throwsStateError,
        );
        await pumpEventQueue();
        repo.reevaluate();
        expect(repo.items.single.isRead, isTrue);
        write.complete();
        await marking;
        expect(repo.items.single.isRead, isFalse);
      });

      test(
        'a mark-all before state loads does not overwrite saved rooms',
        () async {
          final store = _GatedStore(me);
          await store.put(
            'mention-state',
            '{"rooms":{"general":900},"seen":{}}',
          );
          store.puts = 0;
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
          );
          addTearDown(repo.close);
          final loading = repo.initialize();
          await repo.markSeen([for (final item in repo.items) item.id]);
          expect(store.puts, 0);
          store.gate.complete();
          await loading;
          expect(await store.get('mention-state'), contains('general'));
        },
      );

      test(
        'failed concurrent read does not roll back a later acknowledged read',
        () async {
          final store = _FailingStore(me);
          final repo = ChatMentionRepository(
            owner: me,
            communityId: 'community-test',
            store: store,
            now: () => 1000,
            canNotify: (_) => true,
          );
          addTearDown(repo.close);
          await repo.enroll('general');
          repo.updateRoom('general', [message(friend, 1001)]);
          final ids = [repo.items.single.id];
          store.fail = true;
          final failed = expectLater(repo.markSeen(ids), throwsStateError);
          final saved = repo.markSeen(ids);
          await failed;
          await saved;
          expect(repo.items.single.isRead, isTrue);
          repo.updateRoom('general', [message(friend, 1000)]);
          expect(repo.items.single.isRead, isTrue);
          repo.updateRoom('general', [message(friend, 1002)]);
          expect(repo.items.single.isRead, isFalse);
        },
      );
    });
  });
}
