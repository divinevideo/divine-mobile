// ABOUTME: Tests for KeycastAccountStatus parsing and getAccountStatus over HTTP
// ABOUTME: Covers the GET /user/account verified_minor contract (keycast#263)

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/src/oauth/account_status.dart';
import 'package:keycast_flutter/src/oauth/oauth_client.dart';
import 'package:keycast_flutter/src/oauth/oauth_config.dart';

void main() {
  group('KeycastAccountStatus.fromJson', () {
    test('parses an approved minor with timestamp', () {
      final status = KeycastAccountStatus.fromJson({
        'email': 'a@b.com',
        'email_verified': true,
        'public_key': 'abc',
        'verified_minor': true,
        'verified_minor_at': '2026-06-30T12:00:00Z',
      });

      expect(status.verifiedMinor, isTrue);
      expect(status.verifiedMinorReported, isTrue);
      expect(status.verifiedMinorAt, DateTime.utc(2026, 6, 30, 12));
      expect(status.email, 'a@b.com');
      expect(status.emailVerified, isTrue);
      expect(status.publicKey, 'abc');
    });

    test('defaults verified_minor false and timestamp null when absent', () {
      final status = KeycastAccountStatus.fromJson({
        'email': 'a@b.com',
        'email_verified': false,
        'public_key': 'abc',
      });

      expect(status.verifiedMinor, isFalse);
      expect(status.verifiedMinorReported, isFalse);
      expect(status.verifiedMinorAt, isNull);
    });

    test('reports an explicit verified_minor false', () {
      final status = KeycastAccountStatus.fromJson({
        'email': 'a@b.com',
        'email_verified': true,
        'public_key': 'abc',
        'verified_minor': false,
      });

      expect(status.verifiedMinor, isFalse);
      expect(status.verifiedMinorReported, isTrue);
    });

    test('does not report a verified_minor that is not a boolean', () {
      final status = KeycastAccountStatus.fromJson({
        'email': 'a@b.com',
        'email_verified': true,
        'public_key': 'abc',
        'verified_minor': 'false',
      });

      expect(status.verifiedMinor, isFalse);
      expect(status.verifiedMinorReported, isFalse);
    });

    test('keeps verified_minor true but null timestamp on a bad date', () {
      final status = KeycastAccountStatus.fromJson({
        'email': 'a@b.com',
        'email_verified': true,
        'public_key': 'abc',
        'verified_minor': true,
        'verified_minor_at': 'not-a-date',
      });

      expect(status.verifiedMinor, isTrue);
      expect(status.verifiedMinorAt, isNull);
    });
  });

  group('KeycastOAuth.getAccountStatus', () {
    const config = OAuthConfig(
      serverUrl: 'https://login.divine.video',
      clientId: 'test-client',
      redirectUri: 'divine://oauth/callback',
    );

    test(
      'GETs /api/user/account with bearer token and parses the flag',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            '{"email":"a@b.com","email_verified":true,"public_key":"abc",'
            '"verified_minor":true,"verified_minor_at":"2026-06-30T12:00:00Z"}',
            200,
          );
        });
        final oauth = KeycastOAuth(config: config, httpClient: client);

        final status = await oauth.getAccountStatus('tok123');

        expect(captured.method, 'GET');
        expect(
          captured.url.toString(),
          'https://login.divine.video/api/user/account',
        );
        expect(captured.headers['Authorization'], 'Bearer tok123');
        expect(status, isNotNull);
        expect(status!.verifiedMinor, isTrue);
      },
    );

    test('returns null on server error', () async {
      final client = MockClient((request) async => http.Response('err', 500));
      final oauth = KeycastOAuth(config: config, httpClient: client);

      final status = await oauth.getAccountStatus('tok');

      expect(status, isNull);
    });
  });
}
