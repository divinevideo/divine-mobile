// ABOUTME: Tests the email confirmation repository: mapping Keycast account
// ABOUTME: status, unknown on missing token or failure, and bearer resend.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/repositories/email_confirmation_repository.dart';

const _config = OAuthConfig(
  serverUrl: 'https://login.divine.video',
  clientId: 'c',
  redirectUri: 'divine://cb',
);

KeycastOAuth _oauth(Future<http.Response> Function(http.Request) handler) =>
    KeycastOAuth(config: _config, httpClient: MockClient(handler));

String _accountBody({required String email, required bool verified}) =>
    '{"email":"$email","email_verified":$verified,"public_key":"p",'
    '"verified_minor":false}';

void main() {
  group(EmailConfirmationRepository, () {
    group('fetchStatus', () {
      test('is unconfirmed with the address when Keycast says so', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth(
            (_) async => http.Response(
              _accountBody(email: 'you@example.com', verified: false),
              200,
            ),
          ),
          readAccessToken: () async => 'token',
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.unconfirmed('you@example.com')),
        );
      });

      test('is confirmed when the email is verified', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth(
            (_) async => http.Response(
              _accountBody(email: 'you@example.com', verified: true),
              200,
            ),
          ),
          readAccessToken: () async => 'token',
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.confirmed()),
        );
      });

      test('is confirmed when the account has no email at all', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth(
            (_) async =>
                http.Response(_accountBody(email: '', verified: false), 200),
          ),
          readAccessToken: () async => 'token',
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.confirmed()),
        );
      });

      test('is unknown without a Keycast token', () async {
        var requested = false;
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((_) async {
            requested = true;
            return http.Response('{}', 200);
          }),
          readAccessToken: () async => null,
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.unknown()),
        );
        expect(requested, isFalse);
      });

      test('is unknown when Keycast fails', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((_) async => http.Response('boom', 503)),
          readAccessToken: () async => 'token',
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.unknown()),
        );
      });
    });

    group('resend', () {
      test('authenticates the resend with the account token', () async {
        String? authorization;
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((request) async {
            authorization = request.headers['Authorization'];
            return http.Response('{"success":true,"message":"Sent"}', 200);
          }),
          readAccessToken: () async => 'token',
        );

        expect(await repository.resend(), isTrue);
        expect(authorization, equals('Bearer token'));
      });

      test('reports failure without a Keycast token', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((_) async => http.Response('{}', 200)),
          readAccessToken: () async => null,
        );

        expect(await repository.resend(), isFalse);
      });

      test('reports failure when Keycast fails', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((_) async => http.Response('boom', 500)),
          readAccessToken: () async => 'token',
        );

        expect(await repository.resend(), isFalse);
      });
    });
  });
}
