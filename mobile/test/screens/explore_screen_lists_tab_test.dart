// ABOUTME: Unit tests for Explore's Lists tab identity and persistence.
// ABOUTME: Ensures tab selection is stored by name rather than shifting index.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/providers/route_feed_providers.dart';

void main() {
  group('ExploreScreen Lists tab structure', () {
    test('base Explore tab order includes Lists by stable name', () {
      const state = ExploreTabsState();

      expect(state.tabNames, const [
        exploreDefaultTabName,
        explorePopularTabName,
        exploreCategoriesTabName,
        exploreListsTabName,
        exploreBadgesTabName,
      ]);
    });

    test('Tab name provider supports stable Explore tab identities', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Test representative tab identities without depending on tab order.
      container.read(exploreTabNameProvider.notifier).state =
          exploreDefaultTabName;
      expect(
        container.read(exploreTabNameProvider),
        exploreDefaultTabName,
        reason: 'New tab persists by name',
      );

      container.read(exploreTabNameProvider.notifier).state =
          explorePopularTabName;
      expect(
        container.read(exploreTabNameProvider),
        explorePopularTabName,
        reason: 'Popular tab persists by name',
      );

      container.read(exploreTabNameProvider.notifier).state =
          exploreListsTabName;
      expect(
        container.read(exploreTabNameProvider),
        exploreListsTabName,
        reason: 'Lists tab persists by name',
      );
    });
  });
}
