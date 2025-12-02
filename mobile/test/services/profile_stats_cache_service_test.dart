// ABOUTME: Unit tests for ProfileStatsCacheService
// ABOUTME: Tests Hive-based persistent caching of profile statistics

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/services/profile_stats_cache_service.dart';
import 'package:openvine/providers/profile_stats_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProfileStatsCacheService cacheService;
  late Directory tempDir;

  setUpAll(() async {
    // Create temporary directory for Hive testing
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    cacheService = ProfileStatsCacheService();
  });

  tearDown(() async {
    // Clean up after each test
    try {
      await cacheService.clearAll();
      if (Hive.isBoxOpen('profile_stats_cache')) {
        await Hive.box('profile_stats_cache').close();
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  tearDownAll(() async {
    try {
      await Hive.close();
      await tempDir.delete(recursive: true);
    } catch (e) {
      // Ignore cleanup errors
    }
  });

  group('ProfileStatsCacheService', () {
    test('should save and retrieve profile stats', () async {
      const pubkey = 'test_pubkey_123';
      final stats = ProfileStats(
        videoCount: 42,
        totalLikes: 100,
        followers: 50,
        following: 30,
        totalViews: 1000,
        lastUpdated: DateTime.now(),
      );

      await cacheService.saveStats(pubkey, stats);

      final retrieved = await cacheService.getCachedStats(pubkey);

      expect(retrieved, isNotNull);
      expect(retrieved!.videoCount, equals(42));
      expect(retrieved.totalLikes, equals(100));
      expect(retrieved.followers, equals(50));
      expect(retrieved.following, equals(30));
      expect(retrieved.totalViews, equals(1000));
    });

    test('should return null for non-existent pubkey', () async {
      final retrieved = await cacheService.getCachedStats('nonexistent_pubkey');
      expect(retrieved, isNull);
    });

    test('should update existing stats when saving again', () async {
      const pubkey = 'test_pubkey_update';
      final stats1 = ProfileStats(
        videoCount: 10,
        totalLikes: 20,
        followers: 5,
        following: 3,
        totalViews: 100,
        lastUpdated: DateTime.now(),
      );

      await cacheService.saveStats(pubkey, stats1);

      final stats2 = ProfileStats(
        videoCount: 20,
        totalLikes: 40,
        followers: 10,
        following: 6,
        totalViews: 200,
        lastUpdated: DateTime.now(),
      );

      await cacheService.saveStats(pubkey, stats2);

      final retrieved = await cacheService.getCachedStats(pubkey);

      expect(retrieved, isNotNull);
      expect(retrieved!.videoCount, equals(20));
      expect(retrieved.totalLikes, equals(40));
      expect(retrieved.followers, equals(10));
    });

    test('should expire stats after cache expiry duration', () async {
      const pubkey = 'test_pubkey_expire';

      // Create stats with a timestamp in the past (6 minutes ago, cache expiry is 5 minutes)
      final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 6));
      final stats = ProfileStats(
        videoCount: 42,
        totalLikes: 100,
        followers: 50,
        following: 30,
        totalViews: 1000,
        lastUpdated: oldTimestamp,
      );

      // Manually insert expired data into cache
      await cacheService.saveStats(pubkey, stats);

      // Simulate time passing by directly modifying the cached_at timestamp
      final box = await Hive.openBox<Map>('profile_stats_cache');
      final data = box.get(pubkey);
      if (data != null) {
        data['cached_at'] = oldTimestamp.millisecondsSinceEpoch;
        await box.put(pubkey, data);
      }

      final retrieved = await cacheService.getCachedStats(pubkey);

      expect(retrieved, isNull, reason: 'Expired stats should return null');
    });

    test('should clear stats for specific pubkey', () async {
      const pubkey1 = 'test_pubkey_1';
      const pubkey2 = 'test_pubkey_2';

      final stats = ProfileStats(
        videoCount: 42,
        totalLikes: 100,
        followers: 50,
        following: 30,
        totalViews: 1000,
        lastUpdated: DateTime.now(),
      );

      await cacheService.saveStats(pubkey1, stats);
      await cacheService.saveStats(pubkey2, stats);

      await cacheService.clearStats(pubkey1);

      final retrieved1 = await cacheService.getCachedStats(pubkey1);
      final retrieved2 = await cacheService.getCachedStats(pubkey2);

      expect(retrieved1, isNull);
      expect(retrieved2, isNotNull);
    });

    test('should clear all cached stats', () async {
      final stats = ProfileStats(
        videoCount: 42,
        totalLikes: 100,
        followers: 50,
        following: 30,
        totalViews: 1000,
        lastUpdated: DateTime.now(),
      );

      await cacheService.saveStats('pubkey1', stats);
      await cacheService.saveStats('pubkey2', stats);
      await cacheService.saveStats('pubkey3', stats);

      await cacheService.clearAll();

      final retrieved1 = await cacheService.getCachedStats('pubkey1');
      final retrieved2 = await cacheService.getCachedStats('pubkey2');
      final retrieved3 = await cacheService.getCachedStats('pubkey3');

      expect(retrieved1, isNull);
      expect(retrieved2, isNull);
      expect(retrieved3, isNull);
    });

    test('should cleanup expired entries', () async {
      const freshPubkey = 'fresh_pubkey';
      const expiredPubkey = 'expired_pubkey';

      final stats = ProfileStats(
        videoCount: 42,
        totalLikes: 100,
        followers: 50,
        following: 30,
        totalViews: 1000,
        lastUpdated: DateTime.now(),
      );

      // Add fresh stats
      await cacheService.saveStats(freshPubkey, stats);

      // Add expired stats by manipulating timestamp
      await cacheService.saveStats(expiredPubkey, stats);
      final box = await Hive.openBox<Map>('profile_stats_cache');
      final data = box.get(expiredPubkey);
      if (data != null) {
        final oldTimestamp = DateTime.now().subtract(
          const Duration(minutes: 6),
        );
        data['cached_at'] = oldTimestamp.millisecondsSinceEpoch;
        await box.put(expiredPubkey, data);
      }

      await cacheService.cleanupExpired();

      final freshRetrieved = await cacheService.getCachedStats(freshPubkey);
      final expiredRetrieved = await cacheService.getCachedStats(expiredPubkey);

      expect(
        freshRetrieved,
        isNotNull,
        reason: 'Fresh stats should still exist',
      );
      expect(
        expiredRetrieved,
        isNull,
        reason: 'Expired stats should be cleaned up',
      );
    });

    test('should handle multiple concurrent saves', () async {
      const pubkey = 'concurrent_pubkey';

      final futures = List.generate(10, (index) {
        final stats = ProfileStats(
          videoCount: index,
          totalLikes: index * 2,
          followers: index * 3,
          following: index * 4,
          totalViews: index * 5,
          lastUpdated: DateTime.now(),
        );
        return cacheService.saveStats(pubkey, stats);
      });

      await Future.wait(futures);

      final retrieved = await cacheService.getCachedStats(pubkey);

      expect(
        retrieved,
        isNotNull,
        reason: 'Should have saved at least one version',
      );
    });

    test('should persist stats across service instances', () async {
      const pubkey = 'persist_pubkey';
      final stats = ProfileStats(
        videoCount: 42,
        totalLikes: 100,
        followers: 50,
        following: 30,
        totalViews: 1000,
        lastUpdated: DateTime.now(),
      );

      await cacheService.saveStats(pubkey, stats);

      // Create new instance (simulating app restart)
      final newCacheService = ProfileStatsCacheService();
      final retrieved = await newCacheService.getCachedStats(pubkey);

      expect(retrieved, isNotNull);
      expect(retrieved!.videoCount, equals(42));
      expect(retrieved.totalLikes, equals(100));
    });
  });
}
