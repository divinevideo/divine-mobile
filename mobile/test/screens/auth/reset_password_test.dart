// ABOUTME: Tests for ResetPasswordScreen autofill integration
// ABOUTME: Verifies AutofillGroup wrapping, newPassword hint, and
// ABOUTME: finishAutofillContext call on successful password reset.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/reset_password.dart';

import '../../../integration_test/helpers/navigation_helpers.dart';
import '../../helpers/autofill_context_mock.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  group(ResetPasswordScreen, () {
    late _MockKeycastOAuth mockOAuth;

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
    });

    Widget buildTestWidget({String? email}) {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          oauthClientProvider.overrideWithValue(mockOAuth),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ResetPasswordScreen(
            token: 'test-token-abc123',
            email: email,
          ),
        ),
      );
    }

    group('autofill', () {
      testWidgets('password field has AutofillHints.newPassword', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // DivineAuthTextField forwards autofillHints to the underlying
        // TextField. Find the TextField whose autofillHints contains
        // AutofillHints.newPassword.
        final matchingField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              (widget.autofillHints?.contains(AutofillHints.newPassword) ??
                  false),
        );

        expect(matchingField, findsNWidgets(2));
      });

      testWidgets('renders confirm password field', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Confirm new password'),
          findsOneWidget,
        );
      });

      testWidgets('wraps form in $AutofillGroup', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AutofillGroup), findsOneWidget);
      });

      testWidgets(
        'renders read-only email field with AutofillHints.username when '
        'email param present',
        (tester) async {
          const email = 'user@example.com';

          await tester.pumpWidget(buildTestWidget(email: email));
          await tester.pumpAndSettle();

          final usernameField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                (widget.autofillHints?.contains(AutofillHints.username) ??
                    false),
          );

          expect(usernameField, findsOneWidget);
          final textField = tester.widget<TextField>(usernameField);
          expect(textField.readOnly, isTrue);
          expect(textField.controller?.text, equals(email));
        },
      );

      testWidgets(
        'omits email field when email param is null',
        (tester) async {
          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();

          final usernameField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                (widget.autofillHints?.contains(AutofillHints.username) ??
                    false),
          );

          expect(usernameField, findsNothing);
        },
      );

      testWidgets(
        'omits email field when email param is empty string',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(email: ''));
          await tester.pumpAndSettle();

          final usernameField = find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                (widget.autofillHints?.contains(AutofillHints.username) ??
                    false),
          );

          expect(usernameField, findsNothing);
        },
      );

      testWidgets(
        'reset password helper fills confirmation field before submit',
        (tester) async {
          when(
            () => mockOAuth.resetPassword(
              token: any(named: 'token'),
              newPassword: any(named: 'newPassword'),
            ),
          ).thenAnswer(
            (_) async => ResetPasswordResult(success: true),
          );

          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();

          await enterResetPassword(tester, 'NewSecure123!');
          await tester.tap(
            find.widgetWithText(DivineButton, 'Update password'),
          );
          await tester.pump();

          verify(
            () => mockOAuth.resetPassword(
              token: 'test-token-abc123',
              newPassword: 'NewSecure123!',
            ),
          ).called(1);
        },
      );

      testWidgets(
        'calls TextInput.finishAutofillContext on successful reset',
        (tester) async {
          final recorder = AutofillContextRecorder.install();

          when(
            () => mockOAuth.resetPassword(
              token: any(named: 'token'),
              newPassword: any(named: 'newPassword'),
            ),
          ).thenAnswer(
            (_) async => ResetPasswordResult(success: true),
          );

          await tester.pumpWidget(buildTestWidget());
          await tester.pumpAndSettle();

          // Enter a valid password (>= 8 characters).
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(DivineAuthTextField, 'New Password'),
              matching: find.byType(TextField),
            ),
            'NewSecure123!',
          );
          await tester.enterText(
            find.descendant(
              of: find.widgetWithText(
                DivineAuthTextField,
                'Confirm new password',
              ),
              matching: find.byType(TextField),
            ),
            'NewSecure123!',
          );

          await tester.tap(
            find.widgetWithText(DivineButton, 'Update password'),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(recorder.didFinishAutofillContext, isTrue);
        },
      );

      testWidgets('blocks password mismatch before reset request', (
        tester,
      ) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'New Password'),
            matching: find.byType(TextField),
          ),
          'NewSecure123!',
        );
        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(
              DivineAuthTextField,
              'Confirm new password',
            ),
            matching: find.byType(TextField),
          ),
          'DifferentPass123!',
        );

        await tester.tap(find.widgetWithText(DivineButton, 'Update password'));
        await tester.pumpAndSettle();

        expect(find.text("Passwords don't match"), findsOneWidget);
        verifyNever(
          () => mockOAuth.resetPassword(
            token: any(named: 'token'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      });
    });
  });
}
