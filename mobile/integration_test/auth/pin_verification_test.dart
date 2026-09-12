// ABOUTME: E2E for the in-app PIN fallback + cold-start verification restore
// ABOUTME: Register -> seed PIN -> relaunch app.main (cold start) -> PIN sign-in

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

Finder _closeButton() => find.byWidgetPredicate(
  (w) => w is DivineIcon && w.icon == DivineIconName.x,
);

Finder _pinField() => find.descendant(
  of: find.widgetWithText(
    DivineAuthTextField,
    _en.authVerificationPinFieldLabel,
  ),
  matching: find.byType(TextField),
);

void main() {
  ignorePlatformSemanticsHandle();

  group('Email verification PIN fallback', () {
    // Requires a keycast image with the verify-pin endpoint + the
    // oauth_codes.pin_hash migration (keycast#262). Until ghcr:latest rebuilds
    // with that migration, run against a local image:
    //   KEYCAST_IMAGE=keycast:262-local KEYCAST_PULL_POLICY=never \
    //     mise run e2e_test integration_test/auth/pin_verification_test.dart
    patrolTest(
      'cold reopen restores the verify screen and a seeded PIN signs in',
      ($) async {
        final tester = $.tester;
        final testEmail =
            'pin-restore-${DateTime.now().millisecondsSinceEpoch}'
            '@test.divine.video';
        const password = 'TestPass123!';

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        // 1. First launch + register -> land on the verification screen.
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, password);

        expect(
          await waitForText(tester, _en.authCompleteRegistration),
          isTrue,
          reason: 'Registration should land on the verification screen',
        );

        // 2. Seed a PIN keycast can verify (the real PIN is bcrypt-hashed and
        // never surfaced, so we write a known hash and type the known value).
        await seedKnownPin(testEmail);

        // 3. Simulate a cold start. A literal OS kill ends a patrol test, so
        // re-launching app.main() (local storage persists) is the faithful way
        // to exercise the startup restore path.
        logPhase('Cold start: relaunching app.main()');
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // 4. The app should restore to the verification screen with the PIN
        // field visible and still polling — not Welcome.
        expect(
          await waitForText(tester, _en.authCompleteRegistration),
          isTrue,
          reason: 'Cold start should restore the verification screen',
        );
        expect(
          find.text(_en.authVerificationPinPrompt),
          findsOneWidget,
          reason: 'Restored screen should show the PIN entry field',
        );
        expect(
          find.text(_en.authWaitingForVerification),
          findsOneWidget,
          reason: 'Restored screen should still be polling',
        );

        // 5. The escape hatch must be reachable (register / log in as a
        // different user) without being a dead-end.
        expect(
          _closeButton(),
          findsOneWidget,
          reason:
              'Restored screen must offer a close / start-over escape hatch',
        );

        // 6. Type the seeded PIN and submit -> sign-in completes via the
        // restored deviceCode/verifier (proves the persisted record still
        // exchanges).
        await tester.enterText(_pinField(), knownPin);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(DivineButton, _en.authVerificationPinSubmit),
        );

        expect(
          await waitForTextGone(tester, _en.authCompleteRegistration),
          isTrue,
          reason: 'Submitting the PIN should leave the verification screen',
        );
        await pumpUntilSettled(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        expect(
          container.read(authServiceProvider).isAuthenticated,
          isTrue,
          reason: 'PIN verification should complete sign-in',
        );

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    patrolTest(
      'escape hatch on the restored screen clears the record and exits to '
      'Welcome',
      ($) async {
        final tester = $.tester;
        final testEmail =
            'pin-escape-${DateTime.now().millisecondsSinceEpoch}'
            '@test.divine.video';
        const password = 'TestPass123!';

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        // Register, then cold-start to land on the restored screen.
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, password);
        expect(await waitForText(tester, _en.authCompleteRegistration), isTrue);

        logPhase('Cold start: relaunching app.main()');
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          await waitForText(tester, _en.authCompleteRegistration),
          isTrue,
          reason: 'Cold start should restore the verification screen',
        );

        // Tap the escape hatch -> back to Welcome.
        await tester.tap(_closeButton());
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(
          await waitForText(tester, _en.authCreateNewAccount),
          isTrue,
          reason: 'Escape hatch should return to the Welcome screen',
        );
        expect(
          find.byType(EmailVerificationScreen),
          findsNothing,
          reason: 'Escape hatch should leave the verification screen',
        );

        // The record must be cleared: a second cold start must NOT restore.
        logPhase('Cold start 2: should NOT restore (record cleared)');
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(
          await waitForText(tester, _en.authCreateNewAccount),
          isTrue,
          reason: 'Cleared record means the second cold start stays on Welcome',
        );
        expect(
          find.text(_en.authCompleteRegistration),
          findsNothing,
          reason: 'Cleared record must not restore the verification screen',
        );

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
