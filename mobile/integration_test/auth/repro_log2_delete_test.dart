// ABOUTME: Reproduce bug #2233 (user log 2): delete account flow breaks signing
// ABOUTME: Scenario: sign into 2nd account -> delete it -> sign back into main -> uploads fail
// ABOUTME: Root cause: signOut(deleteKeys:true) leaves stale state that causes
// ABOUTME: authSource=automatic and _keyStorage primary keys deleted -> signer returns null
// ABOUTME: Requires: local Docker stack running (mise run local_up)
// ABOUTME: Run with: mise run e2e_test integration_test/auth/repro_log2_delete_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:patrol/patrol.dart';

import '../helpers/constants.dart';
import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';

/// Pre-register and verify a keycast account via HTTP API.
///
/// Calls headless register, extracts the verification token from postgres,
/// and verifies the email so the account is ready for login.
Future<String> _registerAndVerifyViaApi(String email, String password) async {
  final serverUrl = 'http://$localHost:$localKeycastPort';
  const clientId = 'divine-mobile';
  const redirectUri = 'http://$loopbackHost:$localKeycastPort/app/callback';

  // Generate PKCE challenge
  final random = List<int>.generate(
    32,
    (_) => DateTime.now().microsecond % 256,
  );
  final verifier = base64Url.encode(random).replaceAll('=', '');
  final challengeHash = sha256.convert(utf8.encode(verifier));
  final challenge = base64Url.encode(challengeHash.bytes).replaceAll('=', '');

  final client = HttpClient();
  try {
    final request = await client.postUrl(
      Uri.parse('$serverUrl/api/headless/register'),
    );
    request.headers.set('Content-Type', 'application/json');
    request.write(
      jsonEncode({
        'email': email,
        'password': password,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': 'policy:full',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      }),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('headless register failed: ${response.statusCode} $body');
    }
  } finally {
    client.close();
  }

  final token = await getVerificationToken(email);
  await callVerifyEmail(token);

  final pubkey = await getUserPubkeyByEmail(email);
  if (pubkey == null || pubkey.isEmpty) {
    throw Exception('_registerAndVerifyViaApi: no pubkey for $email');
  }
  debugPrint('_registerAndVerifyViaApi: $email -> pubkey=$pubkey');
  return pubkey;
}

void main() {
  ignorePlatformSemanticsHandle();

  group('Bug #2233 -- Delete Account Flow (User Log 2)', () {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final emailA = 'log2-a-$ts@test.divine.video';
    final emailB = 'log2-b-$ts@test.divine.video';
    const password = 'TestPass123!';

    // ──────────────────────────────────────────────────────────────────
    // Case 1: divineOAuth A -> login B -> delete B (signOut deleteKeys:true)
    //         -> sign back in as A -> sign event
    // ──────────────────────────────────────────────────────────────────
    patrolTest(
      'signing works after deleting second account and returning to first',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        // Pre-register B so we can login without polling
        final pubkeyB = await _registerAndVerifyViaApi(emailB, password);
        logPhase('Pre-registered B: pubkey=$pubkeyB');

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Phase 1: Register A via UI ──
        logPhase('-- Phase 1: Register account A --');

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, emailA, password);

        final foundVerify = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerify, isTrue, reason: 'Should reach verify screen');

        final tokenA = await getVerificationToken(emailA);
        await callVerifyEmail(tokenA);

        final leftVerify = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerify, isTrue, reason: 'A verification should complete');
        await pumpUntilSettled(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        expect(authService.isAuthenticated, isTrue);
        final pubkeyA = authService.currentPublicKeyHex;
        logPhase('Phase 1 complete: A pubkey=$pubkeyA');

        // ── Phase 2: Sign out A, login as B ──
        logPhase('-- Phase 2: Sign out A, login B --');

        // This reproduction intentionally overlaps sign-out with the next
        // login to exercise the original account-swap race.
        // ignore: unawaited_futures
        authService.signOut();

        final foundWelcome = await waitForWidget(
          tester,
          find.byType(WelcomeScreen),
          maxSeconds: 30,
        );
        expect(foundWelcome, isTrue);
        await pumpUntilSettled(tester, maxSeconds: 3);

        await navigateToLoginOptions(tester);
        await loginWithCredentials(tester, emailB, password);

        final foundMainAfterB = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is BottomNavigationBar ||
                (widget is Text &&
                    (widget.data == 'Popular' || widget.data == 'Trending')),
          ),
          maxSeconds: 30,
        );
        expect(foundMainAfterB, isTrue, reason: 'Should be in app as B');

        expect(authService.currentPublicKeyHex, equals(pubkeyB));
        logPhase('Phase 2 complete: logged in as B, pubkey=$pubkeyB');

        // ── Phase 3: Delete B (signOut deleteKeys:true) ──
        logPhase('-- Phase 3: Delete account B --');

        await authService.signOut(deleteKeys: true);

        final foundWelcome2 = await waitForWidget(
          tester,
          find.byType(WelcomeScreen),
          maxSeconds: 30,
        );
        expect(foundWelcome2, isTrue);
        await pumpUntilSettled(tester, maxSeconds: 3);

        logPhase('Phase 3 complete: B deleted');

        // ── Phase 4: Sign back in as A ──
        logPhase('-- Phase 4: Sign back in as A --');

        // Try welcome "Log back in" first, fall back to login credentials
        final foundLogBackIn = await waitForText(
          tester,
          'Log back in',
          maxSeconds: 10,
        );

        if (foundLogBackIn) {
          logPhase('Using "Log back in" button');
          await tester.tap(find.text('Log back in'));
          await pumpUntilSettled(tester, maxSeconds: 15);
        } else {
          logPhase('Using login credentials');
          await navigateToLoginOptions(tester);
          await loginWithCredentials(tester, emailA, password);
          await pumpUntilSettled(tester, maxSeconds: 15);
        }

        var authenticated = false;
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 250));
          if (authService.isAuthenticated) {
            authenticated = true;
            break;
          }
        }
        expect(authenticated, isTrue, reason: 'Should auth as A');

        logPhase(
          'Phase 4 complete: pubkey=${authService.currentPublicKeyHex}, '
          'source=${authService.authenticationSource.name}',
        );

        // ── Phase 5: Assert state and signing ──
        logPhase('-- Phase 5: Assert state and signing --');

        expect(
          authService.currentPublicKeyHex,
          equals(pubkeyA),
          reason:
              'Pubkey should match A (got '
              '${authService.currentPublicKeyHex})',
        );

        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
          reason:
              'Auth source should be divineOAuth, not '
              '${authService.authenticationSource.name}. '
              'Bug #2233: reverted to automatic after delete.',
        );

        final signedEvent = await authService.createAndSignEvent(
          kind: 1,
          content: 'repro-log2-test-$ts',
        );

        expect(
          signedEvent,
          isNotNull,
          reason:
              'createAndSignEvent should not return null. '
              'User log 2: "Signer returned null".',
        );
        expect(signedEvent!.pubkey, equals(pubkeyA));

        logPhase('Phase 5 complete: signing works');

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // ──────────────────────────────────────────────────────────────────
    // Case 2: divineOAuth A -> login B -> delete B -> app restart
    //         (re-initialize) -> check state + sign
    // ──────────────────────────────────────────────────────────────────
    patrolTest(
      'auth state correct after delete + app restart (re-initialize)',
      ($) async {
        final tester = $.tester;
        final originalOnError = suppressSetStateErrors();
        addTearDown(() => restoreErrorHandler(originalOnError));
        final originalErrorBuilder = saveErrorWidgetBuilder();
        addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));
        final semanticsHandle = tester.ensureSemantics();

        // Use unique emails for this test case
        final emailA2 = 'log2-rst-a-$ts@test.divine.video';
        final emailB2 = 'log2-rst-b-$ts@test.divine.video';

        final pubkeyB = await _registerAndVerifyViaApi(emailB2, password);
        logPhase('Pre-registered B: pubkey=$pubkeyB');

        launchAppGuarded(app.main);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // ── Phase 1: Register A via UI ──
        logPhase('-- Phase 1: Register A --');

        await navigateToCreateAccount(tester);
        await registerNewUser(tester, emailA2, password);

        final foundVerify = await waitForText(
          tester,
          'Complete your registration',
        );
        expect(foundVerify, isTrue);

        final tokenA = await getVerificationToken(emailA2);
        await callVerifyEmail(tokenA);

        final leftVerify = await waitForTextGone(
          tester,
          'Complete your registration',
        );
        expect(leftVerify, isTrue);
        await pumpUntilSettled(tester);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MaterialApp)),
        );
        final authService = container.read(authServiceProvider);

        final pubkeyA = authService.currentPublicKeyHex;
        logPhase('Phase 1 complete: A pubkey=$pubkeyA');

        // ── Phase 2: Sign out A, login B ──
        logPhase('-- Phase 2: Sign out A, login B --');

        // This reproduction intentionally overlaps sign-out with the next
        // login to exercise the original account-swap race.
        // ignore: unawaited_futures
        authService.signOut();

        final foundWelcome = await waitForWidget(
          tester,
          find.byType(WelcomeScreen),
          maxSeconds: 30,
        );
        expect(foundWelcome, isTrue);
        await pumpUntilSettled(tester, maxSeconds: 3);

        await navigateToLoginOptions(tester);
        await loginWithCredentials(tester, emailB2, password);

        final foundMain = await waitForWidget(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is BottomNavigationBar ||
                (widget is Text &&
                    (widget.data == 'Popular' || widget.data == 'Trending')),
          ),
          maxSeconds: 30,
        );
        expect(foundMain, isTrue);
        logPhase('Phase 2 complete: logged in as B');

        // ── Phase 3: Delete B ──
        logPhase('-- Phase 3: Delete B --');

        await authService.signOut(deleteKeys: true);

        final foundWelcome2 = await waitForWidget(
          tester,
          find.byType(WelcomeScreen),
          maxSeconds: 30,
        );
        expect(foundWelcome2, isTrue);
        await pumpUntilSettled(tester, maxSeconds: 3);

        logPhase('Phase 3 complete: B deleted');

        // ── Phase 4: Simulate app restart ──
        logPhase('-- Phase 4: App restart (re-initialize) --');

        await authService.initialize();
        await pumpUntilSettled(tester);

        logPhase(
          'Phase 4 post-init: '
          'authenticated=${authService.isAuthenticated}, '
          'pubkey=${authService.currentPublicKeyHex}, '
          'source=${authService.authenticationSource.name}',
        );

        if (authService.isAuthenticated) {
          expect(
            authService.authenticationSource,
            isNot(equals(AuthenticationSource.automatic)),
            reason: 'Bug #2233: authSource should not revert to automatic',
          );
        }

        // ── Phase 4b: Sign back in as A ──
        logPhase('-- Phase 4b: Sign back in as A --');

        // After deleting B and reinitializing, A's archived OAuth session
        // may be restored automatically (multi-account archive/restore).
        // Only navigate the sign-in flow if not already authenticated as A.
        if (authService.isAuthenticated &&
            authService.currentPublicKeyHex == pubkeyA) {
          logPhase('Phase 4b: already authenticated as A after reinitialize');
        } else {
          final foundLogBackIn = await waitForText(
            tester,
            'Log back in',
            maxSeconds: 10,
          );

          if (foundLogBackIn) {
            await tester.tap(find.text('Log back in'));
            await pumpUntilSettled(tester, maxSeconds: 15);
          } else {
            await navigateToLoginOptions(tester);
            await loginWithCredentials(tester, emailA2, password);
            await pumpUntilSettled(tester, maxSeconds: 15);
          }

          var authenticated = false;
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 250));
            if (authService.isAuthenticated) {
              authenticated = true;
              break;
            }
          }
          expect(authenticated, isTrue);
        }

        expect(authService.currentPublicKeyHex, equals(pubkeyA));
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.divineOAuth),
        );

        final signedEvent = await authService.createAndSignEvent(
          kind: 1,
          content: 'repro-log2-restart-$ts',
        );

        expect(signedEvent, isNotNull, reason: 'Signing should work');
        expect(signedEvent!.pubkey, equals(pubkeyA));

        logPhase('Phase 4b complete: signing works after restart');

        semanticsHandle.dispose();
        drainAsyncErrors(tester);
        // Inline restore is required by the framework's end-of-body
        // ErrorWidget.builder check; the addTearDown above covers throws.
        restoreErrorWidgetBuilder(originalErrorBuilder);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    // ──────────────────────────────────────────────────────────────────
    // Case 3: TWO LOCAL ACCOUNTS (no keycast) -> delete second -> sign
    //
    // This is the EXACT user log 2 scenario:
    // - authSource=automatic, not divineOAuth
    // - "Signer returned null" (not "signature validation FAILED")
    // - signOut(deleteKeys:true) wipes PRIMARY key slot
    // - _currentKeyContainer restored from per-identity storage (pubkey
    //   only), but createAndSignEvent uses _keyStorage.withPrivateKey
    //   which reads from the wiped PRIMARY slot -> null
    // ──────────────────────────────────────────────────────────────────
    patrolTest(
      'local keys: signing works after deleting second auto account',
      ($) async {
        final tester = $.tester;
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

        // ── Phase 1: Create local account A (auto identity) ──
        logPhase('-- Phase 1: Create local account A --');

        final resultA = await authService.createNewIdentity();
        expect(resultA.success, isTrue, reason: 'A creation should succeed');
        await pumpUntilSettled(tester, maxSeconds: 3);

        expect(authService.isAuthenticated, isTrue);
        expect(authService.isAnonymous, isTrue);
        final pubkeyA = authService.currentPublicKeyHex;

        // Verify signing works for A
        final signedA = await authService.createAndSignEvent(
          kind: 1,
          content: 'test-A-before-switch',
        );
        expect(signedA, isNotNull, reason: 'A should sign before switch');
        expect(signedA!.pubkey, equals(pubkeyA));

        logPhase('Phase 1 complete: A pubkey=$pubkeyA, signing works');

        // ── Phase 2: Sign out A, create local account B ──
        logPhase('-- Phase 2: Sign out A, create B --');

        await authService.signOut();
        await pumpUntilSettled(tester, maxSeconds: 3);

        final resultB = await authService.createNewIdentity();
        expect(resultB.success, isTrue, reason: 'B creation should succeed');
        await pumpUntilSettled(tester, maxSeconds: 3);

        expect(authService.isAuthenticated, isTrue);
        final pubkeyB = authService.currentPublicKeyHex;
        expect(pubkeyB, isNot(equals(pubkeyA)));

        logPhase('Phase 2 complete: B pubkey=$pubkeyB');

        // ── Phase 3: Delete B (signOut deleteKeys:true) ──
        logPhase('-- Phase 3: Delete account B --');

        await authService.signOut(deleteKeys: true);
        await pumpUntilSettled(tester, maxSeconds: 3);

        expect(authService.isAuthenticated, isFalse);
        logPhase(
          'Phase 3 complete: B deleted, '
          'authSource=${authService.authenticationSource.name}',
        );

        // ── Phase 4: Sign back in as A ──
        logPhase('-- Phase 4: Sign back in as A --');

        // Use signInForAccount with A's pubkey and automatic source
        // (this is what the welcome screen's "Log back in" does)
        await authService.signInForAccount(
          pubkeyA!,
          AuthenticationSource.automatic,
        );
        await pumpUntilSettled(tester, maxSeconds: 3);

        expect(authService.isAuthenticated, isTrue);
        expect(
          authService.currentPublicKeyHex,
          equals(pubkeyA),
          reason: 'Should be signed in as A',
        );

        logPhase(
          'Phase 4 complete: pubkey=${authService.currentPublicKeyHex}, '
          'source=${authService.authenticationSource.name}',
        );

        // ── Phase 5: Try to sign — this is where user log 2 failed ──
        logPhase('-- Phase 5: Sign event as A --');

        final signedEvent = await authService.createAndSignEvent(
          kind: 1,
          content: 'repro-log2-local-$ts',
        );

        expect(
          signedEvent,
          isNotNull,
          reason:
              'createAndSignEvent should NOT return null. '
              'User log 2: "Signer returned null" because '
              'signOut(deleteKeys:true) wiped PRIMARY key slot '
              'and createAndSignEvent uses _keyStorage.withPrivateKey '
              'instead of _currentKeyContainer.withPrivateKey.',
        );
        expect(signedEvent!.pubkey, equals(pubkeyA));

        logPhase('Phase 5 complete: signing works');

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
