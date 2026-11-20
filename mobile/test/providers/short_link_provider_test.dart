// ABOUTME: Verifies native sharing shortens without feature flags or login and disposes its cache.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/short_link_provider.dart';

void main() {
  const target = 'https://divine.video/video/synthetic-provider-check';
  const shortened = 'https://divine.video/l/Abc12345';

  group('shortLinkClientProvider', () {
    test('web builds keep full URLs without creating an HTTP client', () {
      final container = ProviderContainer(
        overrides: [
          shortLinkIsWebProvider.overrideWithValue(true),
          instrumentedHttpClientFactoryProvider.overrideWith(
            (ref) => throw StateError('web must not create an HTTP client'),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(shortLinkClientProvider), isNull);
    });

    test(
      'creates short links without feature flags or authentication',
      () async {
        var requests = 0;
        final container = ProviderContainer(
          overrides: [
            featureFlagServiceProvider.overrideWith(
              (ref) => throw StateError('feature flags must not be read'),
            ),
            authServiceProvider.overrideWith(
              (ref) => throw StateError('login must not be read'),
            ),
            currentAuthStateProvider.overrideWith(
              () => throw StateError('account state must not be read'),
            ),
            instrumentedHttpClientFactoryProvider.overrideWithValue(
              () => MockClient((request) async {
                requests++;
                expect(request.headers.containsKey('Authorization'), isFalse);
                expect(jsonDecode(request.body), {'url': target});
                return http.Response(
                  jsonEncode({
                    'code': 'Abc12345',
                    'short_url': shortened,
                    'url': target,
                  }),
                  201,
                );
              }),
            ),
          ],
        );
        addTearDown(container.dispose);
        final client = container.read(shortLinkClientProvider);
        expect(client, isNotNull);
        expect(await client!.shorten(target), shortened);
        expect(await client.shorten(target), shortened);
        expect(requests, 1);
        container.invalidate(shortLinkClientProvider);
        expect(await client.shorten(target), target);
        expect(
          await container.read(shortLinkClientProvider)!.shorten(target),
          shortened,
        );
        expect(requests, 2);
      },
    );
  });
}
