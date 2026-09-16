// ABOUTME: Tests in-memory caching of server-computed OG Diviner eligibility.
// ABOUTME: Ensures repeated profile renders do not repeat network requests.

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/og_diviner_eligibility_service.dart';
import 'package:test/test.dart';

void main() {
  const pubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
  const config = OAuthConfig(
    serverUrl: 'https://login.divine.video',
    clientId: 'divine-mobile',
    redirectUri: 'divine://oauth/callback',
  );

  group('isEligible', () {
    test('fetches once and reuses the result in memory', () async {
      var requests = 0;
      final service = OgDivinerEligibilityService(
        keycast: KeycastOAuth(
          config: config,
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{"eligible":true}', 200);
          }),
        ),
      );

      expect(await service.isEligible(pubkey), isTrue);
      expect(await service.isEligible(pubkey.toUpperCase()), isTrue);
      expect(requests, 1);
    });

    test('coalesces concurrent requests for the same pubkey', () async {
      var requests = 0;
      final service = OgDivinerEligibilityService(
        keycast: KeycastOAuth(
          config: config,
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{"eligible":true}', 200);
          }),
        ),
      );

      expect(
        await Future.wait([
          service.isEligible(pubkey),
          service.isEligible(pubkey),
        ]),
        [true, true],
      );
      expect(requests, 1);
    });

    test('does not cache a failed request', () async {
      var requests = 0;
      final service = OgDivinerEligibilityService(
        keycast: KeycastOAuth(
          config: config,
          httpClient: MockClient((_) async {
            requests++;
            if (requests == 1) return http.Response('unavailable', 503);
            return http.Response('{"eligible":true}', 200);
          }),
        ),
      );

      await expectLater(
        service.isEligible(pubkey),
        throwsA(isA<http.ClientException>()),
      );
      expect(await service.isEligible(pubkey), isTrue);
      expect(requests, 2);
    });
  });
}
