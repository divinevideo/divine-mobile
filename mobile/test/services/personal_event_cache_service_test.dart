// ABOUTME: Tests for PersonalEventCacheService initialization race handling.
// ABOUTME: Ensures signed user events are not dropped while the store opens.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/personal_event_cache_service.dart';

import '../helpers/test_helpers.dart';

/// Wall-clock budget for waits that depend on Hive file I/O.
const Duration _settleTimeout = Duration(seconds: 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late PersonalEventCacheService service;

  final userPubkey = List.filled(64, 'a').join();
  final otherPubkey = List.filled(64, 'b').join();

  String hexId(int index) => index.toRadixString(16).padLeft(64, '0');

  Event createEvent({
    required String pubkey,
    required String id,
    String content = 'A plant video',
  }) {
    final event = Event(
      pubkey,
      32222,
      const [
        ['d', 'test-video-id'],
        ['title', 'Plants'],
      ],
      content,
      createdAt: 1700000000,
    );
    event.id = id;
    event.sig = id.padRight(128, '0').substring(0, 128);
    return event;
  }

  Future<void> waitForKindIndex(Event event) async {
    // cacheUserEvent is fire-and-forget: the event record is written before
    // its kind index. Wait for the index entry instead of assuming that one
    // event-loop pump means both Hive writes have completed.
    await TestHelpers.waitForCondition(
      () => service
          .getEventsByKind(event.kind)
          .any((cachedEvent) => cachedEvent.id == event.id),
      timeout: _settleTimeout,
      description: 'event ${event.id} to be added to kind ${event.kind} index',
    );
  }

  setUp(() async {
    // An in-memory database per test. Unlike the Hive boxes this replaced
    // (#6986), the store is not opened under a fixed global name, so nothing
    // leaks into the next file in the shared VGV isolate (#5738).
    database = AppDatabase.test(NativeDatabase.memory());
    service = PersonalEventCacheService(dao: database.personalEventsDao);
  });

  tearDown(() async {
    service.dispose();
    await database.close();
  });

  group('PersonalEventCacheService initialization', () {
    test('caches user events queued while initialize is in flight', () async {
      final event = createEvent(pubkey: userPubkey, id: hexId(1));

      final initialize = service.initialize(userPubkey);
      service.cacheUserEvent(event);

      await initialize;

      expect(service.isInitialized, isTrue);
      expect(service.hasEvent(event.id), isTrue);
      expect(service.getEventById(event.id)?.id, event.id);
      expect(
        service
            .getEventsByKind(event.kind)
            .map((cachedEvent) => cachedEvent.id),
        contains(event.id),
      );
    });

    test('drops queued events for a different user after initialize', () async {
      final otherUserEvent = createEvent(pubkey: otherPubkey, id: hexId(2));

      final initialize = service.initialize(userPubkey);
      service.cacheUserEvent(otherUserEvent);

      await initialize;

      expect(service.hasEvent(otherUserEvent.id), isFalse);
      expect(service.getEventById(otherUserEvent.id), isNull);
    });

    test(
      'filters queued events by pubkey when no user was known at queue time',
      () async {
        // No initialize() has run yet, so _currentUserPubkey is null and the
        // queue-time pubkey filter cannot apply. The filter must instead kick in
        // when the queue is flushed after initialization resolves the pubkey.
        final ownEvent = createEvent(pubkey: userPubkey, id: hexId(3));
        final foreignEvent = createEvent(pubkey: otherPubkey, id: hexId(4));

        service.cacheUserEvent(ownEvent);
        service.cacheUserEvent(foreignEvent);

        await service.initialize(userPubkey);

        expect(service.hasEvent(ownEvent.id), isTrue);
        expect(service.hasEvent(foreignEvent.id), isFalse);
      },
    );

    test(
      'keeps only the latest queued write for a repeated event id',
      () async {
        final stale = createEvent(
          pubkey: userPubkey,
          id: hexId(5),
          content: 'stale content',
        );
        final fresh = createEvent(
          pubkey: userPubkey,
          id: hexId(5),
          content: 'fresh content',
        );

        service.cacheUserEvent(stale);
        service.cacheUserEvent(fresh);

        await service.initialize(userPubkey);

        expect(service.getEventById(hexId(5))?.content, 'fresh content');
      },
    );

    test('drops the oldest queued event past the pending-write cap', () async {
      const pendingWriteCap = 100;
      // Queue one more than the cap before initialization completes; the
      // first-queued (oldest) event must be evicted to honor the bound.
      for (var i = 0; i <= pendingWriteCap; i++) {
        service.cacheUserEvent(createEvent(pubkey: userPubkey, id: hexId(i)));
      }

      await service.initialize(userPubkey);

      expect(service.hasEvent(hexId(0)), isFalse);
      expect(service.hasEvent(hexId(1)), isTrue);
      expect(service.hasEvent(hexId(pendingWriteCap)), isTrue);
      expect(service.getEventsByKind(32222), hasLength(pendingWriteCap));
    });

    test(
      'dispose prevents in-flight initialize from resurrecting cache',
      () async {
        final event = createEvent(pubkey: userPubkey, id: hexId(101));

        final initialize = service.initialize(userPubkey);
        service.cacheUserEvent(event);
        service.dispose();

        await initialize;

        expect(service.isInitialized, isFalse);
        expect(service.hasEvent(event.id), isFalse);
        expect(service.getEventById(event.id), isNull);
      },
    );

    test('reads only return events for the current initialized user', () async {
      final userEvent = createEvent(pubkey: userPubkey, id: hexId(201));
      final otherUserEvent = createEvent(pubkey: otherPubkey, id: hexId(202));

      await service.initialize(userPubkey);
      service.cacheUserEvent(userEvent);
      await waitForKindIndex(userEvent);

      await service.initialize(otherPubkey);
      service.cacheUserEvent(otherUserEvent);
      await waitForKindIndex(otherUserEvent);

      expect(service.hasEvent(userEvent.id), isFalse);
      expect(service.getEventById(userEvent.id), isNull);
      expect(service.hasEvent(otherUserEvent.id), isTrue);
      expect(service.getEventById(otherUserEvent.id)?.id, otherUserEvent.id);
      expect(
        service.getEventsByKind(32222).map((event) => event.id),
        containsAll(<String>[otherUserEvent.id]),
      );
      expect(
        service.getEventsByKind(32222).map((event) => event.id),
        isNot(contains(userEvent.id)),
      );
    });

    test(
      'resetCurrentUser makes cached events unreadable until reauth',
      () async {
        final event = createEvent(pubkey: userPubkey, id: hexId(203));

        await service.initialize(userPubkey);
        service.cacheUserEvent(event);
        await waitForKindIndex(event);
        expect(service.hasEvent(event.id), isTrue);

        service.resetCurrentUser();

        expect(service.isInitialized, isFalse);
        expect(service.hasEvent(event.id), isFalse);
        expect(service.getEventById(event.id), isNull);

        await service.initialize(userPubkey);

        expect(service.hasEvent(event.id), isTrue);
      },
    );
  });

  group('PersonalEventCacheService retention', () {
    Event contactList(int createdAt) {
      final event = Event(
        userPubkey,
        3,
        const [
          ['p', 'a'],
        ],
        '',
        createdAt: createdAt,
      );
      event.id = hexId(createdAt);
      event.sig = event.id.padRight(128, '0').substring(0, 128);
      return event;
    }

    test('collapses contact-list history to the newest event', () async {
      // Every follow, unfollow, block, unblock and automatic re-broadcast
      // used to append a full kind-3 list that was never evicted (#6986).
      await service.initialize(userPubkey);

      for (var i = 1; i <= 20; i++) {
        service.cacheUserEvent(contactList(1700000000 + i));
        await TestHelpers.waitForCondition(
          () => service
              .getEventsByKind(3)
              .any((event) => event.createdAt == 1700000000 + i),
          timeout: _settleTimeout,
          description: 'contact list $i to be cached',
        );
      }

      final lists = service.getEventsByKind(3);
      expect(lists, hasLength(1));
      expect(lists.single.createdAt, 1700000020);
      expect(await database.personalEventsDao.countForOwner(userPubkey), 1);
    });

    test('an older contact list does not replace a newer one', () async {
      await service.initialize(userPubkey);

      service.cacheUserEvent(contactList(1700000010));
      await TestHelpers.waitForCondition(
        () => service.getEventsByKind(3).isNotEmpty,
        timeout: _settleTimeout,
        description: 'newer contact list to be cached',
      );

      service.cacheUserEvent(contactList(1700000000));
      await pumpEventQueue();

      final lists = service.getEventsByKind(3);
      expect(lists, hasLength(1));
      expect(lists.single.createdAt, 1700000010);
    });

    test('survives the shared event cache expiry sweep', () async {
      // deleteExpiredEvents removes rows whose expire_at IS NULL as well as
      // past-dated ones, which is why personal events do not live in the
      // shared `event` table (#6986).
      await service.initialize(userPubkey);
      final event = createEvent(pubkey: userPubkey, id: hexId(301));
      service.cacheUserEvent(event);
      await waitForKindIndex(event);

      await database.nostrEventsDao.deleteExpiredEvents(null);
      await service.initialize(userPubkey);

      expect(service.hasEvent(event.id), isTrue);
    });

    test('a failing durable write does not throw to the caller', () async {
      // `cacheUserEvent` is called from the publish path, which must not fail
      // because a cache write did. There was no test for this before #6986.
      await service.initialize(userPubkey);
      await database.close();

      final event = createEvent(pubkey: userPubkey, id: hexId(302));

      expect(() => service.cacheUserEvent(event), returnsNormally);
      await pumpEventQueue();

      // The in-memory mirror still answers, so a retry in the same session
      // can still find the signed event it just wrote.
      expect(service.getEventById(event.id), isNotNull);

      // Re-open so tearDown's close() does not throw on an already-closed db.
      database = AppDatabase.test(NativeDatabase.memory());
    });
  });
}
