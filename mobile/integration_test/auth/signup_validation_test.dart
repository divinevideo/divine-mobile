// ABOUTME: E2E coverage for signup credential validation before submission.
// ABOUTME: Requires: local Docker stack running (mise run local_up).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Signup validation', () {
    patrolTest(
      'invalid email and password mismatch stay on create account',
      ($) async {
        final tester = $.tester;
        await runWithAppErrorHandlers(() async {
          launchAppGuarded(app.main);
          await tester.pumpAndSettle(const Duration(seconds: 3));

          await navigateToCreateAccount(tester);

          final fields = find.byType(DivineAuthTextField);
          expect(
            fields,
            findsNWidgets(3),
            reason: 'Create account should show email, password, and confirm fields',
          );

          await tester.enterText(fields.at(0), 'person@gmail..com');
          await tester.enterText(fields.at(1), 'SecurePass123!');
          await tester.enterText(fields.at(2), 'SecurePass123!');
          await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
          await tester.pumpAndSettle();

          expect(find.text('Please enter a valid email'), findsOneWidget);
          expect(find.text('Complete your registration'), findsNothing);

          await tester.enterText(fields.at(0), 'person@example.com');
          await tester.enterText(fields.at(2), 'DifferentPass123!');
          await tester.tap(find.widgetWithText(DivineButton, 'Create account'));
          await tester.pumpAndSettle();

          expect(find.text("Passwords don't match"), findsOneWidget);
          expect(find.text('Complete your registration'), findsNothing);

          drainAsyncErrors(tester);
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
