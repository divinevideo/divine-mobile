// ABOUTME: TDD tests for EventRouter verifying centralized event caching to database
// ABOUTME: Tests routing logic, kind-specific processing, and error handling

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/services/event_router.dart';
import 'package:path/path.dart' as p;

void main() {
  group('EventRouter', () {
    late AppDatabase db;
    late EventRouter eventRouter;
    late String testDbPath;

    setUp(() async {
      // Create temporary database for testing
      final tempDir = Directory.systemTemp.createTempSync('openvine_test_');
      testDbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(testDbPath);
      eventRouter = EventRouter(db);
    });

    tearDown(() async {
      await db.close();
      // Clean up test database
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test(
      'handleEvent inserts kind 34236 (video) event to NostrEvents table',
      () async {
        final videoEvent = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          34236,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          'Test video content',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        // Set id and sig manually since they're calculated fields
        videoEvent.id =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        videoEvent.sig =
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

        await eventRouter.handleEvent(videoEvent);

        // Verify event was inserted to NostrEvents table
        final storedEvent = await db.nostrEventsDao.getEvent(
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        );
        expect(storedEvent, isNotNull);
        expect(
          storedEvent!.id,
          equals(
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          ),
        );
        expect(storedEvent.kind, equals(34236));
        expect(
          storedEvent.pubkey,
          equals(
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          ),
        );
        expect(storedEvent.content, equals('Test video content'));
      },
    );

    test('handleEvent inserts kind 0 (profile) event to both tables', () async {
      final profileContent = jsonEncode({
        'name': 'testuser',
        'display_name': 'Test User',
        'about': 'Test bio',
        'picture': 'https://example.com/avatar.jpg',
      });

      final profileEvent = Event(
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        0,
        [],
        profileContent,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      profileEvent.id =
          'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
      profileEvent.sig =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

      await eventRouter.handleEvent(profileEvent);

      // Verify event was inserted to NostrEvents table
      final storedEvent = await db.nostrEventsDao.getEvent(
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
      );
      expect(storedEvent, isNotNull);
      expect(storedEvent!.kind, equals(0));

      // Verify profile was extracted to UserProfiles table
      final profile = await db.userProfilesDao.getProfile(
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
      );
      expect(profile, isNotNull);
      expect(profile!.name, equals('testuser'));
      expect(profile.displayName, equals('Test User'));
      expect(profile.about, equals('Test bio'));
      expect(profile.picture, equals('https://example.com/avatar.jpg'));
    });

    test(
      'handleEvent inserts kind 3 (contacts) event to NostrEvents table',
      () async {
        final contactsEvent = Event(
          '1111111111111111111111111111111111111111111111111111111111111111',
          3,
          [
            [
              'p',
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ],
            [
              'p',
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            ],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        contactsEvent.id =
            '2222222222222222222222222222222222222222222222222222222222222222';
        contactsEvent.sig =
            '3333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333';

        await eventRouter.handleEvent(contactsEvent);

        // Verify event was inserted to NostrEvents table
        final storedEvent = await db.nostrEventsDao.getEvent(
          '2222222222222222222222222222222222222222222222222222222222222222',
        );
        expect(storedEvent, isNotNull);
        expect(storedEvent!.kind, equals(3));
        expect(storedEvent.tags.length, equals(2));
      },
    );

    test(
      'handleEvent inserts kind 7 (reaction) event to NostrEvents table',
      () async {
        final reactionEvent = Event(
          '4444444444444444444444444444444444444444444444444444444444444444',
          7,
          [
            [
              'e',
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            ], // Event being reacted to
          ],
          '+',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        reactionEvent.id =
            '5555555555555555555555555555555555555555555555555555555555555555';
        reactionEvent.sig =
            '6666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666';

        await eventRouter.handleEvent(reactionEvent);

        // Verify event was inserted to NostrEvents table
        final storedEvent = await db.nostrEventsDao.getEvent(
          '5555555555555555555555555555555555555555555555555555555555555555',
        );
        expect(storedEvent, isNotNull);
        expect(storedEvent!.kind, equals(7));
        expect(storedEvent.content, equals('+'));
      },
    );

    test(
      'handleEvent inserts kind 6 (repost) event to NostrEvents table',
      () async {
        final repostEvent = Event(
          '7777777777777777777777777777777777777777777777777777777777777777',
          6,
          [
            [
              'e',
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            ],
            [
              'p',
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            ],
          ],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        repostEvent.id =
            '8888888888888888888888888888888888888888888888888888888888888888';
        repostEvent.sig =
            '9999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999';

        await eventRouter.handleEvent(repostEvent);

        // Verify event was inserted to NostrEvents table
        final storedEvent = await db.nostrEventsDao.getEvent(
          '8888888888888888888888888888888888888888888888888888888888888888',
        );
        expect(storedEvent, isNotNull);
        expect(storedEvent!.kind, equals(6));
      },
    );

    test('handleEvent handles duplicate events (upsert behavior)', () async {
      final event1 = Event(
        'abababababababababababababababababababababababababababababababab',
        34236,
        [],
        'Original content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event1.id =
          'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
      event1.sig =
          'efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef';

      // Insert first time
      await eventRouter.handleEvent(event1);

      final storedEvent1 = await db.nostrEventsDao.getEvent(
        'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
      expect(storedEvent1, isNotNull);
      expect(storedEvent1!.content, equals('Original content'));

      // Insert same ID with different content (should replace)
      final event2 = Event(
        'abababababababababababababababababababababababababababababababab',
        34236,
        [],
        'Updated content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event2.id =
          'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';
      event2.sig =
          '0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a';

      await eventRouter.handleEvent(event2);

      final storedEvent2 = await db.nostrEventsDao.getEvent(
        'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd',
      );
      expect(storedEvent2, isNotNull);
      expect(storedEvent2!.content, equals('Updated content'));
      expect(
        storedEvent2.sig,
        equals(
          '0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a',
        ),
      );
    });

    test('handleEvent handles malformed profile event gracefully', () async {
      final malformedProfileEvent = Event(
        'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
        0,
        [],
        'This is not valid JSON', // Invalid JSON
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      malformedProfileEvent.id =
          'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
      malformedProfileEvent.sig =
          'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';

      // Should not throw - gracefully handle malformed profile
      await expectLater(
        eventRouter.handleEvent(malformedProfileEvent),
        completes,
      );

      // Event should still be in NostrEvents table
      final storedEvent = await db.nostrEventsDao.getEvent(
        'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
      );
      expect(storedEvent, isNotNull);
      expect(storedEvent!.kind, equals(0));

      // Profile should exist with minimal data (from fallback in UserProfile.fromNostrEvent)
      final profile = await db.userProfilesDao.getProfile(
        'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
      );
      expect(profile, isNotNull);
      expect(
        profile!.pubkey,
        equals(
          'f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0',
        ),
      );
    });

    test('handleEvent inserts unknown kind to NostrEvents table', () async {
      final unknownKindEvent = Event(
        'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3',
        12345, // Unknown kind
        [],
        'Unknown kind content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      unknownKindEvent.id =
          'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';
      unknownKindEvent.sig =
          'e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5';

      await eventRouter.handleEvent(unknownKindEvent);

      // Verify event was inserted to NostrEvents table
      final storedEvent = await db.nostrEventsDao.getEvent(
        'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4',
      );
      expect(storedEvent, isNotNull);
      expect(storedEvent!.kind, equals(12345));
      expect(storedEvent.content, equals('Unknown kind content'));
    });
  });
}
