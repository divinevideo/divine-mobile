// ABOUTME: Explore screen Page — thin route entry that provides
// ABOUTME: ExploreTabsCubit to the ExploreView body.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/featured_tabs_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/screens/explore/explore_view.dart';

/// Explore screen: a thin tabs Page over [ExploreTabsCubit] + [ExploreView].
class ExploreScreen extends ConsumerWidget {
  /// Creates the explore screen, optionally selecting [initialTabName].
  const ExploreScreen({super.key, this.initialTabName, this.initialTabSlug});

  static const _routeTabNames = <String>{
    exploreClassicsTabName,
    exploreDefaultTabName,
    explorePopularTabName,
    exploreCategoriesTabName,
    exploreForYouTabName,
    exploreListsTabName,
    exploreAppsTabName,
  };

  /// Route name for this screen.
  static const routeName = 'explore';

  /// Path for this route (grid mode).
  static const String path = RoutePaths.explore;

  /// Path for this route with index (feed mode).
  static const pathWithIndex = '/explore/:index';

  /// Path for selecting a specific tab by name (grid mode).
  /// Valid URL slugs: 'classics', 'new', 'popular', 'categories',
  /// 'for-you', 'lists', 'apps'.
  static const pathTabSubpath = '/explore/tab/:name';

  /// Build path for grid mode or specific index.
  static String pathForIndex(int? index) => RoutePaths.exploreForIndex(index);

  /// Build path for selecting a specific tab by name.
  static String pathForTab(String name) =>
      '/explore/tab/${tabSlugForName(name)}';

  /// Convert an internal tab name to the public URL slug.
  static String tabSlugForName(String name) => switch (name) {
    exploreForYouTabName => exploreForYouTabSlug,
    _ => name,
  };

  /// Convert a URL path parameter to the internal tab name.
  static String? tabNameFromPathParameter(String? slug) {
    if (slug == null) return null;
    if (slug.contains('_')) return null;
    final name = switch (slug) {
      exploreForYouTabSlug => exploreForYouTabName,
      _ => slug,
    };
    return _routeTabNames.contains(name) ? name : null;
  }

  /// Optional tab name to select on first build.
  final String? initialTabName;

  /// Raw URL slug, kept so a server-configured featured slug can still be
  /// resolved once its configuration arrives.
  ///
  /// [tabNameFromPathParameter] only knows the tab names compiled into the
  /// app, so a featured slug resolves to `null` there by design.
  final String? initialTabSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featuredTabsRepository = ref.watch(featuredTabsRepositoryProvider);
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          // Both providers are stable keepAlive Providers that are never
          // invalidated, so ref.read is safe here (state_management.md §1).
          create: (_) => ExploreTabsCubit(
            screenAnalytics: ref.read(screenAnalyticsServiceProvider),
            topHashtags: ref.read(topHashtagsServiceProvider),
          ),
        ),
        BlocProvider(
          // Keyed on the repository so an environment or relay swap rebuilds
          // the cubit against the new host instead of polling a stale one.
          // The shell keeps Explore mounted after the first visit; continuing
          // at the clamped cadence lets backend kill switches land off-tab.
          key: ValueKey(featuredTabsRepository),
          create: (_) => FeaturedTabsCubit(
            repository: featuredTabsRepository,
            gateAgeRestrictedContent: () =>
                ref.read(featuredTabAgeGateProvider),
          )..refresh(),
        ),
      ],
      child: ExploreView(
        initialTabName: initialTabName,
        initialTabSlug: initialTabSlug,
      ),
    );
  }
}
