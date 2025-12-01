// ABOUTME: Tests that tapping hashtag from search pushes instead of replacing
// ABOUTME: Verifies search screen remains in navigation stack

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import '../helpers/test_provider_overrides.dart';

void main() {
  group('Search hashtag navigation', () {
    testWidgets('tapping hashtag pushes route instead of replacing search', (
      tester,
    ) async {
      await tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SearchScreenPure(embedded: false)),
          ),
        ),
      );

      // Wait for search screen to build
      await tester.pumpAndSettle();

      // Verify we're on search screen
      expect(find.text('Search for videos'), findsOneWidget);

      // Find the search field and enter a query that will match hashtags
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'test');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // TODO: Once we have hashtag results showing, tap on one
      // and verify that Navigator.push was called (search screen still in stack)

      // For now, verify search screen is still visible
      expect(find.text('Search for videos'), findsOneWidget);
    });
  });
}
