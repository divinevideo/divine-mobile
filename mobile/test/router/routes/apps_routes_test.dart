// ABOUTME: Tests the Nostr-apps routes registered by appsRoutes.
// ABOUTME: Pins locations, match order, providers and the extra warm-start hint.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_error_screen.dart';
import 'package:openvine/router/routes/apps_routes.dart';
import 'package:openvine/router/widgets/resolved_app_route_screen.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/apps/apps_permissions_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';
import 'package:openvine/screens/apps/web_iframe_sandbox_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';
import '../../helpers/test_pubkeys.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required String location,
    this.pathParameters = const {},
    this.extra,
  }) : uri = Uri.parse(location),
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
  final Map<String, String> pathParameters;

  @override
  final Object? extra;
}

/// Ids whose encoding has broken routes before: a hex key, an npub, an naddr,
/// a literal `%`, a space, a slash, a `?` and a `#`.
const List<String> _awkwardIds = [
  'abababababababababababababababababababababababababababababababab',
  syntheticOtherTestNpub,
  'naddr1qqxnzd3cxqmrzv3exgmr2wfeqgsxu35yyt0mwjjh8pcz4zprhxegz69t',
  '100%fun',
  'a b',
  'a/b',
  '?',
  '#',
];

/// The ids that need no escaping, where the screens' unencoded detail builder
/// and the typed location are the same string.
const List<String> _plainIds = [
  'primal',
  'abababababababababababababababababababababababababababababababab',
  syntheticOtherTestNpub,
];

