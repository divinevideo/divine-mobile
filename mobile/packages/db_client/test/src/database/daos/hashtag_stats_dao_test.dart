// ABOUTME: Unit tests for HashtagStatsDao with batch operations and cache
// ABOUTME: expiry. Tests upsertHashtag, upsertBatch, getPopularHashtags,
// ABOUTME: isCacheFresh, deleteExpired.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late HashtagStatsDao dao;
  late String tempDbPath;

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.hashtagStatsDao;
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

  group('HashtagStatsDao', () {
    group('upsertHashtag', () {
      test('inserts new hashtag stats', () async {
        await dao.upsertHashtag(
          hashtag: 'flutter',
          videoCount: 100,
          totalViews: 5000,
          totalLikes: 250,
        );

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(1));
        expect(results.first.hashtag, equals('flutter'));
        expect(results.first.videoCount, equals(100));
        expect(results.first.totalViews, equals(5000));
        expect(results.first.totalLikes, equals(250));
      });

      test('updates existing hashtag with same name', () async {
        await dao.upsertHashtag(
          hashtag: 'flutter',
          videoCount: 100,
        );

        await dao.upsertHashtag(
          hashtag: 'flutter',
          videoCount: 200,
          totalViews: 10000,
        );

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(1));
        expect(results.first.videoCount, equals(200));
        expect(results.first.totalViews, equals(10000));
      });

      test('handles null optional fields', () async {
        await dao.upsertHashtag(hashtag: 'nostr');

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(1));
        expect(results.first.hashtag, equals('nostr'));
        expect(results.first.videoCount, isNull);
        expect(results.first.totalViews, isNull);
        expect(results.first.totalLikes, isNull);
      });

      test('handles multiple different hashtags', () async {
        await dao.upsertHashtag(hashtag: 'flutter', videoCount: 100);
        await dao.upsertHashtag(hashtag: 'dart', videoCount: 80);
        await dao.upsertHashtag(hashtag: 'nostr', videoCount: 50);

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(3));
      });
    });

    group('upsertBatch', () {
      test('inserts multiple hashtags in batch', () async {
        await dao.upsertBatch([
          HashtagStatsCompanion.insert(
            hashtag: 'flutter',
            videoCount: const Value(100),
            cachedAt: DateTime.now(),
          ),
          HashtagStatsCompanion.insert(
            hashtag: 'dart',
            videoCount: const Value(80),
            cachedAt: DateTime.now(),
          ),
          HashtagStatsCompanion.insert(
            hashtag: 'nostr',
            videoCount: const Value(60),
            cachedAt: DateTime.now(),
          ),
        ]);

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(3));
      });

      test('updates existing hashtags in batch', () async {
        await dao.upsertHashtag(hashtag: 'flutter', videoCount: 50);

        await dao.upsertBatch([
          HashtagStatsCompanion.insert(
            hashtag: 'flutter',
            videoCount: const Value(150),
            cachedAt: DateTime.now(),
          ),
          HashtagStatsCompanion.insert(
            hashtag: 'dart',
            videoCount: const Value(100),
            cachedAt: DateTime.now(),
          ),
        ]);

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(2));

        final flutter = results.firstWhere((r) => r.hashtag == 'flutter');
        expect(flutter.videoCount, equals(150));
      });
    });

    group('getPopularHashtags', () {
      test('returns hashtags sorted by video count descending', () async {
        await dao.upsertHashtag(hashtag: 'low', videoCount: 10);
        await dao.upsertHashtag(hashtag: 'high', videoCount: 100);
        await dao.upsertHashtag(hashtag: 'medium', videoCount: 50);

        final results = await dao.getPopularHashtags();
        expect(results[0].hashtag, equals('high'));
        expect(results[1].hashtag, equals('medium'));
        expect(results[2].hashtag, equals('low'));
      });

      test('respects limit parameter', () async {
        await dao.upsertHashtag(hashtag: 'a', videoCount: 100);
        await dao.upsertHashtag(hashtag: 'b', videoCount: 80);
        await dao.upsertHashtag(hashtag: 'c', videoCount: 60);
        await dao.upsertHashtag(hashtag: 'd', videoCount: 40);

        final results = await dao.getPopularHashtags(
          limit: 2,
        );
        expect(results, hasLength(2));
        expect(results[0].hashtag, equals('a'));
        expect(results[1].hashtag, equals('b'));
      });

      test('excludes expired entries', () async {
        // Insert with an old timestamp using batch
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await dao.upsertBatch([
          HashtagStatsCompanion.insert(
            hashtag: 'flutter',
            videoCount: const Value(100),
            cachedAt: oldTime,
          ),
        ]);

        // Query with 5 minute expiry - entry is 10 minutes old so should
        // be excluded
        final results = await dao.getPopularHashtags(
          expiry: const Duration(minutes: 5),
        );
        expect(results, isEmpty);
      });

      test('returns empty list when no hashtags exist', () async {
        final results = await dao.getPopularHashtags();
        expect(results, isEmpty);
      });
    });

    group('isCacheFresh', () {
      test('returns true when fresh data exists', () async {
        await dao.upsertHashtag(hashtag: 'flutter', videoCount: 100);

        final isFresh = await dao.isCacheFresh();
        expect(isFresh, isTrue);
      });

      test('returns false when no data exists', () async {
        final isFresh = await dao.isCacheFresh();
        expect(isFresh, isFalse);
      });

      test('returns false when all data is expired', () async {
        // Insert with an old timestamp using batch
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await dao.upsertBatch([
          HashtagStatsCompanion.insert(
            hashtag: 'flutter',
            videoCount: const Value(100),
            cachedAt: oldTime,
          ),
        ]);

        // Query with 5 minute expiry - entry is 10 minutes old so should
        // be expired
        final isFresh = await dao.isCacheFresh(
          expiry: const Duration(minutes: 5),
        );
        expect(isFresh, isFalse);
      });
    });

    group('deleteExpired', () {
      test('deletes only expired entries', () async {
        // Insert with old timestamps using batch
        final oldTime = DateTime.now().subtract(const Duration(minutes: 10));
        await dao.upsertBatch([
          HashtagStatsCompanion.insert(
            hashtag: 'flutter',
            videoCount: const Value(100),
            cachedAt: oldTime,
          ),
          HashtagStatsCompanion.insert(
            hashtag: 'dart',
            videoCount: const Value(80),
            cachedAt: oldTime,
          ),
        ]);

        // Delete with 5 minute expiry - entries are 10 minutes old so
        // should be deleted
        final deleted = await dao.deleteExpired(
          expiry: const Duration(minutes: 5),
        );

        expect(deleted, equals(2));

        final results = await dao.getPopularHashtags();
        expect(results, isEmpty);
      });

      test('keeps fresh entries', () async {
        await dao.upsertHashtag(hashtag: 'flutter', videoCount: 100);

        // Delete with long expiry should keep the entry
        final deleted = await dao.deleteExpired();

        expect(deleted, equals(0));

        final results = await dao.getPopularHashtags();
        expect(results, hasLength(1));
      });
    });

    group('clearAll', () {
      test('deletes all entries', () async {
        await dao.upsertHashtag(hashtag: 'flutter', videoCount: 100);
        await dao.upsertHashtag(hashtag: 'dart', videoCount: 80);
        await dao.upsertHashtag(hashtag: 'nostr', videoCount: 60);

        final deleted = await dao.clearAll();

        expect(deleted, equals(3));

        final results = await dao.getPopularHashtags();
        expect(results, isEmpty);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });
  });
}
