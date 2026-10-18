// ABOUTME: Tests the lifecycle wiring of the Funnelcake API client provider.
// ABOUTME: Pins that disposing the account container stops its REST retries.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
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
      final nostrClient = _MockNostrClient();
      when(() => nostrClient.configuredRelays).thenReturn(<String>[]);
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(nostrClient),
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
