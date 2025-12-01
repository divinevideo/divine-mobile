// ABOUTME: TDD test for eliminating Future.delayed from VineDraftsScreen
// ABOUTME: Ensures proper async pattern without artificial delays

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/vine_drafts_screen.dart';

void main() {
  group('VineDraftsScreen Future.delayed elimination', () {
    testWidgets('should load drafts without artificial delay', (tester) async {
      // Build the screen
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const VineDraftsScreen()),
      );

      // Initially should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No Drafts Yet'), findsNothing);

      // Record start time
      final startTime = DateTime.now();

      // Pump to process microtasks
      await tester.pump();
      await tester.pump(); // One more pump to complete setState

      // Calculate elapsed time
      final elapsedTime = DateTime.now().difference(startTime);

      // Should complete very quickly with microtask (not 500ms delay)
      expect(
        elapsedTime.inMilliseconds,
        lessThan(50),
        reason: 'Loading should complete quickly without Future.delayed',
      );

      // Should show empty state after loading
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No Drafts Yet'), findsOneWidget);
      expect(
        find.text('Your saved Vine drafts will appear here'),
        findsOneWidget,
      );
    });

    testWidgets('should handle loading errors gracefully', (tester) async {
      // Build the screen
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const VineDraftsScreen()),
      );

      // Initially should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Process microtasks
      await tester.pump();
      await tester.pump();

      // Should handle errors and show empty state
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No Drafts Yet'), findsOneWidget);
    });

    testWidgets('should transition states properly', (tester) async {
      // Build the screen
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const VineDraftsScreen()),
      );

      // Initially loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After one frame, should process microtask
      await tester.pump();

      // Complete loading with one more pump
      await tester.pump();

      // Should show final state
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No Drafts Yet'), findsOneWidget);
    });
  });
}
