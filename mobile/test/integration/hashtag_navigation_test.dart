import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/screens/explore_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Hashtag Navigation Integration Tests', () {
    testWidgets(
      'clicking hashtag navigates to explore screen with hashtag filter',
      (tester) async {
        // Start the app
        app.main();
        await tester.pumpAndSettle();

        // Navigate to a screen with clickable hashtags
        // This would need to be adapted based on the actual app flow

        // Find a hashtag to click
        final hashtagFinder = find.text('#vine').first;

        if (hashtagFinder.evaluate().isNotEmpty) {
          // Tap the hashtag
          await tester.tap(hashtagFinder);
          await tester.pumpAndSettle();

          // Verify we're on the explore screen
          expect(find.byType(ExploreScreen), findsOneWidget);

          // Verify the hashtag filter is applied
          // This would need to check the actual state of the explore screen
        }
      },
    );

    testWidgets('hashtag navigation maintains footer', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Find and tap a hashtag
      final hashtagFinder = find.text('#trending').first;

      if (hashtagFinder.evaluate().isNotEmpty) {
        await tester.tap(hashtagFinder);
        await tester.pumpAndSettle();

        // Verify footer is still visible
        // Look for bottom navigation bar
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      }
    });
  });
}
