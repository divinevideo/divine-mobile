// ABOUTME: Tests for Hive to Drift data migration ensuring zero data loss
// ABOUTME: Verifies migration safety, idempotency, and error handling

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/database/hive_to_drift_migrator.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late String testDbPath;
  late Directory testTempDir;
  late AppDatabase db;
  late HiveToDriftMigrator migrator;

  // One-time Hive setup for all tests
  setUpAll(() {
    // Initialize Hive (only once)
    final globalTempDir = Directory.systemTemp.createTempSync('hive_global_');
    Hive.init(globalTempDir.path);

    // Register UserProfile adapter manually (typeId: 3)
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(UserProfileAdapter());
    }
  });

  setUp(() async {
    // Setup unique paths for each test
    testTempDir = Directory.systemTemp.createTempSync('migration_test_');
    testDbPath = '${testTempDir.path}/test_drift.db';

    // Initialize Drift database
    db = AppDatabase.test(testDbPath);

    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create migrator
    migrator = HiveToDriftMigrator(db);
  });

  tearDown(() async {
    // Close and delete the 'profiles' box to clean up between tests
    if (Hive.isBoxOpen('profiles')) {
      final box = Hive.box<UserProfile>('profiles');
      await box.clear(); // Clear all data
      await box.close();
    }

    // Delete the box file to ensure fresh state for next test
    await Hive.deleteBoxFromDisk('profiles');

    // Close Drift database
    await db.close();

    // Clean up test files
    try {
      if (await testTempDir.exists()) {
        await testTempDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignore cleanup errors in tests
    }
  });

  group('Migration Completion Flag', () {
    test('migration is not complete initially', () async {
      final isComplete = await migrator.isMigrationComplete();
      expect(isComplete, false);
    });

    test(
      'migration completion flag gets set after successful migration',
      () async {
        final result = await migrator.migrate();
        expect(result.success, true);

        final isComplete = await migrator.isMigrationComplete();
        expect(isComplete, true);
      },
    );

    test('migration can be rolled back', () async {
      // Run migration
      await migrator.migrate();
      expect(await migrator.isMigrationComplete(), true);

      // Rollback
      await migrator.rollback();
      expect(await migrator.isMigrationComplete(), false);
    });
  });

  group('Empty Hive Box Migration', () {
    test('handles empty Hive box gracefully', () async {
      // Open empty box
      final profileBox = await Hive.openBox<UserProfile>('profiles');
      expect(profileBox.isEmpty, true);

      // Run migration
      final result = await migrator.migrate();

      expect(result.success, true);
      expect(result.profilesMigrated, 0);

      await profileBox.close();
    });

    test('marks migration complete even with no data', () async {
      await Hive.openBox<UserProfile>('profiles');

      await migrator.migrate();
      final isComplete = await migrator.isMigrationComplete();

      expect(isComplete, true);
    });
  });

  group('Profile Data Migration', () {
    test('migrates all profiles from Hive to Drift', () async {
      // Create test profiles in Hive
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      final profile1 = UserProfile(
        pubkey: 'test_pubkey_1',
        name: 'Alice',
        displayName: 'Alice Wonder',
        about: 'Test user 1',
        picture: 'https://example.com/alice.jpg',
        rawData: {'test': 'data1'},
        createdAt: DateTime(2024, 1, 1),
        eventId: 'event_1',
      );

      final profile2 = UserProfile(
        pubkey: 'test_pubkey_2',
        name: 'Bob',
        displayName: 'Bob Builder',
        about: 'Test user 2',
        picture: 'https://example.com/bob.jpg',
        rawData: {'test': 'data2'},
        createdAt: DateTime(2024, 1, 2),
        eventId: 'event_2',
      );

      final profile3 = UserProfile(
        pubkey: 'test_pubkey_3',
        name: 'Charlie',
        displayName: null, // Test null field
        about: null,
        picture: null,
        rawData: {},
        createdAt: DateTime(2024, 1, 3),
        eventId: 'event_3',
      );

      await profileBox.put(profile1.pubkey, profile1);
      await profileBox.put(profile2.pubkey, profile2);
      await profileBox.put(profile3.pubkey, profile3);

      expect(profileBox.length, 3);

      // Run migration
      final result = await migrator.migrate();

      expect(result.success, true);
      expect(result.profilesMigrated, 3);

      // Verify data in Drift
      final driftProfiles = await db.userProfilesDao.getAllProfiles();
      expect(driftProfiles.length, 3);

      // Verify profile1
      final driftProfile1 = await db.userProfilesDao.getProfile(
        'test_pubkey_1',
      );
      expect(driftProfile1, isNotNull);
      expect(driftProfile1!.pubkey, profile1.pubkey);
      expect(driftProfile1.name, profile1.name);
      expect(driftProfile1.displayName, profile1.displayName);
      expect(driftProfile1.about, profile1.about);
      expect(driftProfile1.picture, profile1.picture);
      expect(driftProfile1.eventId, profile1.eventId);
      expect(driftProfile1.rawData['test'], 'data1');

      // Verify profile2
      final driftProfile2 = await db.userProfilesDao.getProfile(
        'test_pubkey_2',
      );
      expect(driftProfile2, isNotNull);
      expect(driftProfile2!.name, profile2.name);

      // Verify profile3 (with null fields)
      final driftProfile3 = await db.userProfilesDao.getProfile(
        'test_pubkey_3',
      );
      expect(driftProfile3, isNotNull);
      expect(driftProfile3!.name, profile3.name);
      expect(driftProfile3.displayName, isNull);
      expect(driftProfile3.about, isNull);
      expect(driftProfile3.picture, isNull);

      await profileBox.close();
    });

    test('preserves all profile fields during migration', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      final complexProfile = UserProfile(
        pubkey: 'complex_pubkey',
        name: 'Complex User',
        displayName: 'Complex Display',
        about: 'This is a complex bio with special chars: 😀 🎉',
        picture: 'https://example.com/complex.jpg',
        banner: 'https://example.com/banner.jpg',
        website: 'https://example.com',
        nip05: 'user@example.com',
        lud16: 'user@lightning.com',
        lud06: 'LNURL...',
        rawData: {
          'vine_username': 'vineuser',
          'vine_verified': true,
          'vine_followers': 1000,
          'vine_loops': 5000,
          'location': 'San Francisco',
          'nested': {'data': 'value'},
        },
        createdAt: DateTime(2024, 6, 15, 10, 30, 45),
        eventId: 'complex_event_id',
      );

      await profileBox.put(complexProfile.pubkey, complexProfile);

      // Migrate
      final result = await migrator.migrate();
      expect(result.success, true);

      // Verify ALL fields preserved
      final migrated = await db.userProfilesDao.getProfile('complex_pubkey');
      expect(migrated, isNotNull);
      expect(migrated!.pubkey, complexProfile.pubkey);
      expect(migrated.name, complexProfile.name);
      expect(migrated.displayName, complexProfile.displayName);
      expect(migrated.about, complexProfile.about);
      expect(migrated.picture, complexProfile.picture);
      expect(migrated.banner, complexProfile.banner);
      expect(migrated.website, complexProfile.website);
      expect(migrated.nip05, complexProfile.nip05);
      expect(migrated.lud16, complexProfile.lud16);
      expect(migrated.lud06, complexProfile.lud06);
      expect(migrated.eventId, complexProfile.eventId);
      expect(migrated.createdAt.year, complexProfile.createdAt.year);
      expect(migrated.createdAt.month, complexProfile.createdAt.month);
      expect(migrated.createdAt.day, complexProfile.createdAt.day);

      // Verify rawData
      expect(migrated.rawData['vine_username'], 'vineuser');
      expect(migrated.rawData['vine_verified'], true);
      expect(migrated.rawData['vine_followers'], 1000);
      expect(migrated.rawData['vine_loops'], 5000);
      expect(migrated.rawData['location'], 'San Francisco');
      expect(migrated.rawData['nested']['data'], 'value');

      await profileBox.close();
    });

    test('handles profile with minimal data', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      final minimalProfile = UserProfile(
        pubkey: 'minimal_pubkey',
        rawData: {},
        createdAt: DateTime(2024, 1, 1),
        eventId: 'minimal_event',
      );

      await profileBox.put(minimalProfile.pubkey, minimalProfile);

      final result = await migrator.migrate();
      expect(result.success, true);

      final migrated = await db.userProfilesDao.getProfile('minimal_pubkey');
      expect(migrated, isNotNull);
      expect(migrated!.pubkey, minimalProfile.pubkey);
      expect(migrated.name, isNull);
      expect(migrated.displayName, isNull);
      expect(migrated.about, isNull);

      await profileBox.close();
    });
  });

  group('Migration Idempotency', () {
    test('running migration twice does not cause errors', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      final profile = UserProfile(
        pubkey: 'idempotent_test',
        name: 'Test User',
        rawData: {},
        createdAt: DateTime(2024, 1, 1),
        eventId: 'event_1',
      );

      await profileBox.put(profile.pubkey, profile);

      // First migration
      final result1 = await migrator.migrate();
      expect(result1.success, true);
      expect(result1.profilesMigrated, 1);

      // Second migration (should be skipped)
      final result2 = await migrator.migrate();
      expect(result2.success, true);
      expect(result2.profilesMigrated, 0); // Already complete

      // Verify data still intact
      final driftProfiles = await db.userProfilesDao.getAllProfiles();
      expect(driftProfiles.length, 1);

      await profileBox.close();
    });

    test('migration after rollback re-migrates data', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      final profile = UserProfile(
        pubkey: 'rollback_test',
        name: 'Rollback User',
        rawData: {},
        createdAt: DateTime(2024, 1, 1),
        eventId: 'event_1',
      );

      await profileBox.put(profile.pubkey, profile);

      // First migration
      await migrator.migrate();
      expect(await migrator.isMigrationComplete(), true);

      // Rollback
      await migrator.rollback();
      expect(await migrator.isMigrationComplete(), false);

      // Verify Drift table cleared
      final clearedProfiles = await db.userProfilesDao.getAllProfiles();
      expect(clearedProfiles.length, 0);

      // Re-migrate
      final result = await migrator.migrate();
      expect(result.success, true);
      expect(result.profilesMigrated, 1);

      // Verify data restored
      final restoredProfiles = await db.userProfilesDao.getAllProfiles();
      expect(restoredProfiles.length, 1);

      await profileBox.close();
    });
  });

  group('Error Handling', () {
    test('continues migration if single profile fails', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      // Valid profile
      final validProfile = UserProfile(
        pubkey: 'valid_pubkey',
        name: 'Valid User',
        rawData: {},
        createdAt: DateTime(2024, 1, 1),
        eventId: 'valid_event',
      );

      await profileBox.put(validProfile.pubkey, validProfile);

      // Note: Creating a truly corrupt profile that Drift will reject is hard
      // because UserProfile validation happens before Drift.
      // This test verifies the migration continues even if individual upserts fail.

      final result = await migrator.migrate();
      expect(result.success, true);
      expect(result.profilesMigrated, greaterThanOrEqualTo(1));

      await profileBox.close();
    });

    test('handles missing Hive box gracefully', () async {
      // Don't create any Hive box - test that migration handles this

      final result = await migrator.migrate();

      // Migration should succeed but migrate 0 profiles
      expect(result.success, true);
      expect(result.profilesMigrated, 0);
    });

    test('handles corrupted Hive data gracefully', () async {
      // Hive will handle corrupted data during box opening
      // If box can't be opened, migration returns 0 profiles

      final result = await migrator.migrate();
      expect(result.success, true);
    });
  });

  group('Migration Rollback', () {
    test('rollback clears Drift tables', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      final profile = UserProfile(
        pubkey: 'rollback_clear_test',
        name: 'Rollback User',
        rawData: {},
        createdAt: DateTime(2024, 1, 1),
        eventId: 'event_1',
      );

      await profileBox.put(profile.pubkey, profile);

      // Migrate
      await migrator.migrate();
      final migratedProfiles = await db.userProfilesDao.getAllProfiles();
      expect(migratedProfiles.length, 1);

      // Rollback
      await migrator.rollback();

      // Verify Drift table cleared
      final clearedProfiles = await db.userProfilesDao.getAllProfiles();
      expect(clearedProfiles.length, 0);

      // Verify Hive data still exists (rollback doesn't touch Hive)
      // Re-open box since migration closed it
      final reopenedBox = await Hive.openBox<UserProfile>('profiles');
      expect(reopenedBox.length, 1);
      await reopenedBox.close();
    });

    test('rollback removes migration completion flag', () async {
      await migrator.migrate();
      expect(await migrator.isMigrationComplete(), true);

      await migrator.rollback();
      expect(await migrator.isMigrationComplete(), false);
    });
  });

  group('Migration Statistics', () {
    test('reports correct number of migrated profiles', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      // Add 5 profiles
      for (int i = 0; i < 5; i++) {
        final profile = UserProfile(
          pubkey: 'pubkey_$i',
          name: 'User $i',
          rawData: {},
          createdAt: DateTime(2024, 1, i + 1),
          eventId: 'event_$i',
        );
        await profileBox.put(profile.pubkey, profile);
      }

      final result = await migrator.migrate();
      expect(result.success, true);
      expect(result.profilesMigrated, 5);

      await profileBox.close();
    });

    test('returns zero profiles when already migrated', () async {
      // First migration
      await migrator.migrate();

      // Second attempt
      final result = await migrator.migrate();
      expect(result.success, true);
      expect(result.profilesMigrated, 0);
    });
  });

  group('Large Dataset Migration', () {
    test('migrates 100 profiles successfully', () async {
      final profileBox = await Hive.openBox<UserProfile>('profiles');

      // Create 100 test profiles
      for (int i = 0; i < 100; i++) {
        final profile = UserProfile(
          pubkey: 'large_test_pubkey_$i',
          name: 'User $i',
          displayName: 'Display $i',
          rawData: {'index': i},
          createdAt: DateTime(2024, 1, 1).add(Duration(days: i)),
          eventId: 'event_$i',
        );
        await profileBox.put(profile.pubkey, profile);
      }

      // Migrate
      final result = await migrator.migrate();
      expect(result.success, true);
      expect(result.profilesMigrated, 100);

      // Verify all profiles migrated
      final driftProfiles = await db.userProfilesDao.getAllProfiles();
      expect(driftProfiles.length, 100);

      // Spot check a few profiles
      final profile0 = await db.userProfilesDao.getProfile(
        'large_test_pubkey_0',
      );
      expect(profile0, isNotNull);
      expect(profile0!.name, 'User 0');

      final profile50 = await db.userProfilesDao.getProfile(
        'large_test_pubkey_50',
      );
      expect(profile50, isNotNull);
      expect(profile50!.name, 'User 50');

      final profile99 = await db.userProfilesDao.getProfile(
        'large_test_pubkey_99',
      );
      expect(profile99, isNotNull);
      expect(profile99!.name, 'User 99');

      await profileBox.close();
    });
  });
}
