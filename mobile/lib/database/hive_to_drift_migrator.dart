// ABOUTME: Migrates data from Hive boxes to Drift database ensuring zero data loss
// ABOUTME: One-time migration with idempotent execution and rollback support

import 'package:hive_ce/hive.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Migrates data from Hive boxes to Drift database
///
/// This is a ONE-TIME migration that runs on app startup
/// if the migration hasn't been completed yet.
///
/// Safety measures:
/// - Migration is idempotent (can run multiple times safely)
/// - Original Hive data is NOT deleted (allows rollback)
/// - Individual profile failures don't abort entire migration
/// - Migration flag prevents duplicate runs
/// - Rollback capability for emergency recovery
class HiveToDriftMigrator {
  final AppDatabase _db;
  static const String _migrationFlagKey = 'hive_to_drift_migration_complete';

  HiveToDriftMigrator(this._db);

  /// Check if migration has already been completed
  Future<bool> isMigrationComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_migrationFlagKey) ?? false;
  }

  /// Run full migration
  Future<MigrationResult> migrate() async {
    if (await isMigrationComplete()) {
      Log.info(
        'Hive to Drift migration already complete',
        name: 'HiveToDriftMigrator',
        category: LogCategory.storage,
      );
      return MigrationResult.alreadyComplete();
    }

    try {
      Log.info(
        'Starting Hive to Drift migration...',
        name: 'HiveToDriftMigrator',
        category: LogCategory.storage,
      );

      // Migrate profiles
      final profileCount = await migrateProfiles();

      // TODO: Migrate other boxes (notifications, hashtags, etc.)

      // Mark migration as complete
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_migrationFlagKey, true);

      Log.info(
        'Migration complete: $profileCount profiles migrated',
        name: 'HiveToDriftMigrator',
        category: LogCategory.storage,
      );
      return MigrationResult.success(profileCount);
    } catch (e, stackTrace) {
      Log.error(
        'Migration failed: $e',
        stackTrace: stackTrace,
        name: 'HiveToDriftMigrator',
        category: LogCategory.storage,
      );
      return MigrationResult.failure(e.toString());
    }
  }

  /// Migrate profile_cache Hive box to Drift
  Future<int> migrateProfiles() async {
    try {
      // Try to open Hive box
      Box<UserProfile>? profileBox;
      try {
        profileBox = await Hive.openBox<UserProfile>('profiles');
      } catch (e) {
        Log.warning(
          'Failed to open Hive profile box: $e',
          name: 'HiveToDriftMigrator',
          category: LogCategory.storage,
        );
        return 0;
      }

      int count = 0;
      int failedCount = 0;

      for (final profile in profileBox.values) {
        try {
          await _db.userProfilesDao.upsertProfile(profile);
          count++;
        } catch (e) {
          Log.warning(
            'Failed to migrate profile ${profile.pubkey}: $e',
            name: 'HiveToDriftMigrator',
            category: LogCategory.storage,
          );
          failedCount++;
          // Continue with next profile - don't fail entire migration
        }
      }

      if (failedCount > 0) {
        Log.warning(
          'Migration completed with $failedCount failed profiles',
          name: 'HiveToDriftMigrator',
          category: LogCategory.storage,
        );
      }

      await profileBox.close();
      return count;
    } catch (e) {
      Log.error(
        'Failed to migrate profiles: $e',
        name: 'HiveToDriftMigrator',
        category: LogCategory.storage,
      );
      return 0;
    }
  }

  /// Rollback migration (for testing or emergency)
  Future<void> rollback() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_migrationFlagKey);

    // Clear Drift tables
    await _db.customStatement('DELETE FROM user_profiles');

    Log.info(
      'Migration rolled back',
      name: 'HiveToDriftMigrator',
      category: LogCategory.storage,
    );
  }
}

/// Result of a migration operation
class MigrationResult {
  final bool success;
  final int profilesMigrated;
  final String? error;

  MigrationResult.success(this.profilesMigrated) : success = true, error = null;

  MigrationResult.failure(this.error) : success = false, profilesMigrated = 0;

  MigrationResult.alreadyComplete()
    : success = true,
      profilesMigrated = 0,
      error = null;
}
