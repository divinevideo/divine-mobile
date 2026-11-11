// ABOUTME: Tests the minor-account review routes registered by
// ABOUTME: minorAccountReviewRoutes: locations, names, navigators and order.

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/router/routes/minor_account_review_routes.dart';
import 'package:openvine/screens/minor_account_review_parent_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_parent_contact_screen.dart';
import 'package:openvine/screens/minor_account_review_record_consent_screen.dart';
import 'package:openvine/screens/minor_account_review_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_screen.dart';
import 'package:openvine/screens/minor_account_review_under13_support_screen.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState(String location)
    : uri = Uri.parse(location),
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
  Map<String, String> get pathParameters => const {};

  @override
  Object? get extra => null;
}

typedef _Expected = ({String path, String name});

// Literals on purpose: the protected-minor gate in app_router_redirect.dart
// compares these exact location strings, so they are not read back from the
// constants the route annotations use. The order is the one the routes were
// registered in before they were typed.
const List<_Expected> _expectedInOrder = [
  (path: '/account-review/welcome', name: 'minor-account-review-welcome'),
  (path: '/account-review', name: 'minor-account-review'),
  (path: '/account-review/checking', name: 'minor-account-review-loading'),
  (
    path: '/account-review/parent-consent',
    name: 'minor-account-review-parent-consent',
  ),
  (
    path: '/account-review/parent-consent/record',
    name: 'minor-account-review-record-consent',
  ),
  (
    path: '/account-review/parent-contact',
    name: 'minor-account-review-parent-contact',
  ),
  (path: '/account-review/under-13', name: 'minor-account-review-under13'),
  (
    path: '/account-review/under-13-support',
    name: 'minor-account-review-under13-support',
  ),
];

void main() {
  group('minorAccountReviewRoutes', () {
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

    List<GoRoute> registered() =>
        minorAccountReviewRoutes().whereType<GoRoute>().toList();

    GoRoute routeAt(String path) =>
        registered().singleWhere((route) => route.path == path);

    Widget build(String location) {
      final path = Uri.parse(location).path;
      return routeAt(path).builder!(context, _FakeGoRouterState(location));
    }

    group('typed locations', () {
      test('each route class navigates to its literal location', () {
        expect(
          [
            const MinorAccountReviewWelcomeRouteData().location,
            const MinorAccountReviewRouteData().location,
            const MinorAccountReviewLoadingRouteData().location,
            const MinorAccountReviewParentConsentRouteData().location,
            const MinorAccountReviewRecordConsentRouteData().location,
            const MinorAccountReviewParentContactRouteData().location,
            const MinorAccountReviewUnder13RouteData().location,
            const MinorAccountReviewUnder13SupportRouteData().location,
          ],
          equals([for (final expected in _expectedInOrder) expected.path]),
        );
      });

      test('the welcome route is where the screen sends the welcome entry', () {
        expect(
          const MinorAccountReviewWelcomeRouteData().location,
          equals(MinorAccountReviewScreen.pathFor()),
        );
        expect(
          const MinorAccountReviewRouteData().location,
          equals(
            MinorAccountReviewScreen.pathFor(
              entryPoint: MinorAccountReviewEntryPoint.moderation,
            ),
          ),
        );
      });
    });

    group('registration', () {
      test('registers one childless GoRoute per review step', () {
        final routes = minorAccountReviewRoutes();

        expect(routes, hasLength(_expectedInOrder.length));
        expect(
          routes,
          everyElement(
            isA<GoRoute>().having((route) => route.routes, 'routes', isEmpty),
          ),
        );
      });

      test('registers the routes in their original order', () {
        expect(
          [
            for (final route in registered())
              (path: route.path, name: route.name!),
          ],
          equals(_expectedInOrder),
        );
      });
    });

    group('navigators', () {
      test('every review step covers the shell', () {
        for (final route in registered()) {
          expect(
            route.parentNavigatorKey,
            same(NavigatorKeys.root),
            reason: route.path,
          );
        }
      });
    });

    group('builders', () {
      testWidgets('the welcome entry opens the review as the welcome entry', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          build('/account-review/welcome'),
          isA<MinorAccountReviewScreen>().having(
            (screen) => screen.entryPoint,
            'entryPoint',
            MinorAccountReviewEntryPoint.welcome,
          ),
        );
      });

      testWidgets('the review route opens the moderation entry', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          build('/account-review'),
          isA<MinorAccountReviewScreen>().having(
            (screen) => screen.entryPoint,
            'entryPoint',
            MinorAccountReviewEntryPoint.moderation,
          ),
        );
      });

      testWidgets('each remaining location builds its own screen', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          build('/account-review/checking'),
          isA<MinorAccountReviewLoadingScreen>(),
        );
        expect(
          build('/account-review/parent-consent'),
          isA<MinorAccountReviewParentConsentScreen>(),
        );
        expect(
          build('/account-review/parent-consent/record'),
          isA<MinorAccountReviewRecordConsentScreen>(),
        );
        expect(
          build('/account-review/parent-contact'),
          isA<MinorAccountReviewParentContactScreen>(),
        );
        expect(
          build('/account-review/under-13'),
          isA<MinorAccountReviewUnder13Screen>(),
        );
        expect(
          build('/account-review/under-13-support'),
          isA<MinorAccountReviewUnder13SupportScreen>(),
        );
      });

      // The redirect sends a gated user here with the location to resume as
      // a `from` query, and the screen shows no matter what rides along.
      testWidgets('the loading route builds with the from query attached', (
        tester,
      ) async {
        await captureContext(tester);

        expect(
          build('/account-review/checking?from=%2Fvideo%2Fabc'),
          isA<MinorAccountReviewLoadingScreen>(),
        );
      });
    });

    group('resolution', () {
      test('a gated location resolves to the loading route with its query', () {
        final router = GoRouter(
          navigatorKey: NavigatorKeys.root,
          routes: minorAccountReviewRoutes(),
        );
        addTearDown(router.dispose);

        final match = router.configuration.findMatch(
          Uri.parse('/account-review/checking?from=%2Fvideo%2Fabc'),
        );

        expect(match.isError, isFalse);
        expect(match.uri.queryParameters['from'], equals('/video/abc'));
        expect(
          match.last.route,
          isA<GoRoute>().having(
            (route) => route.name,
            'name',
            'minor-account-review-loading',
          ),
        );
      });

      test('every registered location resolves to its own named route', () {
        final router = GoRouter(
          navigatorKey: NavigatorKeys.root,
          routes: minorAccountReviewRoutes(),
        );
        addTearDown(router.dispose);

        for (final expected in _expectedInOrder) {
          final match = router.configuration.findMatch(
            Uri.parse(expected.path),
          );

          expect(match.isError, isFalse, reason: expected.path);
          expect(
            match.last.route,
            isA<GoRoute>().having(
              (route) => route.name,
              'name',
              expected.name,
            ),
            reason: expected.path,
          );
        }
      });
    });
  });
}
