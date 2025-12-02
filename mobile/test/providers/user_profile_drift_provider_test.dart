// ABOUTME: Tests for Drift-based UserProfile provider - verifies reactive stream behavior
// ABOUTME: Tests provider emits null for missing profiles, emits profiles from DB, and auto-updates

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/user_profile_drift_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UserProfile Drift Provider', () {
    late ProviderContainer container;
    late AppDatabase testDb;
    late String testDbPath;

    setUp(() async {
      // Create isolated test database
      testDbPath = p.join(
        Directory.systemTemp.path,
        'test_user_profile_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      testDb = AppDatabase.test(testDbPath);

      // Create container with test database override
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(testDb)],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();

      // Clean up test database file
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('emits null for non-existent profile', () async {
      const pubkey = 'nonexistent123';

      // Listen to provider - should emit null initially
      final listener = container.listen(
        userProfileProvider(pubkey),
        (prev, next) {},
      );

      // Wait for initial value
      await Future.delayed(Duration(milliseconds: 100));

      // Should be AsyncData with null value
      final state = listener.read();
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNull);
    });

    test('emits profile from database', () async {
      const pubkey = 'test_pubkey_123';

      // Insert test profile into database
      final testProfile = UserProfile(
        pubkey: pubkey,
        displayName: 'Test User',
        name: 'testuser',
        about: 'Test bio',
        picture: 'https://example.com/avatar.jpg',
        createdAt: DateTime.now(),
        eventId: 'event123',
        rawData: {},
      );

      await testDb.userProfilesDao.upsertProfile(testProfile);

      // Listen to provider - should emit profile
      final listener = container.listen(
        userProfileProvider(pubkey),
        (prev, next) {},
      );

      // Wait for stream to emit
      await Future.delayed(Duration(milliseconds: 100));

      // Should have profile data
      final state = listener.read();
      expect(state, isA<AsyncData<UserProfile?>>());
      expect(state.value, isNotNull);
      expect(state.value!.pubkey, pubkey);
      expect(state.value!.displayName, 'Test User');
    });

    test('auto-updates when database changes', () async {
      const pubkey = 'auto_update_test';
      final updates = <UserProfile?>[];

      // Listen to provider
      final listener = container.listen(userProfileProvider(pubkey), (
        prev,
        next,
      ) {
        if (next is AsyncData<UserProfile?>) {
          updates.add(next.value);
        }
      });

      // Wait for initial null
      await Future.delayed(Duration(milliseconds: 100));
      expect(updates.length, greaterThanOrEqualTo(1));
      expect(updates.first, isNull);

      // Insert profile - should trigger update
      final profile1 = UserProfile(
        pubkey: pubkey,
        displayName: 'First Name',
        createdAt: DateTime.now(),
        eventId: 'event1',
        rawData: {},
      );
      await testDb.userProfilesDao.upsertProfile(profile1);

      // Wait for update
      await Future.delayed(Duration(milliseconds: 100));
      expect(updates.length, greaterThanOrEqualTo(2));
      expect(updates.last?.displayName, 'First Name');

      // Update profile - should trigger another update
      final profile2 = UserProfile(
        pubkey: pubkey,
        displayName: 'Updated Name',
        createdAt: DateTime.now(),
        eventId: 'event2',
        rawData: {},
      );
      await testDb.userProfilesDao.upsertProfile(profile2);

      // Wait for update
      await Future.delayed(Duration(milliseconds: 100));
      expect(updates.length, greaterThanOrEqualTo(3));
      expect(updates.last?.displayName, 'Updated Name');

      listener.close();
    });

    test('works with overridden test database', () async {
      // Verify we're using the test database, not the shared one
      final db = container.read(databaseProvider);
      expect(identical(db, testDb), true);
    });
  });
}
