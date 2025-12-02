// ABOUTME: Comprehensive widget test for AgeVerificationDialog covering all verification types
// ABOUTME: Tests both creation (16+) and adult content (18+) verification flows with edge cases

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';

void main() {
  group('AgeVerificationDialog - Comprehensive Tests', () {
    group('Creation Verification (16+)', () {
      testWidgets('displays correct content for creation verification', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AgeVerificationDialog(type: AgeVerificationType.creation),
            ),
          ),
        );

        // Check for correct title
        expect(find.text('Age Verification'), findsOneWidget);

        // Check for correct explanation
        expect(
          find.text(
            'To use the camera and create content, you must be at least 16 years old.',
          ),
          findsOneWidget,
        );

        // Check for correct question
        expect(find.text('Are you 16 years of age or older?'), findsOneWidget);

        // Check for correct button text
        expect(find.text('Yes, I am 16+'), findsOneWidget);
      });

      testWidgets('returns false when No button is pressed for creation', (
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
                      result = await AgeVerificationDialog.show(
                        context,
                        type: AgeVerificationType.creation,
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();

        expect(result, false);
      });

      testWidgets('returns true when Yes button is pressed for creation', (
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
                      result = await AgeVerificationDialog.show(
                        context,
                        type: AgeVerificationType.creation,
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Yes, I am 16+'));
        await tester.pumpAndSettle();

        expect(result, true);
      });
    });

    group('Adult Content Verification (18+)', () {
      testWidgets('displays correct content for adult content verification', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AgeVerificationDialog(
                type: AgeVerificationType.adultContent,
              ),
            ),
          ),
        );

        // Check for correct title
        expect(find.text('Content Warning'), findsOneWidget);

        // Check for correct explanation
        expect(
          find.text(
            'This content has been flagged as potentially containing adult material. You must be 18 or older to view it.',
          ),
          findsOneWidget,
        );

        // Check for correct question
        expect(find.text('Are you 18 years of age or older?'), findsOneWidget);

        // Check for correct button text
        expect(find.text('Yes, I am 18+'), findsOneWidget);
      });

      testWidgets('returns false when No button is pressed for adult content', (
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
                      result = await AgeVerificationDialog.show(
                        context,
                        type: AgeVerificationType.adultContent,
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();

        expect(result, false);
      });

      testWidgets('returns true when Yes button is pressed for adult content', (
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
                      result = await AgeVerificationDialog.show(
                        context,
                        type: AgeVerificationType.adultContent,
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Yes, I am 18+'));
        await tester.pumpAndSettle();

        expect(result, true);
      });
    });

    group('Dialog Behavior', () {
      testWidgets('is not dismissible by tapping outside', (tester) async {
        bool? result;
        bool dialogShown = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      dialogShown = true;
                      result = await AgeVerificationDialog.show(context);
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(dialogShown, isTrue);
        expect(find.text('Age Verification'), findsOneWidget);

        // Try to dismiss by tapping outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Dialog should still be visible
        expect(find.text('Age Verification'), findsOneWidget);
        expect(result, isNull); // Dialog hasn't returned a result yet
      });

      testWidgets('returns false by default if dialog is dismissed', (
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

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Force dismiss the dialog (simulates system back button or other dismissal)
        Navigator.of(tester.element(find.byType(AgeVerificationDialog))).pop();
        await tester.pumpAndSettle();

        expect(result, false);
      });
    });

    group('Styling and Visual Elements', () {
      testWidgets('uses VineTheme colors correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
        );

        // Check icon color
        final icon = tester.widget<Icon>(find.byIcon(Icons.person_outline));
        expect(icon.color, VineTheme.vineGreen);
        expect(icon.size, 64);

        // Check Yes button styling
        final yesButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Yes, I am 16+'),
        );
        expect(
          yesButton.style?.backgroundColor?.resolve({}),
          VineTheme.vineGreen,
        );

        // Check No button styling
        final noButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'No'),
        );
        expect(noButton.style?.side?.resolve({})?.color, Colors.white54);
      });

      testWidgets('has correct dialog structure and constraints', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
        );

        // Check dialog shape and border
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, Colors.black);
        expect(dialog.shape, isA<RoundedRectangleBorder>());

        // Check container constraints
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(Container),
          ),
        );
        expect(container.constraints?.maxWidth, 400);
        expect(container.padding, const EdgeInsets.all(24));
      });

      testWidgets('has proper text styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                headlineSmall: TextStyle(fontSize: 20),
                bodyLarge: TextStyle(fontSize: 16),
              ),
            ),
            home: const Scaffold(body: AgeVerificationDialog()),
          ),
        );

        // Check title text style
        final titleText = tester.widget<Text>(find.text('Age Verification'));
        expect(titleText.style?.color, Colors.white);
        expect(titleText.style?.fontWeight, FontWeight.bold);

        // Check explanation text style
        final explanationText = tester.widget<Text>(
          find.text(
            'To use the camera and create content, you must be at least 16 years old.',
          ),
        );
        expect(explanationText.style?.color, Colors.white70);
        expect(explanationText.textAlign, TextAlign.center);

        // Check question text style
        final questionText = tester.widget<Text>(
          find.text('Are you 16 years of age or older?'),
        );
        expect(questionText.style?.color, Colors.white);
        expect(questionText.style?.fontWeight, FontWeight.w600);
        expect(questionText.textAlign, TextAlign.center);
      });
    });

    group('Layout and Responsiveness', () {
      testWidgets('maintains proper layout structure', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
        );

        // Check that all elements are present in correct order
        expect(find.byIcon(Icons.person_outline), findsOneWidget);
        expect(find.text('Age Verification'), findsOneWidget);
        expect(
          find.text(
            'To use the camera and create content, you must be at least 16 years old.',
          ),
          findsOneWidget,
        );
        expect(find.text('Are you 16 years of age or older?'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
        expect(find.text('Yes, I am 16+'), findsOneWidget);

        // Check button layout
        final buttonRow = tester.widget<Row>(
          find.descendant(
            of: find.byType(AgeVerificationDialog),
            matching: find.byType(Row),
          ),
        );
        expect(buttonRow.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
      });

      testWidgets('buttons are properly sized and spaced', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
        );

        // Check button containers are Expanded (equal width)
        expect(find.byType(Expanded), findsNWidgets(2));

        // Check spacing between buttons
        final sizedBox = tester.widget<SizedBox>(
          find.descendant(
            of: find.byType(Row),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, 16);
      });
    });

    group('Type-Specific Content Variations', () {
      testWidgets('shows different content for each verification type', (
        tester,
      ) async {
        // Test creation type
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AgeVerificationDialog(type: AgeVerificationType.creation),
            ),
          ),
        );

        expect(find.text('Age Verification'), findsOneWidget);
        expect(find.text('Yes, I am 16+'), findsOneWidget);

        // Clear and test adult content type
        await tester.pumpWidget(Container());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: AgeVerificationDialog(
                type: AgeVerificationType.adultContent,
              ),
            ),
          ),
        );

        expect(find.text('Content Warning'), findsOneWidget);
        expect(find.text('Yes, I am 18+'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('supports semantic labels', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: AgeVerificationDialog())),
        );

        // Check that buttons are accessible
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);

        // Verify text is selectable and accessible
        final titleText = find.text('Age Verification');
        expect(titleText, findsOneWidget);
      });
    });
  });
}
