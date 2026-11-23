// ABOUTME: Tests the email confirmation repository: mapping Keycast account
// ABOUTME: status, unknown on missing token or failure, and bearer resend.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/repositories/email_confirmation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

const _account =
    'a3c1e0b6f7d2948e5c1b0a9f8e7d6c5b4a3928170f6e5d4c3b2a19087f6e5d4c';

void main() {
  group(EmailConfirmationRepository, () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

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
          preferences: preferences,
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.unconfirmed('you@example.com')),
        );
      });

      test('is confirmed for the verified address', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth(
            (_) async => http.Response(
              _accountBody(email: 'you@example.com', verified: true),
              200,
            ),
          ),
          readAccessToken: () async => 'token',
          preferences: preferences,
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.confirmed('you@example.com')),
        );
      });

      test('is missing when the account has no email at all', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth(
            (_) async =>
                http.Response(_accountBody(email: '', verified: false), 200),
          ),
          readAccessToken: () async => 'token',
          preferences: preferences,
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.missing()),
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
          preferences: preferences,
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
          preferences: preferences,
        );

        expect(
          await repository.fetchStatus(),
          equals(const EmailConfirmation.unknown()),
        );
      });
    });

    group('remembered', () {
      EmailConfirmationRepository buildRepository() =>
          EmailConfirmationRepository(
            oauthClient: _oauth((_) async => http.Response('{}', 200)),
            readAccessToken: () async => 'token',
            preferences: preferences,
          );

      test('is unknown for an account never seen', () {
        expect(
          buildRepository().remembered(_account),
          equals(const EmailConfirmation.unknown()),
        );
      });

      test('returns what was remembered for the account', () async {
        final repository = buildRepository();
        await repository.remember(
          _account,
          const EmailConfirmation.unconfirmed('you@example.com'),
        );

        expect(
          buildRepository().remembered(_account),
          equals(const EmailConfirmation.unconfirmed('you@example.com')),
        );
      });

      test('keeps each account separate', () async {
        final repository = buildRepository();
        await repository.remember(
          _account,
          const EmailConfirmation.unconfirmed('you@example.com'),
        );

        expect(
          repository.remembered('b' * 64),
          equals(const EmailConfirmation.unknown()),
        );
      });

      test('does not overwrite a known answer with unknown', () async {
        final repository = buildRepository();
        await repository.remember(_account, const EmailConfirmation.missing());
        await repository.remember(_account, const EmailConfirmation.unknown());

        expect(
          repository.remembered(_account),
          equals(const EmailConfirmation.missing()),
        );
      });

      test('reads a corrupt entry as unknown', () async {
        await preferences.setString('email_confirmation_$_account', '{oops');

        expect(
          buildRepository().remembered(_account),
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
          preferences: preferences,
        );

        expect(await repository.resend(), isTrue);
        expect(authorization, equals('Bearer token'));
      });

      test('reports failure without a Keycast token', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((_) async => http.Response('{}', 200)),
          readAccessToken: () async => null,
          preferences: preferences,
        );

        expect(await repository.resend(), isFalse);
      });

      test('reports failure when Keycast fails', () async {
        final repository = EmailConfirmationRepository(
          oauthClient: _oauth((_) async => http.Response('boom', 500)),
          readAccessToken: () async => 'token',
          preferences: preferences,
        );

        expect(await repository.resend(), isFalse);
      });
    });
  });
}
