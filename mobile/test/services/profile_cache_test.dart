// ABOUTME: Test for ProfileCacheService to verify persistent profile storage works correctly
// ABOUTME: Ensures profiles are cached to Hive storage and persist across app restarts

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/services/profile_cache_service.dart';

void main() {
  group('ProfileCacheService', () {
    late ProfileCacheService cacheService;
    late Directory tempDir;

    setUp(() async {
      // Create temporary directory for Hive
      tempDir = await Directory.systemTemp.createTemp('profile_cache_test');
      Hive.init(tempDir.path);

      cacheService = ProfileCacheService();
      await cacheService.initialize();
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('should initialize successfully', () {
      expect(cacheService.isInitialized, isTrue);
    });

    test('should cache and retrieve profile', () async {
      final profile = UserProfile(
        pubkey: 'test_pubkey',
        name: 'Test User',
        displayName: 'Test Display Name',
        about: 'Test bio',
        picture: 'https://example.com/avatar.jpg',
        rawData: {'name': 'Test User'},
        createdAt: DateTime.now(),
        eventId: 'test_event_id',
      );

      // Cache the profile
      await cacheService.cacheProfile(profile);

      // Retrieve the profile
      final retrieved = cacheService.getCachedProfile('test_pubkey');

      expect(retrieved, isNotNull);
      expect(retrieved!.pubkey, equals('test_pubkey'));
      expect(retrieved.name, equals('Test User'));
      expect(retrieved.displayName, equals('Test Display Name'));
      expect(retrieved.about, equals('Test bio'));
    });

    test('should return null for non-existent profile', () {
      final retrieved = cacheService.getCachedProfile('non_existent_pubkey');
      expect(retrieved, isNull);
    });

    test('should update existing cached profile', () async {
      final profile1 = UserProfile(
        pubkey: 'test_pubkey',
        name: 'Old Name',
        displayName: 'Old Display',
        about: 'Old bio',
        rawData: {'name': 'Old Name'},
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        eventId: 'old_event_id',
      );

      final profile2 = UserProfile(
        pubkey: 'test_pubkey',
        name: 'New Name',
        displayName: 'New Display',
        about: 'New bio',
        rawData: {'name': 'New Name'},
        createdAt: DateTime.now(),
        eventId: 'new_event_id',
      );

      // Cache original profile
      await cacheService.cacheProfile(profile1);

      // Update with newer profile
      await cacheService.updateCachedProfile(profile2);

      // Retrieve and verify it's the newer one
      final retrieved = cacheService.getCachedProfile('test_pubkey');
      expect(retrieved!.name, equals('New Name'));
      expect(retrieved.displayName, equals('New Display'));
    });

    test('should not update with older profile', () async {
      final newerProfile = UserProfile(
        pubkey: 'test_pubkey',
        name: 'Newer Name',
        displayName: 'Newer Display',
        rawData: {'name': 'Newer Name'},
        createdAt: DateTime.now(),
        eventId: 'newer_event_id',
      );

      final olderProfile = UserProfile(
        pubkey: 'test_pubkey',
        name: 'Older Name',
        displayName: 'Older Display',
        rawData: {'name': 'Older Name'},
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        eventId: 'older_event_id',
      );

      // Cache newer profile first
      await cacheService.cacheProfile(newerProfile);

      // Try to update with older profile
      await cacheService.updateCachedProfile(olderProfile);

      // Should still have the newer profile
      final retrieved = cacheService.getCachedProfile('test_pubkey');
      expect(retrieved!.name, equals('Newer Name'));
    });

    test('should remove cached profile', () async {
      final profile = UserProfile(
        pubkey: 'test_pubkey',
        name: 'Test User',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'test_event_id',
      );

      await cacheService.cacheProfile(profile);
      expect(cacheService.getCachedProfile('test_pubkey'), isNotNull);

      await cacheService.removeCachedProfile('test_pubkey');
      expect(cacheService.getCachedProfile('test_pubkey'), isNull);
    });

    test('should clear all cached profiles', () async {
      final profile1 = UserProfile(
        pubkey: 'test_pubkey_1',
        name: 'User 1',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event_1',
      );

      final profile2 = UserProfile(
        pubkey: 'test_pubkey_2',
        name: 'User 2',
        rawData: {},
        createdAt: DateTime.now(),
        eventId: 'event_2',
      );

      await cacheService.cacheProfile(profile1);
      await cacheService.cacheProfile(profile2);

      final stats = cacheService.getCacheStats();
      expect(stats['totalProfiles'], equals(2));

      await cacheService.clearCache();

      final statsAfter = cacheService.getCacheStats();
      expect(statsAfter['totalProfiles'], equals(0));
    });

    test('should provide cache statistics', () async {
      final stats = cacheService.getCacheStats();

      expect(stats['isInitialized'], isTrue);
      expect(stats['totalProfiles'], isA<int>());
      expect(stats['expiredProfiles'], isA<int>());
    });

    test('should handle expired profiles', () async {
      // Create an old profile (simulated as expired)
      final oldProfile = UserProfile(
        pubkey: 'old_pubkey',
        name: 'Old User',
        rawData: {},
        createdAt: DateTime.now().subtract(
          const Duration(days: 8),
        ), // 8 days old
        eventId: 'old_event_id',
      );

      await cacheService.cacheProfile(oldProfile);

      // Since our cache service considers profiles older than 7 days as expired,
      // this should return null and clean up the old profile
      final retrieved = cacheService.getCachedProfile('old_pubkey');
      expect(retrieved, isNull);
    });
  });
}
