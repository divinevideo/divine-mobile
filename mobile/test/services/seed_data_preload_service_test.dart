// ABOUTME: Tests for SeedDataPreloadService seed data loading
// ABOUTME: Verifies service skips load when DB non-empty and loads when empty

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/database/app_database.dart';
import 'package:openvine/services/seed_data_preload_service.dart';
import 'package:nostr_sdk/event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SeedDataPreloadService', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.test(':memory:');
    });

    tearDown(() async {
      await db.close();
      // Clear the asset bundle cache and mock message handlers to prevent test pollution
      rootBundle.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', null);
    });

    test('skips load when database already has events', () async {
      // Insert an event to make DB non-empty
      final event = Event(
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        34236,
        [],
        'Existing video',
        createdAt: 1234567890,
      );
      event.id =
          'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
      event.sig =
          'abc1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef123456789';

      await db.nostrEventsDao.upsertEvent(event);

      // Should skip load
      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      // Count should still be 1 (no seed data added)
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(1));
    });

    test('loads seed data when database is empty', () async {
      // Mock asset to return minimal SQL
      const mockSql = '''
INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES ('seed1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd', 'seedpubkey1234567890abcdef1234567890abcdef1234567890abcdef12345678', 1234567890, 34236, '[]', 'Seed video', 'seedsig1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab', NULL);

INSERT OR IGNORE INTO event (id, pubkey, created_at, kind, tags, content, sig, sources)
VALUES ('seed2234567890abcdef1234567890abcdef1234567890abcdef1234567890abcd', 'seedpubkey2234567890abcdef1234567890abcdef1234567890abcdef12345678', 1234567891, 0, '[]', '{"name":"Alice"}', 'seedsig2234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab', NULL);
''';

      // Override rootBundle for test
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;

            // The message is the asset name as UTF-8 bytes
            final assetName = utf8.decode(message.buffer.asUint8List());

            if (assetName == 'assets/seed_data/seed_events.sql') {
              // Return the SQL content as bytes
              final bytes = Uint8List.fromList(utf8.encode(mockSql));
              return ByteData.sublistView(bytes);
            }

            return null;
          });

      // Database should be empty
      expect(await db.nostrEventsDao.getEventCount(), equals(0));

      // Load seed data
      await SeedDataPreloadService.loadSeedDataIfNeeded(db);

      // Should have 2 events now
      final count = await db.nostrEventsDao.getEventCount();
      expect(count, equals(2));
    });

    test('handles missing asset gracefully', () async {
      // Override rootBundle to return null (asset not found)
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            return null; // Asset not found
          });

      // Should not throw, just log error
      await expectLater(
        SeedDataPreloadService.loadSeedDataIfNeeded(db),
        completes,
      );

      // Database should still be empty
      expect(await db.nostrEventsDao.getEventCount(), equals(0));
    });

    test('handles malformed SQL gracefully', () async {
      // Mock asset with invalid SQL
      const badSql = 'INVALID SQL SYNTAX HERE;;;';

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
            if (message == null) return null;

            final assetName = utf8.decode(message.buffer.asUint8List());

            if (assetName == 'assets/seed_data/seed_events.sql') {
              final bytes = Uint8List.fromList(utf8.encode(badSql));
              return ByteData.sublistView(bytes);
            }

            return null;
          });

      // Should not throw, just log error
      await expectLater(
        SeedDataPreloadService.loadSeedDataIfNeeded(db),
        completes,
      );

      // Database should still be empty (no events inserted)
      expect(await db.nostrEventsDao.getEventCount(), equals(0));
    });
  });
}
