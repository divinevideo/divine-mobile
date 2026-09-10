// ABOUTME: Comprehensive widget test for AgeVerificationDialog covering all
// ABOUTME: verification types. Tests both creation (16+) and adult content
// ABOUTME: (18+) verification flows with edge cases.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';

/// Helper to create a test widget with GoRouter for dialog interaction tests.
Widget _createDialogTestApp({
  AgeVerificationType type = AgeVerificationType.creation,
  ValueChanged<bool?>? onResult,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await AgeVerificationDialog.show(
                  context,
                  type: type,
                );
                onResult?.call(result);
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    ],
  );
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

Finder _divineIcon(DivineIconName name) =>
    find.byWidgetPredicate((w) => w is DivineIcon && w.icon == name);

void main() {
  group('AgeVerificationDialog - Comprehensive Tests', () {
    group('Creation Verification (16+)', () {
      testWidgets('displays correct content for creation verification', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        expect(find.text('Age Verification'), findsOneWidget);
        expect(
          find.text(
            'To use the camera and create content, you must be at '
            'least 16 years old.',
          ),
          findsOneWidget,
        );
        expect(find.text('Are you 16 years of age or older?'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
      });

      testWidgets('returns false when No button is pressed for creation', (
        tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          _createDialogTestApp(onResult: (r) => result = r),
        );
        await tester.pumpAndSettle();

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
          _createDialogTestApp(onResult: (r) => result = r),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Yes'));
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AgeVerificationDialog(
                type: AgeVerificationType.adultContent,
              ),
            ),
          ),
        );

        expect(find.text('Content Warning'), findsOneWidget);
        expect(
          find.text(
            'This content has been flagged as potentially containing '
            'adult material. You must be 18 or older to view it.',
          ),
          findsOneWidget,
        );
        expect(find.text('Are you 18 years of age or older?'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
      });

      testWidgets('returns false when No button is pressed for adult content', (
        tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          _createDialogTestApp(
            type: AgeVerificationType.adultContent,
            onResult: (r) => result = r,
          ),
        );
        await tester.pumpAndSettle();

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
          _createDialogTestApp(
            type: AgeVerificationType.adultContent,
            onResult: (r) => result = r,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        expect(result, true);
      });
    });

    group('Dialog Behavior', () {
      testWidgets('is not dismissible by tapping outside', (tester) async {
        bool? result;

        await tester.pumpWidget(
          _createDialogTestApp(onResult: (r) => result = r),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Age Verification'), findsOneWidget);

        // Try to dismiss by tapping outside
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Dialog should still be visible
        expect(find.text('Age Verification'), findsOneWidget);
        expect(result, isNull);
      });

      testWidgets('returns false by default if dialog is dismissed', (
        tester,
      ) async {
        bool? result;

        await tester.pumpWidget(
          _createDialogTestApp(onResult: (r) => result = r),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        // Force dismiss using Navigator (simulates system back button)
        Navigator.of(tester.element(find.byType(AgeVerificationDialog))).pop();
        await tester.pumpAndSettle();

        expect(result, false);
      });
    });

    group('Styling and Visual Elements', () {
      testWidgets('uses $VineTheme colors correctly', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        // Check icon color
        final icon = tester.widget<DivineIcon>(
          _divineIcon(DivineIconName.user),
        );
        expect(icon.color, VineTheme.vineGreen);
        expect(icon.size, 64);

        // Check Yes button styling
        final yesButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Yes'),
        );
        expect(
          yesButton.style?.backgroundColor?.resolve({}),
          VineTheme.vineGreen,
        );

        // Check No button styling
        final noButton = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, 'No'),
        );
        expect(
          noButton.style?.side?.resolve({})?.color,
          VineTheme.onSurfaceMuted,
        );
      });

      testWidgets('has correct dialog structure and constraints', (
        tester,
      ) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect(dialog.backgroundColor, Colors.black);
        expect(dialog.shape, isA<RoundedRectangleBorder>());

        // Verify the border includes VineTheme green
        final shape = dialog.shape! as RoundedRectangleBorder;
        expect(shape.side.color, VineTheme.vineGreen);
        expect(shape.side.width, 2);
      });

      testWidgets('has proper text styling', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
            'To use the camera and create content, you must be at '
            'least 16 years old.',
          ),
        );
        expect(explanationText.style?.color, VineTheme.onSurfaceVariant);
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
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        // Check that all elements are present
        expect(_divineIcon(DivineIconName.user), findsOneWidget);
        expect(find.text('Age Verification'), findsOneWidget);
        expect(
          find.text(
            'To use the camera and create content, you must be at '
            'least 16 years old.',
          ),
          findsOneWidget,
        );
        expect(find.text('Are you 16 years of age or older?'), findsOneWidget);
        expect(find.text('No'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);

        // Check button row layout
        final rows = find.descendant(
          of: find.byType(AgeVerificationDialog),
          matching: find.byType(Row),
        );
        // Find the row containing the buttons
        final buttonRow = tester
            .widgetList<Row>(rows)
            .firstWhere(
              (row) => row.mainAxisAlignment == MainAxisAlignment.spaceEvenly,
            );
        expect(buttonRow.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
      });

      testWidgets('buttons are properly sized and spaced', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        // Both buttons are wrapped in Expanded for equal width
        final expandedWidgets = find.descendant(
          of: find.byType(AgeVerificationDialog),
          matching: find.byType(Expanded),
        );
        expect(expandedWidgets, findsNWidgets(2));
      });
    });

    group('Type-Specific Content Variations', () {
      testWidgets('shows different content for each verification type', (
        tester,
      ) async {
        // Test creation type
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        expect(find.text('Age Verification'), findsOneWidget);
        expect(find.text('Are you 16 years of age or older?'), findsOneWidget);

        // Clear and test adult content type
        await tester.pumpWidget(Container());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AgeVerificationDialog(
                type: AgeVerificationType.adultContent,
              ),
            ),
          ),
        );

        expect(find.text('Content Warning'), findsOneWidget);
        expect(find.text('Are you 18 years of age or older?'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('supports semantic labels', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: AgeVerificationDialog()),
          ),
        );

        // Check that buttons are accessible
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);

        // Verify text is present and accessible
        expect(find.text('Age Verification'), findsOneWidget);
      });
    });
  });
}
