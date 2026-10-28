import 'dart:async';
import 'dart:convert';

import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/features/chat/chat_mention_repository.dart';

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
    id: id ?? '$time'.padLeft(64, '0'),
    channelId: 'general',
    author: author,
    body: 'hello',
    createdAt: time,
    mentionedPubkeys: tagged ? [me] : [],
  );
  group('reevaluate', () {
    test(
      'only explicit recent mentions from trusted senders produce a grouped row',
      () async {
        var blocked = false;
        final repo = ChatMentionRepository(
          owner: me,
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
  group('initialize', () {
    test(
      'enrollment and read state survive restart without plaintext copies',
      () async {
        final store = InMemoryConcordStore(me);
        ChatMentionRepository make() => ChatMentionRepository(
          owner: me,
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
      test('an unreadable record starts empty and the next write replaces it: '
          '$unreadable', () async {
        final store = InMemoryConcordStore(me);
        await store.put('mention-state', unreadable);
        final repo = ChatMentionRepository(
          owner: me,
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
      });
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
  group('enroll', () {
    test('failed enrollment and observer start can retry', () async {
      final store = _FailingStore(me)..fail = true;
      final room = _Room();
      when(room.close).thenAnswer((_) async {});
      when(() => room.changes).thenAnswer((_) => const Stream.empty());
      when(() => room.timeline(now: 1000)).thenReturn(FoldedThread([], {}));
      var starts = 0;
      final repo = ChatMentionRepository(
        owner: me,
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
  group('refresh', () {
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
  group('markSeen', () {
    test(
      'a mark-all before state loads does not overwrite saved rooms',
      () async {
        final store = _GatedStore(me);
        await store.put('mention-state', '{"rooms":{"general":900},"seen":{}}');
        store.puts = 0;
        final repo = ChatMentionRepository(
          owner: me,
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
}
