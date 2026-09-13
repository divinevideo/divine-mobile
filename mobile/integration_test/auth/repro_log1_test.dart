// ABOUTME: Reproduction test for bug #2233 (event signature validation failure)
// ABOUTME: Reproduces the pubkey/nsec mismatch that occurs when switching
// ABOUTME: between multiple accounts. The PRIMARY key slot in SecureKeyStorage
// ABOUTME: retains the previous account's nsec while _currentKeyContainer holds
// ABOUTME: a different identity's pubkey.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

void main() {
  ignorePlatformSemanticsHandle();

  group('Bug 2233 Repro Log 1 pubkey-nsec mismatch', () {
    patrolTest(
      'auto A → import nsec B → switch back to A → signing fails',
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
        // Phase 1: Create anonymous account A via UI
        // ════════════════════════════════════════════════════════════

        await navigateToCreateAccount(tester);

        final skipButton = find.text('Use Divine with no backup');
        expect(skipButton, findsOneWidget);
        await tester.tap(skipButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));

        final confirmSkip = find.text('Use this device only');
        expect(confirmSkip, findsOneWidget);
        await tester.tap(confirmSkip);
        await pumpUntilSettled(tester, maxSeconds: 10);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        expect(authService.isAuthenticated, isTrue);
        expect(authService.isAnonymous, isTrue);
        final pubkeyA = authService.currentPublicKeyHex!;

        logPhase('Phase 1: anonymous A created — pubkey=$pubkeyA');

        // ════════════════════════════════════════════════════════════
        // Phase 2: Sign out from A, import nsec B
        //
        // importFromNsec writes to the PRIMARY key slot, overwriting
        // A's nsec with B's nsec. This is the corruption step.
        // ════════════════════════════════════════════════════════════

        // Generate second identity before signOut to minimize time
        // between auth state changes.
        final privateKeyB = generatePrivateKey();
        final nsecB = Nip19.encodePrivateKey(privateKeyB);

        // Use tester.runAsync for real async operations that trigger
        // auth state changes and app navigation.
        await tester.runAsync(authService.signOut);
        await pumpUntilSettled(tester);

        logPhase('Phase 2a: signed out from A');

        final resultB = await tester.runAsync(
          () => authService.importFromNsec(nsecB),
        );
        expect(resultB!.success, isTrue);
        await tester.runAsync(authService.acceptTerms);
        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        final pubkeyB = authService.currentPublicKeyHex!;
        expect(pubkeyB, isNot(equals(pubkeyA)));

        logPhase('Phase 2b: imported nsec B — pubkey=$pubkeyB');

        // Sanity: signing works for B (PRIMARY matches B)
        final sanityB = await tester.runAsync(
          () => authService.createAndSignEvent(
            kind: 1,
            content: 'sanity check B',
          ),
        );
        expect(
          sanityB,
          isNotNull,
          reason: 'Signing should work for freshly imported account B',
        );

        logPhase('Phase 2c: signing works for B');

        // ════════════════════════════════════════════════════════════
        // Phase 3: Sign out from B, sign back in as A
        //
        // signInForAccount loads identity[npubA] which has pubkey_A.
        // But PRIMARY still has nsec_B from the import.
        // ════════════════════════════════════════════════════════════

        await tester.runAsync(authService.signOut);
        await pumpUntilSettled(tester);

        logPhase('Phase 3a: signed out from B');

        await tester.runAsync(
          () => authService.signInForAccount(
            pubkeyA,
            AuthenticationSource.automatic,
          ),
        );
        await pumpUntilSettled(tester);

        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentPublicKeyHex, equals(pubkeyA));
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.automatic),
        );

        logPhase('Phase 3b: signed back in as A');

        // ════════════════════════════════════════════════════════════
        // Phase 4: Try to sign — BUG MANIFESTS HERE
        //
        // createAndSignEvent builds event with pubkey_A (from
        // _currentKeyContainer) but _keyStorage.withPrivateKey reads
        // nsec_B from PRIMARY → signature fails validation.
        // ════════════════════════════════════════════════════════════

        final signedEvent = await tester.runAsync(
          () => authService.createAndSignEvent(
            kind: 1,
            content: 'repro test after switching back to A',
          ),
        );

        logPhase(
          'Phase 4: sign attempt as A — '
          'result=${signedEvent != null ? "OK" : "FAILED (bug #2233)"}',
        );

        expect(
          signedEvent,
          isNotNull,
          reason:
              'BUG #2233: signing fails because _keyStorage.withPrivateKey '
              'reads from PRIMARY slot (nsec_B) but event.pubkey is pubkey_A. '
              'Fix: use _currentKeyContainer.withPrivateKey or update PRIMARY '
              'on identity switch.',
        );
        expect(signedEvent?.pubkey, equals(pubkeyA));

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
