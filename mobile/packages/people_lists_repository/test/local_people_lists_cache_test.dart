// ABOUTME: Tests for LocalPeopleListsCache Hive-backed people-list storage.
// ABOUTME: Covers owner scoping, sort order, tombstones, and recreation.

// `DateTime.utc(year, month, 1)` passes an explicit day-of-month to document
// the test date even though `1` matches the default; readability wins here.
// ignore_for_file: avoid_redundant_argument_values

import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:models/models.dart';
import 'package:people_lists_repository/src/local_people_lists_cache.dart';
import 'package:test/test.dart';

/// Test constants. Full pubkeys — never truncate.
const _ownerA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _ownerB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _memberA =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _memberB =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

UserList _list({
  required String id,
  required DateTime updatedAt,
  String name = 'Crew',
  List<String> pubkeys = const [_memberA],
}) {
  return UserList(
    id: id,
    name: name,
    pubkeys: pubkeys,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}

void main() {
  group(LocalPeopleListsCache, () {
    late Directory tempDir;
    late int boxCounter;

    Future<Box<dynamic>> Function() makeOpener() {
      final boxName = 'people_lists_test_${boxCounter++}';
      return () async => Hive.openBox<dynamic>(boxName, path: tempDir.path);
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'local_people_lists_cache_test_',
      );
      Hive.init(tempDir.path);
      boxCounter = 0;
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('readLists', () {
      test('returns empty list when no entries exist', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(lists, isEmpty);
      });

      test('scopes entries by owner pubkey', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());
        final receivedAt = DateTime.utc(2026, 4, 20);

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'owner-a-list',
            updatedAt: DateTime.utc(2026, 4, 1),
          ),
          receivedAt: receivedAt,
        );
        await cache.putList(
          ownerPubkey: _ownerB,
          list: _list(
            id: 'owner-b-list',
            updatedAt: DateTime.utc(2026, 4, 2),
          ),
          receivedAt: receivedAt,
        );

        final ownerALists = await cache.readLists(ownerPubkey: _ownerA);
        final ownerBLists = await cache.readLists(ownerPubkey: _ownerB);

        expect(ownerALists.map((l) => l.id), equals(['owner-a-list']));
        expect(ownerBLists.map((l) => l.id), equals(['owner-b-list']));
      });

      test('sorts lists by updatedAt descending', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());
        final receivedAt = DateTime.utc(2026, 4, 20);

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'oldest',
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
          receivedAt: receivedAt,
        );
        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'newest',
            updatedAt: DateTime.utc(2026, 4, 1),
          ),
          receivedAt: receivedAt,
        );
        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'middle',
            updatedAt: DateTime.utc(2026, 2, 1),
          ),
          receivedAt: receivedAt,
        );

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(
          lists.map((l) => l.id),
          equals(['newest', 'middle', 'oldest']),
        );
      });

      test('hides tombstoned listIds', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());
        final updatedAt = DateTime.utc(2026, 4, 1);

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(id: 'keep-me', updatedAt: updatedAt),
          receivedAt: DateTime.utc(2026, 4, 5),
        );
        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(id: 'delete-me', updatedAt: updatedAt),
          receivedAt: DateTime.utc(2026, 4, 5),
        );

        await cache.markDeleted(
          ownerPubkey: _ownerA,
          listId: 'delete-me',
          deletedAt: DateTime.utc(2026, 4, 10),
        );

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(lists.map((l) => l.id), equals(['keep-me']));
      });

      test(
        'skips malformed rows and returns the remaining good rows',
        () async {
          // Share a single Hive box between the cache and the raw writer so
          // we can inject a malformed row behind the cache's back.
          const boxName = 'people_lists_test_shared';
          Future<Box<dynamic>> openShared() =>
              Hive.openBox<dynamic>(boxName, path: tempDir.path);

          final cache = LocalPeopleListsCache(openBox: openShared);
          final box = await openShared();

          await cache.putList(
            ownerPubkey: _ownerA,
            list: _list(
              id: 'good',
              updatedAt: DateTime.utc(2026, 4, 1),
            ),
            receivedAt: DateTime.utc(2026, 4, 1),
          );

          // Malformed record: `list` payload is missing required fields so
          // `UserList.fromJson` will throw when the cache tries to decode it.
          await box.put('list:$_ownerA:broken', <String, dynamic>{
            'ownerPubkey': _ownerA,
            'list': <String, dynamic>{'nope': 'no required fields'},
            'receivedAtMillis': 0,
          });

          final lists = await cache.readLists(ownerPubkey: _ownerA);

          expect(lists.map((l) => l.id), equals(['good']));
        },
      );
    });

    group('putList', () {
      test('round-trips the complete publish source', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());
        final list = _list(
          id: 'source-list',
          updatedAt: DateTime.utc(2026, 4, 1),
        );
        const sourceTags = [
          ['d', 'source-list'],
          ['alt', 'Written elsewhere'],
          ['p', _memberA, 'wss://relay.example'],
        ];

        await cache.putList(
          ownerPubkey: _ownerA,
          list: list,
          receivedAt: DateTime.utc(2026, 4, 20),
          sourceTags: sourceTags,
          sourceContent: 'encrypted-private-items',
        );

        final record = await cache.readRecord(
          ownerPubkey: _ownerA,
          listId: list.id,
        );
        expect(record, isNotNull);
        expect(record!.list, list);
        expect(record.sourceTags, sourceTags);
        expect(record.sourceContent, 'encrypted-private-items');
        expect(record.hasPublishSource, isTrue);
      });

      test(
        'loads a legacy row without treating it as a publish source',
        () async {
          final cache = LocalPeopleListsCache(openBox: makeOpener());
          final list = _list(
            id: 'legacy-list',
            updatedAt: DateTime.utc(2026, 4, 1),
          );

          await cache.putList(
            ownerPubkey: _ownerA,
            list: list,
            receivedAt: DateTime.utc(2026, 4, 20),
          );

          final record = await cache.readRecord(
            ownerPubkey: _ownerA,
            listId: list.id,
          );
          expect(record, isNotNull);
          expect(record!.list, list);
          expect(record.hasPublishSource, isFalse);
        },
      );

      test('keeps a list readable but rejects its malformed source', () async {
        final box = await Hive.openBox<dynamic>(
          'malformed_source_${boxCounter++}',
          path: tempDir.path,
        );
        final list = _list(
          id: 'malformed-source',
          updatedAt: DateTime.utc(2026, 4, 1),
        );
        await box.put('list:$_ownerA:${list.id}', <String, dynamic>{
          'ownerPubkey': _ownerA,
          'list': list.toJson(),
          'receivedAtMillis': DateTime.utc(2026, 4, 20).millisecondsSinceEpoch,
          'sourceTags': [
            ['d', null],
          ],
          'sourceContent': '',
        });
        final cache = LocalPeopleListsCache(openBox: () async => box);

        expect(await cache.readLists(ownerPubkey: _ownerA), [list]);
        final record = await cache.readRecord(
          ownerPubkey: _ownerA,
          listId: list.id,
        );
        expect(record, isNotNull);
        expect(record!.list, list);
        expect(record.hasPublishSource, isFalse);
      });

      test('ignores events older than a tombstone', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());

        await cache.markDeleted(
          ownerPubkey: _ownerA,
          listId: 'ghost',
          deletedAt: DateTime.utc(2026, 4, 10),
        );

        // An older event arrives (e.g. lagging relay).
        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'ghost',
            updatedAt: DateTime.utc(2026, 4, 1),
          ),
          receivedAt: DateTime.utc(2026, 4, 11),
        );

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(lists, isEmpty);
      });

      test('recreates a list when newer than its tombstone', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());

        await cache.markDeleted(
          ownerPubkey: _ownerA,
          listId: 'phoenix',
          deletedAt: DateTime.utc(2026, 4, 10),
        );

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'phoenix',
            name: 'Phoenix Rising',
            pubkeys: const [_memberA, _memberB],
            updatedAt: DateTime.utc(2026, 4, 15),
          ),
          receivedAt: DateTime.utc(2026, 4, 15),
        );

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(lists, hasLength(1));
        expect(lists.single.id, equals('phoenix'));
        expect(lists.single.name, equals('Phoenix Rising'));
        expect(
          lists.single.pubkeys,
          equals(const [_memberA, _memberB]),
        );
      });
    });

    group('watchLists', () {
      test('forwards box opener failures as stream errors', () async {
        final error = StateError('Hive storage is not initialized');
        final cache = LocalPeopleListsCache(openBox: () async => throw error);

        await expectLater(
          cache.watchLists(ownerPubkey: _ownerA),
          emitsInOrder([emitsError(same(error)), emitsDone]),
        );
      });

      test('retries box opener after a failed open', () async {
        final error = StateError('Hive storage is not initialized');
        final boxName = 'people_lists_test_retry_${boxCounter++}';
        var attempts = 0;
        final cache = LocalPeopleListsCache(
          openBox: () async {
            attempts += 1;
            if (attempts == 1) {
              throw error;
            }
            return Hive.openBox<dynamic>(boxName, path: tempDir.path);
          },
        );

        await expectLater(
          cache.watchLists(ownerPubkey: _ownerA),
          emitsInOrder([emitsError(same(error)), emitsDone]),
        );

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(lists, isEmpty);
        expect(attempts, 2);
      });

      test('emits current lists immediately, then on updates', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'initial',
            updatedAt: DateTime.utc(2026, 4, 1),
          ),
          receivedAt: DateTime.utc(2026, 4, 1),
        );

        final emissions = <List<UserList>>[];
        final subscription = cache
            .watchLists(ownerPubkey: _ownerA)
            .listen(emissions.add);

        await pumpEventQueue();
        expect(emissions, hasLength(1));
        expect(emissions.first.map((l) => l.id), equals(['initial']));

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'second',
            updatedAt: DateTime.utc(2026, 4, 5),
          ),
          receivedAt: DateTime.utc(2026, 4, 5),
        );
        await pumpEventQueue();

        expect(
          emissions.last.map((l) => l.id),
          equals(['second', 'initial']),
        );

        await subscription.cancel();
      });

      test('does not emit for a different owner', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());

        // Warm the cache so the watch stream's first emission arrives
        // synchronously once we subscribe.
        await cache.readLists(ownerPubkey: _ownerA);

        final emissionsForA = <List<UserList>>[];
        final subscription = cache
            .watchLists(ownerPubkey: _ownerA)
            .listen(emissionsForA.add);
        await pumpEventQueue();
        expect(emissionsForA, hasLength(1));
        expect(emissionsForA.first, isEmpty);

        // Snapshot the exact emissions we had before touching the other owner.
        final before = List<List<UserList>>.from(emissionsForA);

        await cache.putList(
          ownerPubkey: _ownerB,
          list: _list(
            id: 'owner-b-only',
            updatedAt: DateTime.utc(2026, 4, 5),
          ),
          receivedAt: DateTime.utc(2026, 4, 5),
        );
        await pumpEventQueue();

        // Writing under owner B must produce zero additional emissions for A.
        expect(emissionsForA, equals(before));

        await subscription.cancel();
      });

      test('emits after tombstone hides the list', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(
            id: 'temporary',
            updatedAt: DateTime.utc(2026, 4, 1),
          ),
          receivedAt: DateTime.utc(2026, 4, 1),
        );

        final emissions = <List<UserList>>[];
        final subscription = cache
            .watchLists(ownerPubkey: _ownerA)
            .listen(emissions.add);
        await pumpEventQueue();

        await cache.markDeleted(
          ownerPubkey: _ownerA,
          listId: 'temporary',
          deletedAt: DateTime.utc(2026, 4, 2),
        );
        await pumpEventQueue();

        expect(emissions.last, isEmpty);

        await subscription.cancel();
      });
    });

    group('clearOwner', () {
      test('removes lists and tombstones for only that owner', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());
        final receivedAt = DateTime.utc(2026, 4, 1);

        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(id: 'a-list', updatedAt: receivedAt),
          receivedAt: receivedAt,
        );
        await cache.markDeleted(
          ownerPubkey: _ownerA,
          listId: 'a-ghost',
          deletedAt: receivedAt,
        );
        await cache.putList(
          ownerPubkey: _ownerB,
          list: _list(id: 'b-list', updatedAt: receivedAt),
          receivedAt: receivedAt,
        );

        await cache.clearOwner(ownerPubkey: _ownerA);

        expect(await cache.readLists(ownerPubkey: _ownerA), isEmpty);
        // Tombstone must be cleared: older events may now repopulate the list.
        await cache.putList(
          ownerPubkey: _ownerA,
          list: _list(id: 'a-ghost', updatedAt: receivedAt),
          receivedAt: receivedAt,
        );
        expect(
          (await cache.readLists(ownerPubkey: _ownerA)).map((l) => l.id),
          equals(['a-ghost']),
        );

        final ownerBLists = await cache.readLists(ownerPubkey: _ownerB);
        expect(ownerBLists.map((l) => l.id), equals(['b-list']));
      });
    });

    group('putLists', () {
      test('writes multiple lists in a single call', () async {
        final cache = LocalPeopleListsCache(openBox: makeOpener());
        final receivedAt = DateTime.utc(2026, 4, 20);

        await cache.putLists(
          ownerPubkey: _ownerA,
          lists: [
            _list(id: 'one', updatedAt: DateTime.utc(2026, 4, 1)),
            _list(id: 'two', updatedAt: DateTime.utc(2026, 4, 5)),
          ],
          receivedAt: receivedAt,
        );

        final lists = await cache.readLists(ownerPubkey: _ownerA);

        expect(lists.map((l) => l.id), equals(['two', 'one']));
      });
    });
  });
}
