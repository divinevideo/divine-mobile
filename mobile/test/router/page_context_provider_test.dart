// ABOUTME: Tests for derived page context provider
// ABOUTME: Verifies route location is parsed into structured context

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('Page Context Provider', () {
    testWidgets('parses home route from router location', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build widget tree with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Wait for initial render
      await tester.pumpAndSettle();

      // Access the context via AsyncValue
      final contextAsync = container.read(pageContextProvider);
      final context = contextAsync.value!;

      expect(context.type, RouteType.home);
      expect(context.videoIndex, 0);
    });

    testWidgets('updates context when router navigates', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build widget tree
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Initial state - home
      await tester.pumpAndSettle();
      var contextAsync = container.read(pageContextProvider);
      expect(contextAsync.hasValue, true);
      expect(contextAsync.value!.type, RouteType.home);
      expect(contextAsync.value!.videoIndex, 0);

      // Navigate to explore
      container.read(goRouterProvider).go('/explore/3');
      await tester.pumpAndSettle();

      // Context should update
      contextAsync = container.read(pageContextProvider);
      expect(contextAsync.value!.type, RouteType.explore);
      expect(contextAsync.value!.videoIndex, 3);

      // Navigate to profile
      container.read(goRouterProvider).go('/profile/npub1test/7');
      await tester.pumpAndSettle();

      // Context should update again
      contextAsync = container.read(pageContextProvider);
      expect(contextAsync.value!.type, RouteType.profile);
      expect(contextAsync.value!.npub, 'npub1test');
      expect(contextAsync.value!.videoIndex, 7);
    });

    testWidgets('parses hashtag route correctly', (tester) async {
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

      // Navigate to hashtag
      container.read(goRouterProvider).go('/hashtag/bitcoin/2');
      await tester.pumpAndSettle();

      final contextAsync = container.read(pageContextProvider);
      final context = contextAsync.value!;
      expect(context.type, RouteType.hashtag);
      expect(context.hashtag, 'bitcoin');
      expect(context.videoIndex, 2);
    });

    testWidgets('parses camera route correctly', (tester) async {
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

      // Navigate to camera
      container.read(goRouterProvider).go('/camera');
      await tester.pumpAndSettle();

      final contextAsync = container.read(pageContextProvider);
      final context = contextAsync.value!;
      expect(context.type, RouteType.camera);
      expect(context.videoIndex, isNull);
    });

    testWidgets('parses settings route correctly', (tester) async {
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

      // Navigate to settings
      container.read(goRouterProvider).go('/settings');
      await tester.pumpAndSettle();

      final contextAsync = container.read(pageContextProvider);
      final context = contextAsync.value!;
      expect(context.type, RouteType.settings);
      expect(context.videoIndex, isNull);
    });
  });
}
