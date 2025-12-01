// ABOUTME: Tests for consolidated routes with optional parameters
// ABOUTME: Verifies single route handles both grid and feed modes without GlobalKey conflicts

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('Consolidated Route Tests', () {
    testWidgets('Navigate /explore → /explore/0 without GlobalKey conflict', (
      tester,
    ) async {
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

      // Start at /explore (grid mode)
      container.read(goRouterProvider).go('/explore');
      await tester.pumpAndSettle();

      // Navigate to /explore/0 (feed mode)
      container.read(goRouterProvider).go('/explore/0');
      await tester.pumpAndSettle();

      // Should complete without GlobalKey conflict
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Navigate /search → /search/bitcoin without GlobalKey conflict',
      (tester) async {
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

        // Start at /search (empty)
        container.read(goRouterProvider).go('/search');
        await tester.pumpAndSettle();

        // Navigate to /search/bitcoin (grid with term)
        container.read(goRouterProvider).go('/search/bitcoin');
        await tester.pumpAndSettle();

        // Should complete without GlobalKey conflict
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Navigate /hashtag/bitcoin → /hashtag/bitcoin/0 without GlobalKey conflict',
      (tester) async {
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

        // Start at /hashtag/bitcoin (grid)
        container.read(goRouterProvider).go('/hashtag/bitcoin');
        await tester.pumpAndSettle();

        // Navigate to /hashtag/bitcoin/0 (feed)
        container.read(goRouterProvider).go('/hashtag/bitcoin/0');
        await tester.pumpAndSettle();

        // Should complete without GlobalKey conflict
        expect(tester.takeException(), isNull);
      },
    );

    test('parseRoute handles optional index for explore', () {
      final gridMode = parseRoute('/explore');
      expect(gridMode.type, RouteType.explore);
      expect(gridMode.videoIndex, null);

      final feedMode = parseRoute('/explore/5');
      expect(feedMode.type, RouteType.explore);
      expect(feedMode.videoIndex, 5);
    });

    test('parseRoute handles optional searchTerm and index for search', () {
      final empty = parseRoute('/search');
      expect(empty.type, RouteType.search);
      expect(empty.searchTerm, null);
      expect(empty.videoIndex, null);

      final withTerm = parseRoute('/search/bitcoin');
      expect(withTerm.type, RouteType.search);
      expect(withTerm.searchTerm, 'bitcoin');
      expect(withTerm.videoIndex, null);

      final withTermAndIndex = parseRoute('/search/bitcoin/3');
      expect(withTermAndIndex.type, RouteType.search);
      expect(withTermAndIndex.searchTerm, 'bitcoin');
      expect(withTermAndIndex.videoIndex, 3);
    });

    test('parseRoute handles optional index for hashtag', () {
      final gridMode = parseRoute('/hashtag/bitcoin');
      expect(gridMode.type, RouteType.hashtag);
      expect(gridMode.hashtag, 'bitcoin');
      expect(gridMode.videoIndex, null);

      final feedMode = parseRoute('/hashtag/bitcoin/2');
      expect(feedMode.type, RouteType.hashtag);
      expect(feedMode.hashtag, 'bitcoin');
      expect(feedMode.videoIndex, 2);
    });
  });
}
