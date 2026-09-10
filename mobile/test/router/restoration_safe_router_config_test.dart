// ABOUTME: Pins the route-state guard against the go_router codec bug
// ABOUTME: Regression coverage for the #7869 crash

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/router/restoration_safe_router_config.dart';

class _RecordingCrashReporter implements CrashReporter {
  final List<({Object error, String? reason})> recorded = [];

  @override
  void log(String message) {}

  @override
  Future<void> setCustomKey(String key, Object value) async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    recorded.add((error: error, reason: reason));
  }
}

/// A shell-based router in the shape of the app's own: bottom-nav branches
/// wrapped in a `StatefulShellRoute`, with a detail route the user can push.
GoRouter _buildRouter({required bool withRetiredRoute}) {
  return GoRouter(
    initialLocation: '/home',
    routes: <RouteBase>[
      if (withRetiredRoute)
        GoRoute(path: '/retired', builder: (_, _) => const Text('retired')),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => shell,
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/home',
                builder: (_, _) => const Text('home'),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'detail',
                    builder: (_, _) => const Text('detail'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// Produces a route state whose root location the router under test no
/// longer serves, with an imperative push on top of it that still resolves
/// through the shell.
Future<RouteInformation> _savedStateFromRetiredLocation(
  WidgetTester tester,
) async {
  final previousBuild = _buildRouter(withRetiredRoute: true);
  addTearDown(previousBuild.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: previousBuild,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  previousBuild.go('/retired');
  await tester.pumpAndSettle();
  // Fire-and-forget: the future completes when the pushed route pops, and
  // this one never does.
  unawaited(previousBuild.push('/home/detail'));
  await tester.pumpAndSettle();
  final saved = previousBuild.routeInformationParser.restoreRouteInformation(
    previousBuild.routerDelegate.currentConfiguration,
  );
  expect(saved, isNotNull, reason: 'go_router must encode a state to restore');
  expect(saved!.state, isNot(isA<RouteInformationState<Object?>>()));
  return saved;
}

void main() {
  group(RestorationSafeRouteInformationParser, () {
    group('parseRouteInformationWithDependencies', () {
      testWidgets('recovers when the saved root location no longer resolves', (
        tester,
      ) async {
        final saved = await _savedStateFromRetiredLocation(tester);

        final router = _buildRouter(withRetiredRoute: false);
        addTearDown(router.dispose);
        final reporter = _RecordingCrashReporter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: restorationSafeRouterConfig(
              router,
              crashReporter: reporter,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Navigator).first);

        final parser = RestorationSafeRouteInformationParser(
          router.routeInformationParser,
          crashReporter: reporter,
        );
        final matches = await parser.parseRouteInformationWithDependencies(
          saved,
          context,
        );

        expect(matches.uri.path, '/retired');
        expect(reporter.recorded, hasLength(1));
        expect(
          reporter.recorded.single.reason,
          'RestorationSafeRouter.parseRouteInformation',
        );
      });

      testWidgets('the unguarded parser throws on that same state', (
        tester,
      ) async {
        final saved = await _savedStateFromRetiredLocation(tester);

        final router = _buildRouter(withRetiredRoute: false);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(Navigator).first);

        // Pins the defect the guard exists for. When a future go_router
        // release fixes `_createNewMatchUntilIncompatible`, this fails and
        // tells us the guard can go.
        Object? thrown;
        try {
          await router.routeInformationParser
              .parseRouteInformationWithDependencies(saved, context);
        } catch (error) {
          thrown = error;
        }
        expect(thrown, isA<TypeError>());
      });

      testWidgets('leaves an ordinary navigation untouched', (tester) async {
        final router = _buildRouter(withRetiredRoute: false);
        addTearDown(router.dispose);
        final reporter = _RecordingCrashReporter();
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: restorationSafeRouterConfig(
              router,
              crashReporter: reporter,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();

        router.go('/home/detail');
        await tester.pumpAndSettle();

        expect(find.text('detail'), findsOneWidget);
        expect(reporter.recorded, isEmpty);
      });
    });

    group('restorationSafeRouterConfig', () {
      testWidgets('keeps a router mounted again alive when its state no longer '
          'decodes', (tester) async {
        final saved = await _savedStateFromRetiredLocation(tester);

        final router = _buildRouter(withRetiredRoute: false);
        addTearDown(router.dispose);
        final reporter = _RecordingCrashReporter();
        final config = restorationSafeRouterConfig(
          router,
          crashReporter: reporter,
        );
        Widget app(Key key) => MaterialApp.router(
          key: key,
          routerConfig: config,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
        await tester.pumpWidget(app(const ValueKey(1)));
        await tester.pumpAndSettle();

        // The router reports every location it lands on, so its provider
        // holds an encoded state. A Router mounted again over the same
        // GoRouter decodes it from Router.restoreState — the #7869 stack.
        router.routeInformationProvider.routerReportsNewRouteInformation(saved);
        await tester.pumpWidget(app(const ValueKey(2)));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(reporter.recorded, hasLength(1));
      });
    });

    group('restoreRouteInformation', () {
      testWidgets('delegates encoding unchanged', (tester) async {
        final router = _buildRouter(withRetiredRoute: false);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );
        await tester.pumpAndSettle();

        final configuration = router.routerDelegate.currentConfiguration;
        final parser = RestorationSafeRouteInformationParser(
          router.routeInformationParser,
        );

        expect(
          parser.restoreRouteInformation(configuration)?.uri,
          router.routeInformationParser
              .restoreRouteInformation(configuration)
              ?.uri,
        );
      });
    });
  });
}
