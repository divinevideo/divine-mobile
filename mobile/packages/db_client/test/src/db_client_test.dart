// ABOUTME: Unit tests for the generic DbClient wrapper around Drift.
// ABOUTME: Tests all CRUD ops: insert, getBy, getAll, watch, delete, update.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('db_client_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(tempDbPath);
    dbClient = DbClient(generatedDatabase: database);
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  /// Helper to create a UserProfilesCompanion for testing.
  UserProfilesCompanion createProfile({
    required String pubkey,
    required String eventId,
    String? name,
    DateTime? createdAt,
  }) {
    return UserProfilesCompanion.insert(
      pubkey: pubkey,
      name: name != null ? Value(name) : const Value.absent(),
      createdAt: createdAt ?? DateTime.now(),
      eventId: eventId,
      lastFetched: DateTime.now(),
    );
  }

  group('DbClient', () {
    test('can be instantiated', () {
      expect(DbClient(), isNotNull);
    });

    test('can be instantiated with generatedDatabase', () {
      expect(dbClient, isNotNull);
    });

    group('insert', () {
      test('inserts a new entry and returns it', () async {
        final result = await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Test User',
            eventId: 'event1',
          ),
        );

        expect(result, isNotNull);
        expect((result as UserProfileRow).pubkey, equals('pubkey1'));
        expect(result.name, equals('Test User'));
      });

      test('replaces existing entry with same primary key', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Original Name',
            eventId: 'event1',
          ),
        );

        final result = await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Updated Name',
            eventId: 'event1_updated',
          ),
        );

        expect((result as UserProfileRow).name, equals('Updated Name'));

        final count = await dbClient.count(database.userProfiles);
        expect(count, equals(1));
      });
    });

    group('insertAll', () {
      test('inserts multiple entries in batch', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'User 1', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'User 2', eventId: 'event2'),
            createProfile(pubkey: 'pubkey3', name: 'User 3', eventId: 'event3'),
          ],
        );

        final count = await dbClient.count(database.userProfiles);
        expect(count, equals(3));
      });

      test('handles empty entries list gracefully', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [],
        );

        final count = await dbClient.count(database.userProfiles);
        expect(count, equals(0));
      });

      test('replaces entries with same primary key', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Original',
            eventId: 'event1',
          ),
        );

        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(
              pubkey: 'pubkey1',
              name: 'Updated via batch',
              eventId: 'event1_batch',
            ),
            createProfile(
              pubkey: 'pubkey2',
              name: 'New User',
              eventId: 'event2',
            ),
          ],
        );

        final count = await dbClient.count(database.userProfiles);
        expect(count, equals(2));

        final updated = await dbClient.getBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
        );
        expect(
          (updated as UserProfileRow?)?.name,
          equals('Updated via batch'),
        );
      });
    });

    group('getBy', () {
      test('returns matching entry', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Test User',
            eventId: 'event1',
          ),
        );

        final result = await dbClient.getBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
        );

        expect(result, isNotNull);
        expect((result as UserProfileRow?)?.pubkey, equals('pubkey1'));
      });

      test('returns null for non-matching filter', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Test User',
            eventId: 'event1',
          ),
        );

        final result = await dbClient.getBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('nonexistent'),
        );

        expect(result, isNull);
      });
    });

    group('getAll', () {
      Future<void> insertTestProfiles() async {
        final now = DateTime.now();
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(
              pubkey: 'pubkey1',
              name: 'Alice',
              eventId: 'event1',
              createdAt: now.subtract(const Duration(minutes: 5)),
            ),
            createProfile(
              pubkey: 'pubkey2',
              name: 'Bob',
              eventId: 'event2',
              createdAt: now.subtract(const Duration(minutes: 3)),
            ),
            createProfile(
              pubkey: 'pubkey3',
              name: 'Charlie',
              eventId: 'event3',
              createdAt: now.subtract(const Duration(minutes: 1)),
            ),
          ],
        );
      }

      test('returns all entries without filter', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(database.userProfiles);

        expect(results.length, equals(3));
      });

      test('returns filtered entries', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey2'),
        );

        expect(results.length, equals(1));
        expect((results.first as UserProfileRow).name, equals('Bob'));
      });

      test('returns ordered entries', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
        );

        expect(results.length, equals(3));
        expect((results[0] as UserProfileRow).name, equals('Alice'));
        expect((results[1] as UserProfileRow).name, equals('Bob'));
        expect((results[2] as UserProfileRow).name, equals('Charlie'));
      });

      test('returns ordered entries descending', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.desc((t as UserProfiles).name),
          ],
        );

        expect(results.length, equals(3));
        expect((results[0] as UserProfileRow).name, equals('Charlie'));
        expect((results[1] as UserProfileRow).name, equals('Bob'));
        expect((results[2] as UserProfileRow).name, equals('Alice'));
      });

      test('respects limit', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
          limit: 2,
        );

        expect(results.length, equals(2));
        expect((results[0] as UserProfileRow).name, equals('Alice'));
        expect((results[1] as UserProfileRow).name, equals('Bob'));
      });

      test('respects offset', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
          offset: 1,
        );

        expect(results.length, equals(2));
        expect((results[0] as UserProfileRow).name, equals('Bob'));
        expect((results[1] as UserProfileRow).name, equals('Charlie'));
      });

      test('respects limit and offset together', () async {
        await insertTestProfiles();

        final results = await dbClient.getAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
          limit: 1,
          offset: 1,
        );

        expect(results.length, equals(1));
        expect((results.first as UserProfileRow).name, equals('Bob'));
      });

      test('returns empty list for empty table', () async {
        final results = await dbClient.getAll(database.userProfiles);

        expect(results, isEmpty);
      });
    });

    group('watchSingleBy', () {
      test('emits matching entry', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Test User',
            eventId: 'event1',
          ),
        );

        final stream = dbClient.watchSingleBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
        );

        final result = await stream.first;

        expect(result, isNotNull);
        expect((result as UserProfileRow?)?.name, equals('Test User'));
      });

      test('emits null for non-matching filter', () async {
        final stream = dbClient.watchSingleBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('nonexistent'),
        );

        final result = await stream.first;

        expect(result, isNull);
      });

      test('emits updates when entry changes', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Original Name',
            eventId: 'event1',
          ),
        );

        final stream = dbClient.watchSingleBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
        );

        final emissions = <DataClass?>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Updated Name',
            eventId: 'event1_updated',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(
          (emissions.first as UserProfileRow?)?.name,
          equals('Original Name'),
        );
        expect(
          (emissions.last as UserProfileRow?)?.name,
          equals('Updated Name'),
        );
      });
    });

    group('watchBy', () {
      test('emits matching entries', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'User 1', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'User 2', eventId: 'event2'),
          ],
        );

        final stream = dbClient.watchBy(
          database.userProfiles,
          filter: (t) =>
              (t as UserProfiles).pubkey.isIn(['pubkey1', 'pubkey2']),
        );

        final result = await stream.first;

        expect(result.length, equals(2));
      });

      test('respects ordering', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'Zeta', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'Alpha', eventId: 'event2'),
          ],
        );

        final stream = dbClient.watchBy(
          database.userProfiles,
          filter: (t) =>
              (t as UserProfiles).pubkey.isIn(['pubkey1', 'pubkey2']),
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
        );

        final result = await stream.first;

        expect((result[0] as UserProfileRow).name, equals('Alpha'));
        expect((result[1] as UserProfileRow).name, equals('Zeta'));
      });

      test('respects limit and offset', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'A', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'B', eventId: 'event2'),
            createProfile(pubkey: 'pubkey3', name: 'C', eventId: 'event3'),
          ],
        );

        final stream = dbClient.watchBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles)
              .pubkey
              .isIn(['pubkey1', 'pubkey2', 'pubkey3']),
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
          limit: 1,
          offset: 1,
        );

        final result = await stream.first;

        expect(result.length, equals(1));
        expect((result.first as UserProfileRow).name, equals('B'));
      });
    });

    group('watchAll', () {
      test('emits all entries', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'User 1', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'User 2', eventId: 'event2'),
          ],
        );

        final stream = dbClient.watchAll(database.userProfiles);

        final result = await stream.first;

        expect(result.length, equals(2));
      });

      test('emits empty list for empty table', () async {
        final stream = dbClient.watchAll(database.userProfiles);

        final result = await stream.first;

        expect(result, isEmpty);
      });

      test('emits updates when entries change', () async {
        final stream = dbClient.watchAll(database.userProfiles);

        final emissions = <List<DataClass>>[];
        final subscription = stream.listen(emissions.add);

        await Future<void>.delayed(const Duration(milliseconds: 50));

        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'New User',
            eventId: 'event1',
          ),
        );

        await Future<void>.delayed(const Duration(milliseconds: 50));
        await subscription.cancel();

        expect(emissions.length, greaterThanOrEqualTo(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last.length, equals(1));
      });

      test('respects ordering', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'Zeta', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'Alpha', eventId: 'event2'),
          ],
        );

        final stream = dbClient.watchAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
        );

        final result = await stream.first;

        expect((result[0] as UserProfileRow).name, equals('Alpha'));
        expect((result[1] as UserProfileRow).name, equals('Zeta'));
      });

      test('respects limit and offset', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'A', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'B', eventId: 'event2'),
            createProfile(pubkey: 'pubkey3', name: 'C', eventId: 'event3'),
          ],
        );

        final stream = dbClient.watchAll(
          database.userProfiles,
          orderBy: [
            (t) => OrderingTerm.asc((t as UserProfiles).name),
          ],
          limit: 2,
          offset: 1,
        );

        final result = await stream.first;

        expect(result.length, equals(2));
        expect((result[0] as UserProfileRow).name, equals('B'));
        expect((result[1] as UserProfileRow).name, equals('C'));
      });
    });

    group('delete', () {
      test('deletes matching entries and returns count', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'User 1', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'User 2', eventId: 'event2'),
          ],
        );

        final deleted = await dbClient.delete(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
        );

        expect(deleted, equals(1));

        final remaining = await dbClient.count(database.userProfiles);
        expect(remaining, equals(1));
      });

      test('returns 0 when no entries match', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'User 1',
            eventId: 'event1',
          ),
        );

        final deleted = await dbClient.delete(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('nonexistent'),
        );

        expect(deleted, equals(0));

        final remaining = await dbClient.count(database.userProfiles);
        expect(remaining, equals(1));
      });

      test('can delete multiple entries', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(
              pubkey: 'pubkey1',
              name: 'Delete Me',
              eventId: 'event1',
            ),
            createProfile(
              pubkey: 'pubkey2',
              name: 'Delete Me',
              eventId: 'event2',
            ),
            createProfile(
              pubkey: 'pubkey3',
              eventId: 'event3',
              name: 'Keep Me',
            ),
          ],
        );

        final deleted = await dbClient.delete(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).name.equals('Delete Me'),
        );

        expect(deleted, equals(2));

        final remaining = await dbClient.count(database.userProfiles);
        expect(remaining, equals(1));
      });
    });

    group('deleteAll', () {
      test('deletes all entries and returns count', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'User 1', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'User 2', eventId: 'event2'),
            createProfile(pubkey: 'pubkey3', name: 'User 3', eventId: 'event3'),
          ],
        );

        final deleted = await dbClient.deleteAll(database.userProfiles);

        expect(deleted, equals(3));

        final remaining = await dbClient.count(database.userProfiles);
        expect(remaining, equals(0));
      });

      test('returns 0 for empty table', () async {
        final deleted = await dbClient.deleteAll(database.userProfiles);

        expect(deleted, equals(0));
      });
    });

    group('update', () {
      test('updates matching entries and returns count', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Original Name',
            eventId: 'event1',
          ),
        );

        final updated = await dbClient.update(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
          entry: const UserProfilesCompanion(
            name: Value('Updated Name'),
          ),
        );

        expect(updated, equals(1));

        final result = await dbClient.getBy(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('pubkey1'),
        );

        expect((result as UserProfileRow?)?.name, equals('Updated Name'));
      });

      test('returns 0 when no entries match', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'Original Name',
            eventId: 'event1',
          ),
        );

        final updated = await dbClient.update(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).pubkey.equals('nonexistent'),
          entry: const UserProfilesCompanion(
            name: Value('Updated Name'),
          ),
        );

        expect(updated, equals(0));
      });

      test('can update multiple entries', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(
              pubkey: 'pubkey1',
              name: 'Same Name',
              eventId: 'event1',
            ),
            createProfile(
              pubkey: 'pubkey2',
              name: 'Same Name',
              eventId: 'event2',
            ),
            createProfile(
              pubkey: 'pubkey3',
              name: 'Different',
              eventId: 'event3',
            ),
          ],
        );

        final updated = await dbClient.update(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).name.equals('Same Name'),
          entry: const UserProfilesCompanion(
            name: Value('Bulk Updated'),
          ),
        );

        expect(updated, equals(2));

        final results = await dbClient.getAll(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).name.equals('Bulk Updated'),
        );

        expect(results.length, equals(2));
      });
    });

    group('count', () {
      test('returns total count without filter', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'User 1', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'User 2', eventId: 'event2'),
            createProfile(pubkey: 'pubkey3', name: 'User 3', eventId: 'event3'),
          ],
        );

        final count = await dbClient.count(database.userProfiles);

        expect(count, equals(3));
      });

      test('returns filtered count', () async {
        await dbClient.insertAll(
          database.userProfiles,
          entries: [
            createProfile(pubkey: 'pubkey1', name: 'Target', eventId: 'event1'),
            createProfile(pubkey: 'pubkey2', name: 'Target', eventId: 'event2'),
            createProfile(pubkey: 'pubkey3', name: 'Other', eventId: 'event3'),
          ],
        );

        final count = await dbClient.count(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).name.equals('Target'),
        );

        expect(count, equals(2));
      });

      test('returns 0 for empty table', () async {
        final count = await dbClient.count(database.userProfiles);

        expect(count, equals(0));
      });

      test('returns 0 for non-matching filter', () async {
        await dbClient.insert(
          database.userProfiles,
          entry: createProfile(
            pubkey: 'pubkey1',
            name: 'User 1',
            eventId: 'event1',
          ),
        );

        final count = await dbClient.count(
          database.userProfiles,
          filter: (t) => (t as UserProfiles).name.equals('Nonexistent'),
        );

        expect(count, equals(0));
      });
    });
  });
}
