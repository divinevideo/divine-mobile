// ABOUTME: Tests for KeycastOAuth.exportKey over HTTP
// ABOUTME: Covers the POST /user/export-key contract and its refusal mapping

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/oauth/headless_models.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';

void main() {
  group('KeycastOAuth.exportKey', () {
    const config = OAuthConfig(
      serverUrl: 'https://login.divine.video',
      clientId: 'test-client',
      redirectUri: 'divine://oauth/callback',
    );

    const nsec =
        'nsec1testkeymaterialthatisnotarealkey00000000000000000000000000';

    /// The account state behind the token, as `GET /api/user/account` reports
    /// it. Every refusal that HTTP alone cannot classify is resolved from this.
    String accountBody({
      bool emailVerified = true,
      bool verifiedMinor = false,
    }) => jsonEncode({
      'email': 'a@b.com',
      'email_verified': emailVerified,
      'public_key': 'abc',
      'verified_minor': verifiedMinor,
    });

    /// A client that answers export-key with [status]/[body] and account-status
    /// with [accountStatusCode]/[account], so both overloaded refusal codes can
    /// be driven.
    MockClient exportClient({
      required int status,
      required String body,
      int accountStatusCode = 200,
      String? account,
      void Function(http.Request request)? onExport,
    }) {
      return MockClient((request) async {
        if (request.url.path == '/api/user/export-key') {
          onExport?.call(request);
          return http.Response(body, status);
        }
        if (request.url.path == '/api/user/account') {
          return http.Response(account ?? accountBody(), accountStatusCode);
        }
        return http.Response('unexpected ${request.url.path}', 404);
      });
    }

    test('reports an account without a password before probing it', () async {
      var probed = false;
      final oauth = KeycastOAuth(
        config: config,
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/user/account') probed = true;
          return http.Response(
            jsonEncode({'error': 'no password', 'code': 'PASSWORD_NOT_SET'}),
            403,
          );
        }),
      );

      final result = await oauth.exportKey('tok123', 'hunter2');

      expect(result.failure, ExportKeyFailure.passwordNotSet);
      expect(probed, isFalse);
    });

    test(
      'POSTs the bearer token, password and format, and returns the key',
      () async {
        late http.Request captured;
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: 200,
            body: jsonEncode({'key': nsec}),
            onExport: (request) => captured = request,
          ),
        );

        final result = await oauth.exportKey('tok123', 'hunter2');

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://login.divine.video/api/user/export-key',
        );
        expect(captured.headers['Authorization'], 'Bearer tok123');
        expect(jsonDecode(captured.body), {
          'password': 'hunter2',
          'format': 'nsec',
        });
        expect(result.success, isTrue);
        expect(result.key, nsec);
        expect(result.failure, isNull);
      },
    );

    test(
      'treats a 200 with no key as a failure rather than an empty key',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(status: 200, body: '{}'),
        );

        final result = await oauth.exportKey('tok', 'pw');

        expect(result.success, isFalse);
        expect(result.key, isNull);
        expect(result.failure, ExportKeyFailure.unknown);
      },
    );

    // Keycast answers 401 for a wrong password and for a stale token alike, so
    // these two pin the only thing that separates them.
    test('reads 401 as a wrong password while the token still works', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 401,
          body: jsonEncode({'error': 'Invalid email or password.'}),
        ),
      );

      final result = await oauth.exportKey('tok', 'wrong');

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.wrongPassword);
    });

    test('reads 401 as needing sign-in when the token is dead too', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 401,
          body: jsonEncode({'error': 'Invalid or expired token.'}),
          accountStatusCode: 401,
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.needsSignIn);
    });

    // 403 is as overloaded as 401, and the server's two bodies are English
    // prose it owns — the same wording it can reword or translate per
    // deployment. These pin that the split comes from the account state.
    test('separates the two 403s on account state, not on the body', () async {
      // Both accounts get the *same* refusal body, so a classifier that read
      // the prose could not tell them apart at all.
      const body = 'Please verify your email address before continuing.';

      final unverified = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 403,
          body: jsonEncode({'error': body}),
          account: accountBody(emailVerified: false),
        ),
      );

      expect(
        (await unverified.exportKey('tok', 'pw')).failure,
        ExportKeyFailure.emailUnverified,
      );

      final denied = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 403,
          body: jsonEncode({'error': body}),
          account: accountBody(verifiedMinor: true),
        ),
      );

      expect(
        (await denied.exportKey('tok', 'pw')).failure,
        ExportKeyFailure.denied,
      );
    });

    // The server refuses a minor before it looks at the email, so a minor whose
    // email is also unverified must not be told to go and verify it — that
    // would promise an export that verifying can never unlock.
    test('reads a minor with an unverified email as a policy denial', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 403,
          body: jsonEncode({'error': 'Operation denied by policy'}),
          account: accountBody(emailVerified: false, verifiedMinor: true),
        ),
      );

      expect(
        (await oauth.exportKey('tok', 'pw')).failure,
        ExportKeyFailure.denied,
      );
    });

    test(
      'does not guess which 403 it was when the probe cannot answer',
      () async {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: 403,
            body: jsonEncode({'error': 'Operation denied by policy'}),
            accountStatusCode: 503,
          ),
        );

        expect(
          (await oauth.exportKey('tok', 'pw')).failure,
          ExportKeyFailure.unknown,
        );
      },
    );

    // The probe is the only thing separating the two 401s, so a probe that
    // never answered must not be reported as either verdict.
    test('does not read an unanswerable probe as a dead session', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 401,
          body: jsonEncode({'error': 'Invalid email or password.'}),
          accountStatusCode: 503,
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.failure, ExportKeyFailure.unknown);
    });

    // A 200 the parser cannot read leaves the 403 as unresolved as an
    // unanswerable probe does. Reporting it as the custody denial would tell a
    // user Divine manages their keys on a response that proves neither cause.
    test('does not read an unreadable account body as a denial', () async {
      for (final body in const ['not json', '[1,2]', '"a string"']) {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: 403,
            body: jsonEncode({'error': 'Operation not permitted.'}),
            account: body,
          ),
        );

        expect(
          (await oauth.exportKey('tok', 'pw')).failure,
          ExportKeyFailure.unknown,
          reason: 'account body $body',
        );
      }
    });

    test('maps 404 to no key on record', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 404,
          body: jsonEncode({'error': 'No account found with this email.'}),
        ),
      );

      expect(
        (await oauth.exportKey('tok', 'pw')).failure,
        ExportKeyFailure.noKey,
      );
    });

    // Waiting is the remedy here and nothing else on this endpoint, so it must
    // not land in the generic bucket that tells the user to try again now.
    test('maps 429 to a rate limit', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 429,
          body: jsonEncode({'error': 'Too many requests'}),
        ),
      );

      expect(
        (await oauth.exportKey('tok', 'pw')).failure,
        ExportKeyFailure.rateLimited,
      );
    });

    test('maps 5xx to a server failure', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: exportClient(
          status: 503,
          body: jsonEncode({'error': 'Service temporarily unavailable.'}),
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.failure, ExportKeyFailure.server);
      expect(result.error, contains('Service temporarily unavailable'));
    });

    test('maps a transport failure to network', () async {
      final oauth = KeycastOAuth(
        config: config,
        httpClient: MockClient(
          (_) async => throw http.ClientException('connection reset'),
        ),
      );

      final result = await oauth.exportKey('tok', 'pw');

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.network);
    });

    test('never returns a key on any failure path', () async {
      for (final status in [400, 401, 403, 404, 429, 500, 503]) {
        final oauth = KeycastOAuth(
          config: config,
          httpClient: exportClient(
            status: status,
            // A server that wrongly echoes key material must not leak it
            // through a failure result.
            body: jsonEncode({'error': 'nope', 'key': nsec}),
          ),
        );

        final result = await oauth.exportKey('tok', 'pw');

        expect(result.success, isFalse, reason: 'status $status');
        expect(result.key, isNull, reason: 'status $status');
      }
    });
  });
}
