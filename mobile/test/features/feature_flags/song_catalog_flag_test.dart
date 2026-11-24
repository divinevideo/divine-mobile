// ABOUTME: Tests for the song catalog flag: an internal experiment that only
// ABOUTME: exists in a build made with a developer token.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/services/build_configuration.dart';
import 'package:openvine/features/feature_flags/services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Song catalog flag', () {
    Future<FeatureFlagService> buildService({
      required bool songCatalogConfigured,
      bool internalAccess = true,
      Map<String, Object> stored = const {},
    }) async {
      SharedPreferences.setMockInitialValues(stored);
      final service = FeatureFlagService(
        await SharedPreferences.getInstance(),
        BuildConfiguration(songCatalogConfigured: songCatalogConfigured),
        canOverrideInternalFlags: () => internalAccess,
      );
      addTearDown(service.dispose);
      await service.initialize();
      return service;
    }

    test('is an internal flag', () {
      expect(FeatureFlag.songCatalog.isInternal, isTrue);
    });

    test('is off by default in a build with a developer token', () async {
      final service = await buildService(songCatalogConfigured: true);

      expect(service.isAvailable(FeatureFlag.songCatalog), isTrue);
      expect(service.isEnabled(FeatureFlag.songCatalog), isFalse);
    });

    test('can be turned on in a build with a developer token', () async {
      final service = await buildService(songCatalogConfigured: true);

      await service.setFlag(FeatureFlag.songCatalog, true);

      expect(service.isEnabled(FeatureFlag.songCatalog), isTrue);
    });

    test('stays off without internal access', () async {
      final service = await buildService(
        songCatalogConfigured: true,
        internalAccess: false,
        stored: {'ff_songCatalog': true},
      );

      await service.setFlag(FeatureFlag.songCatalog, true);

      expect(service.isEnabled(FeatureFlag.songCatalog), isFalse);
    });

    test('is not offered by a build without a developer token, whatever is '
        'stored or set', () async {
      final service = await buildService(
        songCatalogConfigured: false,
        stored: {'ff_songCatalog': true},
      );

      await service.setFlag(FeatureFlag.songCatalog, true);

      expect(service.isAvailable(FeatureFlag.songCatalog), isFalse);
      expect(service.isEnabled(FeatureFlag.songCatalog), isFalse);
      expect(
        service.currentState.isEnabled(FeatureFlag.songCatalog),
        isFalse,
      );
    });

    test('reads its build default from FF_SONG_CATALOG', () {
      const config = BuildConfiguration(songCatalogConfigured: true);

      expect(
        config.getEnvironmentKey(FeatureFlag.songCatalog),
        equals('FF_SONG_CATALOG'),
      );
      // The test run defines no FF_SONG_CATALOG, so the default is off.
      expect(config.getDefault(FeatureFlag.songCatalog), isFalse);
    });
  });
}
