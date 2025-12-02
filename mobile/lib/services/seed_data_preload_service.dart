// ABOUTME: Service for loading seed data into database on first launch
// ABOUTME: Executes bundled SQL INSERT statements when database is empty

import 'package:flutter/services.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/utils/unified_logger.dart';

class SeedDataPreloadService {
  /// Load seed data if database is empty
  ///
  /// This is a one-time operation on first app launch.
  /// If database already has events, this is a no-op.
  ///
  /// Errors are logged but non-critical - app works normally by fetching
  /// from relay if seed load fails.
  static Future<void> loadSeedDataIfNeeded(AppDatabase db) async {
    try {
      // Check if database already has events
      final count = await db.nostrEventsDao.getEventCount();
      if (count > 0) {
        Log.info(
          '[SEED] Database has $count events, skipping seed load',
          name: 'SeedDataPreload',
          category: LogCategory.system,
        );
        return;
      }

      Log.info(
        '[SEED] Database empty, loading seed data...',
        name: 'SeedDataPreload',
        category: LogCategory.system,
      );

      // Load SQL file from assets
      final sql = await rootBundle.loadString(
        'assets/seed_data/seed_events.sql',
      );

      // Execute all SQL statements in a single transaction
      await db.transaction(() async {
        final statements = sql
            .split(';')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty && !s.startsWith('--'));

        for (final statement in statements) {
          await db.customStatement(statement);
        }
      });

      // Log success
      final finalCount = await db.nostrEventsDao.getEventCount();
      Log.info(
        '[SEED] ✅ Loaded seed data: $finalCount events',
        name: 'SeedDataPreload',
        category: LogCategory.system,
      );
    } catch (e, stack) {
      // Non-critical failure: user will fetch from relay normally
      Log.error(
        '[SEED] ❌ Failed to load seed data (non-critical): $e',
        name: 'SeedDataPreload',
        category: LogCategory.system,
      );
      Log.verbose(
        '[SEED] Stack trace: $stack',
        name: 'SeedDataPreload',
        category: LogCategory.system,
      );
    }
  }
}
