// ABOUTME: Regression tests for support diagnostics retaining pre-support routes
// ABOUTME: Ensures support screens cannot overwrite the bounded route trail

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/router.dart';
import 'package:riverpod/misc.dart' show Override;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<String> locations;
  late ProviderContainer container;

  setUp(() {
    locations = StreamController<String>.broadcast();
    container = ProviderContainer(
      overrides: [
        routerLocationStreamProvider.overrideWithValue(locations.stream),
        _appRouter,
      ],
    );
    container.read(supportRouteTrailProvider);
    container.listen(routerLocationProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await locations.close();
  });

  Future<SupportRouteSnapshot> visit(List<String> paths) async {
    for (final path in paths) {
      locations.add(path);
      await pumpEventQueue();
    }
    return container.read(supportRouteTrailProvider.notifier).snapshot;
  }

  group('SupportRouteTrail', () {
    test('keeps route types in visit order and includes settings', () async {
      final snapshot = await visit(['/home/0', '/profile/0', '/settings']);

      expect(snapshot.currentScreen, 'settings');
      expect(snapshot.recentScreens, ['home', 'profile', 'settings']);
    });

    test(
      'records account review after a restricted redirect from home',
      () async {
        final snapshot = await visit(['/home/0', '/account-review']);

        expect(snapshot.currentScreen, 'minorAccountReview');
        expect(snapshot.recentScreens, ['home', 'minorAccountReview']);
      },
    );

    test(
      'records a cold account-review entry without prior navigation',
      () async {
        final snapshot = await visit(['/account-review']);

        expect(snapshot.currentScreen, 'minorAccountReview');
        expect(snapshot.recentScreens, ['minorAccountReview']);
      },
    );

    test('excludes the complete support subtree', () async {
      final snapshot = await visit([
        '/explore',
        '/support-center',
        '/support-center/report-bug',
        '/support-center/request-feature',
      ]);

      expect(snapshot.currentScreen, 'explore');
      expect(snapshot.recentScreens, ['explore']);
    });

    test('collapses consecutive duplicate route types', () async {
      final snapshot = await visit([
        '/home/0',
        '/home/1',
        '/profile/0',
        '/profile/4',
      ]);

      expect(snapshot.recentScreens, ['home', 'profile']);
    });

    test('retains only the five most recent route types', () async {
      final snapshot = await visit([
        '/home/0',
        '/explore',
        '/inbox',
        '/profile/0',
        '/settings',
        '/relay-settings',
      ]);

      expect(snapshot.recentScreens, [
        'explore',
        'inbox',
        'profile',
        'settings',
        'relaySettings',
      ]);
    });

    test('does not record a route registered under a parsed one', () async {
      final snapshot = await visit([
        '/home/0',
        '/video/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef/likers',
      ]);

      expect(snapshot.recentScreens, ['home']);
    });

    test('records a list addressed by its owner as that list', () async {
      final snapshot = await visit([
        '/people-lists/new?owner=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      ]);

      expect(snapshot.recentScreens, ['peopleListMembers']);
    });

    test('ignores unknown locations rather than recording home', () async {
      final snapshot = await visit(['/profile/0', '/not-a-real-route']);

      expect(snapshot.currentScreen, 'profile');
      expect(snapshot.recentScreens, ['profile']);
    });

    test('does not record a route registered under a profile as it', () async {
      final nestedLocations = StreamController<String>.broadcast();
      final nestedContainer = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWithValue(
            nestedLocations.stream,
          ),
          goRouterProvider.overrideWith((ref) {
            final router = GoRouter(
              navigatorKey: NavigatorKeys.root,
              routes: [
                GoRoute(
                  path: '/profile/:npub/collections',
                  builder: (_, _) => throw UnimplementedError(),
                ),
                ...appRoutes(ref),
              ],
            );
            ref.onDispose(router.dispose);
            return router;
          }),
        ],
      );
      addTearDown(() async {
        nestedContainer.dispose();
        await nestedLocations.close();
      });
      nestedContainer.read(supportRouteTrailProvider);
      nestedContainer.listen(routerLocationProvider, (_, _) {});

      for (final location in [
        '/home/0',
        '/profile/0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef/collections',
      ]) {
        nestedLocations.add(location);
        await pumpEventQueue();
      }

      expect(
        nestedContainer
            .read(supportRouteTrailProvider.notifier)
            .snapshot
            .recentScreens,
        ['home'],
      );
    });

    test(
      'uses the root router stream when page context is branch-scoped',
      () async {
        final rootLocations = StreamController<String>.broadcast();
        final rootContainer = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWithValue(
              rootLocations.stream,
            ),
            pageContextProvider.overrideWith(
              (ref) => Stream.value(const RouteContext(type: RouteType.home)),
            ),
            _appRouter,
          ],
        );
        addTearDown(() async {
          rootContainer.dispose();
          await rootLocations.close();
        });
        rootContainer.read(supportRouteTrailProvider);
        rootContainer.listen(routerLocationProvider, (_, _) {});

        rootLocations.add('/profile/0');
        await pumpEventQueue();

        expect(
          rootContainer
              .read(supportRouteTrailProvider.notifier)
              .snapshot
              .currentScreen,
          'profile',
        );
      },
    );
  });
}

/// The app's real routes, so the trail sees what GoRouter matched.
final Override _appRouter = goRouterProvider.overrideWith((ref) {
  final router = GoRouter(
    navigatorKey: NavigatorKeys.root,
    routes: appRoutes(ref),
  );
  ref.onDispose(router.dispose);
  return router;
});
