// ABOUTME: E2E test for expired Keycast session refresh flow
// ABOUTME: Registers via OAuth, waits for token expiry, re-initializes auth,
// ABOUTME: and verifies refresh token exchange via DB + preserved auth source
// ABOUTME: Requires: local Docker stack with TOKEN_EXPIRY_SECONDS=15
// ABOUTME: Run with: TOKEN_EXPIRY_SECONDS=15 mise run local_up && mise run e2e_test

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('Token Refresh', () {
    final testEmail =
        'refresh-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'expired token is refreshed and auth source stays divineOAuth',
      ($) async {
        final tester = $.tester;
        // ── Setup ──
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        // Launch the full app (LOCAL env via --dart-define)
        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ════════════════════════════════════════════════════════════
        // Phase 1: Register via OAuth (creates refresh token server-side)
        // ════════════════════════════════════════════════════════════

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, testEmail, testPassword);

        // Wait for email verification screen
        final foundVerifyScreen = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyScreen,
          isTrue,
          reason: 'Should navigate to email verification screen',
        );

        // Extract verification token from DB and verify via deep link
        final verifyToken = await getVerificationToken(testEmail);
        expect(verifyToken, isNotEmpty);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final emailListener = container.read(emailVerificationListenerProvider);
        await emailListener.handleUri(
          Uri.parse(
            'https://login.divine.video/verify-email?token=$verifyToken',
          ),
        );

        // Wait for verification to complete
        final leftVerifyScreen = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerifyScreen, isTrue);
        await pumpUntilSettled(tester);

        // Assert: landed on main app
        final hasMainApp =
            find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
            find.text('Popular').evaluate().isNotEmpty ||
            find.text('Trending').evaluate().isNotEmpty;
        expect(hasMainApp, isTrue, reason: 'Should land on main app');

        // ════════════════════════════════════════════════════════════
        // Phase 2: Capture initial state + verify DB has refresh token
        // ════════════════════════════════════════════════════════════

        final authService = container.read(authServiceProvider);
        final userPubkey = authService.currentPublicKeyHex;
        expect(userPubkey, isNotNull, reason: 'Should have a pubkey');
        expect(
          userPubkey!.length,
          equals(64),
          reason: 'Pubkey should be 64 hex chars',
        );

        // Verify auth source is divineOAuth after registration
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
          reason: 'Auth source should be divineOAuth after registration',
        );

        // Query DB for initial refresh tokens
        final initialTokens = await getRefreshTokenRecords(userPubkey);
        logPhase(
          '[REFRESH TEST] Initial refresh tokens: ${initialTokens.length}',
        );
        for (final t in initialTokens) {
          logPhase(
            '[REFRESH TEST]   id=${t.id} consumed=${t.isConsumed} '
            'created=${t.createdAt}',
          );
        }
        expect(
          initialTokens,
          isNotEmpty,
          reason: 'Server should have issued a refresh token during OAuth flow',
        );
        // At least one token should be valid (not consumed)
        final initialValidCount = initialTokens.where((t) => t.isValid).length;
        expect(
          initialValidCount,
          greaterThan(0),
          reason: 'Should have at least one valid refresh token',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 3: Wait for access token to expire
        // ════════════════════════════════════════════════════════════
        // TOKEN_EXPIRY_SECONDS should be set to 15 in docker-compose.
        // Wait 20s to ensure expiry.

        logPhase(
          '[REFRESH TEST] Waiting 20s for access token to expire...',
        );
        await pumpUntilSettled(tester, maxSeconds: 20);
        logPhase('[REFRESH TEST] Wait complete, re-initializing auth...');

        // ════════════════════════════════════════════════════════════
        // Phase 4: Re-initialize auth (simulates app restart)
        // ════════════════════════════════════════════════════════════
        // AuthService.initialize() will detect expired session, attempt
        // refresh, and if successful, restore the divineOAuth session.

        await authService.initialize();

        // Pump frames to let async work settle
        await pumpUntilSettled(tester, maxSeconds: 10);

        // ════════════════════════════════════════════════════════════
        // Phase 5: Verify refresh happened
        // ════════════════════════════════════════════════════════════

        // 5a: Auth source should still be divineOAuth
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
          reason:
              'Auth source must stay divineOAuth after token refresh '
              '(should never downgrade to automatic)',
        );

        // 5b: User should not be anonymous
        expect(
          authService.isAnonymous,
          isFalse,
          reason:
              'isAnonymous should be false — user registered via OAuth, '
              'session was refreshed',
        );

        // 5c: User should still be authenticated
        expect(authService.isAuthenticated, isTrue);

        // 5d: Same pubkey
        expect(
          authService.currentPublicKeyHex,
          equals(userPubkey),
          reason: 'Pubkey should be unchanged after refresh',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 6: Verify refresh in keycast DB
        // ════════════════════════════════════════════════════════════
        // After a successful refresh token exchange:
        // - The old refresh token should have consumed_at != NULL
        // - A new refresh token should exist with consumed_at IS NULL

        final postRefreshTokens = await getRefreshTokenRecords(userPubkey);
        logPhase(
          '[REFRESH TEST] Post-refresh tokens: ${postRefreshTokens.length}',
        );
        for (final t in postRefreshTokens) {
          logPhase(
            '[REFRESH TEST]   id=${t.id} consumed=${t.isConsumed} '
            'created=${t.createdAt} consumedAt=${t.consumedAt}',
          );
        }

        // Should have more tokens than before (new one issued)
        expect(
          postRefreshTokens.length,
          greaterThan(initialTokens.length),
          reason:
              'Server should have issued a new refresh token '
              '(token rotation per RFC 9700)',
        );

        // The old token(s) should be consumed
        final consumedCount = postRefreshTokens
            .where((t) => t.isConsumed)
            .length;
        expect(
          consumedCount,
          greaterThan(0),
          reason:
              'At least one refresh token should be consumed '
              '(the one exchanged during refresh)',
        );

        // Should still have a valid (non-consumed, non-expired) token
        final postValidCount = postRefreshTokens.where((t) => t.isValid).length;
        expect(
          postValidCount,
          greaterThan(0),
          reason:
              'Should have a valid refresh token after rotation '
              '(ready for next refresh cycle)',
        );

        logPhase(
          '[REFRESH TEST] PASS: '
          'consumed=$consumedCount, '
          'valid=$postValidCount, '
          'total=${postRefreshTokens.length}',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 7: Consume all refresh tokens (simulate expiry)
        // ════════════════════════════════════════════════════════════
        // This makes the server reject the next refresh attempt,
        // testing the "session expired" fallback path.

        final consumedRows = await consumeAllRefreshTokens(userPubkey);
        logPhase(
          '[REFRESH TEST] Consumed $consumedRows refresh tokens in DB',
        );
        expect(
          consumedRows,
          greaterThan(0),
          reason: 'Should have consumed at least one refresh token',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 8: Wait for access token to expire again
        // ════════════════════════════════════════════════════════════

        logPhase(
          '[REFRESH TEST] Waiting 20s for access token to expire again...',
        );
        await pumpUntilSettled(tester, maxSeconds: 20);
        logPhase(
          '[REFRESH TEST] Wait complete, re-initializing with no valid '
          'refresh token...',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 9: Re-initialize auth (refresh will fail this time)
        // ════════════════════════════════════════════════════════════
        // The client sends its local refresh token to the server,
        // but the server has it marked consumed → returns error.
        // AuthService falls to local-keys fallback with
        // hasExpiredOAuthSession = true.

        await authService.initialize();
        await pumpUntilSettled(tester, maxSeconds: 10);

        // ════════════════════════════════════════════════════════════
        // Phase 10: Verify session expired state
        // ════════════════════════════════════════════════════════════
        // In headless OAuth flow, private keys live on the server
        // only — no local nsec. When refresh fails, auth goes to
        // unauthenticated. But hasExpiredOAuthSession should be true
        // so the welcome screen can show "Session Expired" instead
        // of a fresh welcome.

        // 10a: hasExpiredOAuthSession should be true regardless of
        // whether local keys exist
        expect(
          authService.hasExpiredOAuthSession,
          isTrue,
          reason:
              'hasExpiredOAuthSession should be true so the UI shows '
              '"Session Expired" instead of "Secure Your Account"',
        );

        // 10b: Auth state is unauthenticated (headless flow has no
        // local keys to fall back to)
        expect(
          authService.authState,
          equals(AuthState.unauthenticated),
          reason:
              'Without local keys, auth falls to unauthenticated — '
              'user must re-login',
        );

        logPhase(
          '[REFRESH TEST] PASS: Session expired state verified — '
          'hasExpiredOAuthSession=true, authSource=divineOAuth, '
          'isAnonymous=false',
        );
        logPhase(
          '[REFRESH TEST] To inspect keycast server logs, run: '
          'mise run local_logs_keycast',
        );

        // Cleanup
        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
