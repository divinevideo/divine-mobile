// ABOUTME: Tests for SocialSignInRepository: the provider token reaches
// ABOUTME: Keycast intact, and every refusal surfaces as a typed exception.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/social_sign_in_repository.dart';
import 'package:openvine/services/social_identity_service.dart';

class _MockIdentityService extends Mock implements SocialIdentityService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  group(SocialSignInRepository, () {
    late _MockIdentityService identityService;
    late _MockKeycastOAuth oauthClient;
    late SocialSignInRepository repository;

    const appleToken = SocialIdentityToken(
      provider: SocialProvider.apple,
      idToken: 'apple.id.token',
      rawNonce: 'raw-nonce',
      authorizationCode: 'apple-code',
    );

    void stubKeycastLogin(SocialLoginResult result) {
      when(
        () => oauthClient.headlessSocialLogin(
          provider: any(named: 'provider'),
          idToken: any(named: 'idToken'),
          rawNonce: any(named: 'rawNonce'),
          authorizationCode: any(named: 'authorizationCode'),
        ),
      ).thenAnswer((_) async => (result, 'pkce-verifier'));
    }

    setUpAll(() => registerFallbackValue(SocialProvider.google));

    setUp(() {
      identityService = _MockIdentityService();
      oauthClient = _MockKeycastOAuth();
      repository = SocialSignInRepository(
        identityService: identityService,
        oauthClient: oauthClient,
      );
      when(
        () => identityService.obtainToken(SocialProvider.apple),
      ).thenAnswer((_) async => appleToken);
    });

    group('signIn', () {
      test('sends the token to Keycast and exchanges the code it returns '
          'with the matching verifier', () async {
        stubKeycastLogin(SocialLoginResult(success: true, code: 'auth-code'));
        when(
          () => oauthClient.exchangeCode(
            code: any(named: 'code'),
            verifier: any(named: 'verifier'),
          ),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'bunker://session'),
        );

        final session = await repository.signIn(SocialProvider.apple);

        expect(session.bunkerUrl, 'bunker://session');
        verify(
          () => oauthClient.headlessSocialLogin(
            provider: SocialProvider.apple,
            idToken: 'apple.id.token',
            rawNonce: 'raw-nonce',
            authorizationCode: 'apple-code',
          ),
        ).called(1);
        verify(
          () => oauthClient.exchangeCode(
            code: 'auth-code',
            verifier: 'pkce-verifier',
          ),
        ).called(1);
      });

      test('surfaces a Keycast refusal without exchanging anything', () async {
        stubKeycastLogin(
          SocialLoginResult.error('linked', code: 'ACCOUNT_LINK_REQUIRED'),
        );

        await expectLater(
          repository.signIn(SocialProvider.apple),
          throwsA(
            isA<SocialSignInException>().having(
              (e) => e.failure,
              'failure',
              SocialLoginFailure.accountLinkRequired,
            ),
          ),
        );
        verifyNever(
          () => oauthClient.exchangeCode(
            code: any(named: 'code'),
            verifier: any(named: 'verifier'),
          ),
        );
      });

      test('treats a rejected code exchange as an unknown failure', () async {
        stubKeycastLogin(SocialLoginResult(success: true, code: 'auth-code'));
        when(
          () => oauthClient.exchangeCode(
            code: any(named: 'code'),
            verifier: any(named: 'verifier'),
          ),
        ).thenThrow(OAuthException('invalid_grant'));

        await expectLater(
          repository.signIn(SocialProvider.apple),
          throwsA(
            isA<SocialSignInException>().having(
              (e) => e.failure,
              'failure',
              SocialLoginFailure.unknown,
            ),
          ),
        );
      });

      test('treats a code exchange timeout as a network failure', () async {
        stubKeycastLogin(SocialLoginResult(success: true, code: 'auth-code'));
        when(
          () => oauthClient.exchangeCode(
            code: any(named: 'code'),
            verifier: any(named: 'verifier'),
          ),
        ).thenThrow(TimeoutException('slow'));

        await expectLater(
          repository.signIn(SocialProvider.apple),
          throwsA(
            isA<SocialSignInException>().having(
              (e) => e.failure,
              'failure',
              SocialLoginFailure.network,
            ),
          ),
        );
      });

      test('lets a provider failure through without calling Keycast', () async {
        when(() => identityService.obtainToken(SocialProvider.google))
            .thenThrow(
              const SocialIdentityException(
                SocialProvider.google,
                SocialIdentityFailure.cancelled,
              ),
            );

        await expectLater(
          repository.signIn(SocialProvider.google),
          throwsA(isA<SocialIdentityException>()),
        );
        verifyNoMoreInteractions(oauthClient);
      });
    });
  });
}
