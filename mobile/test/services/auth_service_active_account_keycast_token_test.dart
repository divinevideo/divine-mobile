// ABOUTME: Tests AuthService.activeAccountKeycastToken: the Keycast bearer token
// ABOUTME: is only handed out for the account a caller is acting for.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Nip19, generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService activeAccountKeycastToken', () {
    const accessToken = 'test-access-token';
    const otherAccountPubkey =
        'cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd';

    late _MockUserDataCleanupService cleanupService;
    late _MockKeycastOAuth oauthClient;
    late AuthServiceChannelMocks channelMocks;

    setUp(() {
      cleanupService = _MockUserDataCleanupService();
      oauthClient = _MockKeycastOAuth();
      stubUserDataCleanupSuccess(cleanupService);
      channelMocks = AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    Future<(AuthService, String)> signedInAuthService() async {
      final privateKeyHex = generatePrivateKey();
      final pubkeyHex = SecureKeyContainer.fromPrivateKeyHex(
        privateKeyHex,
      ).publicKeyHex;
      final authService = buildTestAuthService(
        cleanupService: cleanupService,
        oauthClient: oauthClient,
      );
      addTearDown(authService.dispose);
      await ignoringDiscoveryErrors(
        () => authService.importFromNsec(Nip19.encodePrivateKey(privateKeyHex)),
      );
      expect(authService.currentPublicKeyHex, pubkeyHex);
      return (authService, pubkeyHex);
    }

    void stubSessionFor(String owner) {
      when(() => oauthClient.getSession()).thenAnswer(
        (_) async => KeycastSession(
          bunkerUrl: 'https://bunker.example.com',
          accessToken: accessToken,
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          userPubkey: owner,
        ),
      );
    }

    test(
      'returns the token for the signed-in account it was asked for',
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        stubSessionFor(pubkeyHex);

        expect(
          await authService.activeAccountKeycastToken(forAccount: pubkeyHex),
          accessToken,
        );
      },
    );

    // Work started for one account can still be running after another signs
    // in. Handing it the new account's token would answer, or act, for the
    // wrong account.
    test(
      'returns nothing when asked for an account that is not signed in',
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        stubSessionFor(pubkeyHex);

        expect(
          await authService.activeAccountKeycastToken(
            forAccount: otherAccountPubkey,
          ),
          isNull,
        );
        verifyNever(() => oauthClient.getSession());
      },
    );

    test(
      'returns nothing when the active account changes during token lookup',
      () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        final pendingSession = Completer<KeycastSession?>();
        when(
          () => oauthClient.getSession(),
        ).thenAnswer((_) => pendingSession.future);

        final tokenFuture = authService.activeAccountKeycastToken(
          forAccount: pubkeyHex,
        );
        await ignoringDiscoveryErrors(
          () => authService.importFromNsec(
            Nip19.encodePrivateKey(generatePrivateKey()),
          ),
        );
        expect(authService.currentPublicKeyHex, isNot(pubkeyHex));
        pendingSession.complete(
          KeycastSession(
            bunkerUrl: 'https://bunker.example.com',
            accessToken: accessToken,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            userPubkey: pubkeyHex,
          ),
        );

        expect(await tokenFuture, isNull);
      },
    );

    group('refresh of an expired session', () {
      void storeExpiredSessionFor(String owner) {
        channelMocks.secureStorage['keycast_session'] = jsonEncode(
          KeycastSession(
            bunkerUrl: 'https://bunker.example.com',
            accessToken: 'expired-access-token',
            expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
            userPubkey: owner,
          ).toJson(),
        );
      }

      void stubRefreshMintingFor(String owner) {
        when(() => oauthClient.getSession()).thenAnswer((_) async => null);
        when(
          () => oauthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (_) async => KeycastSession(
            bunkerUrl: 'https://bunker.example.com',
            accessToken: accessToken,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            userPubkey: owner,
          ),
        );
      }

      test('refreshes a session stored for the signed-in account', () async {
        final (authService, pubkeyHex) = await signedInAuthService();
        storeExpiredSessionFor(pubkeyHex);
        stubRefreshMintingFor(pubkeyHex);

        expect(
          await authService.activeAccountKeycastToken(forAccount: pubkeyHex),
          accessToken,
        );
        verify(
          () => oauthClient.refreshSession(userPubkey: pubkeyHex),
        ).called(1);
      });

      // A refresh stamps the expected owner onto the session it mints, so
      // the owner check after it cannot catch another account's token.
      test(
        'does not refresh a session another account left in storage',
        () async {
          final (authService, pubkeyHex) = await signedInAuthService();
          storeExpiredSessionFor(otherAccountPubkey);
          stubRefreshMintingFor(pubkeyHex);

          expect(
            await authService.activeAccountKeycastToken(forAccount: pubkeyHex),
            isNull,
          );
          verifyNever(
            () => oauthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          );
        },
      );
    });

    test(
      'binds the live signer to the verified account on unbound OAuth sign-in',
      () async {
        final verifiedPubkey = freshPubkeyHex();
        final nextRefusal = KeycastPolicyRefusals.stream.first;

        await http.runWithClient(
          () async {
            final authService = buildTestAuthService(
              cleanupService: cleanupService,
              oauthClient: oauthClient,
            );
            addTearDown(authService.dispose);

            await ignoringDiscoveryErrors(
              () => authService.signInWithDivineOAuth(
                KeycastSession(
                  bunkerUrl: 'https://bunker.example.com',
                  accessToken: accessToken,
                  expiresAt: DateTime.now().add(const Duration(hours: 1)),
                ),
              ),
            );
            expect(authService.currentPublicKeyHex, verifiedPubkey);

            await expectLater(
              authService.currentIdentity!.signEvent(
                Event(verifiedPubkey, 1059, const [], 'ciphertext'),
              ),
              throwsA(isA<EmailNotConfirmedException>()),
            );
          },
          () => MockClient((request) async {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['method'] == 'get_public_key') {
              return http.Response(jsonEncode({'result': verifiedPubkey}), 200);
            }
            return http.Response(
              jsonEncode({
                'error': 'confirm your email',
                'code': 'EMAIL_NOT_CONFIRMED',
              }),
              403,
            );
          }),
        );

        final refusal = await nextRefusal;
        expect(refusal.kind, KeycastPolicyRefusalKind.emailNotConfirmed);
        expect(refusal.owner, verifiedPubkey);
      },
    );
  });
}
