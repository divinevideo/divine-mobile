// ABOUTME: Tests for the song catalog wiring: the repository is there only
// ABOUTME: while the flag is on and the build carries a developer token.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/song_catalog_providers.dart';

void main() {
  group('songCatalogRepositoryProvider', () {
    ProviderContainer buildContainer({
      required bool flagEnabled,
      required String developerToken,
    }) {
      final container = ProviderContainer(
        overrides: [
          isFeatureEnabledProvider(
            FeatureFlag.songCatalog,
          ).overrideWith((_) => flagEnabled),
          songCatalogDeveloperTokenProvider.overrideWithValue(developerToken),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('gives the catalog while the flag is on and a token is there', () {
      final container = buildContainer(
        flagEnabled: true,
        developerToken: 'developer-token',
      );

      final repository = container.read(songCatalogRepositoryProvider);

      expect(repository, isNotNull);
      expect(repository!.storefront, hasLength(2));
    });

    test('gives nothing while the flag is off', () {
      final container = buildContainer(
        flagEnabled: false,
        developerToken: 'developer-token',
      );

      expect(container.read(songCatalogRepositoryProvider), isNull);
    });

    test('gives nothing in a build without a token', () {
      final container = buildContainer(flagEnabled: true, developerToken: '');

      expect(container.read(songCatalogRepositoryProvider), isNull);
    });

    test('the build of the test run carries no token', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(songCatalogDeveloperTokenProvider), isEmpty);
    });
  });
}