void main() {
  group('appsRoutes', () {
    late BuildContext context;

    Future<void> captureContext(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
    }

    GoRoute routeNamed(String name) => appsRoutes()
        .whereType<GoRoute>()
        .singleWhere((route) => route.name == name);

    Widget build(
      String name,
      String location, {
      Map<String, String> pathParameters = const {},
      Object? extra,
    }) => routeNamed(name).builder!(
      context,
      _FakeGoRouterState(
        location: location,
        pathParameters: pathParameters,
        extra: extra,
      ),
    );

    group('locations', () {
      // Redirects and the gates compare these exact strings, so they are
      // written out rather than read back from the constants the annotations
      // use, which could not fail on an edit to one of them.
      test('the directory and permissions routes keep their paths', () {
        expect(const AppsDirectoryRouteData().location, equals('/apps'));
        expect(
          const AppsPermissionsRouteData().location,
          equals('/apps/permissions'),
        );
      });

      // Callers and the screens' path builders still build these locations,
      // so the typed routes must produce the same URL for every id.
      for (final id in _awkwardIds) {
        test('the sandbox location matches pathForAppId for "$id"', () {
          expect(
            NostrAppSandboxRouteData(appId: id).location,
            equals(NostrAppSandboxScreen.pathForAppId(id)),
          );
        });

        test('the web sandbox location matches pathForAppId for "$id"', () {
          expect(
            WebIframeSandboxRouteData(appId: id).location,
            equals(WebIframeSandboxScreen.pathForAppId(id)),
          );
        });

        // RoutePaths.appDetailForSlug does not encode the slug, so for an id
        // that needs escaping the typed location is the safe one. Its one
        // caller, buildRoute in page_context_provider.dart, encodes first.
        test('the detail location encodes the slug "$id"', () {
          expect(
            AppDetailRouteData(slug: id).location,
            equals('/apps/${Uri.encodeComponent(id)}'),
          );
        });
      }

      for (final slug in _plainIds) {
        test('the detail location matches pathForSlug for "$slug"', () {
          expect(
            AppDetailRouteData(slug: slug).location,
            equals(AppDetailScreen.pathForSlug(slug)),
          );
        });
      }
    });

    group('declarations', () {
      // The gates, deep links and callers know the routes by these exact
      // strings, so they are written out here rather than read back from the
      // constants the annotations use.
      test('every route keeps its name, in declaration order', () {
        expect(
          appsRoutes().whereType<GoRoute>().map((route) => route.name),
          equals([
            'apps-directory',
            'apps-permissions',
            'nostr-app-sandbox',
            'web-iframe-sandbox',
            'app-detail',
          ]),
        );
      });

      test('every route keeps its path template, in declaration order', () {
        expect(
          appsRoutes().whereType<GoRoute>().map((route) => route.path),
          equals([
            '/apps',
            '/apps/permissions',
            '/apps/:appId/sandbox',
            '/apps/:appId/web-sandbox',
            '/apps/:slug',
          ]),
        );
      });
    });

    group('directory', () {
      testWidgets('builds the apps directory screen', (tester) async {
        await captureContext(tester);

        final screen = build(AppsDirectoryScreen.routeName, '/apps');

        expect(screen, isA<AppsDirectoryScreen>());
      });
    });

    group('order', () {
      // go_router matches same-segment-count routes top-to-bottom, so the
      // literal `permissions` must be registered before `:slug` can read it
      // as an app.
      test('permissions precedes the detail route', () {
        final paths = appsRoutes()
            .whereType<GoRoute>()
            .map((route) => route.path)
            .toList();

        expect(
          paths.indexOf(AppsPermissionsScreen.path),
          lessThan(paths.indexOf(AppDetailScreen.path)),
        );
      });

      testWidgets('/apps/permissions resolves to permissions, not a slug', (
        tester,
      ) async {
        final matched = <String?>[];
        final routes = appsRoutes().whereType<GoRoute>().map(
          (route) => GoRoute(
            path: route.path,
            name: route.name,
            builder: (_, state) {
              matched.add(state.name);
              return const SizedBox.shrink();
            },
          ),
        );
        final router = GoRouter(
          initialLocation: AppsPermissionsScreen.path,
          routes: [...routes],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );
        await tester.pumpAndSettle();
        router.go(const AppDetailRouteData(slug: 'primal').location);
        await tester.pumpAndSettle();

        expect(
          matched,
          equals([AppsPermissionsScreen.routeName, AppDetailScreen.routeName]),
        );
      });

      testWidgets('every location round-trips its id through the router', (
        tester,
      ) async {
        final seen = <String, String?>{};
        final routes = appsRoutes().whereType<GoRoute>().map(
          (route) => GoRoute(
            path: route.path,
            name: route.name,
            builder: (_, state) {
              final params = state.pathParameters;
              seen['${state.name}'] = params['appId'] ?? params['slug'];
              return const SizedBox.shrink();
            },
          ),
        );
        final router = GoRouter(
          initialLocation: AppsDirectoryScreen.path,
          routes: [...routes],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        );

        for (final id in _awkwardIds) {
          for (final (name, location) in [
            (
              NostrAppSandboxScreen.routeName,
              NostrAppSandboxRouteData(appId: id).location,
            ),
            (
              WebIframeSandboxScreen.routeName,
              WebIframeSandboxRouteData(appId: id).location,
            ),
            (
              AppDetailScreen.routeName,
              AppDetailRouteData(slug: id).location,
            ),
          ]) {
            seen.remove(name);
            router.go(location);
            await tester.pumpAndSettle();

            expect(seen[name], equals(id), reason: '$name at $location');
          }
        }
      });
    });

    group('navigator', () {
      test('every route is a plain top-level builder route', () {
        for (final route in appsRoutes().whereType<GoRoute>()) {
          expect(route.parentNavigatorKey, isNull, reason: '${route.name}');
          expect(route.routes, isEmpty, reason: '${route.name}');
        }
      });
    });

    group('permissions', () {
      late SharedPreferences preferences;
      late NostrAppGrantStore grantStore;
      late MockAuthService authService;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        preferences = await SharedPreferences.getInstance();
        grantStore = NostrAppGrantStore(sharedPreferences: preferences);
        authService = createMockAuthService(
          currentPublicKeyHex: syntheticOtherTestPubkey,
        );
      });

      testWidgets('reads the grant store and the signed-in key from the '
          'provider scope', (tester) async {
        await captureContext(
          tester,
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            nostrAppGrantStoreProvider.overrideWithValue(grantStore),
          ],
        );

        final screen = build(
          AppsPermissionsScreen.routeName,
          AppsPermissionsScreen.path,
        );

        expect(
          screen,
          isA<AppsPermissionsScreen>()
              .having((s) => s.grantStore, 'grantStore', same(grantStore))
              .having(
                (s) => s.currentUserPubkey,
                'currentUserPubkey',
                syntheticOtherTestPubkey,
              ),
        );
      });

      testWidgets('passes no key when nobody is signed in', (tester) async {
        authService = createMockAuthService();
        await captureContext(
          tester,
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            nostrAppGrantStoreProvider.overrideWithValue(grantStore),
          ],
        );

        final screen = build(
          AppsPermissionsScreen.routeName,
          AppsPermissionsScreen.path,
        );

        expect(
          screen,
          isA<AppsPermissionsScreen>().having(
            (s) => s.currentUserPubkey,
            'currentUserPubkey',
            isNull,
          ),
        );
      });
    });

    group('extra hint', () {
      const appId = 'primal-app';
      final app = _app();

      // An entry URL carries no hint, and restored route state can hand one
      // back as a decoded map. Neither may dead-end a route (#3335).
      final hints = <(String, Object?, NostrAppDirectoryEntry?)>[
        ('the entry', app, app),
        ('no hint', null, null),
        ('a restored map', const <String, dynamic>{'id': appId}, null),
      ];

      for (final (label, extra, expected) in hints) {
        testWidgets('the sandbox opens from its id with $label', (
          tester,
        ) async {
          await captureContext(tester);

          final screen = build(
            NostrAppSandboxScreen.routeName,
            NostrAppSandboxScreen.pathForAppId(appId),
            pathParameters: const {'appId': appId},
            extra: extra,
          );

          expect(screen, isNot(isA<RouteErrorScreen>()));
          expect(
            screen,
            isA<ResolvedAppRouteScreen>()
                .having((s) => s.appId, 'appId', appId)
                .having((s) => s.initialApp, 'initialApp', expected),
          );
        });

        testWidgets('the web sandbox opens from its id with $label', (
          tester,
        ) async {
          await captureContext(tester);

          final screen = build(
            WebIframeSandboxScreen.routeName,
            WebIframeSandboxScreen.pathForAppId(appId),
            pathParameters: const {'appId': appId},
            extra: extra,
          );

          expect(screen, isNot(isA<RouteErrorScreen>()));
          expect(
            screen,
            isA<ResolvedAppRouteScreen>()
                .having((s) => s.appId, 'appId', appId)
                .having((s) => s.initialApp, 'initialApp', expected),
          );
        });

        testWidgets('the detail page opens from its slug with $label', (
          tester,
        ) async {
          await captureContext(tester);

          final screen = build(
            AppDetailScreen.routeName,
            AppDetailScreen.pathForSlug('primal'),
            pathParameters: const {'slug': 'primal'},
            extra: extra,
          );

          expect(screen, isNot(isA<RouteErrorScreen>()));
          expect(
            screen,
            isA<AppDetailScreen>()
                .having((s) => s.slug, 'slug', 'primal')
                .having((s) => s.initialEntry, 'initialEntry', expected),
          );
        });
      }

      testWidgets('the sandbox route hands the resolved entry to its screen', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          NostrAppSandboxScreen.routeName,
          NostrAppSandboxScreen.pathForAppId(appId),
          pathParameters: const {'appId': appId},
        ) as ResolvedAppRouteScreen;

        expect(screen.onResolved(app), isA<NostrAppSandboxScreen>());
      });

      testWidgets('the web sandbox route hands the resolved entry to its '
          'screen', (tester) async {
        await captureContext(tester);

        final screen = build(
          WebIframeSandboxScreen.routeName,
          WebIframeSandboxScreen.pathForAppId(appId),
          pathParameters: const {'appId': appId},
        ) as ResolvedAppRouteScreen;

        expect(screen.onResolved(app), isA<WebIframeSandboxScreen>());
      });
    });
  });
}

NostrAppDirectoryEntry _app() {
  return NostrAppDirectoryEntry(
    id: 'primal-app',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
