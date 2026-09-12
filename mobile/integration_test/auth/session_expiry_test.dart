// ABOUTME: E2E test for expired OAuth session flow against local Docker stack
// ABOUTME: Registers user, expires tokens in DB, reinitializes auth, asserts
// ABOUTME: expired session UI. Requires: local Docker stack (mise run local_up)
// ABOUTME: Run with: mise run e2e_test

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/providers/deep_link_listeners.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Session Expiry', () {
    final testEmail =
        'expiry-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'shows expired session UI when both access and refresh tokens are dead',
      ($) async {
        final tester = $.tester;
        // ── Setup ──
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

        // Pre-enable semantics so the handle is disposed at the right time.
        // Android instrumentation can enable semantics after the framework
        // records its baseline count, causing a spurious leak assertion.
        final semanticsHandle = tester.ensureSemantics();

        // Launch full app in guarded zone (LOCAL env via --dart-define=DEFAULT_ENV=LOCAL)
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ════════════════════════════════════════════════════════════
        // Phase 1: Register + Verify (establish a valid OAuth session)
        // ════════════════════════════════════════════════════════════

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Should navigate to email verification screen',
        );

        // Extract token from DB and verify via deep link
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

        // Wait for verification to complete and navigate to main app
        final leftVerifyScreen = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerifyScreen, isTrue);
        await pumpUntilSettled(tester);

        // Assert: authenticated with divineOAuth
        final authService = container.read(authServiceProvider);
        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
        );
        expect(authService.hasExpiredOAuthSession, isFalse);

        logPhase('Phase 1 complete: user registered and authenticated');

        // ════════════════════════════════════════════════════════════
        // Phase 2: Kill both tokens (local session + DB refresh tokens)
        // ════════════════════════════════════════════════════════════

        // 2a. Expire the locally stored session (access token is a JWT —
        // expiry is checked locally via KeycastSession.expiresAt, not in DB).
        // Must use the app's FlutterSecureStorage instance (uses
        // encryptedSharedPreferences on Android).
        final secureStorage = container.read(flutterSecureStorageProvider);
        final storedSession = await KeycastSession.load(secureStorage);
        expect(
          storedSession,
          isNotNull,
          reason: 'Should have a stored KeycastSession after auth',
        );
        final expiredSession = storedSession!.copyWith(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await expiredSession.save(secureStorage);
        logPhase(
          'Phase 2a: local session expired '
          '(hasRpcAccess=${expiredSession.hasRpcAccess})',
        );

        // 2b. Consume all refresh tokens in DB so refresh fails
        final userPubkey = await getUserPubkeyByEmail(testEmail);
        expect(
          userPubkey,
          isNotNull,
          reason: 'Should find user pubkey in keycast DB',
        );
        final consumedCount = await consumeAllRefreshTokens(userPubkey!);
        logPhase('Phase 2b: consumed $consumedCount refresh tokens in DB');

        logPhase(
          'Phase 2 complete: local session expired + DB tokens killed',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 3: Reinitialize auth (simulates cold app restart)
        // ════════════════════════════════════════════════════════════

        await authService.initialize();

        // Pump frames to let the UI react to auth state change
        await pumpUntilSettled(tester, maxSeconds: 10);

        logPhase(
          'Phase 3 complete: auth reinitialized — '
          'isAuthenticated=${authService.isAuthenticated}, '
          'hasExpiredOAuthSession=${authService.hasExpiredOAuthSession}, '
          'authState=${authService.authState}',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 4: Assert expired session state
        // ════════════════════════════════════════════════════════════

        // hasExpiredOAuthSession should be true — this drives the UI
        // to show "Session Expired" instead of "Secure Your Account"
        expect(
          authService.hasExpiredOAuthSession,
          isTrue,
          reason:
              'hasExpiredOAuthSession should be true when refresh fails '
              'for a divineOAuth user',
        );

        // For headless OAuth users (keys generated server-side only),
        // there are no local keys to fall back to, so auth goes to
        // unauthenticated. The user must re-login.
        expect(
          authService.authState,
          equals(AuthState.unauthenticated),
          reason:
              'Headless OAuth user with no local keys should be '
              'unauthenticated when both tokens are dead',
        );

        logPhase('Phase 4 complete: expired session state verified');

        // ════════════════════════════════════════════════════════════
        // Phase 5: Assert expired session UI
        // ════════════════════════════════════════════════════════════

        // User should be on the welcome screen since they're
        // unauthenticated. Look for the welcome screen indicators.
        final foundWelcome = await waitForWidget(
          tester,
          find.textContaining('Sign in'),
        );
        expect(
          foundWelcome,
          isTrue,
          reason: 'Unauthenticated user should see welcome screen',
        );

        logPhase('Phase 5 complete: welcome screen displayed');

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
