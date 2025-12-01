// ABOUTME: Service that runs database migrations on app startup
// ABOUTME: Manages one-time Hive to Drift migration with error handling

import 'package:openvine/database/app_database.dart';
import 'package:openvine/database/hive_to_drift_migrator.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service that runs migrations on app startup
class MigrationService {
  final AppDatabase _db;

  MigrationService(this._db);

  /// Run all pending migrations
  Future<void> runMigrations() async {
    final migrator = HiveToDriftMigrator(_db);

    if (!await migrator.isMigrationComplete()) {
      Log.info(
        'Running Hive to Drift migration...',
        name: 'MigrationService',
        category: LogCategory.storage,
      );

      final result = await migrator.migrate();

      if (!result.success) {
        Log.error(
          'Migration failed: ${result.error}',
          name: 'MigrationService',
          category: LogCategory.storage,
        );
        // Don't block app startup, but log the error
      } else {
        Log.info(
          'Migration successful: ${result.profilesMigrated} profiles migrated',
          name: 'MigrationService',
          category: LogCategory.storage,
        );
      }
    }
  }
}
