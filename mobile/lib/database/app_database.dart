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

part 'app_database.g.dart';

/// Main application database using Drift
///
/// This database shares the same SQLite file as nostr_sdk's embedded relay
/// (local_relay.db) to provide a single source of truth for all Nostr events.
///
/// Schema versioning:
/// - nostr_sdk: schema version 1-2 (event table)
/// - AppDatabase: schema version 3+ (adds user_profiles, etc.)
@DriftDatabase(tables: [NostrEvents, UserProfiles], daos: [UserProfilesDao, NostrEventsDao])
class AppDatabase extends _$AppDatabase {
  /// Default constructor - uses shared database path with nostr_sdk
  AppDatabase() : super(_openConnection());

  /// Test constructor - allows custom database path for testing
  AppDatabase.test(String path)
      : super(NativeDatabase(File(path), logStatements: true));

  @override
  int get schemaVersion => 3;

  /// Open connection to shared database file
  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbPath = await _getSharedDatabasePath();
      return NativeDatabase(
        File(dbPath),
        logStatements: true, // Enable SQL logging for debugging
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
        },
        onUpgrade: (m, from, to) async {
          // Migration from nostr_sdk schema v2 to AppDatabase schema v3
          if (from < 3) {
            // Add user_profiles table (event table already exists from nostr_sdk)
            await m.createTable(userProfiles);
          }
        },
      );
}
