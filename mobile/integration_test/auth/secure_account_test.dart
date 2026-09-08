// ABOUTME: E2E test for the Secure Account flow (anonymous → registered)
// ABOUTME: Verifies that an anonymous user can add email/password via the
// ABOUTME: Secure Account screen. Exercises the exportNsec() → headlessRegister
// ABOUTME: pipeline that has zero E2E coverage. Covers issue #2092.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Secure Account Flow', () {
    final testEmail =
        'secure-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'anonymous user can secure account with email and password',
      ($) async {
        final tester = $.tester;

        // ── Setup ──
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ════════════════════════════════════════════════════════════
        // Phase 1: Create anonymous account (skip registration)
        // ════════════════════════════════════════════════════════════

        await navigateToCreateAccount(tester);

        // Tap "Use Divine with no backup" to show confirmation sheet
        final skipButton = find.text('Use Divine with no backup');
        expect(skipButton, findsOneWidget);
        await tester.tap(skipButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // Confirm with "Use this device only"
        final confirmSkip = find.text('Use this device only');
        expect(confirmSkip, findsOneWidget);
        await tester.tap(confirmSkip);
        await pumpUntilSettled(tester, maxSeconds: 10);

        // Verify we're authenticated as anonymous
        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.isAnonymous,
          isTrue,
          reason: 'User should be anonymous after skipping registration',
        );

        logPhase('Phase 1 complete: anonymous account created');

        // ════════════════════════════════════════════════════════════
        // Phase 2: Navigate to profile and find Secure Account banner
        // ════════════════════════════════════════════════════════════

        await tapBottomNavTab(tester, 'profile_tab');
        await pumpUntilSettled(tester);

        final foundBanner = await waitForText(
          tester,
          'Secure Your Account',
        );
        expect(
          foundBanner,
          isTrue,
          reason: 'Profile should show "Secure Your Account" banner',
        );

        // Tap "Register" button on the banner
        final registerButton = find.widgetWithText(
          ElevatedButton,
          'Register',
        );
        expect(registerButton, findsOneWidget);
        await tester.tap(registerButton);
        await pumpUntilSettled(tester);

        logPhase('Phase 2 complete: navigated to Secure Account screen');

        // ════════════════════════════════════════════════════════════
        // Phase 3: Fill and submit the secure account form
        // ════════════════════════════════════════════════════════════

        // Verify we're on the Secure Account screen
        final foundTitle = await waitForText(tester, 'Secure account');
        expect(
          foundTitle,
          isTrue,
          reason: 'Should be on the Secure Account screen',
        );

        // Fill email, password, and confirmation
        final textFields = find.byType(DivineAuthTextField);
        expect(
          textFields,
          findsNWidgets(3),
          reason: 'Secure account screen should show email, password, and confirmation',
        );

        await tester.enterText(textFields.at(0), testEmail);
        await tester.pumpAndSettle();
        await tester.enterText(textFields.at(1), testPassword);
        await tester.pumpAndSettle();
        await tester.enterText(textFields.at(2), testPassword);
        await tester.pumpAndSettle();

        // Dismiss keyboard
        await tester.tapAt(const Offset(10, 100));
        await tester.pumpAndSettle();

        // Tap "Secure account" button
        final submitButton = find.widgetWithText(
          DivineButton,
          'Secure account',
        );
        expect(submitButton, findsOneWidget);
        await tester.tap(submitButton);
        await pumpUntilSettled(tester, maxSeconds: 10);

        // ── Assert: no key access error (the #2092 bug) ──
        final hasKeyError = find
            .text('Unable to access your keys. Please try again.')
            .evaluate()
            .isNotEmpty;
        expect(
          hasKeyError,
          isFalse,
          reason:
              'exportNsec() should not fail — this is the #2092 bug if it does',
        );

        logPhase('Phase 3 complete: form submitted, no key access error');

        // ════════════════════════════════════════════════════════════
        // Phase 4: Verify email via keycast API
        // ════════════════════════════════════════════════════════════

        // The secure account screen starts polling via
        // EmailVerificationCubit. We verify the email by calling
        // keycast's verify-email endpoint directly. The cubit's next
        // poll cycle (every 3s) will detect verification and complete
        // the OAuth exchange + sign-in automatically.
        final verifyToken = await getVerificationToken(testEmail);
        expect(verifyToken, isNotEmpty);

        await callVerifyEmail(verifyToken);

        // Wait for the polling cubit to detect verification, exchange
        // tokens, and sign in. This can take up to ~10s (poll interval
        // + exchange + sign-in).
        var secured = false;
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (!authService.isAnonymous && authService.isAuthenticated) {
            secured = true;
            break;
          }
        }

        logPhase(
          'Phase 4 complete: email verified via API '
          '(secured=$secured)',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 5: Assert account is now secured
        // ════════════════════════════════════════════════════════════

        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'User should still be authenticated',
        );
        expect(
          authService.isAnonymous,
          isFalse,
          reason: 'User should no longer be anonymous after securing account',
        );
        expect(
          authService.isRegistered,
          isTrue,
          reason: 'User should be registered (divineOAuth) after securing',
        );

        logPhase('Phase 5 complete: account secured successfully');

        // ── Cleanup ──
        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
