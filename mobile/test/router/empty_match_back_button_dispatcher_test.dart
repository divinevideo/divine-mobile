// ABOUTME: Pins system back when go_router has no route matched, which threw
// ABOUTME: Bad state: No element from GoRouterDelegate.popRoute.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/empty_match_back_button_dispatcher.dart';
import 'package:openvine/router/restoration_safe_router_config.dart';
import 'package:openvine/router/route_paths.dart';

GoRouter _buildRouter({
  required String initialLocation,
  GoRouterRedirect? redirect,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    redirect: redirect,
    errorBuilder: (_, _) => const Text('not found'),
    routes: [
      GoRoute(
        path: RoutePaths.videoFeedForIndex(0),
        builder: (_, _) => const Text('home'),
      ),
    ],
  );
  addTearDown(router.dispose);
  return router;
}

Future<RouterConfig<RouteMatchList>> _pumpApp(
  WidgetTester tester,
  GoRouter router,
) async {
  final config = restorationSafeRouterConfig(router);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: config,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  return config;
}

void main() {
  group(EmptyMatchSafeBackButtonDispatcher, () {
    // An unmatched location reached with go or a deep link is a top-level
    // error page, whose match list is empty.
    testWidgets('sends a back on the not-found page to the home feed', (
      tester,
    ) async {
      final router = _buildRouter(initialLocation: '/no-such-page');
      await _pumpApp(tester, router);
      await tester.pumpAndSettle();
      expect(find.text('not found'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.matches, isEmpty);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(find.text('not found'), findsNothing);
    });

    testWidgets('leaves a back to the platform while the first location '
        'is still resolving', (tester) async {
      final redirect = Completer<String?>();
      final router = _buildRouter(
        initialLocation: RoutePaths.videoFeedForIndex(0),
        redirect: (_, _) => redirect.future,
      );
      final config = await _pumpApp(tester, router);
      expect(router.routerDelegate.currentConfiguration.matches, isEmpty);

      final dispatcher =
          config.backButtonDispatcher! as RootBackButtonDispatcher;
      expect(await dispatcher.didPopRoute(), isFalse);

      redirect.complete(null);
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });

    // A pushed unmatched location keeps the page beneath it, so back must
    // return there rather than go home.
    testWidgets('pops a pushed not-found page as go_router does', (
      tester,
    ) async {
      final router = _buildRouter(
        initialLocation: RoutePaths.videoFeedForIndex(0),
      );
      await _pumpApp(tester, router);
      await tester.pumpAndSettle();
      unawaited(router.push<void>('/no-such-page'));
      await tester.pumpAndSettle();
      expect(find.text('not found'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
      expect(router.routerDelegate.currentConfiguration.matches, hasLength(1));
    });
  });
}
