// ABOUTME: Tests for placing the server-configured featured tab in the
// ABOUTME: Explore tab order without shifting the user's selected tab.

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';

FeaturedTabConfig _featured() {
  return const FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: {'default': 'Featured'},
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

/// Asserts the featured tab sits right after the publication feeds (Latest,
/// then New when shown) and right before Popular.
void _expectBeforePopular(ExploreTabsState state) {
  final names = state.tabNames;
  final lastPublicationFeed = state.newCreatorsAvailable
      ? exploreNewTabName
      : exploreLatestTabName;
  expect(
    names.indexOf(exploreFeaturedTabName),
    equals(names.indexOf(lastPublicationFeed) + 1),
    reason: 'featured must sit immediately after $lastPublicationFeed',
  );
  expect(
    names.indexOf(exploreFeaturedTabName) + 1,
    equals(names.indexOf(explorePopularTabName)),
    reason: 'featured must sit immediately before Popular',
  );
}

void main() {
  group('ExploreTabsState featured tab', () {
    test('omits the tab entirely when none is configured', () {
      const state = ExploreTabsState();

      expect(state.tabNames, isNot(contains(exploreFeaturedTabName)));
    });

    test('sits between Latest and Popular', () {
      _expectBeforePopular(ExploreTabsState(featuredTab: _featured()));
    });

    test('sits between Latest and Popular when Classics is hidden', () {
      // Classics is optional, so the slot cannot be a literal index: without
      // it every tab shifts up one and a hard-coded 2 lands on Popular.
      _expectBeforePopular(
        ExploreTabsState(featuredTab: _featured()),
      );
      expect(
        ExploreTabsState(featuredTab: _featured()).tabNames.first,
        equals(exploreLatestTabName),
      );
    });

    test('sits between New and Popular when New is shown', () {
      _expectBeforePopular(
        ExploreTabsState(newCreatorsAvailable: true, featuredTab: _featured()),
      );
    });

    test('sits between New and Popular when every optional tab is on', () {
      _expectBeforePopular(
        ExploreTabsState(
          classicsAvailable: true,
          newCreatorsAvailable: true,
          forYouAvailable: true,
          appsAvailable: true,
          featuredTab: _featured(),
        ),
      );
    });

    test('counts the featured tab in the controller length', () {
      const without = ExploreTabsState();
      final with_ = ExploreTabsState(featuredTab: _featured());

      expect(with_.tabCount, equals(without.tabCount + 1));
    });

    test('keeps name lookup stable when the tab is added', () {
      const before = ExploreTabsState();
      final after = ExploreTabsState(
        featuredTab: _featured(),
      );

      // The user sitting on Lists must still resolve to Lists, not to the
      // tab that inherited its old index.
      final selected = before.nameForIndex(
        before.indexForName(exploreListsTabName),
      );
      expect(
        after.nameForIndex(after.indexForName(selected)),
        equals(exploreListsTabName),
      );
    });

    test('keeps name lookup stable when the tab is removed', () {
      final before = ExploreTabsState(
        featuredTab: _featured(),
      );
      const after = ExploreTabsState();

      final selected = before.nameForIndex(
        before.indexForName(exploreListsTabName),
      );
      expect(
        after.nameForIndex(after.indexForName(selected)),
        equals(exploreListsTabName),
      );
    });

    test('tracks the banner anchors past an inserted featured tab', () {
      final state = ExploreTabsState(
        featuredTab: _featured(),
      );

      expect(
        state.tabNames[state.latestIndex],
        equals(exploreLatestTabName),
      );
      expect(
        state.tabNames[state.trendingIndex],
        equals(explorePopularTabName),
      );
    });

    test('clearing the configuration removes the tab', () {
      final state = ExploreTabsState(featuredTab: _featured());

      expect(
        state.copyWith(clearFeaturedTab: true).tabNames,
        isNot(contains(exploreFeaturedTabName)),
      );
    });

    test('preserves the featured tab when another field changes', () {
      final state = ExploreTabsState(featuredTab: _featured());

      expect(
        state.copyWith(classicsAvailable: true).featuredTab,
        equals(state.featuredTab),
      );
    });
  });
}
