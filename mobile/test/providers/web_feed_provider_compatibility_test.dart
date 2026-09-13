import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:openvine/services/openvine_media_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart' show MockSecureStorage;
import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

void main() {
  setupTestEnvironment();

  setUpAll(() {
    registerFallbackValue(
      SecureKeyContainer.fromNsec(
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5',
      ),
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('web feed provider compatibility', () {
    test('pooled feed provider chain is web-compatible', () async {
      final prefs = await SharedPreferences.getInstance();
      final mockKeyStorage = _MockSecureKeyStorage();
      final secureStorage = MockSecureStorage();
      final crashReporting = CrashReportingService();

      when(mockKeyStorage.initialize).thenAnswer((_) async {});
      when(mockKeyStorage.hasKeys).thenAnswer((_) async => false);
      when(mockKeyStorage.getKeyContainer).thenAnswer((_) async => null);
      when(mockKeyStorage.clearCache).thenReturn(null);
      when(mockKeyStorage.dispose).thenReturn(null);
      when(mockKeyStorage.deleteKeys).thenAnswer((_) async {});
      when(
        () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
      ).thenAnswer((_) async {});
      when(
        () => mockKeyStorage.getIdentityKeyContainer(
          any(),
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockKeyStorage.switchToIdentity(
          any(),
        ),
      ).thenAnswer((_) async => true);

      final container = ProviderContainer(
        overrides: [
          crashReportingServiceProvider.overrideWithValue(crashReporting),
          sharedPreferencesProvider.overrideWithValue(prefs),
          secureKeyStorageProvider.overrideWith((ref) => mockKeyStorage),
          flutterSecureStorageProvider.overrideWith((ref) => secureStorage),
        ],
      );
      addTearDown(container.dispose);

      expect(() => container.read(mediaCacheProvider), returnsNormally);
      expect(() => container.read(authServiceProvider), returnsNormally);
      expect(
        container.read(authServiceProvider).crashReporterForTesting,
        same(crashReporting),
      );
      expect(() => container.read(blossomAuthServiceProvider), returnsNormally);
      expect(() => container.read(featureFlagServiceProvider), returnsNormally);
    });
  });
}
