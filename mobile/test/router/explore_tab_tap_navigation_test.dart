// ABOUTME: Tests that tapping explore tab navigates to grid mode, not feed mode
// ABOUTME: Verifies default explore navigation is /explore (grid) not /explore/0 (feed)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';

void main() {
  group('Explore Tab Tap Navigation Test', () {
    testWidgets(
      'tapping explore tab navigates to /explore (grid mode), not /explore/0',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              routerConfig: container.read(goRouterProvider),
            ),
          ),
        );

        // Start at home
        container.read(goRouterProvider).go('/home/0');
        await tester.pumpAndSettle();

        // Get current location - should be /home/0
        final homeLocation = container
            .read(goRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .toString();
        expect(homeLocation, '/home/0');

        // Simulate tapping explore tab (index 1)
        // This should navigate to /explore (grid mode), NOT /explore/0 (feed mode)
        final appShell = tester.widget<Scaffold>(find.byType(Scaffold).first);
        final bottomNav = appShell.bottomNavigationBar as BottomNavigationBar;
        bottomNav.onTap!(1); // Tap explore tab
        await tester.pumpAndSettle();

        // Verify we're at /explore (grid mode)
        final exploreLocation = container
            .read(goRouterProvider)
            .routeInformationProvider
            .value
            .uri
            .toString();
        expect(
          exploreLocation,
          '/explore',
          reason:
              'Tapping explore tab should navigate to grid mode (/explore), not feed mode (/explore/0)',
        );
      },
    );
  });
}
