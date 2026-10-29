// ABOUTME: Verifies anonymous creation, disabled behavior and cache disposal at the provider boundary.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/short_link_provider.dart';

void main() {
  const target = 'https://divine.video/video/synthetic-provider-check';
  const shortened = 'https://divine.video/l/Abc12345';

  test('disabled sharing does not construct auth or HTTP', () {
    final container = ProviderContainer(
      overrides: [
        isFeatureEnabledProvider(FeatureFlag.shortLinksSharing)
            .overrideWithValue(false),
        authServiceProvider.overrideWith(
          (ref) => throw StateError('auth must not be read'),
        ),
        instrumentedHttpClientFactoryProvider.overrideWith(
          (ref) => throw StateError('HTTP must not be created'),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(shortLinkClientProvider), isNull);
  });

  test(
    'creates short links without reading authentication providers',
    () async {
      var requests = 0;
      final container = ProviderContainer(
        overrides: [
          isFeatureEnabledProvider(FeatureFlag.shortLinksSharing)
              .overrideWithValue(true),
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
}
