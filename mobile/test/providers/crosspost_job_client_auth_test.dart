// ABOUTME: Pins the crosspost job client to the account-bound Divine token
// ABOUTME: Guards against regressing to a raw, unbound Keycast session read

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group('crossposterApiClientProvider', () {
    late _MockAuthService auth;
    late _MockHttpClient httpClient;

    const eventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaa';

    setUpAll(() {
      registerFallbackValue(Uri());
    });

    setUp(() {
      auth = _MockAuthService();
      httpClient = _MockHttpClient();
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(jsonEncode({'jobs': []}), 200));
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          instrumentedHttpClientFactoryProvider.overrideWithValue(
            () => httpClient,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // The publishing path must not read the Keycast session directly.
    // getBoundDivineAccessToken re-checks the owner pubkey across its await
    // and refreshes through the process-wide single-flight coordinator, so a
    // raw session read can hand this client another account's token or race
    // Keycast's rotating refresh (#7802).
    test('authenticates with the account-bound Divine token', () async {
      when(
        () => auth.getBoundDivineAccessToken(),
      ).thenAnswer((_) async => 'owner-bound-token');

      final client = buildContainer().read(crossposterApiClientProvider);
      await client.getCrossposts(eventId: eventId);

      verify(() => auth.getBoundDivineAccessToken()).called(1);
      final headers =
          verify(
                () => httpClient.get(
                  any(),
                  headers: captureAny(named: 'headers'),
                ),
              ).captured.single
              as Map<String, String>;
      expect(headers['Authorization'], equals('Bearer owner-bound-token'));
    });

    test(
      'refuses to publish when no account-bound token is available',
      () async {
        when(
          () => auth.getBoundDivineAccessToken(),
        ).thenAnswer((_) async => null);

        final client = buildContainer().read(crossposterApiClientProvider);

        await expectLater(
          client.getCrossposts(eventId: eventId),
          throwsA(
            isA<CrosspostingApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.code, 'code', 'unauthorized'),
          ),
        );
        verifyNever(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        );
      },
    );
  });
}
