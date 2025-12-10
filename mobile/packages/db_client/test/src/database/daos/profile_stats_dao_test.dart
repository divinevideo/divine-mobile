// ABOUTME: Unit tests for ProfileStatsDao with cache expiry logic.
// ABOUTME: Tests upsertStats, getStats with expiry, deleteExpired, clearAll.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late ProfileStatsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const testPubkey2 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
    dao = database.profileStatsDao;
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

  group('ProfileStatsDao', () {
    group('upsertStats', () {
      test('inserts new stats', () async {
        await dao.upsertStats(
          pubkey: testPubkey,
          videoCount: 10,
          followerCount: 100,
          followingCount: 50,
          totalViews: 1000,
          totalLikes: 500,
        );

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.pubkey, equals(testPubkey));
        expect(result.videoCount, equals(10));
        expect(result.followerCount, equals(100));
        expect(result.followingCount, equals(50));
        expect(result.totalViews, equals(1000));
        expect(result.totalLikes, equals(500));
      });

      test('updates existing stats with same pubkey', () async {
        await dao.upsertStats(
          pubkey: testPubkey,
          videoCount: 10,
          followerCount: 100,
        );

        await dao.upsertStats(
          pubkey: testPubkey,
          videoCount: 20,
          followerCount: 200,
        );

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.videoCount, equals(20));
        expect(result.followerCount, equals(200));

        // Verify only one entry exists
        final count = await appDbClient.countProfileStats();
        expect(count, equals(1));
      });

      test('handles null optional fields', () async {
        await dao.upsertStats(pubkey: testPubkey);

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.videoCount, isNull);
        expect(result.followerCount, isNull);
        expect(result.followingCount, isNull);
        expect(result.totalViews, isNull);
        expect(result.totalLikes, isNull);
      });

      test('handles multiple different pubkeys', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);
        await dao.upsertStats(pubkey: testPubkey2, videoCount: 20);

        final result1 = await appDbClient.getProfileStatRow(testPubkey);
        final result2 = await appDbClient.getProfileStatRow(testPubkey2);

        expect(result1!.videoCount, equals(10));
        expect(result2!.videoCount, equals(20));

        final count = await appDbClient.countProfileStats();
        expect(count, equals(2));
      });

      test('sets cachedAt timestamp', () async {
        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await dao.upsertStats(pubkey: testPubkey);
        final after = DateTime.now().add(const Duration(seconds: 1));

        final result = await appDbClient.getProfileStatRow(testPubkey);
        expect(result, isNotNull);
        expect(result!.cachedAt.isAfter(before), isTrue);
        expect(result.cachedAt.isBefore(after), isTrue);
      });
    });

    group('getStats', () {
      test('returns stats when not expired', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        final result = await dao.getStats(
          testPubkey,
        );

        expect(result, isNotNull);
        expect(result!.videoCount, equals(10));
      });

      test('returns null for non-existent pubkey', () async {
        final result = await dao.getStats(testPubkey);
        expect(result, isNull);
      });

      test('returns null and deletes expired stats', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        // Use a very short expiry to simulate expired data
        final result = await dao.getStats(
          testPubkey,
          expiry: Duration.zero,
        );

        expect(result, isNull);

        // Verify the entry was deleted
        final rawResult = await appDbClient.getProfileStatRow(testPubkey);
        expect(rawResult, isNull);
      });
    });

    group('deleteStats', () {
      test('deletes stats for a pubkey', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);
        await dao.upsertStats(pubkey: testPubkey2, videoCount: 20);

        final deleted = await dao.deleteStats(testPubkey);

        expect(deleted, equals(1));

        final result1 = await appDbClient.getProfileStatRow(testPubkey);
        final result2 = await appDbClient.getProfileStatRow(testPubkey2);

        expect(result1, isNull);
        expect(result2, isNotNull);
      });

      test('returns 0 when pubkey does not exist', () async {
        final deleted = await dao.deleteStats(testPubkey);
        expect(deleted, equals(0));
      });
    });

    group('deleteExpired', () {
      test('deletes only expired entries', () async {
        // Insert with old timestamps using direct database insert
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey,
                videoCount: const Value(10),
                cachedAt: oldTime,
              ),
            );
        await database
            .into(database.profileStats)
            .insert(
              ProfileStatsCompanion.insert(
                pubkey: testPubkey2,
                videoCount: const Value(20),
                cachedAt: oldTime,
              ),
            );

        // Delete with 5 minute expiry - entries are 10 minutes old so
        // should be deleted
        final deleted = await dao.deleteExpired();

        expect(deleted, equals(2));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('keeps fresh entries', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);

        // Delete with long expiry should keep the entry
        final deleted = await dao.deleteExpired(
          expiry: const Duration(hours: 1),
        );

        expect(deleted, equals(0));
        expect(await appDbClient.countProfileStats(), equals(1));
      });
    });

    group('clearAll', () {
      test('deletes all entries', () async {
        await dao.upsertStats(pubkey: testPubkey, videoCount: 10);
        await dao.upsertStats(pubkey: testPubkey2, videoCount: 20);

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        expect(await appDbClient.countProfileStats(), equals(0));
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });
  });
}
