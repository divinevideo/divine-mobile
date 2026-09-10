// ABOUTME: E2E test for session expired banner "Sign in" navigation flow
// ABOUTME: Verifies tapping "Sign in" on expired session banner reaches login
// ABOUTME: options screen instead of bouncing to home feed.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Session Expired Banner', () {
    final testEmail =
        'banner-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
    const testPassword = 'TestPass123!';

    patrolTest(
      'tapping Sign in navigates to login options instead of bouncing home',
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

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        // ════════════════════════════════════════════════════════════
        // Phase 1: Generate local keys, then register with Keycast
        //          passing the nsec so both share the same pubkey.
        //
        // This mirrors the real "started anonymous → secured account"
        // flow where the user's local nsec is imported into Keycast
        // via headlessRegister(nsec: ...).
        // ════════════════════════════════════════════════════════════

        // 1a. Generate local private key
        final keyStorage = container.read(secureKeyStorageProvider);
        final privateKey = generatePrivateKey();
        final nsec = Nip19.encodePrivateKey(privateKey);
        final keyContainer = await tester.runAsync(
          () => keyStorage.importFromNsec(nsec),
        );
        final localPubkey = keyContainer!.publicKeyHex;
        logPhase('Phase 1a: local keys generated — pubkey=$localPubkey');

        // 1b. Register with Keycast passing the same nsec
        final oauthClient = container.read(oauthClientProvider);
        final result = (await tester.runAsync(
          () => oauthClient.headlessRegister(
            email: testEmail,
            password: testPassword,
            nsec: nsec,
            scope: 'policy:full',
          ),
        ))!;
        final registerResult = result.$1;
        final verifier = result.$2;
        expect(
          registerResult.success,
          isTrue,
          reason: 'headlessRegister with nsec should succeed',
        );
        logPhase(
          'Phase 1b: registered with Keycast — '
          'pubkey=${registerResult.pubkey}',
        );

        // 1c. Verify email + exchange code + sign in
        final verifyToken = await getVerificationToken(testEmail);
        expect(verifyToken, isNotEmpty);
        await callVerifyEmail(verifyToken);

        // Poll until Keycast issues the authorization code
        String? authCode;
        for (var i = 0; i < 30; i++) {
          final poll = await tester.runAsync(
            () => oauthClient.pollForCode(registerResult.deviceCode!),
          );
          if (poll!.code != null) {
            authCode = poll.code;
            break;
          }
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(authCode, isNotNull, reason: 'Polling should return auth code');

        final tokenResponse = await tester.runAsync(
          () => oauthClient.exchangeCode(code: authCode!, verifier: verifier),
        );
        final session = KeycastSession.fromTokenResponse(tokenResponse!);
        await tester.runAsync(
          () => authService.signInWithDivineOAuth(session),
        );
        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
        );
        expect(
          authService.currentPublicKeyHex,
          equals(localPubkey),
          reason: 'OAuth pubkey must match local key pubkey',
        );

        logPhase('Phase 1c: authenticated via OAuth with matching local key');

        // ════════════════════════════════════════════════════════════
        // Phase 2: Kill both tokens to trigger expired session state
        // ════════════════════════════════════════════════════════════

        // 2a. Expire the locally stored session
        final secureStorage = container.read(flutterSecureStorageProvider);
        final storedSession = await KeycastSession.load(secureStorage);
        expect(storedSession, isNotNull);
        final expiredSession = storedSession!.copyWith(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        await expiredSession.save(secureStorage);

        // 2b. Consume all refresh tokens in DB so refresh fails
        final userPubkey = await getUserPubkeyByEmail(testEmail);
        expect(userPubkey, isNotNull);
        final consumedCount = await consumeAllRefreshTokens(userPubkey!);
        logPhase(
          'Phase 2: expired local session, consumed $consumedCount DB tokens',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 3: Reinitialize auth (simulates cold app restart)
        // ════════════════════════════════════════════════════════════

        await authService.initialize();
        await pumpUntilSettled(tester, maxSeconds: 10);

        expect(
          authService.hasExpiredOAuthSession,
          isTrue,
          reason: 'Should detect expired OAuth session after reinit',
        );
        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'Should still be authenticated via local key fallback',
        );

        logPhase(
          'Phase 3 complete: hasExpiredOAuthSession=${authService.hasExpiredOAuthSession}',
        );

        // ════════════════════════════════════════════════════════════
        // Phase 4: Navigate to profile, find banner, tap "Sign in"
        // ════════════════════════════════════════════════════════════

        await tapBottomNavTab(tester, 'profile_tab');
        await pumpUntilSettled(tester);

        final foundBanner = await waitForText(tester, 'Session Expired');
        expect(
          foundBanner,
          isTrue,
          reason: 'Profile should show "Session Expired" banner',
        );

        // Tap the "Sign in" button on the banner
        final signInButton = find.widgetWithText(ElevatedButton, 'Sign in');
        expect(signInButton, findsOneWidget);
        await tester.tap(signInButton);
        await pumpUntilSettled(tester, maxSeconds: 10);

        logPhase('Phase 4: tapped Sign in on expired session banner');

        // ════════════════════════════════════════════════════════════
        // Phase 5: Assert user reaches login options (not bounced home)
        // ════════════════════════════════════════════════════════════

        // Login options screen shows "Forgot password?" and auth fields
        final foundLoginScreen = await waitForText(
          tester,
          'Forgot password?',
          maxSeconds: 10,
        );
        expect(
          foundLoginScreen,
          isTrue,
          reason: 'Should reach login options screen, not be bounced to home',
        );

        logPhase('Phase 5: reached login options screen successfully');

        // ════════════════════════════════════════════════════════════
        // Phase 6: Login with credentials, verify banner disappears
        // ════════════════════════════════════════════════════════════

        await loginWithCredentials(tester, testEmail, testPassword);
        await pumpUntilSettled(tester, maxSeconds: 15);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.hasExpiredOAuthSession,
          isFalse,
          reason: 'Banner flag should clear after successful login',
        );

        logPhase('Phase 6: logged in, expired session banner cleared');

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
