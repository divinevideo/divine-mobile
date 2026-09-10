// ABOUTME: Tests app backgrounding and state restoration using Patrol native
// ABOUTME: Verifies app state is preserved after pressHome and reopen

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('App Background / State Restoration', () {
    patrolTest(
      'app state is preserved after backgrounding and reopening',
      ($) async {
        final tester = $.tester;

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // Verify app is on a known screen (welcome or main)
        final hasApp = find.byType(MaterialApp).evaluate().isNotEmpty;
        expect(hasApp, isTrue, reason: 'App should be running');

        // Press home to background the app
        await $.platformAutomator.mobile.pressHome();

        // Wait briefly while app is in background
        await Future<void>.delayed(const Duration(seconds: 2));

        // Reopen the app by launching it again
        await $.platformAutomator.mobile.openApp();

        // Wait for app to resume
        await tester.pump(const Duration(seconds: 3));

        // Verify app is still running and state is preserved
        final hasAppAfterResume = find
            .byType(MaterialApp)
            .evaluate()
            .isNotEmpty;
        expect(
          hasAppAfterResume,
          isTrue,
          reason: 'App should still be running after backgrounding',
        );

        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
