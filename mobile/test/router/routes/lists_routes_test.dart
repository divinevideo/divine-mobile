// ABOUTME: Exercises the real curated-list route table at its author boundary.
// ABOUTME: An author segment that is not a key never reaches a relay query.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/lists_routes.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/explore/explore_screen.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

/// The widget the route builder chose, recorded instead of rendered so these
/// tests never build a screen that queries relays.
Widget? _selected;

final ProviderFamily<GoRouter, String> _routerProvider =
    Provider.family<GoRouter, String>((ref, location) {
      final routes = listsRoutes(ref).cast<GoRoute>().map(
        (route) => GoRoute(
          path: route.path,
          name: route.name,
          redirect: route.redirect,
          builder: (context, state) {
            _selected = route.builder!(context, state);
            return const Scaffold(body: Text('Selected route'));
          },
        ),
      );
      final router = GoRouter(initialLocation: location, routes: [...routes]);
      ref.onDispose(router.dispose);
      return router;
    });

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

  group('Curated list by author route', () {
    setUp(() => _selected = null);

    Future<void> pumpRoute(WidgetTester tester, String location) async {
      await tester.pumpWidget(
        testProviderScope(
          child: Consumer(
            builder: (context, ref, child) => MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: ref.watch(_routerProvider(location)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // Relays require a 64-char hex author, so passing this through only turned
    // into a load failure after a round trip.
    testWidgets('rejects an author that is not a key', (tester) async {
      await pumpRoute(tester, '/list/hello/patrol-list');

      expect(_selected, isA<RouteErrorScreen>());
    });

    testWidgets('rejects an npub author whose checksum fails', (tester) async {
      await pumpRoute(tester, '/list/$syntheticMisspelledNpub/patrol-list');

      expect(_selected, isA<RouteErrorScreen>());
    });

    testWidgets('resolves an npub author to its hex key', (tester) async {
      await pumpRoute(tester, '/list/$syntheticOtherTestNpub/patrol-list');

      expect(
        _selected,
        isA<CuratedListByAuthorScreen>().having(
          (screen) => screen.authorPubkey,
          'authorPubkey',
          syntheticOtherTestPubkey,
        ),
      );
    });

    testWidgets('lowercases an uppercase hex author', (tester) async {
      final upper = syntheticOtherTestPubkey.toUpperCase();

      await pumpRoute(tester, '/list/$upper/patrol-list');

      expect(
        _selected,
        isA<CuratedListByAuthorScreen>().having(
          (screen) => screen.authorPubkey,
          'authorPubkey',
          syntheticOtherTestPubkey,
        ),
      );
    });
  });
}
