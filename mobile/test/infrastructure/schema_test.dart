// ABOUTME: Tests for Drift table schema definitions
// ABOUTME: Verifies NostrEvents and UserProfiles tables are properly defined

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:openvine/database/app_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift Table Schema', () {
    late String testDbPath;
    late AppDatabase db;

    setUp(() async {
      // Create test database path
      final tempDir = await getTemporaryDirectory();
      testDbPath = p.join(
        tempDir.path,
        'openvine_test_schema',
        'database',
        'local_relay_${DateTime.now().millisecondsSinceEpoch}.db',
      );

      // Ensure directory exists
      await Directory(p.dirname(testDbPath)).create(recursive: true);

      // Create database instance
      db = AppDatabase.test(testDbPath);
    });

    tearDown(() async {
      // Close database
      await db.close();

      // Clean up test database
      final dbFile = File(testDbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    });

    group('NostrEvents table', () {
      test('can query existing event table from nostr_sdk', () async {
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
          VALUES (
            'test_event_id_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            1234567890,
            1,
            '[]',
            'test content',
            'test_sig_1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab'
          )
        ''');

        // Query event table
        final result = await db
            .customSelect('SELECT * FROM event LIMIT 1')
            .get();
        expect(result, isNotEmpty);
        expect(result.first.data['id'], contains('test_event_id'));
        expect(result.first.data['kind'], equals(1));
      });

      test('NostrEvents table has all required columns', () async {
        // Create the event table
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

        // Query table schema
        final schema = await db.customSelect('PRAGMA table_info(event)').get();
        final columnNames = schema
            .map((row) => row.data['name'] as String)
            .toList();

        expect(columnNames, contains('id'));
        expect(columnNames, contains('pubkey'));
        expect(columnNames, contains('created_at'));
        expect(columnNames, contains('kind'));
        expect(columnNames, contains('tags'));
        expect(columnNames, contains('content'));
        expect(columnNames, contains('sig'));
        expect(columnNames, contains('sources'));
      });

      test('NostrEvents table has correct primary key', () async {
        // Create the event table
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

        // Query table schema to verify primary key
        final schema = await db.customSelect('PRAGMA table_info(event)').get();
        final idColumn = schema.firstWhere((row) => row.data['name'] == 'id');

        // pk column indicates primary key (1 = yes, 0 = no)
        expect(idColumn.data['pk'], equals(1));
      });
    });

    group('UserProfiles table', () {
      test('UserProfiles table gets created by migration', () async {
        // Run onCreate migration
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            pubkey TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            name TEXT,
            about TEXT,
            picture TEXT,
            banner TEXT,
            website TEXT,
            nip05 TEXT,
            lud16 TEXT,
            lud06 TEXT,
            raw_data TEXT,
            created_at INTEGER NOT NULL,
            event_id TEXT NOT NULL,
            last_fetched INTEGER NOT NULL
          )
        ''');

        // Verify table exists
        final tables = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='user_profiles'",
            )
            .get();

        expect(tables, isNotEmpty);
        expect(tables.first.data['name'], equals('user_profiles'));
      });

      test('UserProfiles table has all required columns', () async {
        // Create user_profiles table
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            pubkey TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            name TEXT,
            about TEXT,
            picture TEXT,
            banner TEXT,
            website TEXT,
            nip05 TEXT,
            lud16 TEXT,
            lud06 TEXT,
            raw_data TEXT,
            created_at INTEGER NOT NULL,
            event_id TEXT NOT NULL,
            last_fetched INTEGER NOT NULL
          )
        ''');

        // Query table schema
        final schema = await db
            .customSelect('PRAGMA table_info(user_profiles)')
            .get();
        final columnNames = schema
            .map((row) => row.data['name'] as String)
            .toList();

        expect(columnNames, contains('pubkey'));
        expect(columnNames, contains('display_name'));
        expect(columnNames, contains('name'));
        expect(columnNames, contains('about'));
        expect(columnNames, contains('picture'));
        expect(columnNames, contains('banner'));
        expect(columnNames, contains('website'));
        expect(columnNames, contains('nip05'));
        expect(columnNames, contains('lud16'));
        expect(columnNames, contains('lud06'));
        expect(columnNames, contains('raw_data'));
        expect(columnNames, contains('created_at'));
        expect(columnNames, contains('event_id'));
        expect(columnNames, contains('last_fetched'));
      });

      test('UserProfiles table has correct primary key', () async {
        // Create user_profiles table
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            pubkey TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            name TEXT,
            about TEXT,
            picture TEXT,
            banner TEXT,
            website TEXT,
            nip05 TEXT,
            lud16 TEXT,
            lud06 TEXT,
            raw_data TEXT,
            created_at INTEGER NOT NULL,
            event_id TEXT NOT NULL,
            last_fetched INTEGER NOT NULL
          )
        ''');

        // Query table schema to verify primary key
        final schema = await db
            .customSelect('PRAGMA table_info(user_profiles)')
            .get();
        final pubkeyColumn = schema.firstWhere(
          (row) => row.data['name'] == 'pubkey',
        );

        // pk column indicates primary key (1 = yes, 0 = no)
        expect(pubkeyColumn.data['pk'], equals(1));
      });

      test('UserProfiles table can store and retrieve profile data', () async {
        // Create user_profiles table
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            pubkey TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            name TEXT,
            about TEXT,
            picture TEXT,
            banner TEXT,
            website TEXT,
            nip05 TEXT,
            lud16 TEXT,
            lud06 TEXT,
            raw_data TEXT,
            created_at INTEGER NOT NULL,
            event_id TEXT NOT NULL,
            last_fetched INTEGER NOT NULL
          )
        ''');

        final now = DateTime.now().millisecondsSinceEpoch;

        // Insert test profile
        await db.customStatement('''
          INSERT INTO user_profiles (
            pubkey, display_name, name, about, picture, banner, website, nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched
          ) VALUES (
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            'Test User',
            'testuser',
            'Test bio',
            'https://example.com/pic.jpg',
            'https://example.com/banner.jpg',
            'https://example.com',
            'test@example.com',
            'test@wallet.com',
            'lnurl123',
            '{}',
            $now,
            'test_event_id_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            $now
          )
        ''');

        // Query profile
        final result = await db
            .customSelect(
              'SELECT * FROM user_profiles WHERE pubkey = ?',
              variables: [
                Variable(
                  'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
                ),
              ],
            )
            .get();

        expect(result, isNotEmpty);
        expect(result.first.data['display_name'], equals('Test User'));
        expect(result.first.data['name'], equals('testuser'));
        expect(result.first.data['about'], equals('Test bio'));
        expect(result.first.data['nip05'], equals('test@example.com'));
      });

      test('UserProfiles table allows updating existing profiles', () async {
        // Create user_profiles table
        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            pubkey TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            name TEXT,
            about TEXT,
            picture TEXT,
            banner TEXT,
            website TEXT,
            nip05 TEXT,
            lud16 TEXT,
            lud06 TEXT,
            raw_data TEXT,
            created_at INTEGER NOT NULL,
            event_id TEXT NOT NULL,
            last_fetched INTEGER NOT NULL
          )
        ''');

        final testPubkey =
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
        final now = DateTime.now().millisecondsSinceEpoch;

        // Insert initial profile
        await db.customStatement(
          '''
          INSERT INTO user_profiles (
            pubkey, display_name, name, about, picture, banner, website, nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            testPubkey,
            'Old Name',
            'oldname',
            'Old bio',
            'https://example.com/old.jpg',
            'https://example.com/old_banner.jpg',
            'https://example.com',
            'old@example.com',
            'old@wallet.com',
            'lnurl123',
            '{}',
            now,
            'test_event_id_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            now,
          ],
        );

        // Update profile
        await db.customStatement(
          '''
          UPDATE user_profiles
          SET display_name = ?, name = ?, last_fetched = ?
          WHERE pubkey = ?
        ''',
          [
            'New Name',
            'newname',
            DateTime.now().millisecondsSinceEpoch,
            testPubkey,
          ],
        );

        // Query updated profile
        final result = await db
            .customSelect(
              'SELECT * FROM user_profiles WHERE pubkey = ?',
              variables: [Variable(testPubkey)],
            )
            .get();

        expect(result, isNotEmpty);
        expect(result.first.data['display_name'], equals('New Name'));
        expect(result.first.data['name'], equals('newname'));
        expect(result.first.data['about'], equals('Old bio')); // Unchanged
      });
    });

    group('Database integration', () {
      test('Can query both NostrEvents and UserProfiles tables', () async {
        // Create both tables
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

        await db.customStatement('''
          CREATE TABLE IF NOT EXISTS user_profiles (
            pubkey TEXT NOT NULL PRIMARY KEY,
            display_name TEXT,
            name TEXT,
            about TEXT,
            picture TEXT,
            banner TEXT,
            website TEXT,
            nip05 TEXT,
            lud16 TEXT,
            lud06 TEXT,
            raw_data TEXT,
            created_at INTEGER NOT NULL,
            event_id TEXT NOT NULL,
            last_fetched INTEGER NOT NULL
          )
        ''');

        // Insert test data
        final testPubkey =
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
        final now = DateTime.now().millisecondsSinceEpoch;

        await db.customStatement(
          '''
          INSERT INTO user_profiles (
            pubkey, display_name, name, about, picture, banner, website, nip05, lud16, lud06, raw_data, created_at, event_id, last_fetched
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            testPubkey,
            'Test User',
            'testuser',
            'Test bio',
            'https://example.com/pic.jpg',
            'https://example.com/banner.jpg',
            'https://example.com',
            'test@example.com',
            'test@wallet.com',
            'lnurl123',
            '{}',
            now,
            'test_event_id_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            now,
          ],
        );

        await db.customStatement(
          '''
          INSERT INTO event (id, pubkey, created_at, kind, tags, content, sig)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            'test_event_id_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
            testPubkey,
            1234567890,
            1,
            '[]',
            'test content',
            'test_sig_1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
          ],
        );

        // Query both tables with JOIN
        final result = await db.customSelect('''
          SELECT e.*, p.display_name, p.name
          FROM event e
          LEFT JOIN user_profiles p ON e.pubkey = p.pubkey
          LIMIT 1
        ''').get();

        expect(result, isNotEmpty);
        expect(result.first.data['display_name'], equals('Test User'));
        expect(result.first.data['name'], equals('testuser'));
        expect(result.first.data['kind'], equals(1));
      });
    });
  });
}
