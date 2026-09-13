// ABOUTME: Characterizes root-observer events from StatefulShellRoute.
// ABOUTME: Pins branch navigation isolation so analytics stays deterministic.

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/go_router_page_name.dart';
import 'package:openvine/router/routes/shell.dart';

enum _ObserverAction { push, pop, remove, replace }

typedef _ObserverEvent = ({_ObserverAction action, String? name});

class _RecordingNavigatorObserver extends NavigatorObserver {
  final events = <_ObserverEvent>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    events.add((action: _ObserverAction.push, name: route.settings.name));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    events.add((action: _ObserverAction.pop, name: route.settings.name));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    events.add((action: _ObserverAction.remove, name: route.settings.name));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    events.add((
      action: _ObserverAction.replace,
      name: newRoute?.settings.name,
    ));
  }
}

void main() {
  group('shell route analytics', () {
    test('production shell keeps branch events away from root observers', () {
      final route = shellRoutes().single as StatefulShellRoute;

      expect(route.notifyRootObserver, isFalse);
    });

    testWidgets('branch navigation stays isolated from root observers', (
      tester,
    ) async {
      final observer = _RecordingNavigatorObserver();
      final router = _buildRouter(
        observer: observer,
        notifyRootObserver: false,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(observer.events, [
        (action: _ObserverAction.push, name: 'home'),
      ]);
      expect(
        AnalyticsSurface.routeSurfaceName(observer.events.single.name),
        AnalyticsSurface.homeFeed,
      );

      for (final location in [
        '/explore',
        '/home',
        '/explore',
        '/explore/tab/comedy',
        '/profile/synthetic-user',
        '/profile/synthetic-user/1',
      ]) {
        router.go(location);
        await tester.pump();
      }

      expect(observer.events, [
        (action: _ObserverAction.push, name: 'home'),
      ]);

      router.push('/details');
      await tester.pump();

      expect(observer.events, [
        (action: _ObserverAction.push, name: 'home'),
        (action: _ObserverAction.push, name: 'details'),
      ]);

      router.pop();
      await tester.pump();

      expect(observer.events.last, (
        action: _ObserverAction.pop,
        name: 'details',
      ));
    });

    testWidgets('forwarding branch events produces lifecycle-dependent data', (
      tester,
    ) async {
      final observer = _RecordingNavigatorObserver();
      final router = _buildRouter(observer: observer, notifyRootObserver: true);
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(observer.events, [
        (action: _ObserverAction.push, name: 'home'),
        (action: _ObserverAction.push, name: 'home'),
      ]);

      router.go('/explore');
      await tester.pump();
      expect(observer.events.last, (
        action: _ObserverAction.push,
        name: 'explore',
      ));

      final firstExploreVisitCount = observer.events.length;
      router.go('/home');
      await tester.pump();
      router.go('/explore');
      await tester.pump();
      expect(observer.events, hasLength(firstExploreVisitCount));

      router.go('/explore/tab/comedy');
      await tester.pump();

      expect(observer.events, [
        (action: _ObserverAction.push, name: 'home'),
        (action: _ObserverAction.push, name: 'home'),
        (action: _ObserverAction.push, name: 'explore'),
        (action: _ObserverAction.push, name: '/explore/tab/:name'),
        (action: _ObserverAction.remove, name: 'explore'),
      ]);
    });
  });
}

GoRouter _buildRouter({
  required NavigatorObserver observer,
  required bool notifyRootObserver,
}) {
  return GoRouter(
    initialLocation: '/home',
    observers: [observer],
    routes: [
      StatefulShellRoute.indexedStack(
        notifyRootObserver: notifyRootObserver,
        pageBuilder: (_, state, navigationShell) => NoTransitionPage<void>(
          key: state.pageKey,
          name: goRouterPageName(state),
          child: navigationShell,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                builder: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/explore',
                name: 'explore',
                builder: (_, _) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/explore/tab/:name',
                builder: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
          StatefulShellBranch(
            initialLocation: '/profile/synthetic-user',
            routes: [
              GoRoute(
                path: '/profile/:user',
                name: 'profile',
                builder: (_, _) => const SizedBox.shrink(),
              ),
              GoRoute(
                path: '/profile/:user/:index',
                builder: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/details',
        name: 'details',
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ],
  );
}
