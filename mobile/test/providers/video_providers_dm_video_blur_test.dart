// ABOUTME: Verifies the signed-in account's "blur video previews in messages"
// ABOUTME: choice is read for that account only, and absent when signed out.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/dm_video_blur_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('dmVideoBlurPreferenceServiceProvider', () {
    final first = 'a' * 64;
    final second = 'b' * 64;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        DmVideoBlurPreferenceService.storageKey(first): true,
      });
    });

    Future<ProviderContainer> buildContainer({required String? account}) async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentAccountIdProvider.overrideWithValue(account),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('is null when no account is signed in', () async {
      final container = await buildContainer(account: null);

      expect(container.read(dmVideoBlurPreferenceServiceProvider), isNull);
    });

    test("reads the signed-in account's own choice", () async {
      final firstContainer = await buildContainer(account: first);
      final secondContainer = await buildContainer(account: second);

      expect(
        firstContainer
            .read(dmVideoBlurPreferenceServiceProvider)!
            .blurVideoPreviews,
        isTrue,
      );
      expect(
        secondContainer
            .read(dmVideoBlurPreferenceServiceProvider)!
            .blurVideoPreviews,
        isFalse,
      );
    });
  });
}
