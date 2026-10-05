// ABOUTME: E2E smoke test for the entry to the video creation auth flow
// ABOUTME: Tests app start -> welcome screen -> registration form
// ABOUTME: Runs headlessly on Linux; external relay failures are non-critical.
// ABOUTME: Does not submit registration or require the local Docker stack.

@Tags(['service'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/main.dart' as app;

import '../helpers/navigation_helpers.dart';
import '../helpers/real_integration_test_helper.dart';
import '../helpers/test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video Creation Registration Entry E2E Tests', () {
    testWidgets(
      'App start -> Welcome -> Registration form',
      (tester) async {
        await runWithAppErrorHandlers(() async {
          // Headless Linux CI has the libsecret client library but no Secret
          // Service session. Mock only the unavailable platform channels so the
          // app can exercise its real startup and navigation flow.
          await RealIntegrationTestHelper.setupTestEnvironment();
          addTearDown(RealIntegrationTestHelper.cleanup);

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

          // The helper waits for the create-account semantic identifier,
          // shared by the fresh-install and returning-user welcome layouts.
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
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
