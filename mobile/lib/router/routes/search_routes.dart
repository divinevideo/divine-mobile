// ABOUTME: Discovery routes (hashtag feed, unified search results, category gallery)
// ABOUTME: Split from app_router.dart (#4508)

import 'package:categories_repository/categories_repository.dart';
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

List<RouteBase> searchRoutes() {
  return [
    GoRoute(
      path: FollowedHashtagsPage.path,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (context, state) => const FollowedHashtagsPage(),
    ),
    // HASHTAG route - standalone screen (no bottom nav)
    GoRoute(
      path: HashtagScreenRouter.path,
      name: HashtagScreenRouter.routeName,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) {
        // go_router already decodes path parameters once during route
        // matching (see go_router/src/match.dart). Decoding again here
        // would crash on legitimate inputs containing literal `%`
        // (e.g. `100%fun`) because the second decode sees a malformed
        // sequence. Pass the value through as-is.
        final tag = st.pathParameters['tag'];
        if (tag == null || tag.isEmpty) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidHashtag);
        }
        return HashtagFeedScreen(hashtag: tag);
      },
    ),
    // SEARCH RESULTS - unified search screen (no bottom nav)
    GoRoute(
      path: SearchResultsPage.emptyPath,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) => SearchResultsPage(
        requestFocusOnMount: SearchResultsPage.requestFocusOnMountForRoute(
          st.uri,
        ),
      ),
    ),
    GoRoute(
      path: SearchResultsPage.path,
      parentNavigatorKey: NavigatorKeys.root,
      builder: (ctx, st) {
        // See note above: do not double-decode path parameters.
        final query = st.pathParameters['query'] ?? '';
        return SearchResultsPage(
          initialQuery: query,
          requestFocusOnMount: SearchResultsPage.requestFocusOnMountForRoute(
            st.uri,
          ),
        );
      },
    ),
    GoRoute(
      path: CategoryGalleryScreen.path,
      name: CategoryGalleryScreen.routeName,
      builder: (ctx, st) {
        final categoryName = st.pathParameters['categoryName'];
        final category =
            extraAs<VideoCategory>(st.extra) ??
            VideoCategory(name: categoryName ?? '', videoCount: 0);

        if (category.name.isEmpty ||
            DiscoveryCategoryPolicy.isDenied(category.name)) {
          return RouteErrorScreen(message: ctx.l10n.routeInvalidCategory);
        }

        return CategoryGalleryScreen(category: category);
      },
    ),
  ];
}
