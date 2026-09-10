// ABOUTME: Reproduction test for bug #2233 (event signature validation failure)
// ABOUTME: Reproduces the pubkey/nsec mismatch that occurs when switching
// ABOUTME: between multiple accounts. The PRIMARY key slot in SecureKeyStorage
// ABOUTME: retains the previous account's nsec while _currentKeyContainer holds
// ABOUTME: a different identity's pubkey.
// ABOUTME: Also covers #6510: the locally generated identity created here must
// ABOUTME: see its lazily granted invite allocation before any code is minted.
// ABOUTME: Requires: local Docker stack (mise run local_up)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/settings/invites_screen.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/invite_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

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
        // Phase 1b: A brand new local identity sees its invites (#6510)
        //
        // The server enrols the pubkey lazily on its first authenticated
        // GET /v1/invite-status and answers
        //   {"canInvite":true,"remaining":10,"total":10,
        //    "codes":[],"totalCodes":0}
        // Entitlement without a single minted code is the regression that
        // matters: anything gating on a non-empty codes list shows this
        // user nothing while they in fact hold 10 invites.
        // ════════════════════════════════════════════════════════════

        final granted = await waitForLoadedInviteStatus(tester);
        final grantedStatus = granted.inviteStatus!;

        expect(
          grantedStatus.codes,
          isEmpty,
          reason:
              'A freshly enrolled identity has entitlement but no minted '
              'codes yet — the rest of this phase asserts the UI still '
              'shows the allocation',
        );
        expect(grantedStatus.canInvite, isTrue);
        expect(grantedStatus.remaining, initialInviteAllocation);
        expect(grantedStatus.total, initialInviteAllocation);
        // Nothing minted yet, so the whole allocation is still generatable.
        expect(grantedStatus.mintableCount, initialInviteAllocation);

        logPhase(
          'Phase 1b: invite status loaded — '
          'remaining=${grantedStatus.remaining} '
          'total=${grantedStatus.total} '
          'codes=${grantedStatus.codes.length}',
        );

        // ── Settings shows the share action independently of invites ──
        // The router comes from the provider container: InheritedGoRouter
        // lives below MaterialApp, so GoRouter.of cannot see it from here.
        final router = container.read(goRouterProvider);
        router.go(SettingsScreen.path);
        await pumpUntilSettled(tester, maxSeconds: 10);

        final shareEntry = find.ancestor(
          of: find.text(_en.settingsShareDivine),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == _en.settingsShareDivine,
          ),
        );
        expect(
          shareEntry,
          findsOneWidget,
          reason:
              'Settings should offer the Divine share action independently '
              'of invite allocation',
        );

        logPhase('Phase 1b: Settings shows the Divine share action');

        // ── The invites screen reports the server's allocation ──
        router.go(InvitesScreen.path);
        await pumpUntilSettled(tester, maxSeconds: 10);

        expect(find.byType(InvitesView), findsOneWidget);
        expect(
          find.text(_en.invitesGenerateCardTitle(grantedStatus.mintableCount)),
          findsOneWidget,
          reason:
              'The invites screen should offer the server-granted '
              '${grantedStatus.mintableCount} invites even with an empty '
              'code list',
        );
        expect(
          find.text(_en.invitesNoneAvailable),
          findsNothing,
          reason: 'An empty code list is not an empty allocation',
        );
        expect(find.text(_en.invitesShareWithPeople), findsNothing);

        logPhase(
          'Phase 1b: invites screen offers '
          '${grantedStatus.remaining} invites with no codes minted',
        );

        // ── Generating mints a shareable code ──
        await tester.tap(find.text(_en.invitesGenerateButtonLabel));

        var generated = inviteState(tester);
        for (var i = 0; i < 120; i++) {
          await tester.pump(const Duration(milliseconds: 500));
          generated = inviteState(tester);
          if (generated.status == InviteStatusLoadingStatus.loaded &&
              generated.hasUnclaimedCodes) {
            break;
          }
        }

        expect(
          generated.status,
          InviteStatusLoadingStatus.loaded,
          reason: 'Generating an invite should settle back into a loaded state',
        );
        final generatedStatus = generated.inviteStatus!;
        expect(generatedStatus.unclaimedCodes, hasLength(1));

        final generatedCode = generatedStatus.unclaimedCodes.single.code;
        expect(
          InviteApiClient.looksLikeInviteCode(generatedCode),
          isTrue,
          reason: '"$generatedCode" should be a shareable XXXX-XXXX code',
        );

        // `remaining` counts unminted entitlement plus minted-but-unclaimed
        // codes, so minting one moves a code into the share list without
        // spending the allocation — nothing is consumed until someone joins.
        expect(generatedStatus.remaining, initialInviteAllocation);
        expect(generatedStatus.total, initialInviteAllocation);
        // The mintable count DOES fall: one of the ten has been created. The
        // card must follow this number, not `remaining`, or it keeps offering a
        // button the server rejects once all ten exist.
        expect(generatedStatus.mintableCount, initialInviteAllocation - 1);

        expect(find.text(_en.invitesShareWithPeople), findsOneWidget);
        expect(find.text(generatedCode), findsOneWidget);
        expect(
          find.text(
            _en.invitesGenerateCardTitle(generatedStatus.mintableCount),
          ),
          findsOneWidget,
        );

        logPhase('Phase 1b: generated invite code=$generatedCode');

        // Back to the feed so the account switching below starts from the
        // same place it did before this phase existed.
        router.go(VideoFeedPage.pathForIndex(0));
        await pumpUntilSettled(tester);

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
