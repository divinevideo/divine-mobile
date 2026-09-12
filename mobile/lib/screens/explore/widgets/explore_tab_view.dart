// ABOUTME: The explore grid TabBarView with its per-tab children and the
// ABOUTME: buffered-videos banner overlay.

import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/screens/explore/tabs/featured_videos_tab.dart';
import 'package:openvine/screens/explore/widgets/explore_buffered_videos_banner.dart';
import 'package:openvine/widgets/categories_tab.dart';
import 'package:openvine/widgets/classic_vines_tab.dart';
import 'package:openvine/widgets/for_you_tab.dart';
import 'package:openvine/widgets/new_videos_tab.dart';
import 'package:openvine/widgets/popular_videos_tab.dart';

/// The grid-mode tab content for the explore screen.
///
/// Children are ordered to match [tabsState.tabNames] and [controller]'s tab
/// count. The buffered-videos banner overlays only the New/Trending tabs.
class ExploreTabView extends StatelessWidget {
  /// Creates the explore tab view.
  const ExploreTabView({
    required this.controller,
    required this.tabsState,
    super.key,
  });

  /// Controller driving tab selection; must match [tabsState.tabCount].
  final TabController controller;

  /// Current tab availability/order.
  final ExploreTabsState tabsState;

  @override
  Widget build(BuildContext context) {
    final featured = tabsState.featuredTab;
    return Stack(
      children: [
        TabBarView(
          controller: controller,
          // Children are derived from the same ordered name list the tab bar
          // uses, so a tab spliced in at a configured anchor cannot desync
          // the two. Feed tabs default to the ScreenAnalyticsService
          // singleton when not given one, so none needs threading here.
          children: [
            for (final name in tabsState.tabNames)
              switch (name) {
                exploreClassicsTabName => const ClassicVinesTab(),
                exploreDefaultTabName => const NewVideosTab(),
                explorePopularTabName => const PopularVideosTab(),
                exploreCategoriesTabName => const CategoriesTab(),
                exploreForYouTabName => const ForYouTab(),
                exploreListsTabName => const ExploreListsTab(),
                exploreAppsTabName => const AppsDirectoryScreen(
                  embedded: true,
                ),
                exploreFeaturedTabName when featured != null =>
                  FeaturedVideosTab(config: featured),
                _ => const SizedBox.shrink(),
              },
          ],
        ),
        // New videos banner only shows on the New Videos and Trending tabs.
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final currentIndex = controller.index;
            if (currentIndex == tabsState.newVideosIndex ||
                currentIndex == tabsState.trendingIndex) {
              return const ExploreBufferedVideosBanner();
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
