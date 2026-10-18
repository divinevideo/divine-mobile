// ABOUTME: Tests for reactive router location provider
// ABOUTME: Verifies location stream emits when router navigates

import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_pubkeys.dart';

void main() {
  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer(
      overrides: [
        ...getStandardTestOverrides(
          mockAuthService: createMockAuthService(
            authState: AuthState.authenticated,
            currentPublicKeyHex: syntheticTestPubkey,
          ),
        ),
        currentMinorAccountReviewStatusProvider.overrideWith(
          (ref) async => MinorAccountReviewStatus.active(),
        ),
        currentAccountDeletionAttemptProvider.overrideWith((ref) async => null),
      ],
    );
    await container.read(currentMinorAccountReviewStatusProvider.future);
    await container.read(currentAccountDeletionAttemptProvider.future);
    return container;
  }

  group('Router Location Provider', () {
    testWidgets('emits initial location immediately', (tester) async {
      final container = await createContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);

      // Get initial location
      final initial = await queue.next;
      expect(initial, WelcomeScreen.path);

      await queue.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });

    testWidgets('emits new location when router navigates', (tester) async {
      final container = await createContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Listen to the raw stream for deterministic events
      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);

      // 1) Initial location
      final initial = await queue.next;
      expect(initial, WelcomeScreen.path);

      // Use error routes so this provider test does not initialize unrelated
      // app-shell side effects.
      container.read(goRouterProvider).go('/unknown-one');
      await tester.pump();

      final next1 = await queue.next;
      expect(next1, '/unknown-one');

      container.read(goRouterProvider).go('/unknown-two');
      await tester.pump();

      final next2 = await queue.next;
      expect(next2, '/unknown-two');

      await queue.cancel();
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump();
    });

    test('delivers a delegate notification asynchronously, so a router '
        'change during build cannot modify a provider mid-build', () async {
      // GoRouterDelegate is a ChangeNotifier and notifies while the widget
      // tree is building (route redirects run inside the build pipeline). A
      // synchronous controller hands that straight to the listening
      // StreamProvider, which then calls setValue mid-build and throws
      // `Tried to modify a provider while the widget tree was building` into
      // the app zone — and on to Crashlytics — on every cold start.
      final (router, delegate) = _mockRouterAt('/sentinel-location');
      final container = ProviderContainer(
        overrides: [goRouterProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);

      final stream = container.read(routerLocationStreamProvider);
      final locations = <String>[];
      final subscription = stream.listen(locations.add);
      addTearDown(subscription.cancel);
      final listener =
          verify(() => delegate.addListener(captureAny())).captured.single
              as VoidCallback;

      // Drain the buffered initial location so only the delegate-driven
      // emission is under test.
      await pumpEventQueue();
      expect(locations, ['/sentinel-location']);
      locations.clear();

      listener();

      expect(
        locations,
        isEmpty,
        reason:
            'the emission must not be delivered inline: the delegate '
            'notifies during build, and a listening StreamProvider would '
            'update mid-build',
      );

      await pumpEventQueue();
      expect(locations, ['/sentinel-location']);
    });

    test('removes its listener and closes the stream on dispose', () async {
      final (router, delegate) = _mockRouterAt('/sentinel-location');
      final container = ProviderContainer(
        overrides: [goRouterProvider.overrideWithValue(router)],
      );
      addTearDown(container.dispose);

      final stream = container.read(routerLocationStreamProvider);
      final locations = <String>[];
      var isDone = false;
      final subscription = stream.listen(
        locations.add,
        onDone: () => isDone = true,
      );
      addTearDown(subscription.cancel);
      final listener =
          verify(() => delegate.addListener(captureAny())).captured.single
              as VoidCallback;

      await pumpEventQueue();
      expect(locations, ['/sentinel-location']);
      expect(isDone, isFalse);

      // Keep the subscription active so cancellation cannot hide a leaked
      // controller. The router remains alive independently of this container.
      container.dispose();
      verify(() => delegate.removeListener(listener)).called(1);
      await pumpEventQueue();
      expect(isDone, isTrue);
    });

    group('after a redirect the router runs itself', () {
      testWidgets('emits the gate the redirect leads to', (tester) async {
        final gated = ValueNotifier(false);
        addTearDown(gated.dispose);
        final router = _gatedRouter(gated);
        addTearDown(router.dispose);
        final container = await _pumpGatedRouter(tester, router);
        expect(container.read(routerLocationProvider).value, _profile);

        gated.value = true;
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.toString(), _gate);
        expect(container.read(routerLocationProvider).value, _gate);
      });

      testWidgets('emits the page the gate returns to', (tester) async {
        final gated = ValueNotifier(true);
        addTearDown(gated.dispose);
        final router = _gatedRouter(gated);
        addTearDown(router.dispose);
        final container = await _pumpGatedRouter(tester, router);
        expect(container.read(routerLocationProvider).value, _gate);

        gated.value = false;
        await tester.pumpAndSettle();

        expect(router.routeInformationProvider.value.uri.toString(), _profile);
        expect(container.read(routerLocationProvider).value, _profile);
      });
    });

    group('after a push', () {
      testWidgets('emits the pushed location', (tester) async {
        // The app router sets this, so the URL follows imperative pushes.
        final reflected = GoRouter.optionURLReflectsImperativeAPIs;
        GoRouter.optionURLReflectsImperativeAPIs = true;
        addTearDown(
          () => GoRouter.optionURLReflectsImperativeAPIs = reflected,
        );
        final gated = ValueNotifier(false);
        addTearDown(gated.dispose);
        final router = _gatedRouter(gated);
        addTearDown(router.dispose);
        final container = await _pumpGatedRouter(tester, router);
        expect(container.read(routerLocationProvider).value, _profile);

        unawaited(router.push<void>('/details'));
        await tester.pumpAndSettle();

        expect(container.read(routerLocationProvider).value, '/details');
      });
    });
  });
}

