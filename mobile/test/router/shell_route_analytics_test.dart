// ABOUTME: Regression coverage for shell route names reaching observers.
// ABOUTME: Prevents normal home navigation from reporting unknown_route.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final pushedNames = <String?>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    pushedNames.add(route.settings.name);
  }
}

void main() {
  group('shell route analytics', () {
    testWidgets('shell home route pushes a named root route for analytics', (
      tester,
    ) async {
      final observer = _RecordingNavigatorObserver();
      final router = GoRouter(
        initialLocation: VideoFeedPage.path,
        observers: [observer],
        routes: [
          StatefulShellRoute.indexedStack(
            pageBuilder: (_, state, navigationShell) => NoTransitionPage<void>(
              key: state.pageKey,
              name: goRouterPageName(state),
              child: navigationShell,
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: VideoFeedPage.path,
                    name: VideoFeedPage.routeName,
                    builder: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(observer.pushedNames, contains(VideoFeedPage.routeName));
      expect(
        AnalyticsSurface.routeSurfaceName(VideoFeedPage.routeName),
        AnalyticsSurface.homeFeed,
      );
    });
  });
}
