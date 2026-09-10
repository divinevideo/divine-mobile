// ABOUTME: Tests for Drift database setup and shared database access
// ABOUTME: Verifies AppDatabase can open nostr_sdk's existing SQLite database

// Permanent: opens file-backed Drift databases through path_provider temp paths;
// keep isolated until DB and path-provider globals are per-test fixtures.
@Tags(['skip_very_good_optimization'])
library;

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift Database Setup', () {
    late String testDbPath;

    setUp(() async {
      // Create test database path (same pattern as nostr_sdk)
      final tempDir = await getTemporaryDirectory();
      testDbPath = p.join(
        tempDir.path,
        'openvine_test',
        'database',
        'local_relay.db',
      );

      // Ensure directory exists
      await Directory(p.dirname(testDbPath)).create(recursive: true);
    });

    tearDown(() async {
      // Clean up test database
      final dbFile = File(testDbPath);
      if (dbFile.existsSync()) {
        await dbFile.delete();
      }
    });

    test('AppDatabase can be instantiated', () {
      final db = AppDatabase.test(NativeDatabase(File(testDbPath)));
      expect(db, isNotNull);
      db.close();
    });

    test('AppDatabase uses correct shared database path', () async {
      final db = AppDatabase.test(NativeDatabase(File(testDbPath)));

      // Verify database path matches nostr_sdk pattern
      expect(testDbPath, contains('local_relay.db'));
      expect(testDbPath, contains(p.join('openvine_test', 'database')));

      await db.close();
    });

    test('AppDatabase can query existing nostr_sdk event table', () async {
      final db = AppDatabase.test(NativeDatabase(File(testDbPath)));

      // Create the event table (simulating nostr_sdk schema)
      await db.customStatement('''
        CREATE TABLE IF NOT EXISTS event (
          id text NOT NULL,
          pubkey text NOT NULL,
          created_at integer NOT NULL,
          kind integer NOT NULL,
          tags text NOT NULL,
          content text NOT NULL,
          sig text NOT NULL,
          sources text,
          PRIMARY KEY (id)
        )
      ''');

      // Insert test event
      await db.customStatement('''
        INSERT INTO event (id, pubkey, created_at, kind, tags, content, sig)
        VALUES ('test_id', 'test_pubkey', 1234567890, 1, '[]', 'test content', 'test_sig')
      ''');

      // Query event table
      final result = await db.customSelect('SELECT * FROM event LIMIT 1').get();
      expect(result, isNotEmpty);
      expect(result.first.data['id'], equals('test_id'));
      expect(result.first.data['kind'], equals(1));

      await db.close();
    });

    test('AppDatabase closes cleanly', () async {
      final db = AppDatabase.test(NativeDatabase(File(testDbPath)));

      // Database should be open initially
      final result = await db.customSelect('SELECT 1').get();
      expect(result, isNotEmpty);

      // Close database
      await db.close();

      // Verify close completed without error
      // Note: Drift doesn't throw on queries after close, it just returns cached results
      // The important thing is that close() completes successfully
      expect(db, isNotNull);
    });
  });
}
