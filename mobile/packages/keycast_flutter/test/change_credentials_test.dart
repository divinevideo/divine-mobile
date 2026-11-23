// ABOUTME: Tests for KeycastOAuth.changePassword and KeycastOAuth.changeEmail
// ABOUTME: Covers both request contracts and the overloaded 401 disambiguation

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';

void main() {
  const config = OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'test-client',
    redirectUri: 'divine://oauth/callback',
  );

  /// What `GET /api/user/account` reports for the token, which is how both
  /// endpoints tell a wrong password apart from a token the server dropped.
  final accountBody = jsonEncode({
    'email': 'a@b.com',
    'email_verified': true,
    'public_key': 'abc',
    'verified_minor': false,
  });

  /// A client answering [path] with [status]/[body] and the account probe with
  /// [accountStatusCode], so both causes behind a 401 can be driven.
  MockClient clientFor(
    String path, {
    required int status,
    String body = '{}',
    int accountStatusCode = 200,
    void Function(http.Request request)? onCall,
  }) {
    return MockClient((request) async {
      if (request.url.path == path) {
        onCall?.call(request);
        return http.Response(body, status);
      }
      if (request.url.path == '/api/user/account') {
        return http.Response(accountBody, accountStatusCode);
      }
      return http.Response('unexpected ${request.url.path}', 404);
    });
  }

  group('KeycastOAuth.changePassword', () {
    const path = '/api/user/change-password';

    test(
      'reports an account without a password, whatever the status',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: clientFor(
            path,
            status: 401,
            body: jsonEncode({
              'error': 'no password',
              'code': 'PASSWORD_NOT_SET',
            }),
          ),
        );

        final result = await oauth.changePassword(
          token: 'tok123',
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        );

        expect(result.failure, ChangePasswordFailure.passwordNotSet);
      },
    );

    test('POSTs the bearer token and both passwords', () async {
      late http.Request captured;
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(
          path,
          status: 200,
          body: jsonEncode({'success': true}),
          onCall: (request) => captured = request,
        ),
      );

      final result = await oauth.changePassword(
        token: 'tok123',
        currentPassword: 'hunter2',
        newPassword: 'hunter22',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://login.divine.video/api/user/change-password',
      );
      expect(captured.headers['Authorization'], 'Bearer tok123');
      expect(jsonDecode(captured.body), {
        'current_password': 'hunter2',
        'new_password': 'hunter22',
      });
      expect(result.success, isTrue);
      expect(result.failure, isNull);
    });

    test(
      'reads a 401 as a wrong password while the token still works',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: clientFor(path, status: 401),
        );

        final result = await oauth.changePassword(
          token: 'tok123',
          currentPassword: 'wrong',
          newPassword: 'hunter22',
        );

        expect(result.success, isFalse);
        expect(result.failure, ChangePasswordFailure.wrongPassword);
      },
    );

    test(
      'reads a 401 as needing sign-in when the token is rejected too',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: clientFor(path, status: 401, accountStatusCode: 401),
        );

        final result = await oauth.changePassword(
          token: 'stale',
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        );

        expect(result.failure, ChangePasswordFailure.needsSignIn);
      },
    );

    test(
      'refuses to name a cause when the account probe cannot answer',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: clientFor(path, status: 401, accountStatusCode: 500),
        );

        final result = await oauth.changePassword(
          token: 'tok123',
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        );

        expect(result.failure, ChangePasswordFailure.unknown);
      },
    );

    test('maps a 400 to a rejected new password', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(
          path,
          status: 400,
          body: jsonEncode({
            'error': 'New password must be at least 8 characters',
          }),
        ),
      );

      final result = await oauth.changePassword(
        token: 'tok123',
        currentPassword: 'hunter2',
        newPassword: 'short',
      );

      expect(result.failure, ChangePasswordFailure.weakPassword);
      expect(result.error, 'New password must be at least 8 characters');
    });

    test('maps a 429 to rate limiting rather than a generic failure', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(path, status: 429),
      );

      final result = await oauth.changePassword(
        token: 'tok123',
        currentPassword: 'hunter2',
        newPassword: 'hunter22',
      );

      expect(result.failure, ChangePasswordFailure.rateLimited);
    });

    test('maps a 5xx to a server fault', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(path, status: 503),
      );

      final result = await oauth.changePassword(
        token: 'tok123',
        currentPassword: 'hunter2',
        newPassword: 'hunter22',
      );

      expect(result.failure, ChangePasswordFailure.server);
    });

    test('maps a transport failure to network', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: MockClient((_) async => throw const SocketishException()),
      );

      final result = await oauth.changePassword(
        token: 'tok123',
        currentPassword: 'hunter2',
        newPassword: 'hunter22',
      );

      expect(result.failure, ChangePasswordFailure.network);
    });
  });

  group('KeycastOAuth.changeEmail', () {
    const path = '/api/user/change-email';

    test('reports an account without a password', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(
          path,
          status: 400,
          body: jsonEncode({
            'error': 'no password',
            'code': 'PASSWORD_NOT_SET',
          }),
        ),
      );

      final result = await oauth.changeEmail(
        token: 'tok123',
        newEmail: 'new@example.com',
        password: 'hunter2',
      );

      expect(result.failure, ChangeEmailFailure.passwordNotSet);
    });

    test('POSTs the bearer token, the new address and the password', () async {
      late http.Request captured;
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(
          path,
          status: 200,
          body: jsonEncode({'success': true, 'message': 'Check both inboxes'}),
          onCall: (request) => captured = request,
        ),
      );

      final result = await oauth.changeEmail(
        token: 'tok123',
        newEmail: 'new@example.com',
        password: 'hunter2',
      );

      expect(captured.method, 'POST');
      expect(
        captured.url.toString(),
        'https://login.divine.video/api/user/change-email',
      );
      expect(captured.headers['Authorization'], 'Bearer tok123');
      expect(jsonDecode(captured.body), {
        'new_email': 'new@example.com',
        'password': 'hunter2',
      });
      expect(result.success, isTrue);
      expect(result.failure, isNull);
    });

    test(
      'reads a 401 as a wrong password while the token still works',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: clientFor(path, status: 401),
        );

        final result = await oauth.changeEmail(
          token: 'tok123',
          newEmail: 'new@example.com',
          password: 'wrong',
        );

        expect(result.failure, ChangeEmailFailure.wrongPassword);
      },
    );

    test(
      'reads a 401 as needing sign-in when the token is rejected too',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: clientFor(path, status: 401, accountStatusCode: 401),
        );

        final result = await oauth.changeEmail(
          token: 'stale',
          newEmail: 'new@example.com',
          password: 'hunter2',
        );

        expect(result.failure, ChangeEmailFailure.needsSignIn);
      },
    );

    test('maps a 400 to a malformed address', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(
          path,
          status: 400,
          body: jsonEncode({'error': 'Invalid email', 'code': 'INVALID_EMAIL'}),
        ),
      );

      final result = await oauth.changeEmail(
        token: 'tok123',
        newEmail: 'not-an-email',
        password: 'hunter2',
      );

      expect(result.failure, ChangeEmailFailure.invalidEmail);
    });

    test('maps a 429 to rate limiting rather than a generic failure', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(path, status: 429),
      );

      final result = await oauth.changeEmail(
        token: 'tok123',
        newEmail: 'new@example.com',
        password: 'hunter2',
      );

      expect(result.failure, ChangeEmailFailure.rateLimited);
    });

    test('maps a 5xx to a server fault', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: clientFor(path, status: 503),
      );

      final result = await oauth.changeEmail(
        token: 'tok123',
        newEmail: 'new@example.com',
        password: 'hunter2',
      );

      expect(result.failure, ChangeEmailFailure.server);
    });

    test('maps a transport failure to network', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: MockClient((_) async => throw const SocketishException()),
      );

      final result = await oauth.changeEmail(
        token: 'tok123',
        newEmail: 'new@example.com',
        password: 'hunter2',
      );

      expect(result.failure, ChangeEmailFailure.network);
    });
  });
}

/// Stands in for a transport failure without depending on `dart:io`, which the
/// package's web-capable client cannot import.
class SocketishException implements Exception {
  const SocketishException();

  @override
  String toString() => 'SocketException: connection refused';
}
