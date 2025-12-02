// ABOUTME: Tests for NostrEventsDao event count queries
// ABOUTME: Verifies getEventCount() returns correct count for empty and populated database

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/database/app_database.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  group('NostrEventsDao.getEventCount', () {
    late AppDatabase db;

    setUp(() async {
      // Create in-memory test database
      db = AppDatabase.test(':memory:');
    });

    tearDown(() async {
      await db.close();
    });

    test('returns 0 for empty database', () async {
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(0));
    });

    test('returns correct count after inserting events', () async {
      // Insert 3 test events (using valid 64-char hex pubkeys)
      final event1 = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcde1',
        34236,
        [],
        'Video 1',
        createdAt: 1234567890,
      );
      event1.id =
          'event1000000000000000000000000000000000000000000000000000000001';
      event1.sig =
          'sig1000000000000000000000000000000000000000000000000000000000001';

      final event2 = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcde2',
        34236,
        [],
        'Video 2',
        createdAt: 1234567891,
      );
      event2.id =
          'event2000000000000000000000000000000000000000000000000000000002';
      event2.sig =
          'sig2000000000000000000000000000000000000000000000000000000000002';

      final event3 = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcde3',
        0,
        [],
        '{"name":"Alice"}',
        createdAt: 1234567892,
      );
      event3.id =
          'event3000000000000000000000000000000000000000000000000000000003';
      event3.sig =
          'sig3000000000000000000000000000000000000000000000000000000000003';

      final events = [event1, event2, event3];

      await db.nostrEventsDao.upsertEventsBatch(events);

      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(3));
    });

    test('count increases as events are added', () async {
      expect(await db.nostrEventsDao.getEventCount(), equals(0));

      final event1 = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcde1',
        34236,
        [],
        'Video 1',
        createdAt: 1234567890,
      );
      event1.id =
          'event1000000000000000000000000000000000000000000000000000000001';
      event1.sig =
          'sig1000000000000000000000000000000000000000000000000000000000001';
      await db.nostrEventsDao.upsertEvent(event1);
      expect(await db.nostrEventsDao.getEventCount(), equals(1));

      final event2 = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcde2',
        34236,
        [],
        'Video 2',
        createdAt: 1234567891,
      );
      event2.id =
          'event2000000000000000000000000000000000000000000000000000000002';
      event2.sig =
          'sig2000000000000000000000000000000000000000000000000000000000002';
      await db.nostrEventsDao.upsertEvent(event2);
      expect(await db.nostrEventsDao.getEventCount(), equals(2));
    });
  });
}
