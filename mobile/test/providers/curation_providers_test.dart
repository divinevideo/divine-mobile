// ABOUTME: Tests environment routing and lifecycle of the Funnelcake API client.
// ABOUTME: Pins API availability and disposal of in-flight REST retries.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/app_version_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/service_providers.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  group('Funnelcake API routing', () {
    for (final environment in AppEnvironment.values) {
      for (final relays in <List<String>>[
        [],
        ['wss://relay.example'],
        ['wss://relay.divine.video'],
        ['wss://relay.example', 'wss://relay.divine.video'],
      ]) {
        test('uses $environment API with relay preferences $relays', () async {
          final config = EnvironmentConfig(environment: environment);
          final nostrClient = _MockNostrClient();
          when(() => nostrClient.configuredRelays).thenReturn(relays);
          final requests = <Uri>[];
          final container = ProviderContainer(
            overrides: [
              nostrServiceProvider.overrideWithValue(nostrClient),
              currentEnvironmentProvider.overrideWithValue(config),
              appVersionProvider.overrideWithValue('1.0.0'),
              instrumentedHttpClientFactoryProvider.overrideWithValue(
                () => MockClient((request) async {
                  requests.add(request.url);
                  return http.Response('{"data":[]}', 200);
                }),
              ),
            ],
          );
          addTearDown(container.dispose);
          final client = container
              .listen(funnelcakeApiClientProvider, (_, _) {})
              .read();

          await client.getRecentVideos(limit: 1);

          expect(client.baseUrl, equals(config.apiBaseUrl));
          expect(requests, hasLength(1));
          expect(requests.single.origin, equals(config.apiBaseUrl));
          expect(
            await container.read(funnelcakeAvailableProvider.future),
            isTrue,
          );
          final probes = switch (environment) {
            AppEnvironment.production || AppEnvironment.staging => 0,
            AppEnvironment.poc || AppEnvironment.local => 1,
          };
          expect(requests, hasLength(1 + probes));
          expect(
            requests.map((url) => url.origin),
            everyElement(config.apiBaseUrl),
          );
        });
      }
    }

    test(
      'environment changes rebuild the client and availability together',
      () async {
        final nostrClient = _MockNostrClient();
        when(() => nostrClient.configuredRelays).thenReturn([
          'wss://relay.divine.video',
        ]);
        final requests = <Uri>[];
        final fixedOverrides = [
          nostrServiceProvider.overrideWithValue(nostrClient),
          appVersionProvider.overrideWithValue('1.0.0'),
          instrumentedHttpClientFactoryProvider.overrideWithValue(
            () => MockClient((request) async {
              requests.add(request.url);
              return http.Response('{"data":[]}', 200);
            }),
          ),
        ];
        final container = ProviderContainer(
          overrides: [
            ...fixedOverrides,
            currentEnvironmentProvider.overrideWithValue(
              EnvironmentConfig.production,
            ),
          ],
        );
        addTearDown(container.dispose);
        final clientSubscription = container.listen(
          funnelcakeApiClientProvider,
          (_, _) {},
        );
        final original = clientSubscription.read();
        expect(
          original.baseUrl,
          equals(EnvironmentConfig.production.apiBaseUrl),
        );
        expect(
          await container.read(funnelcakeAvailableProvider.future),
          isTrue,
        );

        const local = EnvironmentConfig(environment: AppEnvironment.local);
        container.updateOverrides([
          ...fixedOverrides,
          currentEnvironmentProvider.overrideWithValue(local),
        ]);
        await container.pump();

        final switched = clientSubscription.read();
        expect(switched, isNot(same(original)));
        expect(switched.baseUrl, equals(local.apiBaseUrl));
        expect(
          await container.read(funnelcakeAvailableProvider.future),
          isTrue,
        );
        expect(requests, isNotEmpty);
        expect(
          requests.map((url) => url.origin),
          everyElement(local.apiBaseUrl),
        );
      },
    );
  });

  group('funnelcakeApiClientProvider', () {
    const videoId =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    late _MockHttpClient httpClient;
    late int sends;
    late Completer<http.Response> firstSend;

    setUp(() {
      sends = 0;
      firstSend = Completer<http.Response>();
      httpClient = _MockHttpClient();
      when(httpClient.close).thenReturn(null);
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) {
        sends++;
        if (sends == 1) return firstSend.future;
        // What a closed IOClient throws, before any I/O.
        throw http.ClientException(
          'HTTP request failed. Client is already closed.',
        );
      });
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          currentEnvironmentProvider.overrideWithValue(
            EnvironmentConfig.production,
          ),
          appVersionProvider.overrideWithValue('1.0.0'),
          instrumentedHttpClientFactoryProvider.overrideWithValue(
            () => httpClient,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // An in-place account switch disposes the outgoing container while its
    // feed's first request is still out (#10291).
    test('disposing the container stops retrying a request it cut '
        'off', () async {
      final container = createContainer();
      final client = container
          .listen(funnelcakeApiClientProvider, (_, _) {})
          .read();

      final fetching = client.getVideoEvent(videoId);
      await pumpEventQueue();
      expect(sends, equals(1));

      container.dispose();
      firstSend.completeError(
        http.ClientException('Connection closed while receiving data'),
      );

      await expectLater(fetching, throwsA(isA<FunnelcakeException>()));
      expect(sends, equals(1));
      verify(httpClient.close).called(1);
    });
  });
}
