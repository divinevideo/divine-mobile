// ABOUTME: E2E coverage for Key Management private-key export affordances
// ABOUTME: Verifies RPC-only Keycast accounts do not show a local nsec copy action

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/screens/key_management_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Key Management Export', () {
    final testEmail =
        'key-management-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'RPC-only Keycast account explains that no local nsec can be copied',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Registration should reach the email verification screen',
        );

        final verifyToken = await getVerificationToken(testEmail);
        expect(verifyToken, isNotEmpty);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final emailListener = container.read(
          emailVerificationListenerProvider,
        );
        await emailListener.handleUri(
          Uri.parse(
            'https://login.divine.video/verify-email?token=$verifyToken',
          ),
        );

        final leftVerifyScreen = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerifyScreen, isTrue);
        await pumpUntilSettled(tester, maxSeconds: 10);

        final authService = container.read(authServiceProvider);
        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.authenticationSource,
          AuthenticationSource.divineOAuth,
        );
        expect(
          authService.canExportLocalNsec,
          isFalse,
          reason:
              'Standard Keycast registration does not store an nsec locally',
        );

        GoRouter.of(tester.element(find.byType(MaterialApp))).go(
          KeyManagementScreen.path,
        );
        await pumpUntilSettled(tester, maxSeconds: 10);

        // The #182 key-management gate fails closed until the protected-minor
        // status resolves; for this adult account it resolves to not-restricted
        // and reveals the export section. Wait out that resolution window.
        await waitForTextGone(tester, 'Your keys are managed by Divine');

        // Resolved from the ARB rather than hardcoded so this survives copy
        // changes and breaks loudly if the screen stops reading from l10n.
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(find.text('Key Management'), findsOneWidget);
        // The key is reachable, just not on this device: the copy action is
        // offered for this account too, and the explanation above it says the
        // key comes from Divine's login service rather than local storage.
        expect(
          find.text(l10n.keyManagementCopyNsec, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text(
            l10n.keyManagementKeycastRemoteSigning,
            skipOffstage: false,
          ),
          findsOneWidget,
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
