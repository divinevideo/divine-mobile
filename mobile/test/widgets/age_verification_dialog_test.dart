// ABOUTME: Basic widget tests for AgeVerificationDialog
// ABOUTME: Covers element rendering, button interactions, non-dismissibility,
// ABOUTME: VineTheme colors, and dialog constraints.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/age_verification_dialog.dart';

/// Helper to create a test widget with GoRouter for dialog interaction tests.
Widget _createDialogTestApp({ValueChanged<bool?>? onResult}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await AgeVerificationDialog.show(context);
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
  group(AgeVerificationDialog, () {
    testWidgets('should display all required elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AgeVerificationDialog()),
        ),
      );

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
    });

    testWidgets('should return false when No button is pressed', (
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

    testWidgets('should return true when Yes button is pressed', (
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

    testWidgets('should not be dismissible by tapping outside', (tester) async {
      await tester.pumpWidget(_createDialogTestApp());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Try to dismiss by tapping outside
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Dialog should still be visible
      expect(find.text('Age Verification'), findsOneWidget);
    });

    testWidgets('should use $VineTheme colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AgeVerificationDialog()),
        ),
      );

      final icon = tester.widget<DivineIcon>(_divineIcon(DivineIconName.user));
      expect(icon.color, VineTheme.vineGreen);

      final yesButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Yes'),
      );
      expect(
        yesButton.style?.backgroundColor?.resolve({}),
        VineTheme.vineGreen,
      );
    });

    testWidgets('should have proper dialog constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AgeVerificationDialog()),
        ),
      );

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, Colors.black);

      // Find the Container that is a direct child of the Dialog
      final containers = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containers.first);
      expect(container.constraints?.maxWidth, 400);
      expect(container.padding, const EdgeInsets.all(24));
    });
  });
}
