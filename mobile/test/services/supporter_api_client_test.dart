// ABOUTME: Contract tests for the NIP-98 authenticated supporter Worker client.
// ABOUTME: Verifies canonical response mapping and typed failure boundaries.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/nip98_auth_service.dart';
import 'package:openvine/services/supporter_api_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient httpClient;
  late List<({String url, HttpMethod method, String? payload})> authCalls;

  SupporterApiClient buildClient() => SupporterApiClient(
    baseUri: Uri.parse('https://supporters.test'),
    httpClient: httpClient,
    authHeaderProvider: ({required url, required method, payload}) async {
      authCalls.add((url: url, method: method, payload: payload));
      return (
        authorizationHeader: 'Nostr test-token',
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      );
    },
  );

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://supporters.test/fallback'));
  });

  setUp(() {
    httpClient = _MockHttpClient();
    authCalls = [];
  });

  tearDown(() => httpClient.close());

  group('SupporterApiClient methods', () {
    test(
      'fetchMe signs the exact Worker URL and maps canonical state',
      () async {
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'status': 'grace',
              'entitlement': {
                'productId': 'divine.supporter.annual',
                'source': 'server',
                'purchaseDate': '2026-07-01T00:00:00.000Z',
                'expirationDate': '2026-08-01T00:00:00.000Z',
                'isActive': true,
              },
              'paidThroughAt': '2026-08-01T00:00:00.000Z',
              'graceThroughAt': '2026-08-08T00:00:00.000Z',
              'recognition': {
                'haloVisible': true,
                'discoveryVisible': false,
                'foundingHistoryVisible': false,
              },
              'foundingSupporter': false,
              'experimentalTrials': ['supporter_showcase'],
            }),
            200,
          ),
        );

        final snapshot = await buildClient().fetchMe(
          expectedPubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );

        expect(snapshot.status, SupporterServerStatus.grace);
        expect(snapshot.entitlement.productId, 'divine.supporter.annual');
        expect(snapshot.haloVisible, isTrue);
        expect(snapshot.experimentalTrials, ['supporter_showcase']);
        expect(authCalls.single.url, 'https://supporters.test/v1/me');
        expect(authCalls.single.method, HttpMethod.get);
        verify(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).called(1);
      },
    );

    test(
      'claim sends idempotency key and opaque proof without changing it',
      () async {
        late String requestBody;
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) async {
          requestBody = invocation.namedArguments[#body] as String;
          return http.Response(
            jsonEncode({
              'status': 'active',
              'entitlement': {
                'productId': 'divine.supporter.monthly',
                'source': 'server',
                'isActive': true,
              },
              'recognition': {},
            }),
            200,
          );
        });

        final proof = {'signed_payload': 'opaque-proof-material'};
        await buildClient().claimPurchase(
          SupporterPurchaseClaim(
            store: 'apple',
            productId: 'divine.supporter.monthly',
            idempotencyKey: 'attempt-1234567890',
            proof: proof,
          ),
          expectedPubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );

        expect(jsonDecode(requestBody), {
          'store': 'apple',
          'product_id': 'divine.supporter.monthly',
          'idempotency_key': 'attempt-1234567890',
          'proof': proof,
        });
        expect(authCalls.single.method, HttpMethod.post);
        expect(authCalls.single.payload, requestBody);
      },
    );

    test('rejects a claim signed by a different account', () async {
      final client = SupporterApiClient(
        baseUri: Uri.parse('https://supporters.test'),
        httpClient: httpClient,
        authHeaderProvider: ({required url, required method, payload}) async =>
            (
              authorizationHeader: 'Nostr stale-token',
              pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            ),
      );

      await expectLater(
        client.claimPurchase(
          const SupporterPurchaseClaim(
            store: 'apple',
            productId: 'divine.supporter.monthly',
            idempotencyKey: 'attempt-1234567890',
            proof: {'signed_payload': 'opaque-proof-material'},
          ),
          expectedPubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        throwsA(
          isA<SupporterApiException>().having(
            (error) => error.kind,
            'kind',
            SupporterApiFailureKind.unauthorized,
          ),
        ),
      );
      verifyNever(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });

    test(
      'rejects reads and preference writes signed by another account',
      () async {
        final client = SupporterApiClient(
          baseUri: Uri.parse('https://supporters.test'),
          httpClient: httpClient,
          authHeaderProvider:
              ({required url, required method, payload}) async => (
                authorizationHeader: 'Nostr stale-token',
                pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
              ),
        );
        const expectedPubkey =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

        await expectLater(
          client.fetchMe(expectedPubkey: expectedPubkey),
          throwsA(isA<SupporterApiException>()),
        );
        await expectLater(
          client.updateRecognition(
            expectedPubkey: expectedPubkey,
            haloVisible: true,
            discoveryVisible: false,
            foundingHistoryVisible: false,
          ),
          throwsA(isA<SupporterApiException>()),
        );
        verifyNever(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        );
        verifyNever(
          () => httpClient.patch(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        );
      },
    );

    test('maps ownership conflict to a typed API failure', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'ownership_conflict'},
          }),
          409,
        ),
      );

      await expectLater(
        buildClient().claimPurchase(
          const SupporterPurchaseClaim(
            store: 'google',
            productId: 'divine.supporter.annual',
            idempotencyKey: 'attempt-1234567890',
            proof: {'purchase_token': 'opaque'},
          ),
          expectedPubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        throwsA(
          isA<SupporterApiException>().having(
            (error) => error.kind,
            'kind',
            SupporterApiFailureKind.ownershipConflict,
          ),
        ),
      );
    });

    test('treats a claim already in progress as retryable', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'error': {'code': 'claim_in_progress'},
          }),
          409,
        ),
      );

      await expectLater(
        buildClient().claimPurchase(
          const SupporterPurchaseClaim(
            store: 'apple',
            productId: 'divine.supporter.monthly',
            idempotencyKey: 'attempt-1234567890',
            proof: {'signed_payload': 'opaque-proof-material'},
          ),
          expectedPubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        throwsA(
          isA<SupporterApiException>().having(
            (error) => error.kind,
            'kind',
            SupporterApiFailureKind.unavailable,
          ),
        ),
      );
    });
  });
}
