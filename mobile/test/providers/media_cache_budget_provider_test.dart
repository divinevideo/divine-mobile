// ABOUTME: Tests the app wiring of MediaCacheBudgetService: today's fixed
// ABOUTME: sizes as the ceiling, and a player budget only on Android.

import 'package:divine_video_player/divine_video_player.dart'
    show kDefaultCacheMaxSizeBytes;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/media_cache_budget_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingCrashReporting extends Fake implements CrashReportingService {
  final keys = <String, Object?>{};

  @override
  Future<void> setCustomKey(String key, dynamic value) async =>
      keys[key] = value;
}

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

    group('records each applied budget', () {
      const channel = MethodChannel('divine/device_storage');
      late Map<String, String?> userProperties;
      late _RecordingCrashReporting crashReporting;

      setUp(() {
        userProperties = {};
        crashReporting = _RecordingCrashReporting();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (_) async => {
                'totalBytes': 256000000000,
                'freeBytes': 9000000000,
              },
            );
      });

      tearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        // refresh() writes the budget onto the app's shared caches.
        openVineMediaCache.maxCacheSizeBytes = null;
        openVineImageCache.maxCacheSizeBytes = null;
      });

      Future<void> refreshOn(TargetPlatform platform) async {
        debugDefaultTargetPlatformOverride = platform;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            analyticsUserPropertySetterProvider.overrideWithValue(
              ({required name, required value}) async =>
                  userProperties[name] = value,
            ),
            crashReportingServiceProvider.overrideWithValue(crashReporting),
          ],
        );
        addTearDown(container.dispose);

        await container.read(mediaCacheBudgetServiceProvider).refresh();
        await pumpEventQueue();
      }

      test('as the mode alone on iOS', () async {
        await refreshOn(TargetPlatform.iOS);

        expect(userProperties, equals({'cache_mode': 'automatic'}));
        expect(crashReporting.keys, equals({'cache_mode': 'automatic'}));
      });

      test('with the disk labels on Android', () async {
        await refreshOn(TargetPlatform.android);

        expect(
          userProperties.keys,
          unorderedEquals([
            'storage_total',
            'storage_free_pct',
            'cache_budget',
            'cache_mode',
          ]),
        );
        expect(crashReporting.keys.keys, unorderedEquals(userProperties.keys));
      });
    });
  });
}
