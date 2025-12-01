// ABOUTME: Test for search navigation integration
// ABOUTME: Verifies search route and navigation helpers work correctly

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';

void main() {
  group('Search Navigation', () {
    testWidgets('pushSearch() navigates to search screen', (tester) async {
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
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap search button in app bar
      final searchButton = find.byTooltip('Search');
      expect(searchButton, findsOneWidget);

      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Verify we're on the search screen
      expect(find.byType(SearchScreenPure), findsOneWidget);
    });

    testWidgets('Search screen has search bar and tabs', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: SearchScreenPure())),
      );

      await tester.pumpAndSettle();

      // Verify search bar exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search videos, users, hashtags...'), findsOneWidget);

      // Verify tabs exist
      expect(find.text('Videos (0)'), findsOneWidget);
      expect(find.text('Users (0)'), findsOneWidget);
      expect(find.text('Hashtags (0)'), findsOneWidget);
    });

    testWidgets('Back button returns from search screen', (tester) async {
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
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to search
      final searchButton = find.byTooltip('Search');
      await tester.tap(searchButton);
      await tester.pumpAndSettle();

      // Verify we're on search screen
      expect(find.byType(SearchScreenPure), findsOneWidget);

      // Tap back button
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we're back on home screen
      expect(find.byType(SearchScreenPure), findsNothing);
    });
  });
}
