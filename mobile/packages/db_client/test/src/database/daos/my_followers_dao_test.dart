// ABOUTME: Covers durable followers, monotonic dates and owner isolation.
// ABOUTME: Exercises the real SQLite DAO, including batched subset reads.

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final ownerA = 'a' * 64;
  final ownerB = 'b' * 64;
  String pubkey(int value) => value.toRadixString(16).padLeft(64, '0');
  late AppDatabase database;
  late MyFollowersDao dao;

  setUp(() {
    database = AppDatabase.test(NativeDatabase.memory());
    dao = database.myFollowersDao;
  });

  tearDown(() => database.close());

  group('MyFollowersDao', () {
    test('reads and subsets are scoped to the owner', () async {
      await dao.upsertAll(
        ownerPubkey: ownerA,
        followers: [(pubkey: pubkey(1), followedAt: 100)],
        seenAt: 200,
      );
      expect(await dao.followersOf(ownerB), isEmpty);
      expect(
        await dao.followerSubset(ownerPubkey: ownerB, candidates: [pubkey(1)]),
        isEmpty,
      );
      expect(await dao.followersOf(ownerA), [
        (pubkey: pubkey(1), followedAt: 100),
      ]);
      expect(await dao.newestFollowedAt(ownerB), isNull);
    });

    test(
      'orders newest first, breaks ties by pubkey and places nulls last',
      () async {
        await dao.upsertAll(
          ownerPubkey: ownerA,
          followers: [
            (pubkey: pubkey(4), followedAt: null),
            (pubkey: pubkey(3), followedAt: 100),
            (pubkey: pubkey(2), followedAt: 200),
            (pubkey: pubkey(1), followedAt: 200),
            (pubkey: pubkey(5), followedAt: null),
          ],
          seenAt: 300,
        );
        expect(await dao.followersOf(ownerA), [
          (pubkey: pubkey(1), followedAt: 200),
          (pubkey: pubkey(2), followedAt: 200),
          (pubkey: pubkey(3), followedAt: 100),
          (pubkey: pubkey(4), followedAt: null),
          (pubkey: pubkey(5), followedAt: null),
        ]);
        expect(await dao.newestFollowedAt(ownerA), 200);
      },
    );

    test('upsert keeps the newer known date and refreshes last seen', () async {
      for (final (followedAt, expected) in <(int?, int?)>[
        (null, null),
        (100, 100),
        (80, 100),
        (null, 100),
        (200, 200),
      ]) {
        await dao.upsertAll(
          ownerPubkey: ownerA,
          followers: [(pubkey: pubkey(1), followedAt: followedAt)],
          seenAt: 300,
        );
        expect((await dao.followersOf(ownerA)).single.followedAt, expected);
      }
      await dao.upsertAll(
        ownerPubkey: ownerA,
        followers: [(pubkey: pubkey(1), followedAt: 150)],
        seenAt: 400,
      );
      final row = await database.select(database.myFollowers).getSingle();
      expect(row.followedAt, 200);
      expect(row.lastSeenAt, 400);
    });

    test(
      'replace drops missing followers and leaves other owners alone',
      () async {
        for (final owner in [ownerA, ownerB]) {
          await dao.upsertAll(
            ownerPubkey: owner,
            followers: [
              (pubkey: pubkey(1), followedAt: 100),
              (pubkey: pubkey(2), followedAt: 200),
            ],
            seenAt: 300,
          );
        }
        await dao.replaceAll(
          ownerPubkey: ownerA,
          followers: [(pubkey: pubkey(2), followedAt: null)],
          seenAt: 400,
        );
        expect(await dao.followersOf(ownerA), [
          (pubkey: pubkey(2), followedAt: null),
        ]);
        expect(await dao.followersOf(ownerB), [
          (pubkey: pubkey(2), followedAt: 200),
          (pubkey: pubkey(1), followedAt: 100),
        ]);
        await dao.replaceAll(
          ownerPubkey: ownerA,
          followers: const [],
          seenAt: 500,
        );
        expect(await dao.followersOf(ownerA), isEmpty);
      },
    );

    test('replace rolls back its deletion when inserts fail', () async {
      await dao.upsertAll(
        ownerPubkey: ownerA,
        followers: [(pubkey: pubkey(1), followedAt: 100)],
        seenAt: 200,
      );
      await database.customStatement(
        'CREATE TRIGGER reject_follower BEFORE INSERT ON my_followers '
        "BEGIN SELECT RAISE(ABORT, 'rejected'); END",
      );
      await expectLater(
        dao.replaceAll(
          ownerPubkey: ownerA,
          followers: [(pubkey: pubkey(2), followedAt: 300)],
          seenAt: 400,
        ),
        throwsA(isA<Exception>()),
      );
      expect(await dao.followersOf(ownerA), [
        (pubkey: pubkey(1), followedAt: 100),
      ]);
    });

    test('subset intersects 1200 candidates across chunk boundaries', () async {
      final matches = [
        pubkey(1),
        pubkey(500),
        pubkey(501),
        pubkey(1000),
        pubkey(1001),
        pubkey(1200),
      ];
      await dao.upsertAll(
        ownerPubkey: ownerA,
        followers: [
          for (final key in [...matches, pubkey(1201)])
            (pubkey: key, followedAt: null),
        ],
        seenAt: 100,
      );
      await dao.upsertAll(
        ownerPubkey: ownerB,
        followers: [(pubkey: pubkey(2), followedAt: null)],
        seenAt: 100,
      );
      expect(
        await dao.followerSubset(
          ownerPubkey: ownerA,
          candidates: [for (var i = 1; i <= 1200; i++) pubkey(i)],
        ),
        matches.toSet(),
      );
      expect(
        await dao.followerSubset(ownerPubkey: ownerA, candidates: const []),
        isEmpty,
      );
    });

    test(
      'empty inputs and all unknown dates have no newest timestamp',
      () async {
        await dao.upsertAll(
          ownerPubkey: ownerA,
          followers: const [],
          seenAt: 100,
        );
        expect(await dao.newestFollowedAt(ownerA), isNull);
        await dao.upsertAll(
          ownerPubkey: ownerA,
          followers: [(pubkey: pubkey(1), followedAt: null)],
          seenAt: 200,
        );
        expect(await dao.newestFollowedAt(ownerA), isNull);
      },
    );

    test(
      'clear deletes only the requested owner and returns the row count',
      () async {
        for (final owner in [ownerA, ownerB]) {
          await dao.upsertAll(
            ownerPubkey: owner,
            followers: [(pubkey: pubkey(1), followedAt: 100)],
            seenAt: 200,
          );
        }
        expect(await dao.clearAllForUser(ownerA), 1);
        expect(await dao.followersOf(ownerA), isEmpty);
        expect(await dao.followersOf(ownerB), [
          (pubkey: pubkey(1), followedAt: 100),
        ]);
        expect(await dao.clearAllForUser(ownerA), 0);
      },
    );
  });
}
