// ABOUTME: Tests the bottom-nav shell route registered by shellRoutes.
// ABOUTME: Pins its branches, path templates, match order and branch pages.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_feed/video_feed_bloc.dart' show FeedMode;
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/router/app_shell.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/shell.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/profile_unavailable_pins_screen.dart';

import '../../helpers/test_pubkeys.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState(String location, {this.pathParameters = const {}})
    : uri = Uri.parse(location),
      fullPath = location,
      pageKey = ValueKey<String>(location);

  @override
  final Uri uri;

  @override
  final String? fullPath;

  @override
  final ValueKey<String> pageKey;

  @override
  final Map<String, String> pathParameters;

  @override
  String? get name => null;

  @override
  String? get path => null;

  @override
  GoRoute? get topRoute => null;

  @override
  Object? get extra => null;
}

class _FakeNavigationShell extends Fake
    with Diagnosticable
    implements StatefulNavigationShell {
  _FakeNavigationShell(this.currentIndex);

  @override
  final int currentIndex;
}

void main() {
  group('shellRoutes', () {
    StatefulShellRoute shell() => shellRoutes().single as StatefulShellRoute;

    GoRoute routeAt(String template) => shell().branches
        .expand((branch) => branch.routes)
        .cast<GoRoute>()
        .singleWhere((route) => route.path == template);

    group('shell route', () {
      test('is the only route the module registers', () {
        expect(shellRoutes(), [isA<StatefulShellRoute>()]);
      });

      test('keeps branch navigation away from the root observers', () {
        expect(shell().notifyRootObserver, isFalse);
      });

      testWidgets('shows the branch navigators in AppShellBranchContainer', (
        tester,
      ) async {
        await tester.pumpWidget(const SizedBox.shrink());
        final context = tester.element(find.byType(SizedBox));
        final children = <Widget>[
          const SizedBox.shrink(),
          const SizedBox.shrink(),
        ];

        final container = shell().navigatorContainerBuilder(
          context,
          _FakeNavigationShell(1),
          children,
        );

        expect(
          container,
          isA<AppShellBranchContainer>()
              .having((c) => c.currentIndex, 'currentIndex', 1)
              .having((c) => c.children, 'children', same(children)),
        );
      });
    });

    group('branches', () {
      test('keep each tab navigator, in bottom-nav order', () {
        expect(shell().branches.map((branch) => branch.navigatorKey).toList(), [
          same(NavigatorKeys.home),
          same(NavigatorKeys.explore),
          same(NavigatorKeys.inbox),
          same(NavigatorKeys.profile),
        ]);
      });

      test('open each tab at its root location', () {
        expect(
          shell().branches.map((branch) => branch.initialLocation).toList(),
          ['/home/0', '/explore', '/inbox', '/profile'],
        );
      });

      test('keep every route on its branch navigator', () {
        final parentKeys = shell().branches
            .expand((branch) => branch.routes)
            .map((route) => route.parentNavigatorKey);

        expect(parentKeys, everyElement(isNull));
      });
    });

    group('templates', () {
      // Written out rather than read back from the constants the annotations
      // use: analytics page names, route normalization and the profile-owner
      // redirect read these patterns through the matched route's fullPath, so
      // an edit to one of those constants must fail here.
      test(
        'each branch registers its patterns and names in matching order',
        () {
          expect(
            [
              for (final branch in shell().branches)
                [
                  for (final route in branch.routes.cast<GoRoute>())
                    (route.path, route.name),
                ],
            ],
            [
              [('/following/new', null), ('/home/:index', 'home')],
              [
                ('/explore', 'explore'),
                ('/explore/tab/:name', null),
                ('/explore/:index', null),
              ],
              [('/notifications/:index', 'notifications'), ('/inbox', 'inbox')],
              [
                ('/profile/:npub/unavailable-pins', null),
                ('/profile', 'profile'),
                ('/profile/:npub', null),
                ('/profile/:npub/:index', null),
              ],
            ],
          );
        },
      );
    });

    group('matching', () {
      String? templateMatched(String location) {
        final router = GoRouter(
          initialLocation: '/home/0',
          routes: shellRoutes(),
        );
        addTearDown(router.dispose);
        return router.configuration.findMatch(Uri.parse(location)).fullPath;
      }

      // `/profile/:npub/:index` would also match this location, reading
      // `unavailable-pins` as a video index; go_router takes the first match.
      test('an unavailable-pins location matches its own page first', () {
        expect(
          templateMatched('/profile/$syntheticTestNpub/unavailable-pins'),
          equals('/profile/:npub/unavailable-pins'),
        );
      });

      // The profile-owner redirect treats a location as a profile only when
      // its matched template, GoRouterState.fullPath, has the profile shape.
      test(
        'a profile location matches the template the owner redirect reads',
        () {
          expect(
            templateMatched('/profile/$syntheticTestNpub'),
            equals('/profile/:npub'),
          );
          expect(
            templateMatched('/profile/$syntheticTestNpub/3'),
            equals('/profile/:npub/:index'),
          );
        },
      );
    });

    group('pages', () {
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

      /// Builds the page at [template] and returns the screen inside the
      /// branch-scoped [ProviderScope] that [branchPage] wraps it in.
      Widget screenAt(
        String template,
        String location, {
        Map<String, String> pathParameters = const {},
      }) {
        final page = routeAt(template).pageBuilder!(
          context,
          _FakeGoRouterState(location, pathParameters: pathParameters),
        );

        expect(
          page,
          isA<NoTransitionPage<void>>().having(
            (p) => p.key,
            'key',
            ValueKey<String>(location),
          ),
        );
        final scope = (page as NoTransitionPage<void>).child;
        expect(scope, isA<ProviderScope>());
        return (scope as ProviderScope).child;
      }

      testWidgets('/following/new forces the Following feed', (tester) async {
        await captureContext(tester);

        expect(
          screenAt('/following/new', '/following/new'),
          isA<VideoFeedPage>()
              .having((p) => p.initialMode, 'initialMode', FeedMode.following)
              .having((p) => p.forceInitialMode, 'forceInitialMode', isTrue),
        );
      });

      testWidgets('/home/:index starts the feed at the routed video', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          screenAt('/home/:index', '/home/7', pathParameters: {'index': '7'}),
          isA<VideoFeedPage>()
              .having((p) => p.initialIndex, 'initialIndex', 7)
              .having((p) => p.initialMode, 'initialMode', FeedMode.forYou)
              .having((p) => p.forceInitialMode, 'forceInitialMode', isFalse),
        );
      });

      testWidgets('/home/:index starts at the first video for a bad index', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          screenAt('/home/:index', '/home/-3', pathParameters: {'index': '-3'}),
          isA<VideoFeedPage>().having((p) => p.initialIndex, 'initialIndex', 0),
        );
        expect(
          screenAt('/home/:index', '/home/x', pathParameters: {'index': 'x'}),
          isA<VideoFeedPage>().having((p) => p.initialIndex, 'initialIndex', 0),
        );
      });

      testWidgets('/explore opens the default tab', (tester) async {
        await captureContext(tester);

        expect(
          screenAt('/explore', '/explore'),
          isA<ExploreScreen>()
              .having((s) => s.initialTabName, 'initialTabName', isNull)
              .having((s) => s.initialTabSlug, 'initialTabSlug', isNull),
        );
      });

      testWidgets('/explore/tab/:name opens the tab its slug names', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          screenAt(
            '/explore/tab/:name',
            '/explore/tab/for-you',
            pathParameters: {'name': 'for-you'},
          ),
          isA<ExploreScreen>()
              .having((s) => s.initialTabName, 'initialTabName', 'for_you')
              .having((s) => s.initialTabSlug, 'initialTabSlug', 'for-you'),
        );
      });

      testWidgets('/explore/tab/:name keeps an unknown slug for later', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          screenAt(
            '/explore/tab/:name',
            '/explore/tab/garbage',
            pathParameters: {'name': 'garbage'},
          ),
          isA<ExploreScreen>()
              .having((s) => s.initialTabName, 'initialTabName', isNull)
              .having((s) => s.initialTabSlug, 'initialTabSlug', 'garbage'),
        );
      });

      testWidgets('/explore/:index opens the default tab', (tester) async {
        await captureContext(tester);

        expect(
          screenAt(
            '/explore/:index',
            '/explore/2',
            pathParameters: {'index': '2'},
          ),
          isA<ExploreScreen>()
              .having((s) => s.initialTabName, 'initialTabName', isNull)
              .having((s) => s.initialTabSlug, 'initialTabSlug', isNull),
        );
      });

      testWidgets('/notifications/:index opens notifications', (tester) async {
        await captureContext(tester);

        expect(
          screenAt(
            '/notifications/:index',
            '/notifications/0',
            pathParameters: {'index': '0'},
          ),
          isA<NotificationsPage>(),
        );
      });

      testWidgets('/inbox opens the inbox', (tester) async {
        await captureContext(tester);

        expect(screenAt('/inbox', '/inbox'), isA<InboxPage>());
      });

      testWidgets('/profile/:npub/unavailable-pins reads the npub', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          screenAt(
            '/profile/:npub/unavailable-pins',
            '/profile/$syntheticTestNpub/unavailable-pins',
            pathParameters: {'npub': syntheticTestNpub},
          ),
          isA<ProfileUnavailablePinsPage>().having(
            (p) => p.npub,
            'npub',
            syntheticTestNpub,
          ),
        );
      });

      testWidgets('the profile routes open the profile router', (
        tester,
      ) async {
        await captureContext(tester);

        expect(screenAt('/profile', '/profile'), isA<ProfileScreenRouter>());
        expect(
          screenAt(
            '/profile/:npub',
            '/profile/$syntheticTestNpub',
            pathParameters: {'npub': syntheticTestNpub},
          ),
          isA<ProfileScreenRouter>(),
        );
        expect(
          screenAt(
            '/profile/:npub/:index',
            '/profile/$syntheticTestNpub/3',
            pathParameters: {'npub': syntheticTestNpub, 'index': '3'},
          ),
          isA<ProfileScreenRouter>(),
        );
      });
    });

    group('locations', () {
      // Callers, redirects and the route parser still build these locations
      // from RoutePaths and the screens' path builders, so each typed location
      // must produce the same URL for the values callers pass.
      test('a home feed location matches pathForIndex', () {
        for (final index in [0, 1, 42]) {
          expect(
            HomeFeedRouteData(index: '$index').location,
            equals(VideoFeedPage.pathForIndex(index)),
          );
        }
      });

      test('an explore feed location matches pathForIndex', () {
        expect(
          const ExploreFeedRouteData(index: '3').location,
          equals(ExploreScreen.pathForIndex(3)),
        );
      });

      test('a notifications location matches pathForIndex', () {
        expect(
          const NotificationsRouteData(index: '0').location,
          equals(NotificationsPage.pathForIndex(0)),
        );
      });

      // pathForTab interpolates raw; its callers pass only compiled tab names.
      test('an explore tab location carries the tab slug pathForTab uses', () {
        expect(
          const ExploreTabRouteData(name: 'popular').location,
          equals(ExploreScreen.pathForTab('popular')),
        );
        expect(
          const ExploreTabRouteData(name: 'lists').location,
          equals(ExploreScreen.pathForTab('lists')),
        );
        expect(
          const ExploreTabRouteData(name: 'for-you').location,
          equals(ExploreScreen.pathForTab('for_you')),
        );
      });

      for (final npub in _plainProfileIds) {
        test('the profile locations match their builders for "$npub"', () {
          expect(
            ProfileGridRouteData(npub: npub).location,
            equals(ProfileScreenRouter.pathForNpub(npub)),
          );
          expect(
            ProfileFeedRouteData(npub: npub, index: '2').location,
            equals(ProfileScreenRouter.pathForIndex(npub, 2)),
          );
          expect(
            ProfileUnavailablePinsRouteData(npub: npub).location,
            equals(RoutePaths.profileUnavailablePinsForNpub(npub)),
          );
        });
      }

      // The builders take a pre-encoded segment: universal_link_resolver and
      // page_context_provider encode before calling them. A typed route takes
      // the raw value and encodes it, so a call site that moves to a typed
      // route drops its Uri.encodeComponent.
      for (final MapEntry(key: value, value: segment)
          in _awkwardProfileIds.entries) {
        test(
          'the profile locations encode "$value" as the builders expect',
          () {
            final encoded = Uri.encodeComponent(value);
            expect(
              ProfileGridRouteData(npub: value).location,
              allOf(
                equals(ProfileScreenRouter.pathForNpub(encoded)),
                equals('/profile/$segment'),
              ),
            );
            expect(
              ProfileFeedRouteData(npub: value, index: '2').location,
              allOf(
                equals(ProfileScreenRouter.pathForIndex(encoded, 2)),
                equals('/profile/$segment/2'),
              ),
            );
            expect(
              ProfileUnavailablePinsRouteData(npub: value).location,
              allOf(
                equals(RoutePaths.profileUnavailablePinsForNpub(encoded)),
                equals('/profile/$segment/unavailable-pins'),
              ),
            );
          },
        );
      }
    });
  });
}

/// Profile identifiers that need no escaping in a path segment (an npub, a hex
/// pubkey and the `me` placeholder), so encoding them first changes nothing.
const List<String> _plainProfileIds = [
  syntheticTestNpub,
  syntheticTestPubkey,
  'me',
];

/// Text that needs escaping in a path segment, with the segment a typed
/// location writes for it.
const Map<String, String> _awkwardProfileIds = {
  '100%fun': '100%25fun',
  'a b': 'a%20b',
  'a/b': 'a%2Fb',
  '?': '%3F',
  '#': '%23',
};
