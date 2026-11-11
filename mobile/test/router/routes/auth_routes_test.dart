// ABOUTME: Tests the sign-in routes registered by authRoutes.
// ABOUTME: Pins paths, names, query keys, the UTM capture and the reset rewrite.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/auth_routes.dart';
import 'package:openvine/router/routes/router_guards.dart';
import 'package:openvine/screens/auth/create_account_screen.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/login_options_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/auth/reset_password.dart';
import 'package:openvine/screens/auth/secure_account_screen.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/services/analytics_service.dart';

import '../../helpers/test_pubkeys.dart';

class _MockAnalyticsService extends Mock implements AnalyticsService {}

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
  final Map<String, String> pathParameters = const {};

  @override
  final Object? extra = null;
}

Iterable<GoRoute> _allRoutes(List<RouteBase> routes) sync* {
  for (final route in routes.whereType<GoRoute>()) {
    yield route;
    yield* _allRoutes(route.routes);
  }
}

/// The widget the route builder chose, recorded instead of rendered so these
/// tests never build a screen that needs the auth stack.
Widget? _selected;

/// [routes] with every builder replaced by a stub that records what the real
/// builder chose, keeping paths, names, redirects and nesting.
List<RouteBase> _stubbed(List<RouteBase> routes) => [
  for (final route in routes.whereType<GoRoute>())
    GoRoute(
      path: route.path,
      name: route.name,
      redirect: route.redirect,
      builder: (context, state) {
        _selected = route.builder!(context, state);
        return const Scaffold(body: Text('Selected route'));
      },
      routes: _stubbed(route.routes),
    ),
];

