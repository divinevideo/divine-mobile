// ABOUTME: Tests for database provider - verifies singleton behavior, disposal, and test overrides
// ABOUTME: Ensures AppDatabase lifecycle is managed correctly by Riverpod

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Database Provider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('creates singleton AppDatabase instance', () {
      // Read provider - should create database
      final db = container.read(databaseProvider);

      expect(db, isA<AppDatabase>());
    });

    test('returns same instance on multiple reads', () {
      // Read multiple times
      final db1 = container.read(databaseProvider);
      final db2 = container.read(databaseProvider);
      final db3 = container.read(databaseProvider);

      // Should all be the same instance
      expect(identical(db1, db2), true);
      expect(identical(db2, db3), true);
    });

    test('closes database on container dispose', () {
      // Create database
      final db = container.read(databaseProvider);

      // Database should be open
      expect(db, isA<AppDatabase>());

      // Dispose container - should close database
      container.dispose();

      // After disposal, database should be closed
      // We can't directly test if it's closed, but we can verify
      // that a new container gets a different instance
      final container2 = ProviderContainer();
      final db2 = container2.read(databaseProvider);

      expect(identical(db, db2), false);
      container2.dispose();
    });

    test('can be overridden in tests', () async {
      // Create test database with custom path
      final testDbPath = p.join(
        Directory.systemTemp.path,
        'test_db_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      final testDb = AppDatabase.test(testDbPath);

      // Create container with override
      final overriddenContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(testDb)],
      );

      // Read should return our test database
      final db = overriddenContainer.read(databaseProvider);
      expect(identical(db, testDb), true);

      // Clean up
      overriddenContainer.dispose();
      await testDb.close();

      // Delete test database file
      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });
  });
}
