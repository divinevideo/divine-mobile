// ABOUTME: Unit tests for navigation extension helpers (NavX)
// ABOUTME: Tests goSearch() with search terms and video indices

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';

void main() {
  group('NavX.goSearch() - Phase 4 TDD', () {
    testWidgets('goSearch("flutter") navigates to /search/flutter', (
      tester,
    ) async {
      String? capturedRoute;

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => throw UnimplementedError()),
          nostrServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
          videoEventServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          context.goSearch('flutter');
                        },
                        child: const Text('Search Flutter'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/search/:term',
                  builder: (context, state) {
                    capturedRoute = state.uri.toString();
                    return const Scaffold(body: Text('Search Screen'));
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to trigger goSearch('flutter')
      await tester.tap(find.text('Search Flutter'));
      await tester.pumpAndSettle();

      // Verify the route was called with correct path
      expect(capturedRoute, '/search/flutter');
    });

    testWidgets('goSearch("dart", 5) navigates to /search/dart/5', (
      tester,
    ) async {
      String? capturedRoute;

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => throw UnimplementedError()),
          nostrServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
          videoEventServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          context.goSearch('dart', 5);
                        },
                        child: const Text('Search Dart'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/search/:term/:index',
                  builder: (context, state) {
                    capturedRoute = state.uri.toString();
                    return const Scaffold(body: Text('Search Screen'));
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to trigger goSearch('dart', 5)
      await tester.tap(find.text('Search Dart'));
      await tester.pumpAndSettle();

      // Verify the route was called with correct path
      expect(capturedRoute, '/search/dart/5');
    });

    testWidgets('goSearch() with no params navigates to /search', (
      tester,
    ) async {
      String? capturedRoute;

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => throw UnimplementedError()),
          nostrServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
          videoEventServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          context.goSearch();
                        },
                        child: const Text('Search Empty'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/search',
                  builder: (context, state) {
                    capturedRoute = state.uri.toString();
                    return const Scaffold(body: Text('Search Screen'));
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to trigger goSearch()
      await tester.tap(find.text('Search Empty'));
      await tester.pumpAndSettle();

      // Verify the route was called with correct path
      expect(capturedRoute, '/search');
    });

    testWidgets('goSearch(null, 3) navigates to /search/3 (legacy format)', (
      tester,
    ) async {
      String? capturedRoute;

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => throw UnimplementedError()),
          nostrServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
          videoEventServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          context.goSearch(null, 3);
                        },
                        child: const Text('Search Index'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/search/:index',
                  builder: (context, state) {
                    capturedRoute = state.uri.toString();
                    return const Scaffold(body: Text('Search Screen'));
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to trigger goSearch(null, 3)
      await tester.tap(find.text('Search Index'));
      await tester.pumpAndSettle();

      // Verify the route was called with correct path
      expect(capturedRoute, '/search/3');
    });

    testWidgets('goSearch("ethereum", 7) navigates to /search/ethereum/7', (
      tester,
    ) async {
      String? capturedRoute;

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWith((ref) => throw UnimplementedError()),
          nostrServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
          videoEventServiceProvider.overrideWith(
            (ref) => throw UnimplementedError(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => Scaffold(
                    body: Builder(
                      builder: (context) => ElevatedButton(
                        onPressed: () {
                          context.goSearch('ethereum', 7);
                        },
                        child: const Text('Search Ethereum'),
                      ),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/search/:term/:index',
                  builder: (context, state) {
                    capturedRoute = state.uri.toString();
                    return const Scaffold(body: Text('Search Screen'));
                  },
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to trigger goSearch('ethereum', 7)
      await tester.tap(find.text('Search Ethereum'));
      await tester.pumpAndSettle();

      // Verify the route was called with correct path
      expect(capturedRoute, '/search/ethereum/7');
    });
  });
}
