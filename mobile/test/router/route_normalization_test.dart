// ABOUTME: Tests for route normalization skip logic
// ABOUTME: Prevents universal links from being rewritten by internal canonicalization

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/people_lists/view/create_people_list_page.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/profile_setup/profile_setup.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const videoId =
      '672c4eb9fc29adb6b505713bc6da94af2244c1de55dc6f034e2bcdaba133ebbe';
  const pubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  group('shouldSkipRouteNormalization', () {
    test('skips divine video universal links', () {
      expect(
        shouldSkipRouteNormalization('https://divine.video/video/abc123'),
        isTrue,
      );
    });

    test('skips divine profile universal links', () {
      expect(
        shouldSkipRouteNormalization(
          'https://divine.video/profile/npub1abc123',
        ),
        isTrue,
      );
    });

    test('skips divine list universal links', () {
      expect(
        shouldSkipRouteNormalization('https://divine.video/list/my-vines'),
        isTrue,
      );
      expect(
        shouldSkipRouteNormalization(
          'https://www.divine.video/list/my-vines',
        ),
        isTrue,
      );
    });

    test('skips NIP-46 signer callbacks from native signer apps', () {
      expect(
        shouldSkipRouteNormalization(
          'divine://nostrconnect?x-source=aegis&relay=wss://localrelay.link:28443',
        ),
        isTrue,
      );
    });

    test('does not skip unrelated hosts', () {
      expect(
        shouldSkipRouteNormalization('https://example.com/video/abc123'),
        isFalse,
      );
    });

    test('does not skip modeled internal routes without query or fragment', () {
      final routes = {
        '/video/$videoId': 'video detail is fully modeled',
        '/home/0': 'canonical home path is fully modeled',
        '/home/-3': 'negative index can be normalized losslessly',
      };

      for (final entry in routes.entries) {
        expect(
          shouldSkipRouteNormalization(entry.key),
          isFalse,
          reason: entry.value,
        );
      }
    });

    test(
      'skips all query or fragment routes because canonicalization is lossy',
      () {
        final routes = {
          PooledFullscreenVideoFeedScreen.pathForVideoId(videoId):
              'pooled feed carries selected video identity in query',
          CreatePeopleListPage.pathWithInitialPubkey(pubkey):
              'create people list seeds a full pubkey in query',
          SearchResultsPage.pathForQuery('nostr', requestFocusOnMount: true):
              'search focus state lives in query',
          '${EmailVerificationScreen.path}?deviceCode=abc123':
              'email verification polling state lives in query',
          '${ResetPasswordScreen.path}?token=abc123':
              'password reset token lives in query',
          '/home/0#top': 'fragments cannot be rebuilt from RouteContext',
          '/video/$videoId/likers?a=34236%3A$pubkey%3Adtag':
              'engagement list filter state lives in query',
        };

        for (final entry in routes.entries) {
          expect(
            shouldSkipRouteNormalization(entry.key),
            isTrue,
            reason: entry.value,
          );
        }
      },
    );
  });

  group('normalizedPathFor over the registered route tree', () {
    late List<RouteBase> registered;
    late List<String> templates;
    late RouteConfiguration routes;

    setUp(() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      registered = container.read(_appRoutesProvider);
      templates = _templatesOf(registered);
      routes = _configurationOf(registered);
    });

    test('leaves every registered route where it is', () {
      expect(
        templates,
        containsAll([
          '/video/:eventId/likers',
          '/video/:eventId/reposters',
          '/apps/:appId/sandbox',
          '/account-review/parent-consent',
          '/profile/:npub/:index',
          '/welcome/login-options/reset-password',
        ]),
        reason: 'the walk must reach shell branches and nested children',
      );
      for (final template in templates) {
        final location = Uri.parse(_sampleLocation(template));
        expect(
          normalizedPathFor(routes, location),
          isNull,
          reason: 'registered route $template was rewritten from $location',
        );
      }
    });

    test('canonicalizes a negative index on its own route', () {
      final expected = {
        '/home/-3': '/home/0',
        '/notifications/-2': '/notifications/0',
        '/profile/$pubkey/-1': '/profile/$pubkey/0',
      };

      for (final entry in expected.entries) {
        expect(
          normalizedPathFor(routes, Uri.parse(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('rescues a retired alias GoRouter no longer registers', () {
      final expected = {
        '/video-feed': '/pooled-video-feed',
        '/clips-no-sound': '/clips-only',
      };

      for (final entry in expected.entries) {
        expect(
          normalizedPathFor(routes, Uri.parse(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
    });

    test('leaves unknown, incomplete and canonical routes alone', () {
      final cases = {
        '/search-results/nostr': 'search results are not RouteContext modeled',
        '/verify-email': 'auth deep links are GoRouter-owned',
        '/wat/xyz': 'unknown routes must not be rewritten to home',
        '/following': 'an incomplete dynamic route must not normalize',
        ProfileSetupScreen.setupPath: 'setup profile is not edit profile',
        '/hashtag/nostr%20video': 'an encoded parameter is already canonical',
      };

      for (final entry in cases.entries) {
        expect(
          normalizedPathFor(routes, Uri.parse(entry.key)),
          isNull,
          reason: entry.value,
        );
      }
    });

    test('leaves an unregistered trailing segment to GoRouter', () {
      for (final route in [
        ExploreScreen.pathForTab('popular'),
        '/people-lists/new/extra',
        '/hashtag/dogs/3',
        '/video/$videoId/bogus',
        '/home/0/extra',
        '/profile/$pubkey/0/extra',
      ]) {
        expect(
          normalizedPathFor(routes, Uri.parse(route)),
          isNull,
          reason: route,
        );
      }
    });

    test('never moves a route registered under another one onto it', () {
      final lastParameter = RegExp(r'/:\w+$');
      final nested = {
        for (final template in templates) ...{
          _joinPath(template, 'added'),
          if (lastParameter.hasMatch(template))
            template.replaceFirst(lastParameter, '/added'),
        },
      }..removeAll(templates);
      expect(nested, containsAll(['/profile/:npub/added', '/home/added']));
      final withNested = _configurationOf([
        for (final path in nested)
          GoRoute(path: path, builder: (_, _) => const SizedBox()),
        ...registered,
      ]);

      for (final template in nested) {
        final location = Uri.parse(_sampleLocation(template));
        expect(
          normalizedPathFor(withNested, location),
          isNull,
          reason: 'a new route at $template was redirected from $location',
        );
      }
    });
  });

  group('routeNormalizationProvider', () {
    testWidgets('normalizes the location a refresh redirect lands on', (
      tester,
    ) async {
      final refresh = ValueNotifier<bool>(false);
      addTearDown(refresh.dispose);
      var redirected = false;
      final router = GoRouter(
        initialLocation: '/home/0',
        refreshListenable: refresh,
        redirect: (_, _) {
          if (!refresh.value || redirected) return null;
          redirected = true;
          return '/home/-1';
        },
        routes: [
          GoRoute(path: '/home/:index', builder: (_, _) => const SizedBox()),
        ],
      );
      addTearDown(router.dispose);
      final container = ProviderContainer(
        overrides: [goRouterProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      container.read(routeNormalizationProvider);

      refresh.value = true;
      await tester.pumpAndSettle();

      expect(redirected, isTrue);
      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/home/0',
      );
    });
  });
}

RouteConfiguration _configurationOf(List<RouteBase> routes) {
  final router = GoRouter(navigatorKey: NavigatorKeys.root, routes: routes);
  addTearDown(router.dispose);
  return router.configuration;
}

final _appRoutesProvider = Provider<List<RouteBase>>(appRoutes);

/// Full path templates of [routes] and their descendants, shell routes
/// included, in registration order.
List<String> _templatesOf(List<RouteBase> routes, [String parent = '']) => [
  for (final route in routes)
    if (route is GoRoute) ...[
      _joinPath(parent, route.path),
      ..._templatesOf(route.routes, _joinPath(parent, route.path)),
    ] else if (route is ShellRouteBase)
      ..._templatesOf(route.routes, parent),
];

String _joinPath(String parent, String child) {
  if (child.startsWith('/')) return child;
  return parent.endsWith('/') ? '$parent$child' : '$parent/$child';
}

/// A concrete location for [template]: an index for index parameters, a full
/// 64-hex value (valid as an event id, pubkey, list id or slug) for the rest.
String _sampleLocation(String template) => template.replaceAllMapped(
  RegExp(r':(\w+)'),
  (match) => match[1] == 'index' || match[1]!.endsWith('Index')
      ? '2'
      : '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
);
