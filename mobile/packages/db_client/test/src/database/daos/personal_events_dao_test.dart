// ABOUTME: Tests for PersonalEventsDao retention, owner scoping and reads.
// ABOUTME: Pins that personal events survive the shared-event expiry sweep.

import 'dart:io';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  late AppDatabase database;
  late PersonalEventsDao dao;
  late String tempDbPath;

  const owner =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const otherOwner =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  Event createEvent({
    required int createdAt,
    String pubkey = owner,
    int kind = 1,
    List<List<String>>? tags,
    String content = 'content',
  }) =>
      Event(pubkey, kind, tags ?? const [], content, createdAt: createdAt)
        ..sig = 'sig$pubkey';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('personal_events_dao_');
    tempDbPath = '${tempDir.path}/test.db';
    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.personalEventsDao;
  });

  tearDown(() async {
    await database.close();
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('PersonalEventsDao', () {
    group('upsertPersonalEvent', () {
      test('stores an event and reads it back intact', () async {
        final event = createEvent(
          kind: 34236,
          tags: [
            ['d', 'video-1'],
            ['title', 'A vine'],
          ],
          createdAt: 1700000000,
        );

        await dao.upsertPersonalEvent(event);

        final stored = await dao.getById(pubkey: owner, id: event.id);
        expect(stored, isNotNull);
        expect(stored!.id, event.id);
        expect(stored.kind, 34236);
        expect(stored.content, 'content');
        expect(stored.sig, event.sig);
        expect(stored.createdAt, 1700000000);
        expect(stored.tags, event.tags);
      });

      test('collapses a replaceable kind to one row per owner', () async {
        // Every follow/unfollow used to append a full kind-3 contact list that
        // was never evicted (#6986).
        for (var i = 0; i < 25; i++) {
          await dao.upsertPersonalEvent(
            createEvent(kind: 3, createdAt: 1700000000 + i),
          );
        }

        final lists = await dao.getByKind(pubkey: owner, kind: 3);
        expect(lists, hasLength(1));
        expect(lists.single.createdAt, 1700000024);
      });

      test('an older collapsing write does not replace a newer row', () async {
        // The Hive store this replaced kept every version and let readers
        // sort, so an out-of-order write could not surface an older event.
        await dao.upsertPersonalEvent(
          createEvent(kind: 3, content: 'newer', createdAt: 1700000010),
        );
        await dao.upsertPersonalEvent(
          createEvent(kind: 3, content: 'older', createdAt: 1700000000),
        );

        final rows = await dao.getByKind(pubkey: owner, kind: 3);
        expect(rows, hasLength(1));
        expect(rows.single.content, 'newer');
      });

      test(
        'a same-second collapsing write replaces rather than drops',
        () async {
          // Nostr created_at is second-resolution, so two publishes inside one
          // second collide. Dropping the later one would lose a real write.
          await dao.upsertPersonalEvent(
            createEvent(kind: 3, content: 'first', createdAt: 1700000000),
          );
          await dao.upsertPersonalEvent(
            createEvent(kind: 3, content: 'second', createdAt: 1700000000),
          );

          final rows = await dao.getByKind(pubkey: owner, kind: 3);
          expect(rows, hasLength(1));
          expect(rows.single.content, 'second');
        },
      );

      test('collapses kind 0 and 10000-range kinds too', () async {
        for (final kind in [0, 10002]) {
          await dao.upsertPersonalEvent(
            createEvent(kind: kind, createdAt: 1700000000),
          );
          await dao.upsertPersonalEvent(
            createEvent(kind: kind, createdAt: 1700000001),
          );
          final rows = await dao.getByKind(pubkey: owner, kind: kind);
          expect(rows, hasLength(1), reason: 'kind $kind should collapse');
          expect(rows.single.createdAt, 1700000001);
        }
      });

      test('keeps non-replaceable kinds side by side', () async {
        for (var i = 0; i < 5; i++) {
          await dao.upsertPersonalEvent(
            createEvent(
              kind: 34236,
              tags: [
                ['d', 'video-$i'],
              ],
              createdAt: 1700000000 + i,
            ),
          );
        }

        expect(await dao.getByKind(pubkey: owner, kind: 34236), hasLength(5));
      });

      test('a collapsing write does not disturb another owner', () async {
        await dao.upsertPersonalEvent(
          createEvent(pubkey: otherOwner, kind: 3, createdAt: 1700000000),
        );
        await dao.upsertPersonalEvent(
          createEvent(kind: 3, createdAt: 1700000001),
        );

        expect(await dao.getByKind(pubkey: owner, kind: 3), hasLength(1));
        expect(await dao.getByKind(pubkey: otherOwner, kind: 3), hasLength(1));
      });

      test(
        'trims the durable set to the cap, keeping the newest',
        () async {
          for (var i = 0; i < maxDurablePersonalEventsPerOwner + 20; i++) {
            await dao.upsertPersonalEvent(
              createEvent(
                kind: 34236,
                tags: [
                  ['d', 'video-$i'],
                ],
                createdAt: 1700000000 + i,
              ),
            );
          }

          final rows = await dao.getAllForOwner(owner);
          expect(rows, hasLength(maxDurablePersonalEventsPerOwner));
          // Newest survives, oldest is gone.
          expect(rows.first.createdAt, 1700000219);
          expect(rows.last.createdAt, 1700000020);
        },
      );

      test('the cap is per owner, not global', () async {
        for (var i = 0; i < maxDurablePersonalEventsPerOwner; i++) {
          await dao.upsertPersonalEvent(
            createEvent(
              kind: 34236,
              tags: [
                ['d', 'a-$i'],
              ],
              createdAt: 1700000000 + i,
            ),
          );
        }
        await dao.upsertPersonalEvent(
          createEvent(
            pubkey: otherOwner,
            kind: 34236,
            tags: [
              ['d', 'b-0'],
            ],
            createdAt: 1700000000,
          ),
        );

        expect(
          await dao.countForOwner(owner),
          maxDurablePersonalEventsPerOwner,
        );
        expect(await dao.countForOwner(otherOwner), 1);
      });

      test('collapsing rows are not trimmed by the durable cap', () async {
        await dao.upsertPersonalEvent(
          createEvent(kind: 3, createdAt: 1600000000),
        );
        for (var i = 0; i < maxDurablePersonalEventsPerOwner + 5; i++) {
          await dao.upsertPersonalEvent(
            createEvent(
              kind: 34236,
              tags: [
                ['d', 'video-$i'],
              ],
              createdAt: 1700000000 + i,
            ),
          );
        }

        // The kind 3 row has the oldest created_at of all, so a global trim
        // would have evicted it first.
        expect(await dao.getByKind(pubkey: owner, kind: 3), hasLength(1));
      });
    });

    group('reads', () {
      test("getById does not return another owner's event", () async {
        final event = createEvent(pubkey: otherOwner, createdAt: 1700000000);
        await dao.upsertPersonalEvent(event);

        expect(await dao.getById(pubkey: owner, id: event.id), isNull);
        expect(await dao.getById(pubkey: otherOwner, id: event.id), isNotNull);
      });

      test('hasEvent is owner-scoped', () async {
        final event = createEvent(pubkey: otherOwner, createdAt: 1700000000);
        await dao.upsertPersonalEvent(event);

        expect(await dao.hasEvent(pubkey: owner, id: event.id), isFalse);
        expect(await dao.hasEvent(pubkey: otherOwner, id: event.id), isTrue);
      });

      test('getByKind returns newest first', () async {
        for (final createdAt in [1700000002, 1700000000, 1700000001]) {
          await dao.upsertPersonalEvent(
            createEvent(
              kind: 34236,
              tags: [
                ['d', 'video-$createdAt'],
              ],
              createdAt: createdAt,
            ),
          );
        }

        final rows = await dao.getByKind(pubkey: owner, kind: 34236);
        expect(
          rows.map((e) => e.createdAt),
          [1700000002, 1700000001, 1700000000],
        );
      });

      test('getAllForOwner excludes other owners', () async {
        await dao.upsertPersonalEvent(createEvent(createdAt: 1700000000));
        await dao.upsertPersonalEvent(
          createEvent(pubkey: otherOwner, createdAt: 1700000001),
        );

        final rows = await dao.getAllForOwner(owner);
        expect(rows, hasLength(1));
        expect(rows.single.pubkey, owner);
      });
    });

    group('deletion', () {
      test('deleteAllForOwner leaves other owners intact', () async {
        await dao.upsertPersonalEvent(createEvent(createdAt: 1700000000));
        await dao.upsertPersonalEvent(
          createEvent(pubkey: otherOwner, createdAt: 1700000000),
        );

        await dao.deleteAllForOwner(owner);

        expect(await dao.countForOwner(owner), 0);
        expect(await dao.countForOwner(otherOwner), 1);
      });

      test('deleteAll clears every owner', () async {
        await dao.upsertPersonalEvent(createEvent(createdAt: 1700000000));
        await dao.upsertPersonalEvent(
          createEvent(pubkey: otherOwner, createdAt: 1700000000),
        );

        await dao.deleteAll();

        expect(await dao.countForOwner(owner), 0);
        expect(await dao.countForOwner(otherOwner), 0);
      });
    });

    group('isolation from the shared event cache sweep', () {
      test(
        'deleteExpiredEvents does not touch personal events',
        () async {
          // `deleteExpiredEvents` removes rows whose expire_at IS NULL as well
          // as past-dated ones. personal_events has no expire_at column at
          // all, so the sweep cannot reach it (#6986).
          await dao.upsertPersonalEvent(
            createEvent(kind: 3, createdAt: 1700000000),
          );
          await dao.upsertPersonalEvent(
            createEvent(
              kind: 34236,
              tags: [
                ['d', 'video-1'],
              ],
              createdAt: 1700000001,
            ),
          );

          await database.nostrEventsDao.deleteExpiredEvents(null);

          expect(await dao.countForOwner(owner), 2);
        },
      );
    });
  });
}
