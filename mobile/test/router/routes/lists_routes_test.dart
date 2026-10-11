// ABOUTME: Tests the list routes registered by listsRoutes.
// ABOUTME: Pins the legacy discovery URL that now lands on the Explore tab.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/screens/explore/explore_screen.dart';

void main() {
  group('listsRoutes', () {
    group(RoutePaths.discoverLists, () {
      testWidgets('lands on the Explore lists tab', (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final routes = container.read(Provider<List<RouteBase>>(listsRoutes));
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
            ...routes,
            GoRoute(
              path: ExploreScreen.pathTabSubpath,
              builder: (_, state) =>
                  Text('tab:${state.pathParameters['name']}'),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        router.go(RoutePaths.discoverLists);
        await tester.pumpAndSettle();

        expect(find.text('tab:lists'), findsOneWidget);
        expect(
          router.routeInformationProvider.value.uri.path,
          ExploreScreen.pathForTab('lists'),
        );
      });
    });
  });
}
