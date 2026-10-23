// ABOUTME: Discovery routes (hashtag feed, unified search results, category gallery)
// ABOUTME: Typed with go_router_builder; conventions in .claude/rules/routing.md.

import 'package:categories_repository/categories_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show VideoCategory;
import 'package:openvine/features/hashtag_follows/view/followed_hashtags_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/route_extras.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';

part 'search_routes.g.dart';

List<RouteBase> searchRoutes() => $appRoutes;

@TypedGoRoute<FollowedHashtagsRouteData>(path: FollowedHashtagsPage.path)
class FollowedHashtagsRouteData extends GoRouteData
    with $FollowedHashtagsRouteData {
  const FollowedHashtagsRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  @override
  Widget build(BuildContext context, GoRouterState state) =>
      const FollowedHashtagsPage();
}

/// A hashtag feed, a standalone screen with no bottom nav.
@TypedGoRoute<HashtagRouteData>(
  path: HashtagScreenRouter.path,
  name: HashtagScreenRouter.routeName,
)
class HashtagRouteData extends GoRouteData with $HashtagRouteData {
  const HashtagRouteData({required this.tag});

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  /// Already decoded once by go_router's matching. Decoding it again would
  /// crash on a literal `%`, as in `100%fun` (#3413).
  final String tag;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    if (tag.isEmpty) {
      return RouteErrorScreen(message: context.l10n.routeInvalidHashtag);
    }
    return HashtagFeedScreen(hashtag: tag);
  }
}

/// Unified search with no query yet, with no bottom nav.
@TypedGoRoute<SearchRouteData>(path: SearchResultsPage.emptyPath)
class SearchRouteData extends GoRouteData with $SearchRouteData {
  const SearchRouteData({
    @TypedQueryParameter(name: SearchResultsPage.requestFocusQueryParameter)
    this.focus,
  });

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  /// [SearchResultsPage.requestFocusQueryValue] asks the search field to
  /// claim keyboard focus on mount.
  final String? focus;

  @override
  Widget build(BuildContext context, GoRouterState state) => SearchResultsPage(
    requestFocusOnMount: SearchResultsPage.requestFocusOnMountForRoute(
      state.uri,
    ),
  );
}

/// Unified search prefilled with [query], with no bottom nav.
@TypedGoRoute<SearchQueryRouteData>(path: SearchResultsPage.path)
class SearchQueryRouteData extends GoRouteData with $SearchQueryRouteData {
  const SearchQueryRouteData({
    required this.query,
    @TypedQueryParameter(name: SearchResultsPage.requestFocusQueryParameter)
    this.focus,
  });

  static final GlobalKey<NavigatorState> $parentNavigatorKey =
      NavigatorKeys.root;

  /// Already decoded once by go_router's matching; see [HashtagRouteData.tag].
  final String query;

  /// [SearchResultsPage.requestFocusQueryValue] asks the search field to
  /// claim keyboard focus on mount.
  final String? focus;

  @override
  Widget build(BuildContext context, GoRouterState state) => SearchResultsPage(
    initialQuery: query,
    requestFocusOnMount: SearchResultsPage.requestFocusOnMountForRoute(
      state.uri,
    ),
  );
}

@TypedGoRoute<CategoryGalleryRouteData>(
  path: CategoryGalleryScreen.path,
  name: CategoryGalleryScreen.routeName,
)
class CategoryGalleryRouteData extends GoRouteData
    with $CategoryGalleryRouteData {
  const CategoryGalleryRouteData({required this.categoryName, this.$extra});

  final String categoryName;

  /// The tapped [VideoCategory], read through [extraAs]; absent after a
  /// deep link, when the gallery starts from [categoryName] alone.
  final Object? $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    final category =
        extraAs<VideoCategory>($extra) ??
        VideoCategory(name: categoryName, videoCount: 0);

    if (category.name.isEmpty ||
        DiscoveryCategoryPolicy.isDenied(category.name)) {
      return RouteErrorScreen(message: context.l10n.routeInvalidCategory);
    }

    return CategoryGalleryScreen(category: category);
  }
}
