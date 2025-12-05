# Hive to Drift Migration Guide

## Overview

This migration safely moves existing user profile data from Hive boxes to the new Drift database system. The migration is designed to run automatically on app startup with zero data loss.

## Safety Features

### 1. Idempotent Execution
- Migration can be run multiple times without causing errors
- Completion flag (`hive_to_drift_migration_complete`) prevents duplicate runs
- Safe to deploy across all users simultaneously

### 2. Data Preservation
- **Original Hive data is NOT deleted**
- Hive boxes remain intact after migration
- Allows emergency rollback if needed
- Users can downgrade to previous app version safely

### 3. Error Resilience
- Individual profile migration failures don't abort the entire process
- Failed profiles are logged but migration continues
- Empty or missing Hive boxes are handled gracefully

### 4. Rollback Support
- Emergency rollback procedure available
- Clears migrated Drift data
- Resets migration completion flag
- Allows re-running migration from scratch

## Migration Process

### Automatic Migration

The migration runs automatically via `MigrationService.runMigrations()` during app startup:

```dart
final migrationService = MigrationService(appDatabase);
await migrationService.runMigrations();
```

**What gets migrated:**
- User profiles from `user_profiles` Hive box
- All profile fields (name, display_name, picture, etc.)
- Raw metadata (vine_username, vine_verified, etc.)
- Profile timestamps (created_at, event_id)

**What does NOT get migrated yet:**
- Video cache
- Hashtag cache
- Personal events
- Subscription data
- (These will be added in future migration phases)

### Migration Status

Check if migration is complete:

```dart
final migrator = HiveToDriftMigrator(db);
final isComplete = await migrator.isMigrationComplete();
```

## Rollback Procedure

⚠️ **Emergency Use Only** - This will delete all migrated data from Drift.

### When to Use Rollback

- Critical bug discovered in migrated data
- Need to re-run migration with fixes
- Emergency recovery scenario

### How to Rollback

```dart
final migrator = HiveToDriftMigrator(db);
await migrator.rollback();
```

**What rollback does:**
1. Removes migration completion flag from SharedPreferences
2. Deletes all data from `user_profiles` Drift table
3. **Leaves Hive data intact** (allows re-migration)

**After rollback:**
- App will re-run migration on next startup
- Or migration can be triggered manually

## Testing

Comprehensive tests cover:
- ✅ Migration completion flag management
- ✅ Empty Hive box handling
- ✅ Data integrity preservation
- ✅ Idempotent execution
- ✅ Error resilience
- ✅ Rollback functionality
- ✅ Large dataset migration (100+ profiles)

Run migration tests:

```bash
flutter test test/migration/hive_to_drift_migration_test.dart
```

## Monitoring

Migration logs provide detailed information:

```
[HiveToDriftMigrator] Starting Hive to Drift migration...
[HiveToDriftMigrator] Migration complete: 42 profiles migrated
```

Failed individual migrations are logged but don't stop the process:

```
[HiveToDriftMigrator] Failed to migrate profile {pubkey}: {error}
[HiveToDriftMigrator] Migration completed with 3 failed profiles
```

## Future Migration Phases

**Phase 5** (Planned):
- Migrate video cache data
- Migrate hashtag cache
- Migrate personal event cache
- Migrate subscription manager data

**Phase 6** (Planned):
- Remove Hive dependencies entirely
- Delete old Hive boxes
- Clean up migration code (no longer needed)

## Troubleshooting

### Migration appears stuck
- Check logs for errors
- Verify SharedPreferences is accessible
- Ensure Drift database connection is working

### Data missing after migration
- DO NOT rollback immediately
- Check Hive boxes are still intact: `Hive.openBox<UserProfile>('profiles')`
- Verify Drift table: `db.userProfilesDao.getAllProfiles()`
- Report issue with logs

### Want to force re-migration
```dart
// Clear flag and rollback
final prefs = await SharedPreferences.getInstance();
await prefs.remove('hive_to_drift_migration_complete');
await db.customStatement('DELETE FROM user_profiles');
```

## Architecture Notes

- Uses SharedPreferences for migration flag (reliable, simple)
- Drift tables use `INSERT ON CONFLICT UPDATE` for safety
- Hive boxes are closed after reading (not deleted)
- Migration runs before any profile queries
- Safe to run on main thread (fast, <100ms typically)