void main() {
  group('authRoutes', () {
    late _MockAnalyticsService analytics;
    late BuildContext context;

    setUp(() {
      analytics = _MockAnalyticsService();
      _selected = null;
    });

    Future<void> captureContext(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
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

    GoRoute routeNamed(String name) =>
        _allRoutes(authRoutes()).singleWhere((route) => route.name == name);

    Widget build(String name, String location) =>
        routeNamed(name).builder!(context, _FakeGoRouterState(location));

    group('registration', () {
      // The redirect gate compares these strings, so a typed route that
      // drifts from them changes who may reach the sign-in screens.
      test('registers the top-level routes in this order', () {
        expect(
          authRoutes().whereType<GoRoute>().map((route) => route.path),
          equals(<String>[
            '/welcome',
            '/import-key',
            '/nostr-connect',
            '/secure-account',
            '/reset-password',
            '/verify-email',
          ]),
        );
      });

      test('nests create account and sign in under welcome', () {
        final welcome = routeNamed('welcome');

        expect(
          welcome.routes.whereType<GoRoute>().map((route) => route.path),
          equals(<String>['create-account', 'login-options']),
        );
      });

      test('nests reset password under sign in', () {
        final loginOptions = routeNamed('login-options');

        expect(
          loginOptions.routes.whereType<GoRoute>().map((route) => route.path),
          equals(<String>['reset-password']),
        );
      });

      test('keeps every route name', () {
        expect(
          {
            for (final route in _allRoutes(authRoutes()))
              route.path: route.name,
          },
          equals(
            <String, String?>{
              '/welcome': 'welcome',
              'create-account': 'create-account',
              'login-options': 'login-options',
              'reset-password': 'reset-password',
              '/import-key': 'import-key',
              '/nostr-connect': 'nostr-connect',
              '/secure-account': 'secure-account',
              '/verify-email': 'verify-email',
              // The deep link has no name: it only rewrites to the nested one.
              '/reset-password': null,
            },
          ),
        );
      });

      test('gives the reset-password deep link no name', () {
        final deepLink = authRoutes().whereType<GoRoute>().singleWhere(
          (route) => route.path == '/reset-password',
        );

        expect(deepLink.name, isNull);
      });

      test('keeps the screen constants on the literal values', () {
        expect(WelcomeScreen.path, equals('/welcome'));
        expect(
          WelcomeScreen.createAccountPath,
          equals('/welcome/create-account'),
        );
        expect(
          WelcomeScreen.loginOptionsPath,
          equals('/welcome/login-options'),
        );
        expect(
          WelcomeScreen.resetPasswordPath,
          equals('/welcome/login-options/reset-password'),
        );
        expect(ResetPasswordScreen.path, equals('/reset-password'));
        expect(KeyImportScreen.path, equals('/import-key'));
        expect(NostrConnectScreen.path, equals('/nostr-connect'));
        expect(SecureAccountScreen.path, equals('/secure-account'));
        expect(EmailVerificationScreen.path, equals('/verify-email'));
      });
    });

    group('locations', () {
      test('every route keeps its literal path', () {
        expect(const WelcomeRouteData().location, equals('/welcome'));
        expect(
          const CreateAccountRouteData().location,
          equals('/welcome/create-account'),
        );
        expect(
          const LoginOptionsRouteData().location,
          equals('/welcome/login-options'),
        );
        expect(
          const ResetPasswordRouteData().location,
          equals('/welcome/login-options/reset-password'),
        );
        expect(const KeyImportRouteData().location, equals('/import-key'));
        expect(
          const NostrConnectRouteData().location,
          equals('/nostr-connect'),
        );
        expect(
          const SecureAccountRouteData().location,
          equals('/secure-account'),
        );
        expect(
          const ResetPasswordDeepLinkRouteData().location,
          equals('/reset-password'),
        );
        expect(
          const EmailVerificationRouteData().location,
          equals('/verify-email'),
        );
      });

      test('the paths match the screens and RoutePaths', () {
        expect(const WelcomeRouteData().location, equals(WelcomeScreen.path));
        expect(
          const CreateAccountRouteData().location,
          equals(WelcomeScreen.createAccountPath),
        );
        expect(
          const LoginOptionsRouteData().location,
          equals(RoutePaths.welcomeLoginOptions),
        );
        expect(
          const ResetPasswordRouteData().location,
          equals(RoutePaths.welcomeResetPassword),
        );
        expect(
          const KeyImportRouteData().location,
          equals(RoutePaths.keyImport),
        );
        expect(
          const NostrConnectRouteData().location,
          equals(RoutePaths.nostrConnect),
        );
        expect(
          const SecureAccountRouteData().location,
          equals(RoutePaths.secureAccount),
        );
        expect(
          const ResetPasswordDeepLinkRouteData().location,
          equals(RoutePaths.resetPassword),
        );
        expect(
          const EmailVerificationRouteData().location,
          equals(RoutePaths.emailVerification),
        );
      });

      test('welcome keeps the selectedPubkey query key', () {
        expect(
          const WelcomeRouteData(selectedPubkey: syntheticTestPubkey).location,
          equals('/welcome?selectedPubkey=$syntheticTestPubkey'),
        );
        expect(
          const WelcomeRouteData(selectedPubkey: syntheticTestPubkey).location,
          equals(WelcomeScreen.pathWithSelectedPubkey(syntheticTestPubkey)),
        );
      });

      test('sign in keeps the email and error query keys', () {
        expect(
          const LoginOptionsRouteData(
            email: 'person@example.com',
            error: 'Nope',
          ).location,
          equals(
            '/welcome/login-options?email=person%40example.com&error=Nope',
          ),
        );
        expect(
          const LoginOptionsRouteData(email: 'person@example.com').location,
          equals('/welcome/login-options?email=person%40example.com'),
        );
        expect(
          const LoginOptionsRouteData(error: 'Nope').location,
          equals('/welcome/login-options?error=Nope'),
        );
      });

      test('sign in matches the recovery builder for the same values', () {
        const error = 'This email is already registered. Please sign in.';

        expect(
          const LoginOptionsRouteData(
            email: 'person+tag@example.com',
            error: error,
          ).location,
          equals(
            WelcomeScreen.loginOptionsPathWithRecovery(
              email: 'person+tag@example.com',
              error: error,
            ),
          ),
        );
      });

      test('reset password keeps the token and email query keys', () {
        expect(
          const ResetPasswordRouteData(
            token: 'T',
            email: 'u@x.com',
          ).location,
          equals(
            '/welcome/login-options/reset-password?token=T&email=u%40x.com',
          ),
        );
      });

      // The reset-link listener and the deep-link redirect still build this
      // location by hand, so the typed route has to agree with both.
      for (final (token, email) in [
        ('T', 'u@x.com'),
        ('a+b/c=', 'a+b@x.com'),
        ('100%fun', null),
        ('t', ''),
      ]) {
        test('reset password matches the deep-link rewrite for "$token"', () {
          final rewritten = rewriteResetPasswordDeepLink(
            Uri(
              path: RoutePaths.resetPassword,
              queryParameters: {'token': token, 'email': ?email},
            ),
          );

          expect(
            ResetPasswordRouteData(
              token: token,
              email: (email ?? '').isEmpty ? null : email,
            ).location,
            equals(rewritten),
          );
        });
      }

      test('verify email keeps the token flow query key', () {
        expect(
          const EmailVerificationRouteData(token: 'xyz').location,
          equals('/verify-email?token=xyz'),
        );
      });

      test('verify email keeps the polling flow query keys', () {
        expect(
          const EmailVerificationRouteData(
            deviceCode: 'dc',
            verifier: 'vf',
            email: 'u@x.com',
          ).location,
          equals('/verify-email?deviceCode=dc&verifier=vf&email=u%40x.com'),
        );
      });

      test('verify email keeps the restored query key', () {
        expect(
          const EmailVerificationRouteData(
            email: 'u@x.com',
            restored: 'true',
          ).location,
          equals('/verify-email?email=u%40x.com&restored=true'),
        );
      });

      test('verify email matches the restore location for an email', () {
        for (final email in ['u@x.com', 'a+b@x.com', 'a b@x.com']) {
          expect(
            EmailVerificationRouteData(email: email, restored: 'true').location,
            equals(pendingEmailVerificationLocation(email: email)),
            reason: email,
          );
        }
      });

      // create-account and sign-in navigate with a hand-built string today;
      // the typed route must decode to the same parameters.
      test('verify email decodes to what the polling navigation sent', () {
        const deviceCode = 'device-code-123';
        const verifier = 'verifier_ABC-xyz.~';
        const email = 'a+b@example.com';
        final handBuilt = Uri.parse(
          '${EmailVerificationScreen.path}'
          '?deviceCode=$deviceCode'
          '&verifier=$verifier'
          '&email=${Uri.encodeComponent(email)}',
        );

        final typed = Uri.parse(
          const EmailVerificationRouteData(
            deviceCode: deviceCode,
            verifier: verifier,
            email: email,
          ).location,
        );

        expect(typed.path, equals(handBuilt.path));
        expect(typed.queryParameters, equals(handBuilt.queryParameters));
      });
    });

    group('builders', () {
      testWidgets('welcome reads the pre-selected account', (tester) async {
        await captureContext(tester);

        final screen = build(
          'welcome',
          '/welcome?selectedPubkey=$syntheticTestPubkey',
        );

        expect(
          screen,
          isA<WelcomeScreen>().having(
            (s) => s.initialSelectedPubkeyHex,
            'initialSelectedPubkeyHex',
            syntheticTestPubkey,
          ),
        );
      });

      testWidgets('welcome opens with nobody pre-selected', (tester) async {
        await captureContext(tester);

        final screen = build('welcome', '/welcome');

        expect(
          screen,
          isA<WelcomeScreen>().having(
            (s) => s.initialSelectedPubkeyHex,
            'initialSelectedPubkeyHex',
            isNull,
          ),
        );
      });

      testWidgets('create account builds its screen', (tester) async {
        await captureContext(tester);

        expect(
          build('create-account', '/welcome/create-account'),
          isA<CreateAccountScreen>(),
        );
      });

      testWidgets('sign in reads the recovery email and error', (tester) async {
        await captureContext(tester);

        final screen = build(
          'login-options',
          '/welcome/login-options?email=person%40example.com&error=Nope',
        );

        expect(
          screen,
          isA<LoginOptionsScreen>()
              .having(
                (s) => s.initialEmail,
                'initialEmail',
                'person@example.com',
              )
              .having((s) => s.initialError, 'initialError', 'Nope'),
        );
      });

      testWidgets('sign in opens blank without recovery context', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build('login-options', '/welcome/login-options');

        expect(
          screen,
          isA<LoginOptionsScreen>()
              .having((s) => s.initialEmail, 'initialEmail', isNull)
              .having((s) => s.initialError, 'initialError', isNull),
        );
      });

      testWidgets('reset password reads the token and email', (tester) async {
        await captureContext(tester);

        final screen = build(
          'reset-password',
          '/welcome/login-options/reset-password?token=T&email=u%40x.com',
        );

        expect(
          screen,
          isA<ResetPasswordScreen>()
              .having((s) => s.token, 'token', 'T')
              .having((s) => s.email, 'email', 'u@x.com'),
        );
      });

      testWidgets('reset password falls back to an empty token', (
        tester,
      ) async {
        await captureContext(tester);

        final screen = build(
          'reset-password',
          '/welcome/login-options/reset-password',
        );

        expect(
          screen,
          isA<ResetPasswordScreen>()
              .having((s) => s.token, 'token', isEmpty)
              .having((s) => s.email, 'email', isNull),
        );
      });

      testWidgets('the plain screens build their screens', (tester) async {
        await captureContext(tester);

        expect(build('import-key', '/import-key'), isA<KeyImportScreen>());
        expect(
          build('nostr-connect', '/nostr-connect'),
          isA<NostrConnectScreen>(),
        );
        expect(
          build('secure-account', '/secure-account'),
          isA<SecureAccountScreen>(),
        );
      });

      testWidgets('verify email reads the deep-link token', (tester) async {
        await captureContext(tester);

        final screen = build('verify-email', '/verify-email?token=xyz');

        expect(
          screen,
          isA<EmailVerificationScreen>()
              .having((s) => s.token, 'token', 'xyz')
              .having((s) => s.deviceCode, 'deviceCode', isNull)
              .having((s) => s.verifier, 'verifier', isNull)
              .having((s) => s.email, 'email', isNull)
              .having((s) => s.restored, 'restored', isFalse),
        );
      });

      testWidgets('verify email reads the polling parameters', (tester) async {
        await captureContext(tester);

        final screen = build(
          'verify-email',
          '/verify-email?deviceCode=dc&verifier=vf&email=u%40x.com',
        );

        expect(
          screen,
          isA<EmailVerificationScreen>()
              .having((s) => s.token, 'token', isNull)
              .having((s) => s.deviceCode, 'deviceCode', 'dc')
              .having((s) => s.verifier, 'verifier', 'vf')
              .having((s) => s.email, 'email', 'u@x.com')
              .having((s) => s.restored, 'restored', isFalse),
        );
      });

      // `restored` is the string `true` and nothing else, as it was when the
      // builder compared `params['restored'] == 'true'`.
      for (final (value, restored) in [
        ('true', true),
        ('false', false),
        ('1', false),
        ('TRUE', false),
        ('', false),
      ]) {
        testWidgets('verify email restored="$value" is $restored', (
          tester,
        ) async {
          await captureContext(tester);

          final screen = build(
            'verify-email',
            '/verify-email?email=u%40x.com&restored=$value',
          );

          expect(
            screen,
            isA<EmailVerificationScreen>().having(
              (s) => s.restored,
              'restored',
              restored,
            ),
          );
        });
      }
    });

    group('product analytics UTM capture', () {
      testWidgets('welcome captures the query parameters once', (tester) async {
        await captureContext(tester);

        build('welcome', '/welcome?utm_source=ig&utm_campaign=spring');

        verify(
          () => analytics.captureProductAnalyticsUtm({
            'utm_source': 'ig',
            'utm_campaign': 'spring',
          }),
        ).called(1);
      });

      testWidgets('create account captures the query parameters once', (
        tester,
      ) async {
        await captureContext(tester);

        build(
          'create-account',
          '/welcome/create-account?utm_source=ig&utm_medium=bio',
        );

        verify(
          () => analytics.captureProductAnalyticsUtm({
            'utm_source': 'ig',
            'utm_medium': 'bio',
          }),
        ).called(1);
      });

      testWidgets('captures an empty map when the link has no parameters', (
        tester,
      ) async {
        await captureContext(tester);

        build('welcome', '/welcome');

        verify(() => analytics.captureProductAnalyticsUtm({})).called(1);
      });

      testWidgets('captures again on every build', (tester) async {
        await captureContext(tester);

        build('welcome', '/welcome?utm_source=ig');
        build('welcome', '/welcome?utm_source=ig');

        verify(
          () => analytics.captureProductAnalyticsUtm({'utm_source': 'ig'}),
        ).called(2);
      });

      testWidgets('no other route captures', (tester) async {
        await captureContext(tester);

        build('login-options', '/welcome/login-options?utm_source=ig');
        build('reset-password', '/welcome/login-options/reset-password');
        build('import-key', '/import-key');
        build('nostr-connect', '/nostr-connect');
        build('secure-account', '/secure-account');
        build('verify-email', '/verify-email?utm_source=ig');

        verifyNever(() => analytics.captureProductAnalyticsUtm(any()));
      });
    });

    group('reset-password deep link', () {
      GoRoute deepLink() => authRoutes().whereType<GoRoute>().singleWhere(
        (route) => route.path == '/reset-password',
      );

      testWidgets('rewrites to the nested route keeping token and email', (
        tester,
      ) async {
        await captureContext(tester);

        final location = await deepLink().redirect!(
          context,
          _FakeGoRouterState('/reset-password?token=T&email=u%40x.com'),
        );

        expect(
          location,
          equals(
            '/welcome/login-options/reset-password?token=T&email=u%40x.com',
          ),
        );
      });

      testWidgets('uses the shared rewrite for every link', (tester) async {
        await captureContext(tester);

        for (final link in [
          '/reset-password?token=T',
          '/reset-password?token=T&email=',
          '/reset-password?token=a%2Bb%2Fc&email=a%2Bb%40x.com',
          '/reset-password',
        ]) {
          expect(
            await deepLink().redirect!(context, _FakeGoRouterState(link)),
            equals(rewriteResetPasswordDeepLink(Uri.parse(link))),
            reason: link,
          );
        }
      });

      testWidgets('lands on the nested reset-password screen', (tester) async {
        final router = GoRouter(
          initialLocation: '/reset-password?token=T&email=u%40x.com',
          routes: _stubbed(authRoutes()),
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [analyticsServiceProvider.overrideWithValue(analytics)],
            child: MaterialApp.router(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          router.routeInformationProvider.value.uri.toString(),
          equals(
            '/welcome/login-options/reset-password?token=T&email=u%40x.com',
          ),
        );
        expect(
          _selected,
          isA<ResetPasswordScreen>()
              .having((s) => s.token, 'token', 'T')
              .having((s) => s.email, 'email', 'u@x.com'),
        );
      });
    });

    group('typed navigation', () {
      testWidgets('a cold start opens every route from its location alone', (
        tester,
      ) async {
        final locations = [
          '/welcome',
          '/welcome/create-account',
          '/welcome/login-options',
          '/welcome/login-options/reset-password?token=T',
          '/import-key',
          '/nostr-connect',
          '/secure-account',
          '/verify-email?token=xyz',
        ];
        for (final location in locations) {
          _selected = null;
          final router = GoRouter(
            initialLocation: location,
            routes: _stubbed(authRoutes()),
          );
          addTearDown(router.dispose);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                analyticsServiceProvider.overrideWithValue(analytics),
              ],
              child: MaterialApp.router(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                routerConfig: router,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(_selected, isNotNull, reason: location);
          expect(
            router.routeInformationProvider.value.uri.toString(),
            equals(location),
          );
        }
      });
    });
  });
}
