// ABOUTME: Tests for AuthFormScaffold widget
// ABOUTME: Verifies form layout, field rendering, and callback behavior

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_form_scaffold.dart';
import 'package:openvine/widgets/auth_back_button.dart';

void main() {
  group(AuthFormScaffold, () {
    late TextEditingController emailController;
    late TextEditingController passwordController;

    setUp(() {
      emailController = TextEditingController();
      passwordController = TextEditingController();
    });

    tearDown(() {
      emailController.dispose();
      passwordController.dispose();
    });

    Widget createTestWidget({
      String title = 'Create account',
      String? emailError,
      String? passwordError,
      bool enabled = true,
      ValueChanged<String>? onEmailChanged,
      ValueChanged<String>? onPasswordChanged,
      Widget? errorWidget,
      Widget? secondaryButton,
      VoidCallback? onBack,
    }) {
      return MaterialApp.router(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: VineTheme.theme,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => AuthFormScaffold(
                title: title,
                emailController: emailController,
                passwordController: passwordController,
                emailError: emailError,
                passwordError: passwordError,
                enabled: enabled,
                onEmailChanged: onEmailChanged,
                onPasswordChanged: onPasswordChanged,
                errorWidget: errorWidget,
                primaryButton: const SizedBox(
                  key: Key('primary-button'),
                  child: Text('Submit'),
                ),
                secondaryButton: secondaryButton,
                onBack: onBack,
              ),
            ),
          ],
        ),
      );
    }

    group('renders', () {
      testWidgets('displays title', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data == 'Create account' &&
                widget.style?.fontSize == 32,
          ),
          findsOneWidget,
        );
      });

      testWidgets('displays $AuthBackButton', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(AuthBackButton), findsOneWidget);
      });

      testWidgets('displays email field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Email'),
          findsOneWidget,
        );
      });

      testWidgets('displays password field', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(DivineAuthTextField, 'Password'),
          findsOneWidget,
        );
      });

      testWidgets('displays primary button', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('primary-button')), findsOneWidget);
      });

      testWidgets('displays secondary button when provided', (tester) async {
        await tester.pumpWidget(
          createTestWidget(secondaryButton: const Text('Skip for now')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skip for now'), findsOneWidget);
      });

      testWidgets('does not display secondary button when null', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Only the primary button should be present
        expect(find.text('Submit'), findsOneWidget);
      });

      testWidgets('displays error widget when provided', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            errorWidget: const AuthErrorBox(message: 'Auth failed'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Auth failed'), findsOneWidget);
      });

      testWidgets('displays email error', (tester) async {
        await tester.pumpWidget(createTestWidget(emailError: 'Invalid email'));
        await tester.pumpAndSettle();

        expect(find.text('Invalid email'), findsOneWidget);
      });

      testWidgets('displays password error', (tester) async {
        await tester.pumpWidget(createTestWidget(passwordError: 'Too short'));
        await tester.pumpAndSettle();

        expect(find.text('Too short'), findsOneWidget);
      });

      testWidgets('displays dog sticker', (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(SvgPicture), findsAtLeast(1));
      });
    });

    group('interactions', () {
      testWidgets('calls onEmailChanged when email is typed', (tester) async {
        String? changedValue;
        await tester.pumpWidget(
          createTestWidget(onEmailChanged: (value) => changedValue = value),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Email'),
            matching: find.byType(TextField),
          ),
          'user@test.com',
        );

        expect(changedValue, equals('user@test.com'));
      });

      testWidgets('calls onPasswordChanged when password is typed', (
        tester,
      ) async {
        String? changedValue;
        await tester.pumpWidget(
          createTestWidget(onPasswordChanged: (value) => changedValue = value),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.descendant(
            of: find.widgetWithText(DivineAuthTextField, 'Password'),
            matching: find.byType(TextField),
          ),
          'SecurePass123!',
        );

        expect(changedValue, equals('SecurePass123!'));
      });

      testWidgets('calls custom onBack when back button is tapped', (
        tester,
      ) async {
        var backPressed = false;
        await tester.pumpWidget(
          createTestWidget(onBack: () => backPressed = true),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(AuthBackButton));
        expect(backPressed, isTrue);
      });
    });
  });
}
