// ABOUTME: Tests for AccountCredentialsRepository
// ABOUTME: Covers the owner-bound token gate and delegation to KeycastOAuth

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  group(AccountCredentialsRepository, () {
    late _MockKeycastOAuth oauthClient;

    setUp(() {
      oauthClient = _MockKeycastOAuth();
    });

    AccountCredentialsRepository buildSubject({
      required Future<String?> Function() readAccessToken,
    }) => AccountCredentialsRepository(
      oauthClient: oauthClient,
      readAccessToken: readAccessToken,
    );

    group('fetchAccountStatus', () {
      test(
        'answers unknown without a token instead of calling Keycast',
        () async {
          final repository = buildSubject(readAccessToken: () async => null);

          expect(await repository.fetchAccountStatus(), isNull);
          verifyNever(() => oauthClient.getAccountStatus(any()));
        },
      );

      test('returns the status Keycast reports for the token', () async {
        const status = KeycastAccountStatus(
          email: 'a@b.com',
          emailVerified: true,
          publicKey: 'abc',
          verifiedMinor: false,
        );
        when(
          () => oauthClient.getAccountStatus('tok'),
        ).thenAnswer((_) async => status);

        final repository = buildSubject(readAccessToken: () async => 'tok');

        expect(await repository.fetchAccountStatus(), same(status));
      });

      test('answers unknown when the token lookup throws', () async {
        final repository = buildSubject(
          readAccessToken: () async => throw Exception('storage unavailable'),
        );

        expect(await repository.fetchAccountStatus(), isNull);
      });
    });

    group('changePassword', () {
      test('refuses without a token rather than calling Keycast', () async {
        final repository = buildSubject(readAccessToken: () async => '');

        final result = await repository.changePassword(
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        );

        expect(result.failure, ChangePasswordFailure.needsSignIn);
        verifyNever(
          () => oauthClient.changePassword(
            token: any(named: 'token'),
            currentPassword: any(named: 'currentPassword'),
            newPassword: any(named: 'newPassword'),
          ),
        );
      });

      test('passes the owner-bound token through to Keycast', () async {
        when(
          () => oauthClient.changePassword(
            token: 'tok',
            currentPassword: 'hunter2',
            newPassword: 'hunter22',
          ),
        ).thenAnswer((_) async => ChangePasswordResult.success());

        final repository = buildSubject(readAccessToken: () async => 'tok');

        final result = await repository.changePassword(
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        );

        expect(result.success, isTrue);
      });

      test('maps a thrown token lookup to a network failure', () async {
        final repository = buildSubject(
          readAccessToken: () async => throw Exception('refresh failed'),
        );

        final result = await repository.changePassword(
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        );

        expect(result.failure, ChangePasswordFailure.network);
      });
    });

    group('changeEmail', () {
      test('refuses without a token rather than calling Keycast', () async {
        final repository = buildSubject(readAccessToken: () async => null);

        final result = await repository.changeEmail(
          newEmail: 'new@example.com',
          password: 'hunter2',
        );

        expect(result.failure, ChangeEmailFailure.needsSignIn);
        verifyNever(
          () => oauthClient.changeEmail(
            token: any(named: 'token'),
            newEmail: any(named: 'newEmail'),
            password: any(named: 'password'),
          ),
        );
      });

      test('passes the owner-bound token through to Keycast', () async {
        when(
          () => oauthClient.changeEmail(
            token: 'tok',
            newEmail: 'new@example.com',
            password: 'hunter2',
          ),
        ).thenAnswer((_) async => ChangeEmailResult.success());

        final repository = buildSubject(readAccessToken: () async => 'tok');

        final result = await repository.changeEmail(
          newEmail: 'new@example.com',
          password: 'hunter2',
        );

        expect(result.success, isTrue);
      });
    });

    group('requestPasswordSetup', () {
      const status = KeycastAccountStatus(
        email: 'social@example.com',
        emailVerified: true,
        publicKey: 'abc',
        verifiedMinor: false,
      );

      test('asks to sign in again without a token', () async {
        final repository = buildSubject(readAccessToken: () async => null);

        expect(
          await repository.requestPasswordSetup(),
          PasswordSetupRequestResult.needsSignIn,
        );
        verifyNever(() => oauthClient.getAccountStatus(any()));
      });

      test(
        'sends the link request for the email on file with the session',
        () async {
          when(
            () => oauthClient.getAccountStatus('tok'),
          ).thenAnswer((_) async => status);
          when(
            () => oauthClient.sendPasswordResetEmail(
              'social@example.com',
              bearerToken: 'tok',
            ),
          ).thenAnswer((_) async => ForgotPasswordResult(success: true));

          final repository = buildSubject(readAccessToken: () async => 'tok');

          expect(
            await repository.requestPasswordSetup(),
            PasswordSetupRequestResult.requested,
          );
          verify(
            () => oauthClient.sendPasswordResetEmail(
              'social@example.com',
              bearerToken: 'tok',
            ),
          ).called(1);
        },
      );

      test('fails without an email on file', () async {
        when(
          () => oauthClient.getAccountStatus('tok'),
        ).thenAnswer((_) async => null);

        final repository = buildSubject(readAccessToken: () async => 'tok');

        expect(
          await repository.requestPasswordSetup(),
          PasswordSetupRequestResult.failed,
        );
        verifyNever(
          () => oauthClient.sendPasswordResetEmail(
            any(),
            bearerToken: any(named: 'bearerToken'),
          ),
        );
      });

      test('fails when Keycast refuses the request', () async {
        when(
          () => oauthClient.getAccountStatus('tok'),
        ).thenAnswer((_) async => status);
        when(
          () => oauthClient.sendPasswordResetEmail(
            any(),
            bearerToken: any(named: 'bearerToken'),
          ),
        ).thenAnswer((_) async => ForgotPasswordResult.error('reset_failed'));

        final repository = buildSubject(readAccessToken: () async => 'tok');

        expect(
          await repository.requestPasswordSetup(),
          PasswordSetupRequestResult.failed,
        );
      });

      test('fails when Keycast cannot be reached', () async {
        when(
          () => oauthClient.getAccountStatus('tok'),
        ).thenAnswer((_) async => status);
        when(
          () => oauthClient.sendPasswordResetEmail(
            any(),
            bearerToken: any(named: 'bearerToken'),
          ),
        ).thenThrow(Exception('offline'));

        final repository = buildSubject(readAccessToken: () async => 'tok');

        expect(
          await repository.requestPasswordSetup(),
          PasswordSetupRequestResult.failed,
        );
      });
    });
  });
}
