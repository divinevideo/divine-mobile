// ABOUTME: Tests the Riverpod boundary for OG Diviner eligibility lookups.
// ABOUTME: Ensures a decorative chit lookup cannot leak async errors into UI.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/og_diviner_eligibility_provider.dart';
import 'package:openvine/services/og_diviner_eligibility_service.dart';

class _EligibilityService extends Mock implements OgDivinerEligibilityService {}

void main() {
  const pubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  group('ogDivinerEligibilityProvider', () {
    test('returns false when the lookup fails', () async {
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

    test('does not amplify a failed optional badge lookup with retries', () {
      fakeAsync((async) {
        final service = _EligibilityService();
        when(() => service.isEligible(pubkey)).thenAnswer(
          (_) async => throw http.ClientException('unavailable'),
        );
        final container = ProviderContainer(
          overrides: [
            ogDivinerEligibilityServiceProvider.overrideWithValue(service),
          ],
        );
        final subscription = container.listen(
          ogDivinerEligibilityProvider(pubkey),
          (_, _) {},
        );
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 2));

        expect(
          container.read(ogDivinerEligibilityProvider(pubkey)).value,
          isFalse,
        );
        verify(() => service.isEligible(pubkey)).called(1);
        subscription.close();
        container.dispose();
      });
    });

    test('a later visit can recover from a failed lookup', () async {
      final service = _EligibilityService();
      when(() => service.isEligible(pubkey)).thenAnswer(
        (_) async => throw http.ClientException('offline'),
      );
      final container = ProviderContainer(
        overrides: [
          ogDivinerEligibilityServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final provider = ogDivinerEligibilityProvider(pubkey);
      final firstVisit = container.listen(provider, (_, _) {});
      expect(await container.read(provider.future), isFalse);
      firstVisit.close();
      await container.pump();

      when(() => service.isEligible(pubkey)).thenAnswer((_) async => true);
      final secondVisit = container.listen(provider, (_, _) {});
      addTearDown(secondVisit.close);
      expect(await container.read(provider.future), isTrue);
      verify(() => service.isEligible(pubkey)).called(2);
    });
  });
}
