// ABOUTME: Comprehensive test verifying all app routes are properly configured
// ABOUTME: Tests both grid and feed modes for explore, search, hashtag, and profile routes

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';

void main() {
  group('App Router - All Routes', () {
    testWidgets('/home/:index route works', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/home/0');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/0');

      router.go('/home/5');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/home/5');
    });

    testWidgets('/explore route works (grid mode)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/explore');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/explore');
    });

    testWidgets('/explore/:index route works (feed mode)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/explore/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore/0',
      );

      router.go('/explore/3');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/explore/3',
      );
    });

    testWidgets('/notifications/:index route works', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/notifications/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/notifications/0',
      );

      router.go('/notifications/2');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/notifications/2',
      );
    });

    testWidgets('/profile/:npub/:index route works', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/profile/me/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/profile/me/0',
      );

      router.go('/profile/npub1abc/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/profile/npub1abc/5',
      );
    });

    testWidgets('/search route works (empty search)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/search');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/search');
    });

    testWidgets('/search/:term route works (grid mode)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/search/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin',
      );
    });

    testWidgets('/search/:term/:index route works (feed mode)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/search/bitcoin/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/bitcoin/0',
      );

      router.go('/search/nostr/3');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/search/nostr/3',
      );
    });

    testWidgets('/hashtag/:tag route works (grid mode)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/hashtag/bitcoin');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin',
      );
    });

    testWidgets('/hashtag/:tag/:index route works (feed mode)', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/hashtag/bitcoin/0');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/bitcoin/0',
      );

      router.go('/hashtag/nostr/5');
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.toString(),
        '/hashtag/nostr/5',
      );
    });

    testWidgets('/camera route works', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/camera');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/camera');
    });

    testWidgets('/settings route works', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final router = container.read(goRouterProvider);
      router.go('/settings');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.toString(), '/settings');
    });
  });
}
