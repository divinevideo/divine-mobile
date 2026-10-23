// ABOUTME: Tests the discovery routes registered by searchRoutes.
// ABOUTME: Pins their locations against RoutePaths, their navigators and focus.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/hashtag_follows/view/followed_hashtags_page.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/search_routes.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required String location,
    this.pathParameters = const {},
  }) : uri = Uri.parse(location),
       matchedLocation = Uri.parse(location).path,
       fullPath = Uri.parse(location).path,
       pageKey = ValueKey<String>(location);

  @override
  final Uri uri;

  @override
  final String matchedLocation;

  @override
  final String? fullPath;

  @override
  final ValueKey<String> pageKey;

  @override
  final Map<String, String> pathParameters;

  @override
  Object? get extra => null;
}

/// Inputs whose encoding has broken these routes before: a literal `%`
/// (#3413), a space, non-ASCII text and a slash.
const _awkward = ['flutter', '100%fun', 'two words', 'ünïcödé', 'a/b'];

void main() {
  group('searchRoutes', () {
    late BuildContext context;

    Future<void> captureContext(WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    GoRoute routeAt(String path) => searchRoutes()
        .whereType<GoRoute>()
        .singleWhere((route) => route.path == path);

    group('locations', () {
      // Deep links, redirects and the route parser still build these
      // locations from RoutePaths and the page builders, so the typed routes
      // must produce the same URLs.
      for (final tag in _awkward) {
        test('a hashtag location matches RoutePaths for "$tag"', () {
          expect(
            HashtagRouteData(tag: tag).location,
            equals(RoutePaths.hashtagForTag(tag)),
          );
        });

        test('a search location matches pathForQuery for "$tag"', () {
          expect(
            SearchQueryRouteData(query: tag).location,
            equals(
              SearchResultsPage.pathForQuery(tag, requestFocusOnMount: false),
            ),
          );
          expect(
            SearchQueryRouteData(
              query: tag,
              focus: SearchResultsPage.requestFocusQueryValue,
            ).location,
            equals(
              SearchResultsPage.pathForQuery(tag, requestFocusOnMount: true),
            ),
          );
        });
      }

      test('an empty search carries its focus request', () {
        expect(
          const SearchRouteData().location,
          equals(
            SearchResultsPage.pathForEmptyQuery(requestFocusOnMount: false),
          ),
        );
        expect(
          const SearchRouteData(
            focus: SearchResultsPage.requestFocusQueryValue,
          ).location,
          equals(
            SearchResultsPage.pathForEmptyQuery(requestFocusOnMount: true),
          ),
        );
      });

      test('a category location matches RoutePaths', () {
        expect(
          const CategoryGalleryRouteData(categoryName: 'pets & animals')
              .location,
          equals(RoutePaths.categoryGalleryFor('pets & animals')),
        );
      });
    });

    group('navigators', () {
      test('standalone discovery screens cover the shell', () {
        for (final path in [
          FollowedHashtagsPage.path,
          HashtagScreenRouter.path,
          SearchResultsPage.emptyPath,
          SearchResultsPage.path,
        ]) {
          expect(
            routeAt(path).parentNavigatorKey,
            same(NavigatorKeys.root),
            reason: path,
          );
        }
      });
    });

    group('builders', () {
      testWidgets('a hashtag passes its tag through undecoded', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = routeAt(HashtagScreenRouter.path).builder!(
          context,
          _FakeGoRouterState(
            location: RoutePaths.hashtagForTag('100%fun'),
            pathParameters: const {'tag': '100%fun'},
          ),
        );

        expect(
          screen,
          isA<HashtagFeedScreen>().having(
            (s) => s.hashtag,
            'hashtag',
            '100%fun',
          ),
        );
      });

      testWidgets('a search claims focus only when the URL asks', (
        tester,
      ) async {
        await captureContext(tester);

        SearchResultsPage build(String location) =>
            routeAt(SearchResultsPage.path).builder!(
              context,
              _FakeGoRouterState(
                location: location,
                pathParameters: const {'query': 'skate'},
              ),
            ) as SearchResultsPage;

        final focused = build(
          SearchResultsPage.pathForQuery('skate', requestFocusOnMount: true),
        );
        final unfocused = build(
          SearchResultsPage.pathForQuery('skate', requestFocusOnMount: false),
        );

        expect(focused.initialQuery, equals('skate'));
        expect(focused.requestFocusOnMount, isTrue);
        expect(unfocused.requestFocusOnMount, isFalse);
      });

      testWidgets('a category opens from its name alone', (tester) async {
        await captureContext(tester);

        final screen = routeAt(CategoryGalleryScreen.path).builder!(
          context,
          _FakeGoRouterState(
            location: RoutePaths.categoryGalleryFor('animals'),
            pathParameters: const {'categoryName': 'animals'},
          ),
        );

        expect(
          screen,
          isA<CategoryGalleryScreen>().having(
            (s) => s.category.name,
            'category.name',
            'animals',
          ),
        );
      });
    });
  });
}