const _profile = '/profile/a';
const _gate = '/gate?from=%2Fprofile%2Fa';

/// A router whose redirect sends every route to `/gate` while [gated] is
/// true and back to the `from` location once it is false, re-evaluated
/// through `refreshListenable` the way the app's auth and review gates are.
GoRouter _gatedRouter(ValueNotifier<bool> gated) {
  return GoRouter(
    initialLocation: _profile,
    refreshListenable: gated,
    redirect: (context, state) {
      final atGate = state.matchedLocation == '/gate';
      if (gated.value && !atGate) {
        return '/gate?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (!gated.value && atGate) return state.uri.queryParameters['from'];
      return null;
    },
    routes: [
      GoRoute(path: '/profile/:id', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/gate', builder: (_, _) => const SizedBox()),
      GoRoute(path: '/details', builder: (_, _) => const SizedBox()),
    ],
  );
}

Future<ProviderContainer> _pumpGatedRouter(
  WidgetTester tester,
  GoRouter router,
) async {
  final container = ProviderContainer(
    overrides: [goRouterProvider.overrideWithValue(router)],
  );
  addTearDown(container.dispose);
  container.listen(routerLocationProvider, (_, _) {});
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// A mocked router at [location] whose delegate has no configuration yet, so
/// the stream falls back to the information provider's location.
(GoRouter, GoRouterDelegate) _mockRouterAt(String location) {
  final router = _MockGoRouter();
  final delegate = _MockGoRouterDelegate();
  final parser = _MockGoRouteInformationParser();
  final routeInformation = GoRouteInformationProvider(
    initialLocation: location,
    initialExtra: null,
  );
  addTearDown(routeInformation.dispose);
  when(() => router.routerDelegate).thenReturn(delegate);
  when(() => router.routeInformationProvider).thenReturn(routeInformation);
  when(() => router.routeInformationParser).thenReturn(parser);
  when(() => delegate.currentConfiguration).thenReturn(RouteMatchList.empty);
  when(
    () => parser.restoreRouteInformation(RouteMatchList.empty),
  ).thenReturn(null);
  return (router, delegate);
}

class _MockGoRouter extends Mock implements GoRouter {}

class _MockGoRouterDelegate extends Mock implements GoRouterDelegate {}

class _MockGoRouteInformationParser extends Mock
    implements GoRouteInformationParser {}
