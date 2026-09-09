// ABOUTME: Regression tests for support diagnostics retaining pre-support routes
// ABOUTME: Ensures support screens cannot overwrite the bounded route trail

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/providers.dart';

void main() {
  late StreamController<String> locations;
  late ProviderContainer container;

  setUp(() {
    locations = StreamController<String>.broadcast();
    container = ProviderContainer(
      overrides: [
        routerLocationStreamProvider.overrideWithValue(locations.stream),
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

    test('ignores unknown locations rather than recording home', () async {
      final snapshot = await visit(['/profile/0', '/not-a-real-route']);

      expect(snapshot.currentScreen, 'profile');
      expect(snapshot.recentScreens, ['profile']);
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
