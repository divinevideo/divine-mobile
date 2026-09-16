// ABOUTME: Tests the Riverpod boundary for OG Diviner eligibility lookups.
// ABOUTME: Ensures a decorative chit lookup cannot leak async errors into UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/og_diviner_eligibility_provider.dart';
import 'package:openvine/services/og_diviner_eligibility_service.dart';

void main() {
  group('ogDivinerEligibilityProvider', () {
    test('returns false when the lookup fails', () async {
      const pubkey =
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
      final service = OgDivinerEligibilityService(
        keycast: KeycastOAuth(
          config: const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'divine-mobile',
            redirectUri: 'divine://oauth/callback',
          ),
          httpClient: MockClient(
            (_) async => http.Response('unavailable', 503),
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          ogDivinerEligibilityServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(ogDivinerEligibilityProvider(pubkey).future),
        isFalse,
      );
    });
  });
}
