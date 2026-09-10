// ABOUTME: E2E tests for multi-account switching and identity persistence
// ABOUTME: Covers: OAuth account switch (expired session recovery), nsec import
// ABOUTME: identity not overridden by known-accounts restore on reinitialize
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/invite_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

/// Dismiss the Android notification permission dialog if it appears.
///
/// After authentication the app requests POST_NOTIFICATIONS. This is a
/// native system dialog that blocks Flutter widget interaction.
Future<void> dismissNotificationPermission(PatrolIntegrationTester $) async {
  try {
    final allow = $.platformAutomator.tap(
      Selector(textContains: 'Allow'),
      timeout: const Duration(seconds: 3),
    );
    await allow;
  } catch (_) {
    // Dialog didn't appear — permission already granted or not requested.
  }
}

void main() {
  ignorePlatformSemanticsHandle();

  group('Multi-account switching', () {
    patrolTest(
      'Keycast A → Keycast B → switch back to A succeeds',
      ($) async {
        final tester = $.tester;

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ══════════════════════════════════════════════════════════
        // Phase 1: Register Keycast Account A
        // ══════════════════════════════════════════════════════════

        final emailA =
            'switch-a-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
        const password = 'TestPass123!';

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, emailA, password);

        final foundVerify = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerify, isTrue, reason: 'Should reach verification screen');

        final tokenA = await getVerificationToken(emailA);
        await callVerifyEmail(tokenA);

        final leftVerify = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerify, isTrue, reason: 'Verification should complete');

        await pumpUntilSettled(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        expect(authService.isAuthenticated, isTrue);
        await dismissNotificationPermission($);
        final pubkeyA = authService.currentPublicKeyHex!;
        logPhase('Phase 1: Account A registered — pubkey=$pubkeyA');

        // ══════════════════════════════════════════════════════════
        // Phase 1b: A Keycast email identity gets the same allocation
        //
        // #103 grants the initial allocation on the first authenticated
        // GET /v1/invite-status, regardless of how the identity signs.
        // repro_log1 covers the locally generated key; this covers the
        // Keycast-backed one, where signing goes through the remote
        // signer rather than a local nsec.
        //
        // Requires an invite backend that reports remainingToGenerate.
        // local_stack pins ghcr.io/divinevideo/divine-invite-darshan:e2e,
        // which is only republished on push to that repo's main, so until
        // #103 merges this needs a locally built image:
        //   docker build -f Dockerfile.local \
        //     -t ghcr.io/divinevideo/divine-invite-darshan:e2e .
        // Against an older backend remainingToGenerate is absent,
        // mintableCount falls back to remaining, and this phase fails.
        // ══════════════════════════════════════════════════════════

        final grantedA = await waitForLoadedInviteStatus(tester);
        final grantedStatusA = grantedA.inviteStatus!;

        expect(
          grantedStatusA.canInvite,
          isTrue,
          reason: 'A Keycast identity should be able to invite',
        );
        expect(grantedStatusA.remaining, initialInviteAllocation);
        expect(grantedStatusA.total, initialInviteAllocation);
        expect(
          grantedStatusA.codes,
          isEmpty,
          reason: 'Entitlement is granted without minting any code',
        );
        // Nothing minted yet, so the whole allocation is still generatable.
        expect(grantedStatusA.mintableCount, initialInviteAllocation);

        logPhase(
          'Phase 1b: Account A invite allocation — '
          'remaining=${grantedStatusA.remaining} '
          'mintable=${grantedStatusA.mintableCount} '
          'codes=${grantedStatusA.codes.length}',
        );

        // ══════════════════════════════════════════════════════════
        // Phase 2: Sign out A, register Keycast Account B
        // ══════════════════════════════════════════════════════════

        await tester.runAsync(authService.signOut);
        await pumpUntilSettled(tester);

        logPhase('Phase 2a: Signed out from A');

        final emailB =
            'switch-b-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, emailB, password);

        final foundVerifyB = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(
          foundVerifyB,
          isTrue,
          reason: 'Should reach verification screen for B',
        );

        final tokenB = await getVerificationToken(emailB);
        await callVerifyEmail(tokenB);

        final leftVerifyB = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerifyB, isTrue, reason: 'Verification B should complete');

        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        await dismissNotificationPermission($);
        final pubkeyB = authService.currentPublicKeyHex!;
        expect(pubkeyB, isNot(equals(pubkeyA)));
        logPhase('Phase 2b: Account B registered — pubkey=$pubkeyB');

        // ══════════════════════════════════════════════════════════
        // Phase 3: Sign out B, switch back to A
        // ══════════════════════════════════════════════════════════

        await tester.runAsync(authService.signOut);
        await pumpUntilSettled(tester);

        logPhase('Phase 3a: Signed out from B');

        // This is the flow that fails without our fix: signInForAccount
        // tries to restore A's archived OAuth session, which has an
        // expired access token. Previously it threw; now it should
        // recover via refresh or local key fallback.
        await tester.runAsync(
          () => authService.signInForAccount(
            pubkeyA,
            AuthenticationSource.divineOAuth,
          ),
        );
        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.currentPublicKeyHex,
          equals(pubkeyA),
          reason:
              'After switching back to A, identity should be A '
              '(not B, not crash)',
        );

        logPhase('Phase 3b: Successfully switched back to A');

        // ══════════════════════════════════════════════════════════
        // Phase 4: Verify signing works for A
        // ══════════════════════════════════════════════════════════

        final signedEvent = await tester.runAsync(
          () => authService.createAndSignEvent(
            kind: 1,
            content: 'multi-account switch test',
          ),
        );

        expect(
          signedEvent,
          isNotNull,
          reason: 'Signing should work after switching back to A',
        );
        expect(signedEvent?.pubkey, equals(pubkeyA));

        logPhase('Phase 4: Signing works for A');

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    patrolTest(
      'nsec import B after Keycast A survives reinitialize (#2936)',
      ($) async {
        final tester = $.tester;

        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ══════════════════════════════════════════════════════════
        // Phase 1: Register Keycast Account A
        // ══════════════════════════════════════════════════════════

        final emailA =
            'nsec-a-${DateTime.now().millisecondsSinceEpoch}@test.divine.video';
        const password = 'TestPass123!';

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, emailA, password);

        final foundVerify = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerify, isTrue);

        final tokenA = await getVerificationToken(emailA);
        await callVerifyEmail(tokenA);
        await waitForTextGone(tester, 'Complete your registration');
        await pumpUntilSettled(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        expect(authService.isAuthenticated, isTrue);
        await dismissNotificationPermission($);
        final pubkeyA = authService.currentPublicKeyHex!;
        logPhase('Phase 1: Keycast Account A registered — pubkey=$pubkeyA');

        // ══════════════════════════════════════════════════════════
        // Phase 2: Sign out A, import nsec B
        // ══════════════════════════════════════════════════════════

        final privateKeyB = generatePrivateKey();
        final nsecB = Nip19.encodePrivateKey(privateKeyB);

        await tester.runAsync(authService.signOut);
        await pumpUntilSettled(tester);

        logPhase('Phase 2a: Signed out from A');

        final resultB = await tester.runAsync(
          () => authService.importFromNsec(nsecB),
        );
        expect(resultB!.success, isTrue);
        await tester.runAsync(authService.acceptTerms);
        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        final pubkeyB = authService.currentPublicKeyHex!;
        expect(pubkeyB, isNot(equals(pubkeyA)));

        logPhase('Phase 2b: nsec B imported — pubkey=$pubkeyB');

        // ══════════════════════════════════════════════════════════
        // Phase 3: Reinitialize (simulates app restart)
        //
        // This is the #2936 bug: _tryRestoreFromKnownAccounts may
        // pick Account A (most recently used Keycast account) over
        // Account B (the just-imported nsec) if the restore logic
        // doesn't respect _kLastUsedNpubKey correctly.
        // ══════════════════════════════════════════════════════════

        // Re-initialize auth service (simulates cold start)
        await tester.runAsync(authService.initialize);
        await pumpUntilSettled(tester);

        logPhase(
          'Phase 3: After reinitialize — '
          'pubkey=${authService.currentPublicKeyHex}',
        );

        expect(
          authService.isAuthenticated,
          isTrue,
          reason: 'Should be authenticated after reinitialize',
        );
        expect(
          authService.currentPublicKeyHex,
          equals(pubkeyB),
          reason:
              'BUG #2936: After reinitialize, identity should still be B '
              '(the imported nsec), not A (the Keycast account). If this '
              'fails, _tryRestoreFromKnownAccounts is overriding the '
              'imported identity.',
        );

        // Verify signing still works for B
        final signedEvent = await tester.runAsync(
          () => authService.createAndSignEvent(
            kind: 1,
            content: 'nsec import persistence test',
          ),
        );
        expect(signedEvent, isNotNull);
        expect(signedEvent?.pubkey, equals(pubkeyB));

        logPhase('Phase 4: Signing works for B after reinitialize');

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
