// ABOUTME: Tests the privacy-preserving OG Diviner eligibility lookup.
// ABOUTME: Verifies response validation without exposing signup timestamps.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';

void main() {
  const pubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
  const config = OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'divine-mobile',
    redirectUri: 'divine://oauth/callback',
  );

  test('returns the server-computed eligibility boolean', () async {
    final oauth = KeycastOAuth(
      config: config,
      httpClient: MockClient((request) async {
        expect(
          request.url,
          Uri.parse(
            'https://login.divine.video/api/public/users/$pubkey/og-diviner',
          ),
        );
        return http.Response('{"eligible":true}', 200);
      }),
    );

    expect(await oauth.isOgDiviner(pubkey.toUpperCase()), isTrue);
  });

  test('rejects a malformed eligibility response', () async {
    final oauth = KeycastOAuth(
      config: config,
      httpClient: MockClient(
        (_) async => http.Response('{"eligible":"yes"}', 200),
      ),
    );

    expect(oauth.isOgDiviner(pubkey), throwsFormatException);
  });

  test('rejects a failed eligibility response', () async {
    final oauth = KeycastOAuth(
      config: config,
      httpClient: MockClient((_) async => http.Response('not found', 404)),
    );

    expect(oauth.isOgDiviner(pubkey), throwsA(isA<http.ClientException>()));
  });
}
