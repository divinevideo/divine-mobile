// ABOUTME: Pins crossposter auth to NIP-98 and Keycast auth to the bound token
// ABOUTME: Guards provider wiring against leaking the Keycast token off-host

import 'dart:convert';
import 'dart:io' show HttpDate;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/crossposting_providers.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/crosspost_api_client.dart';
import 'package:openvine/services/crossposting_api_client.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('crosspostingApiClientProvider', () {
    late _MockAuthService auth;
    late http.Client httpClient;
    late List<http.Request> requests;
    late bool signerAvailable;

    const ownerPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const eventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaa';

    setUp(() {
      auth = _MockAuthService();
      requests = [];
      httpClient = MockClient((request) async {
        requests.add(request);
        return http.Response(jsonEncode({'jobs': []}), 200);
      });
      signerAvailable = true;
      when(() => auth.isAuthenticated).thenReturn(true);
      when(() => auth.currentPublicKeyHex).thenReturn(ownerPubkey);
      when(
        () => auth.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
          allowUserInteraction: false,
        ),
      ).thenAnswer((invocation) async {
        if (!signerAvailable) return null;
        return Event.fromJson({
          'id': 'ab' * 32,
          'kind': 27235,
          'pubkey': ownerPubkey,
          'created_at': invocation.namedArguments[#createdAt] as int,
          'content': '',
          'tags': invocation.namedArguments[#tags] as List<List<String>>,
          'sig': 'cd' * 64,
        });
      });
    });

    ProviderContainer buildContainer() {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          instrumentedHttpClientFactoryProvider.overrideWithValue(
            () => httpClient,
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // The crossposter only needs identity. A Keycast access token can sign
    // arbitrary events, so it must never leave the device for this service.
    test(
      'authenticates with a NIP-98 event and never the Keycast token',
      () async {
        final client = buildContainer().read(crosspostingApiClientProvider);
        await client.getCrossposts(eventId: eventId);

        verify(
          () => auth.createAndSignEvent(
            kind: 27235,
            content: '',
            tags: any(named: 'tags'),
            createdAt: any(named: 'createdAt'),
            allowUserInteraction: false,
          ),
        ).called(1);
        verifyNever(auth.getBoundDivineAccessToken);
        final headers = requests.single.headers;
        final authorization = headers['Authorization']!;
        expect(authorization, startsWith('Nostr '));
        final event = jsonDecode(
          utf8.decode(
            base64.decode(authorization.substring('Nostr '.length)),
          ),
        ) as Map<String, dynamic>;
        expect(event['kind'], equals(27235));
        expect(event['pubkey'], equals(ownerPubkey));
      },
    );

    test('refuses to send when the signer cannot sign', () async {
      signerAvailable = false;

      final client = buildContainer().read(crosspostingApiClientProvider);

      await expectLater(
        client.getCrossposts(eventId: eventId),
        throwsA(isA<CrosspostingPassiveSigningUnavailable>()),
      );
      expect(requests, isEmpty);
    });

    // A poll re-signs after a timestamp rejection through the passive
    // transport, so the clock correction cannot open a signer prompt either.
    test('re-signs a clock-skew retry without user interaction', () async {
      httpClient = MockClient((request) async {
        requests.add(request);
        if (requests.length == 1) {
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'unauthorized',
                'message': 'nostr auth event is expired or from the future',
              },
            }),
            401,
            headers: {'date': HttpDate.format(DateTime.now().toUtc())},
          );
        }
        return http.Response(jsonEncode({'jobs': []}), 200);
      });

      final client = buildContainer().read(crosspostingApiClientProvider);

      expect(await client.getCrossposts(eventId: eventId), isEmpty);
      expect(requests, hasLength(2));
      verify(
        () => auth.createAndSignEvent(
          kind: 27235,
          content: '',
          tags: any(named: 'tags'),
          createdAt: any(named: 'createdAt'),
          allowUserInteraction: false,
        ),
      ).called(2);
    });
  });

  group('crosspostApiClientProvider', () {
    test('authenticates with the account-bound Divine token', () async {
      final auth = _MockAuthService();
      final httpClient = _MockHttpClient();
      when(
        auth.getBoundDivineAccessToken,
      ).thenAnswer((_) async => 'owner-bound-token');
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async =>
            http.Response(jsonEncode({'enabled': false, 'state': null}), 200),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          instrumentedHttpClientFactoryProvider.overrideWithValue(
            () => httpClient,
          ),
        ],
      );
      addTearDown(container.dispose);

      final client = container.read(crosspostApiClientProvider);
      expect(client, isA<CrosspostApiClient>());
      await client.getStatus();

      verify(auth.getBoundDivineAccessToken).called(1);
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
  });
}
