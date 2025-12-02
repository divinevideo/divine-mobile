// ABOUTME: Tests for account deletion dialog widgets
// ABOUTME: Verifies warning dialog and completion dialog behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';

void main() {
  group('DeleteAccountWarningDialog', () {
    testWidgets('should show warning title and content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ Delete Account?'), findsOneWidget);
      expect(find.textContaining('PERMANENT'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);
    });

    testWidgets('should show Cancel and Delete buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete My Account'), findsOneWidget);
    });

    testWidgets('should call onConfirm when Delete button tapped', (
      tester,
    ) async {
      var confirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () => confirmed = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete My Account'));
      await tester.pumpAndSettle();

      expect(confirmed, isTrue);
    });

    testWidgets('should close dialog when Cancel tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountWarningDialog(
                  context: context,
                  onConfirm: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('⚠️ Delete Account?'), findsNothing);
    });
  });

  group('DeleteAccountCompletionDialog', () {
    testWidgets('should show completion message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountCompletionDialog(
                  context: context,
                  onCreateNewAccount: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('✓ Account Deleted'), findsOneWidget);
      expect(
        find.textContaining('deletion request has been sent'),
        findsOneWidget,
      );
    });

    testWidgets('should show Create New Account and Close buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountCompletionDialog(
                  context: context,
                  onCreateNewAccount: () {},
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Account'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('should call onCreateNewAccount when button tapped', (
      tester,
    ) async {
      var createAccountCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteAccountCompletionDialog(
                  context: context,
                  onCreateNewAccount: () => createAccountCalled = true,
                ),
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create New Account'));
      await tester.pumpAndSettle();

      expect(createAccountCalled, isTrue);
    });
  });
}
