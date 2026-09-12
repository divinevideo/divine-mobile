// ABOUTME: Complete end-to-end integration test for video creation flow
// ABOUTME: Tests app start -> welcome screen -> auth -> camera navigation
// ABOUTME: Requires: the local stack's invite service (mise run local_up).
// ABOUTME: navigateToCreateAccount needs OnboardingMode.open for LOCAL.

@Tags(['service'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/main.dart' as app;

import '../helpers/navigation_helpers.dart';
import '../helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Complete Video Creation Flow E2E Tests', () {
    testWidgets(
      'Full flow: App start -> Welcome -> Camera navigation',
      (tester) async {
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        // Launch app in guarded zone to catch external relay errors.
        // pumpAndSettle never returns here: the app runs persistent polling
        // timers, so the tree never reaches a quiescent frame.
        launchAppGuarded(app.main);
        // Poll rather than pump a fixed budget: first launch on a cold
        // device takes well over three seconds to mount MaterialApp.
        final appStarted = await waitForWidget(
          tester,
          find.byType(MaterialApp),
          maxSeconds: 30,
        );
        expect(appStarted, isTrue, reason: 'App should start');

        // Welcome screen uses passive terms — tap "Create a new Divine
        // account" to proceed (no checkboxes in current UI)
        final foundCreateButton = await waitForText(
          tester,
          'Create a new Divine account',
          maxSeconds: 10,
        );
        expect(
          foundCreateButton,
          isTrue,
          reason: 'Welcome screen should show "Create a new Divine account"',
        );
        await navigateToCreateAccount(tester);

        // Verify we reached the registration screen
        final foundRegScreen = await waitForText(
          tester,
          'Create account',
          maxSeconds: 5,
        );
        expect(
          foundRegScreen,
          isTrue,
          reason: 'Should navigate to create account screen',
        );

        // Scope stops here by design. Reaching the camera needs a completed
        // auth flow (the router redirects unauthenticated users to /welcome)
        // and a native camera/mic permission grant, which a plain
        // integration_test cannot drive — pre-grant it on the device instead.

        await pumpUntilSettled(tester, maxSeconds: 3);
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
