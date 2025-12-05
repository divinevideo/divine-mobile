// ABOUTME: Unit tests for VideoMetricsDao with Event-based metric extraction.
// ABOUTME: Tests upsertVideoMetrics and batchUpsertVideoMetrics.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:nostr_sdk/event.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late DbClient dbClient;
  late AppDbClient appDbClient;
  late VideoMetricsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  /// Helper to create a valid video Event with metric tags.
  Event createVideoEvent({
    String pubkey = testPubkey,
    int? loops,
    int? likes,
    int? comments,
    int? createdAt,
  }) {
    final tags = <List<String>>[];

    if (loops != null) {
      tags.add(['loops', loops.toString()]);
    }
    if (likes != null) {
      tags.add(['likes', likes.toString()]);
    }
    if (comments != null) {
      tags.add(['comments', comments.toString()]);
    }

    // Add required video URL
    tags.add(['url', 'https://example.com/video.mp4']);

    final event = Event(
      pubkey,
      34236, // Video kind
      tags,
      'test content',
      createdAt: createdAt ?? 1000,
    )..sig = 'testsig$pubkey';
    return event;
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dbClient = DbClient(generatedDatabase: database);
    appDbClient = AppDbClient(dbClient, database);
    dao = database.videoMetricsDao;
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

  group('VideoMetricsDao', () {
    group('upsertVideoMetrics', () {
      test('inserts metrics from video event', () async {
        final event = createVideoEvent(loops: 100, likes: 50, comments: 10);

        await dao.upsertVideoMetrics(event);

        final result = await appDbClient.getVideoMetrics(event.id);
        expect(result, isNotNull);
        expect(result!.eventId, equals(event.id));
        expect(result.loopCount, equals(100));
        expect(result.likes, equals(50));
        expect(result.comments, equals(10));
      });

      test('extracts loop count from event tags', () async {
        final event = createVideoEvent(loops: 500);

        await dao.upsertVideoMetrics(event);

        final result = await appDbClient.getVideoMetrics(event.id);
        expect(result, isNotNull);
        expect(result!.loopCount, equals(500));
      });

      test('extracts likes from event tags', () async {
        final event = createVideoEvent(likes: 250);

        await dao.upsertVideoMetrics(event);

        final result = await appDbClient.getVideoMetrics(event.id);
        expect(result, isNotNull);
        expect(result!.likes, equals(250));
      });

      test('extracts comments from event tags', () async {
        final event = createVideoEvent(comments: 75);

        await dao.upsertVideoMetrics(event);

        final result = await appDbClient.getVideoMetrics(event.id);
        expect(result, isNotNull);
        expect(result!.comments, equals(75));
      });

      test('handles event with no metric tags', () async {
        final event = createVideoEvent();

        await dao.upsertVideoMetrics(event);

        final result = await appDbClient.getVideoMetrics(event.id);
        expect(result, isNotNull);
        expect(result!.loopCount, isNull);
        expect(result.likes, isNull);
        expect(result.comments, isNull);
      });

      test('replaces existing metrics with same event ID', () async {
        final event1 = createVideoEvent(loops: 100);
        await dao.upsertVideoMetrics(event1);

        // Create new event with same properties but different loops
        final event2 = createVideoEvent(loops: 200)..id = event1.id;
        await dao.upsertVideoMetrics(event2);

        final result = await appDbClient.getVideoMetrics(event1.id);
        expect(result, isNotNull);
        expect(result!.loopCount, equals(200));

        // Verify only one entry exists
        final count = await appDbClient.countVideoMetrics();
        expect(count, equals(1));
      });

      test('sets updatedAt timestamp', () async {
        final event = createVideoEvent();

        final before = DateTime.now().subtract(const Duration(seconds: 1));
        await dao.upsertVideoMetrics(event);
        final after = DateTime.now().add(const Duration(seconds: 1));

        final result = await appDbClient.getVideoMetrics(event.id);
        expect(result, isNotNull);
        expect(result!.updatedAt.isAfter(before), isTrue);
        expect(result.updatedAt.isBefore(after), isTrue);
      });
    });

    group('batchUpsertVideoMetrics', () {
      test('inserts multiple metrics in a batch', () async {
        final events = [
          createVideoEvent(loops: 100, createdAt: 1000),
          createVideoEvent(loops: 200, createdAt: 2000),
          createVideoEvent(loops: 300, createdAt: 3000),
        ];

        await dao.batchUpsertVideoMetrics(events);

        for (final event in events) {
          final result = await appDbClient.getVideoMetrics(event.id);
          expect(result, isNotNull);
        }

        final count = await appDbClient.countVideoMetrics();
        expect(count, equals(3));
      });

      test('handles empty list gracefully', () async {
        await dao.batchUpsertVideoMetrics([]);

        final count = await appDbClient.countVideoMetrics();
        expect(count, equals(0));
      });

      test('extracts metrics from all events in batch', () async {
        final events = [
          createVideoEvent(loops: 100, likes: 10, createdAt: 1000),
          createVideoEvent(loops: 200, likes: 20, createdAt: 2000),
        ];

        await dao.batchUpsertVideoMetrics(events);

        final result1 = await appDbClient.getVideoMetrics(
          events[0].id,
        );
        expect(result1!.loopCount, equals(100));
        expect(result1.likes, equals(10));

        final result2 = await appDbClient.getVideoMetrics(
          events[1].id,
        );
        expect(result2!.loopCount, equals(200));
        expect(result2.likes, equals(20));
      });

      test('uses insert or replace mode for duplicates', () async {
        final event1 = createVideoEvent(loops: 100);
        await dao.batchUpsertVideoMetrics([event1]);

        // Batch with same event but different metrics
        final event2 = createVideoEvent(loops: 999)..id = event1.id;
        await dao.batchUpsertVideoMetrics([event2]);

        final result = await appDbClient.getVideoMetrics(event1.id);
        expect(result!.loopCount, equals(999));

        // Verify only one entry exists
        final count = await appDbClient.countVideoMetrics();
        expect(count, equals(1));
      });
    });
  });
}
