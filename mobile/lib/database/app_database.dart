// ABOUTME: Main Drift database that shares SQLite file with nostr_sdk
// ABOUTME: Provides reactive queries and unified event/profile caching

import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';
import 'daos/user_profiles_dao.dart';
import 'daos/nostr_events_dao.dart';
import 'daos/video_metrics_dao.dart';

part 'app_database.g.dart';

/// Main application database using Drift
///
/// This database shares the same SQLite file as nostr_sdk's embedded relay
/// (local_relay.db) to provide a single source of truth for all Nostr events.
///
/// Schema versioning:
/// - nostr_sdk: schema version 1-2 (event table)
/// - AppDatabase: schema version 3+ (adds user_profiles, etc.)
@DriftDatabase(
  tables: [NostrEvents, UserProfiles, VideoMetrics],
  daos: [UserProfilesDao, NostrEventsDao, VideoMetricsDao],
)
class AppDatabase extends _$AppDatabase {
  /// Default constructor - uses shared database path with nostr_sdk
  AppDatabase() : super(_openConnection());

  /// Test constructor - allows custom database path for testing
  AppDatabase.test(String path)
    : super(
        NativeDatabase(File(path), logStatements: false),
      ); // Disabled - too verbose

  @override
  int get schemaVersion => 5;

  /// Open connection to shared database file
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbPath = await _getSharedDatabasePath();
      return NativeDatabase(
        File(dbPath),
        logStatements: false, // Disabled - too verbose for production
      );
    });
  }

  /// Get path to shared database file
  ///
  /// Uses same pattern as nostr_sdk:
  /// {appDocuments}/openvine/database/local_relay.db
  static Future<String> _getSharedDatabasePath() async {
    final docDir = await getApplicationDocumentsDirectory();
    return p.join(docDir.path, 'openvine', 'database', 'local_relay.db');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // In production, event table already exists from nostr_sdk
      // In tests, we need to create it ourselves
      await m.createTable(nostrEvents);
      await m.createTable(userProfiles);
      await m.createTable(videoMetrics);
    },
    onUpgrade: (m, from, to) async {
      // Migration from nostr_sdk schema v2 to AppDatabase schema v3
      if (from < 3) {
        // Add user_profiles table (event table already exists from nostr_sdk)
        await m.createTable(userProfiles);
      }

      // Migration from schema v3 to v4: Add video_metrics table
      if (from < 4) {
        await m.createTable(videoMetrics);

        // Create indices for common sort/filter operations
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_video_metrics_loop_count
              ON video_metrics(loop_count DESC)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_video_metrics_likes
              ON video_metrics(likes DESC)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_video_metrics_views
              ON video_metrics(views DESC)
            ''');

        // Backfill metrics for ALL existing video events (kind 34236 and 6)
        // This parses tags from existing events and populates video_metrics
        // CRITICAL: Must happen during migration, not background, so queries work immediately
        try {
          // Count events before backfill for logging
          final countResult = await customSelect(
            'SELECT COUNT(*) as cnt FROM event WHERE kind IN (34236, 6)',
          ).getSingle();
          final eventCount = countResult.read<int>('cnt');

          print(
            '[MIGRATION] Backfilling metrics for $eventCount video events...',
          );

          // Use INSERT OR IGNORE to skip events that fail parsing
          // This ensures migration completes even if some events have bad data
          await customStatement('''
                INSERT OR IGNORE INTO video_metrics (event_id, loop_count, likes, views, comments, avg_completion,
                                           has_proofmode, has_device_attestation, has_pgp_signature, updated_at)
                SELECT
                  e.id,
                  CASE
                    WHEN json_extract(
                      (SELECT value FROM json_each(e.tags)
                       WHERE json_extract(value, '\$[0]') = 'loops' LIMIT 1),
                      '\$[1]'
                    ) IS NOT NULL
                    THEN CAST(json_extract(
                      (SELECT value FROM json_each(e.tags)
                       WHERE json_extract(value, '\$[0]') = 'loops' LIMIT 1),
                      '\$[1]'
                    ) AS INTEGER)
                    ELSE NULL
                  END,
                  CASE
                    WHEN json_extract(
                      (SELECT value FROM json_each(e.tags)
                       WHERE json_extract(value, '\$[0]') = 'likes' LIMIT 1),
                      '\$[1]'
                    ) IS NOT NULL
                    THEN CAST(json_extract(
                      (SELECT value FROM json_each(e.tags)
                       WHERE json_extract(value, '\$[0]') = 'likes' LIMIT 1),
                      '\$[1]'
                    ) AS INTEGER)
                    ELSE NULL
                  END,
                  NULL,
                  CASE
                    WHEN json_extract(
                      (SELECT value FROM json_each(e.tags)
                       WHERE json_extract(value, '\$[0]') = 'comments' LIMIT 1),
                      '\$[1]'
                    ) IS NOT NULL
                    THEN CAST(json_extract(
                      (SELECT value FROM json_each(e.tags)
                       WHERE json_extract(value, '\$[0]') = 'comments' LIMIT 1),
                      '\$[1]'
                    ) AS INTEGER)
                    ELSE NULL
                  END,
                  NULL,
                  NULL,
                  NULL,
                  NULL,
                  datetime('now')
                FROM event e
                WHERE e.kind IN (34236, 6)
              ''');

          // Count successful backfills
          final backfilledResult = await customSelect(
            'SELECT COUNT(*) as cnt FROM video_metrics',
          ).getSingle();
          final backfilledCount = backfilledResult.read<int>('cnt');

          print(
            '[MIGRATION] ✅ Backfilled metrics for $backfilledCount/$eventCount video events',
          );

          if (backfilledCount < eventCount) {
            print(
              '[MIGRATION] ⚠️  ${eventCount - backfilledCount} events skipped (malformed tags or duplicate IDs)',
            );
          }
        } catch (e, stackTrace) {
          // Log error but don't fail migration - table and indices are created
          // Future events will still get metrics via upsertEvent()
          print('[MIGRATION] ⚠️  Backfill failed: $e');
          print('[MIGRATION] Stack trace: $stackTrace');
          print(
            '[MIGRATION] Migration completed with empty video_metrics table',
          );
          print('[MIGRATION] New events will populate metrics going forward');
        }
      }

      // Migration from schema v4 to v5: Add indexes to event table for fast queries
      if (from < 5) {
        print('[MIGRATION] Adding performance indexes to event table...');

        // Create indexes on NostrEvents table for common query patterns
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_event_kind
              ON event (kind)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_event_created_at
              ON event (created_at)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_event_kind_created_at
              ON event (kind, created_at)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_event_pubkey
              ON event (pubkey)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_event_kind_pubkey
              ON event (kind, pubkey)
            ''');
        await customStatement('''
              CREATE INDEX IF NOT EXISTS idx_event_pubkey_created_at
              ON event (pubkey, created_at)
            ''');

        print(
          '[MIGRATION] ✅ Created 6 indexes on event table for fast discovery/trending/profile queries',
        );
      }
    },
  );
}
