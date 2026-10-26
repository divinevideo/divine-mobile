// ABOUTME: Provider-level regression tests for moderation version counters
// ABOUTME: Verifies real service notifications reach Riverpod consumers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('moderation providers', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<ProviderContainer> buildContainer() async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'contentFilterVersionProvider increments from ContentFilterService notifications',
      () async {
        final container = await buildContainer();
        final subscription = container.listen<int>(
          contentFilterVersionProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final initialVersion = container.read(contentFilterVersionProvider);
        final service = container.read(contentFilterServiceProvider);
        await service.initialized;

        await service.setPreference(
          ContentLabel.flashingLights,
          ContentFilterPreference.hide,
        );

        expect(
          service.getPreference(ContentLabel.flashingLights),
          ContentFilterPreference.hide,
        );
        expect(
          container.read(contentFilterVersionProvider),
          initialVersion + 1,
        );
      },
    );

    test(
      'divineHostFilterVersionProvider increments from DivineHostFilterService notifications',
      () async {
        final container = await buildContainer();
        final subscription = container.listen<int>(
          divineHostFilterVersionProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final initialVersion = container.read(divineHostFilterVersionProvider);
        final service = container.read(divineHostFilterServiceProvider);

        await service.setShowDivineHostedOnly(false);

        expect(
          container.read(divineHostFilterVersionProvider),
          initialVersion + 1,
        );
      },
    );
  });
}
