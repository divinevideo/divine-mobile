// ABOUTME: TDD tests for UserProfilesDao verifying CRUD operations and reactive queries
// ABOUTME: Tests database operations, upsert behavior, and stream reactivity

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UserProfilesDao', () {
    late AppDatabase db;
    late String testDbPath;

    setUp(() async {
      // Create temporary database for testing
      final tempDir = Directory.systemTemp.createTempSync('openvine_test_');
      testDbPath = p.join(tempDir.path, 'test.db');
      db = AppDatabase.test(testDbPath);
    });

    tearDown(() async {
      await db.close();
      // Clean up test database
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('getProfile returns null for non-existent profile', () async {
      final profile = await db.userProfilesDao.getProfile('nonexistent_pubkey');
      expect(profile, isNull);
    });

    test('upsertProfile inserts new profile', () async {
      final now = DateTime.now();
      final profile = UserProfile(
        pubkey: 'test_pubkey_123',
        displayName: 'Test User',
        name: 'testuser',
        about: 'Test bio',
        picture: 'https://example.com/avatar.jpg',
        banner: 'https://example.com/banner.jpg',
        nip05: 'test@example.com',
        lud16: 'test@lightning.com',
        rawData: {'custom': 'data'},
        createdAt: now,
        eventId: 'event_123',
      );

      await db.userProfilesDao.upsertProfile(profile);

      final fetched = await db.userProfilesDao.getProfile('test_pubkey_123');
      expect(fetched, isNotNull);
      expect(fetched!.pubkey, equals('test_pubkey_123'));
      expect(fetched.displayName, equals('Test User'));
      expect(fetched.name, equals('testuser'));
      expect(fetched.about, equals('Test bio'));
      expect(fetched.picture, equals('https://example.com/avatar.jpg'));
      expect(fetched.banner, equals('https://example.com/banner.jpg'));
      expect(fetched.nip05, equals('test@example.com'));
      expect(fetched.lud16, equals('test@lightning.com'));
    });

    test('upsertProfile updates existing profile', () async {
      final now = DateTime.now();
      final profile1 = UserProfile(
        pubkey: 'test_pubkey_456',
        displayName: 'Original Name',
        name: 'original',
        rawData: {},
        createdAt: now,
        eventId: 'event_1',
      );

      await db.userProfilesDao.upsertProfile(profile1);

      final profile2 = UserProfile(
        pubkey: 'test_pubkey_456',
        displayName: 'Updated Name',
        name: 'updated',
        about: 'New bio',
        rawData: {},
        createdAt: now,
        eventId: 'event_2',
      );

      await db.userProfilesDao.upsertProfile(profile2);

      final fetched = await db.userProfilesDao.getProfile('test_pubkey_456');
      expect(fetched, isNotNull);
      expect(fetched!.displayName, equals('Updated Name'));
      expect(fetched.name, equals('updated'));
      expect(fetched.about, equals('New bio'));
    });

    test(
      'watchProfile emits null initially for non-existent profile',
      () async {
        final stream = db.userProfilesDao.watchProfile('nonexistent_pubkey');
        final firstValue = await stream.first;
        expect(firstValue, isNull);
      },
    );

    test('watchProfile emits profile after insert', () async {
      final pubkey = 'test_pubkey_789';
      final stream = db.userProfilesDao.watchProfile(pubkey);

      // Skip the initial null emission
      await stream.first;

      final now = DateTime.now();
      final profile = UserProfile(
        pubkey: pubkey,
        displayName: 'Watched User',
        name: 'watched',
        rawData: {},
        createdAt: now,
        eventId: 'event_watch_1',
      );

      await db.userProfilesDao.upsertProfile(profile);

      final emittedProfile = await stream.first;
      expect(emittedProfile, isNotNull);
      expect(emittedProfile!.pubkey, equals(pubkey));
      expect(emittedProfile.displayName, equals('Watched User'));
    });

    test('watchProfile emits updated profile after update', () async {
      final pubkey = 'test_pubkey_update';
      final now = DateTime.now();

      // Insert initial profile
      final profile1 = UserProfile(
        pubkey: pubkey,
        displayName: 'Original',
        name: 'original',
        rawData: {},
        createdAt: now,
        eventId: 'event_1',
      );
      await db.userProfilesDao.upsertProfile(profile1);

      final stream = db.userProfilesDao.watchProfile(pubkey);

      // Skip the initial emission
      await stream.first;

      // Update profile
      final profile2 = UserProfile(
        pubkey: pubkey,
        displayName: 'Updated',
        name: 'updated',
        rawData: {},
        createdAt: now,
        eventId: 'event_2',
      );
      await db.userProfilesDao.upsertProfile(profile2);

      final emittedProfile = await stream.first;
      expect(emittedProfile, isNotNull);
      expect(emittedProfile!.displayName, equals('Updated'));
      expect(emittedProfile.name, equals('updated'));
    });

    test('getAllProfiles returns all profiles', () async {
      final now = DateTime.now();
      final profiles = [
        UserProfile(
          pubkey: 'pubkey_1',
          displayName: 'User 1',
          name: 'user1',
          rawData: {},
          createdAt: now,
          eventId: 'event_1',
        ),
        UserProfile(
          pubkey: 'pubkey_2',
          displayName: 'User 2',
          name: 'user2',
          rawData: {},
          createdAt: now,
          eventId: 'event_2',
        ),
        UserProfile(
          pubkey: 'pubkey_3',
          displayName: 'User 3',
          name: 'user3',
          rawData: {},
          createdAt: now,
          eventId: 'event_3',
        ),
      ];

      for (final profile in profiles) {
        await db.userProfilesDao.upsertProfile(profile);
      }

      final allProfiles = await db.userProfilesDao.getAllProfiles();
      expect(allProfiles.length, equals(3));
      expect(
        allProfiles.map((p) => p.pubkey).toSet(),
        equals({'pubkey_1', 'pubkey_2', 'pubkey_3'}),
      );
    });

    test('deleteProfile removes profile', () async {
      final now = DateTime.now();
      final profile = UserProfile(
        pubkey: 'delete_me',
        displayName: 'Delete User',
        name: 'deleteuser',
        rawData: {},
        createdAt: now,
        eventId: 'event_delete',
      );

      await db.userProfilesDao.upsertProfile(profile);

      // Verify it exists
      final fetched = await db.userProfilesDao.getProfile('delete_me');
      expect(fetched, isNotNull);

      // Delete it
      await db.userProfilesDao.deleteProfile('delete_me');

      // Verify it's gone
      final afterDelete = await db.userProfilesDao.getProfile('delete_me');
      expect(afterDelete, isNull);
    });

    test('watchAllProfiles emits updates when profiles change', () async {
      final stream = db.userProfilesDao.watchAllProfiles();

      // Get initial empty list
      final initial = await stream.first;
      expect(initial, isEmpty);

      // Insert a profile
      final now = DateTime.now();
      final profile = UserProfile(
        pubkey: 'watch_all_test',
        displayName: 'Test User',
        name: 'test',
        rawData: {},
        createdAt: now,
        eventId: 'event_test',
      );
      await db.userProfilesDao.upsertProfile(profile);

      // Stream should emit the new list
      final updated = await stream.first;
      expect(updated.length, equals(1));
      expect(updated[0].pubkey, equals('watch_all_test'));
    });
  });
}
