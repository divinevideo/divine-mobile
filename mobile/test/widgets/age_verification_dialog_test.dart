import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';

void main() {
  group('AgeVerificationDialog', () {
    testWidgets('should display all required elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
      );

      // Check for icon
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      // Check for title
      expect(find.text('Age Verification'), findsOneWidget);

      // Check for explanation text
      expect(
        find.text(
          'To use the camera and create content, you must be at least 16 years old.',
        ),
        findsOneWidget,
      );

      // Check for question
      expect(find.text('Are you 16 years of age or older?'), findsOneWidget);

      // Check for buttons
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Yes, I am 16+'), findsOneWidget);
    });

    testWidgets('should return false when No button is pressed', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AgeVerificationDialog.show(context);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Press No button
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(result, false);
    });

    testWidgets('should return true when Yes button is pressed', (
      tester,
    ) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await AgeVerificationDialog.show(context);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Press Yes button
      await tester.tap(find.text('Yes, I am 16+'));
      await tester.pumpAndSettle();

      expect(result, true);
    });

    testWidgets('should not be dismissible by tapping outside', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    AgeVerificationDialog.show(context);
                  },
                  child: const Text('Show Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Try to dismiss by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should still be visible
      expect(find.text('Age Verification'), findsOneWidget);
    });

    testWidgets('should use VineTheme colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
      );

      // Check that the icon uses VineTheme green color
      final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline));
      expect(icon.color, VineTheme.vineGreen);

      // Check that Yes button uses VineTheme green background
      final yesButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Yes, I am 16+'),
      );
      final style = yesButton.style;
      expect(style?.backgroundColor?.resolve({}), VineTheme.vineGreen);
    });

    testWidgets('should have proper dialog constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
      );

      // Find the Container with constraints
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(Container).first,
        ),
      );

      expect(container.constraints?.maxWidth, 400);
      expect(container.padding, const EdgeInsets.all(24));
    });
  });
}
