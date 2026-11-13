// ABOUTME: Tests the app wiring of MediaCacheBudgetService: today's fixed
// ABOUTME: sizes as the ceiling, and a player budget only on Android.

import 'package:divine_video_player/divine_video_player.dart'
    show kDefaultCacheMaxSizeBytes;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/providers/media_cache_budget_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('appMediaCacheBudgetCeiling', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('caps every cache at its fixed size on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;

      final ceiling = appMediaCacheBudgetCeiling();

      expect(ceiling.videoBytes, equals(kCacheLimitDefaultBytes));
      expect(
        ceiling.imageBytes,
        equals(openVineImageCache.mediaConfig.maxCacheSizeBytes),
      );
      expect(ceiling.playerBytes, equals(kDefaultCacheMaxSizeBytes));
    });

    test('gives no player budget on iOS, whose player keeps no cache', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      expect(appMediaCacheBudgetCeiling().playerBytes, isZero);
    });
  });

  group('mediaCacheBudgetServiceProvider', () {
    test('follows the saved video-cache preference', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final service = container.read(mediaCacheBudgetServiceProvider);
      expect(service.isAutomatic, isTrue);

      await prefs.setInt(kCacheLimitPrefKey, kCacheLimitMinBytes);
      expect(service.isAutomatic, isFalse);
    });
  });
}
