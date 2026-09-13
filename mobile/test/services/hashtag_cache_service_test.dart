// ABOUTME: Tests hashtag-cache persistence, expiry, and cleanup.
// ABOUTME: Uses the shared Hive cleanup helper for merged-isolate safety.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/services/hashtag_cache_service.dart';

import '../helpers/test_helpers.dart';

void main() {
  group(HashtagCacheService, () {
    late Directory tempDirectory;
    late HashtagCacheService service;

    setUp(() async {
      tempDirectory = Directory.systemTemp.createTempSync('hashtag-cache-');
      Hive.init(tempDirectory.path);
      await TestHelpers.cleanupHiveBox(HiveBoxNames.hashtagStats);
      service = HashtagCacheService();
    });

    tearDown(() async {
      await TestHelpers.cleanupHiveBox(HiveBoxNames.hashtagStats);
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test('returns null until initialized', () {
      expect(service.isInitialized, isFalse);
      expect(service.getCachedPopularHashtags(), isNull);
    });

    test('round-trips popular hashtags and clears them', () async {
      await service.initialize();
      await service.cachePopularHashtags(['divine', 'loops']);

      expect(service.getCachedPopularHashtags(), ['divine', 'loops']);

      await service.clearCache();
      expect(service.getCachedPopularHashtags(), isNull);
    });

    test('rejects entries older than one hour', () async {
      final box = await Hive.openBox(HiveBoxNames.hashtagStats);
      await box.put('popular_hashtags', ['stale']);
      await box.put(
        'last_update',
        DateTime.now().subtract(const Duration(hours: 2)),
      );
      await service.initialize();

      expect(service.getCachedPopularHashtags(), isNull);
    });

    test('dispose resets initialization state', () async {
      await service.initialize();
      expect(service.isInitialized, isTrue);

      await service.dispose();

      expect(service.isInitialized, isFalse);
    });
  });
}
