// ABOUTME: Tests EventRouter batch caching + transaction-wrapped kind routing
// ABOUTME: Verifies events are stored and kind 0 profiles extracted in one batch

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/event_router.dart';

void main() {
  group(EventRouter, () {
    late AppDatabase db;
    late EventRouter router;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      router = EventRouter(
        db,
        config: const EventRouterConfig(autoStart: false),
      );
    });

    tearDown(() async {
      router.dispose();
      await db.close();
    });

    /// Returns a 64-hex pubkey derived from [seed] (valid per `keyIsValid`).
    String pubkeyFor(int seed) => seed.toRadixString(16).padLeft(64, '0');

    Event videoEvent(int seed) =>
        Event(pubkeyFor(seed), NIP71VideoKinds.addressableShortVideo, const [
          ['url', 'https://example.com/video.mp4'],
        ], 'video $seed');

    Event profileEvent(int seed, {required String content}) =>
        Event(pubkeyFor(seed), 0, const [], content);

    /// Drives [events] through the deterministic test drain.
    Future<void> flush(List<Event> events) async {
      events.forEach(router.handleEvent);
      await router.drainForTesting();
    }

    test('stores every event in the batch in the nostr_events table', () async {
      final video = videoEvent(1);
      final profile = profileEvent(2, content: jsonEncode({'name': 'alice'}));

      await flush([video, profile]);

      expect(await db.nostrEventsDao.getEventById(video.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(profile.id), isNotNull);
    });

    test('extracts multiple kind 0 profiles from a single batch', () async {
      final alice = profileEvent(2, content: jsonEncode({'name': 'alice'}));
      final bob = profileEvent(3, content: jsonEncode({'name': 'bob'}));

      await flush([alice, bob]);

      final aliceProfile = await db.userProfilesDao.getProfile(alice.pubkey);
      final bobProfile = await db.userProfilesDao.getProfile(bob.pubkey);
      expect(aliceProfile?.name, equals('alice'));
      expect(bobProfile?.name, equals('bob'));
    });

    test('does not re-create the profile of an account that requested '
        'deletion', () async {
      // This router writes to UserProfilesDao directly rather than through
      // ProfileRepository, so it is the path a non-compliant relay would use
      // to resurrect an evicted account minutes after the eviction.
      final deleted = profileEvent(2, content: jsonEncode({'name': 'alice'}));
      await db.vanishedProfilesDao.markVanished(deleted.pubkey);

      await flush([deleted]);

      expect(await db.userProfilesDao.getProfile(deleted.pubkey), isNull);
    });

    test('routes a profile again once the vanish is cleared', () async {
      final recovered = profileEvent(2, content: jsonEncode({'name': 'alice'}));
      await db.vanishedProfilesDao.markVanished(recovered.pubkey);
      await flush([recovered]);

      await db.vanishedProfilesDao.clearVanished(recovered.pubkey);
      await flush([recovered]);

      final profile = await db.userProfilesDao.getProfile(recovered.pubkey);
      expect(profile?.name, equals('alice'));
    });

    test('a malformed profile does not abort routing for the rest of the '
        'batch', () async {
      final broken = profileEvent(2, content: 'not-json-{');
      final valid = profileEvent(3, content: jsonEncode({'name': 'carol'}));
      final video = videoEvent(4);

      await flush([broken, valid, video]);

      // The valid profile and the raw events are still persisted.
      expect(
        (await db.userProfilesDao.getProfile(valid.pubkey))?.name,
        equals('carol'),
      );
      expect(await db.nostrEventsDao.getEventById(video.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(broken.id), isNotNull);
    });

    test('drains visible events before background events', () async {
      final background = profileEvent(
        10,
        content: jsonEncode({'name': 'background'}),
      );
      final visible = profileEvent(
        11,
        content: jsonEncode({'name': 'visible'}),
      );

      router.dispose();
      router = EventRouter(
        db,
        config: const EventRouterConfig(autoStart: false, maxBatchSize: 1),
      );

      router.handleEvent(
        background,
        priority: EventIngestionPriority.background,
      );
      router.handleEvent(visible, priority: EventIngestionPriority.visible);

      await router.drainOneBatchForTesting();

      expect(await db.nostrEventsDao.getEventById(visible.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(background.id), isNull);
    });

    test(
      'yields between bounded batches so large drains are cooperative',
      () async {
        var yieldCount = 0;
        router.dispose();
        router = EventRouter(
          db,
          config: const EventRouterConfig(autoStart: false, maxBatchSize: 10),
          yieldToEventLoop: () async {
            yieldCount++;
          },
        );

        final events = List.generate(25, (i) => videoEvent(2000 + i));
        events.forEach(router.handleEvent);

        await router.drainForTesting();

        expect(yieldCount, greaterThanOrEqualTo(2));
        for (final event in events) {
          expect(await db.nostrEventsDao.getEventById(event.id), isNotNull);
        }
      },
    );

    test('stores all raw profile events but routes only the latest profile per '
        'pubkey', () async {
      final pubkey = pubkeyFor(44);
      final older = Event(
        pubkey,
        0,
        const [],
        jsonEncode({'name': 'old'}),
        createdAt: 100,
      );
      final latest = Event(
        pubkey,
        0,
        const [],
        jsonEncode({'name': 'new'}),
        createdAt: 200,
      );

      router.handleEvent(older);
      router.handleEvent(latest);

      await router.drainForTesting();

      expect(await db.nostrEventsDao.getEventById(older.id), isNotNull);
      expect(await db.nostrEventsDao.getEventById(latest.id), isNotNull);
      expect(
        (await db.userProfilesDao.getProfile(pubkey))?.name,
        equals('new'),
      );
    });

    test('replaces superseded addressable video rows for the same '
        'coordinate', () async {
      final pubkey = pubkeyFor(55);
      final older = Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        const [
          ['d', 'clip-1'],
          ['url', 'https://example.com/old.mp4'],
        ],
        'old',
        createdAt: 100,
      );
      final latest = Event(
        pubkey,
        NIP71VideoKinds.addressableShortVideo,
        const [
          ['d', 'clip-1'],
          ['url', 'https://example.com/new.mp4'],
        ],
        'new',
        createdAt: 200,
      );

      router.handleEvent(older);
      router.handleEvent(latest);

      await router.drainForTesting();

      // Same pubkey+kind+d-tag: the older raw row is deleted so cache-first
      // LIMIT queries don't return a stale duplicate of the edited video.
      expect(await db.nostrEventsDao.getEventById(older.id), isNull);
      expect(await db.nostrEventsDao.getEventById(latest.id), isNotNull);
    });

    test('ignores events enqueued after dispose', () async {
      final event = videoEvent(77);

      router.dispose();
      router.handleEvent(event);

      // A late relay callback after dispose must not re-arm a drain that
      // would run SQLite against a closing/closed database.
      await router.drainForTesting();

      expect(await db.nostrEventsDao.getEventById(event.id), isNull);
    });

    test('queuedLength reflects the number of enqueued events', () {
      router.handleEvent(
        profileEvent(1, content: jsonEncode({'name': 'a'})),
        priority: EventIngestionPriority.background,
      );
      router.handleEvent(
        videoEvent(2),
        priority: EventIngestionPriority.visible,
      );

      expect(router.queuedLength, equals(2));
    });

    test(
      'shedLowPriority drops background and normal but keeps visible',
      () async {
        router.handleEvent(
          videoEvent(1),
          priority: EventIngestionPriority.background,
        );
        // Enqueued at the default (normal) priority.
        router.handleEvent(videoEvent(2));
        final visible = videoEvent(3);
        router.handleEvent(visible, priority: EventIngestionPriority.visible);
        expect(router.queuedLength, equals(3));

        final dropped = router.shedLowPriority();

        expect(dropped, equals(2));
        expect(router.droppedEventCount, equals(2));
        expect(router.queuedLength, equals(1));

        // The retained visible event still persists on the next drain.
        await router.drainForTesting();
        expect(await db.nostrEventsDao.getEventById(visible.id), isNotNull);
      },
    );

    test('shedLowPriority is a no-op after dispose', () {
      router.handleEvent(
        videoEvent(1),
        priority: EventIngestionPriority.background,
      );
      router.dispose();

      expect(router.shedLowPriority(), equals(0));
      expect(router.droppedEventCount, equals(0));
    });

    test(
      'handleEvent enqueues without synchronously persisting the event',
      () async {
        final event = videoEvent(99);

        router.handleEvent(event, priority: EventIngestionPriority.background);

        // Enqueue is intentionally fire-and-forget. Persistence happens when the
        // cooperative router drain runs, so the relay callback can keep updating
        // in-memory UI state.
        expect(await db.nostrEventsDao.getEventById(event.id), isNull);

        await router.drainForTesting();

        expect(await db.nostrEventsDao.getEventById(event.id), isNotNull);
      },
    );

    group('dropQueuedEvents', () {
      test('removes matching pending writes across every priority', () async {
        final visible = videoEvent(6001);
        final normal = videoEvent(6002);
        final background = videoEvent(6003);
        final keeper = videoEvent(6004);

        router
          ..handleEvent(visible, priority: EventIngestionPriority.visible)
          ..handleEvent(normal)
          ..handleEvent(background, priority: EventIngestionPriority.background)
          ..handleEvent(keeper, priority: EventIngestionPriority.background);

        final dropped = router.dropQueuedEvents({
          visible.id,
          normal.id,
          background.id,
        });

        expect(dropped, equals(3));
        expect(router.queuedLength, equals(1));

        await router.drainForTesting();

        expect(await db.nostrEventsDao.getEventById(visible.id), isNull);
        expect(await db.nostrEventsDao.getEventById(normal.id), isNull);
        expect(await db.nostrEventsDao.getEventById(background.id), isNull);
        expect(await db.nostrEventsDao.getEventById(keeper.id), isNotNull);
      });

      test('ignores ids that are not queued', () {
        router.handleEvent(videoEvent(6010));

        expect(router.dropQueuedEvents({videoEvent(6011).id}), equals(0));
        expect(router.queuedLength, equals(1));
      });

      test('is a no-op after dispose', () {
        final event = videoEvent(6020);
        router
          ..handleEvent(event)
          ..dispose();

        expect(router.dropQueuedEvents({event.id}), equals(0));
      });
    });

    group('maxQueueDepth', () {
      test('bounds the queue and drops events once the cap is exceeded', () {
        router.dispose();
        router = EventRouter(
          db,
          config: const EventRouterConfig(autoStart: false, maxQueueDepth: 500),
        );

        for (var i = 0; i < 5000; i++) {
          router.handleEvent(
            videoEvent(3000 + i),
            priority: EventIngestionPriority.background,
          );
        }

        expect(router.queuedLength, lessThanOrEqualTo(500));
        expect(router.droppedEventCount, greaterThan(0));
      });

      test('drops oldest background events but never visible ones', () async {
        router.dispose();
        router = EventRouter(
          db,
          config: const EventRouterConfig(autoStart: false, maxQueueDepth: 10),
        );

        final visible = List.generate(5, (i) => videoEvent(4000 + i));
        for (final event in visible) {
          router.handleEvent(event, priority: EventIngestionPriority.visible);
        }

        // Flood background well past the cap to force drops.
        for (var i = 0; i < 200; i++) {
          router.handleEvent(
            videoEvent(5000 + i),
            priority: EventIngestionPriority.background,
          );
        }

        expect(router.queuedLength, lessThanOrEqualTo(10));
        expect(router.droppedEventCount, greaterThan(0));

        // Every visible event survives the bound and still persists.
        await router.drainForTesting();
        for (final event in visible) {
          expect(await db.nostrEventsDao.getEventById(event.id), isNotNull);
        }
      });

      test('is unbounded by default so existing callers are unaffected', () {
        // Default config leaves maxQueueDepth null.
        for (var i = 0; i < 1000; i++) {
          router.handleEvent(
            videoEvent(6000 + i),
            priority: EventIngestionPriority.background,
          );
        }

        expect(router.queuedLength, equals(1000));
        expect(router.droppedEventCount, equals(0));
      });
    });

    group('unsupported routing kinds', () {
      test('raw-caches kind 3 (contacts) and kind 7 (reactions) without '
          'denormalizing them', () async {
        final contacts = Event(pubkeyFor(80), 3, const [], '');
        final reaction = Event(pubkeyFor(81), 7, const [], '+');

        await flush([contacts, reaction]);

        // Both are stored raw in the events table...
        expect(await db.nostrEventsDao.getEventById(contacts.id), isNotNull);
        expect(await db.nostrEventsDao.getEventById(reaction.id), isNotNull);
        // ...but neither is denormalized: _routeEvent is a no-op for these
        // kinds, so no profile (or any other derived row) is written.
        expect(await db.userProfilesDao.getProfile(contacts.pubkey), isNull);
        expect(await db.userProfilesDao.getProfile(reaction.pubkey), isNull);
      });
    });

    group('autoStart ingestion path', () {
      test('flushes immediately when the batch reaches maxBatchSize', () async {
        final r = EventRouter(
          db,
          config: const EventRouterConfig(maxBatchSize: 3),
        );
        addTearDown(r.dispose);
        final events = [videoEvent(93), videoEvent(94), videoEvent(95)];

        r.handleEvent(events[0]);
        r.handleEvent(events[1]);
        // Below the threshold: a flush timer is armed, nothing drained yet.
        expect(r.queuedLength, equals(2));

        r.handleEvent(events[2]);
        // Reaching maxBatchSize cancels the timer and drains synchronously
        // (the batch is dequeued before the first await in _processNextBatch).
        expect(r.queuedLength, equals(0));

        await pumpEventQueue();
        for (final event in events) {
          expect(await db.nostrEventsDao.getEventById(event.id), isNotNull);
        }
      });

      test('arms a flush timer that drains the queue on elapse', () {
        fakeAsync((async) {
          final r = EventRouter(
            db,
            config: const EventRouterConfig(
              flushDelay: Duration(milliseconds: 20),
              maxBatchSize: 10,
            ),
          );

          r.handleEvent(videoEvent(90));
          // Timer armed but not yet fired.
          expect(r.queuedLength, equals(1));

          async.elapse(const Duration(milliseconds: 20));
          // Timer fired: _takeNextBatch dequeues synchronously, so the queue
          // is empty even though the DB write completes on the real loop
          // (asserting queuedLength here needs no DB under the fake clock).
          expect(r.queuedLength, equals(0));

          r.dispose();
        });
      });

      test('persists an enqueued event without a manual drain', () async {
        final r = EventRouter(
          db,
          config: const EventRouterConfig(flushDelay: Duration.zero),
        );
        addTearDown(r.dispose);
        final event = videoEvent(91);

        r.handleEvent(event);
        // Duration.zero takes the immediate branch; pump the real event loop
        // so the fire-and-forget persist completes.
        await pumpEventQueue();

        expect(await db.nostrEventsDao.getEventById(event.id), isNotNull);
      });

      test(
        'swallows a persistence error so ingestion is not aborted',
        () async {
          // Close the shared database so the DAO throws mid-persist. The group
          // tearDown closes it again, which drift tolerates.
          await db.close();

          router.handleEvent(videoEvent(92));

          // drainForTesting must complete without rethrowing, and the batch is
          // still consumed (the error is caught and logged in _persistBatch).
          await router.drainForTesting();

          expect(router.queuedLength, equals(0));
        },
      );
    });
  });
}
