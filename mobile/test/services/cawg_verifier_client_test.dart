import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/cawg_verifier_client.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient mockHttpClient;
  late CawgVerifierClient client;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://verifyer.divine.video'));
  });

  setUp(() {
    mockHttpClient = _MockHttpClient();
    client = CawgVerifierClient(
      httpClient: mockHttpClient,
      baseUri: Uri.parse('https://verifyer.divine.video'),
      timeout: const Duration(milliseconds: 50),
    );
  });

  group('CawgVerifierClient.verifyClaims', () {
    test('parses a successful CAWG issuance response', () async {
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode(<String, dynamic>{
            'issuer': 'verifyer.divine.video',
            'status': 'verified',
            'verified_claims': <Map<String, String>>[
              <String, String>{
                'type': 'nip05',
                'value': 'alice@example.com',
                'method': 'nip05_dns',
                'verified_at': '2026-03-29T08:35:00Z',
              },
            ],
            'identity_assertion_label': 'cawg.identity',
            'identity_assertion_payload': <String, dynamic>{
              'issuer': 'verifyer.divine.video',
            },
          }),
          200,
        ),
      );

      const request = VerifierClaimRequest(
        pubkey:
            '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
        nip05: 'alice@example.com',
        creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
        creatorBindingPayloadJson: '{"version":1}',
      );

      final bundle = await client.verifyClaims(request);

      expect(bundle, isNotNull);
      expect(bundle!.issuer, equals('verifyer.divine.video'));
      expect(bundle.status, equals('verified'));
      expect(bundle.verifiedClaims, hasLength(1));
      expect(bundle.identityAssertionLabel, equals('cawg.identity'));
      expect(
        bundle.identityAssertionPayload,
        containsPair('issuer', 'verifyer.divine.video'),
      );
    });

    test(
      'parses partial success with oauth and public-proof requirements',
      () async {
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'issuer': 'verifyer.divine.video',
              'status': 'partial_success',
              'verified_claims': <Map<String, String>>[
                <String, String>{
                  'type': 'nip05',
                  'value': 'alice@example.com',
                  'method': 'nip05_dns',
                  'verified_at': '2026-03-29T08:35:00Z',
                },
              ],
              'required_actions': <Map<String, String>>[
                <String, String>{
                  'type': 'social_handle',
                  'platform': 'github',
                  'value': 'alice',
                  'required_method': 'oauth',
                },
                <String, String>{
                  'type': 'social_handle',
                  'platform': 'x',
                  'value': '@alice',
                  'required_method': 'public_proof',
                },
              ],
            }),
            200,
          ),
        );

        final bundle = await client.verifyClaims(
          const VerifierClaimRequest(
            pubkey: '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
            socialHandles: <VerifierSocialHandleClaim>[
              VerifierSocialHandleClaim(
                platform: 'github',
                handle: 'alice',
                preferredMethods: <VerifierRequiredMethod>[
                  VerifierRequiredMethod.oauth,
                  VerifierRequiredMethod.publicProof,
                ],
              ),
              VerifierSocialHandleClaim(
                platform: 'x',
                handle: '@alice',
                preferredMethods: <VerifierRequiredMethod>[
                  VerifierRequiredMethod.publicProof,
                ],
              ),
            ],
          ),
        );

        expect(bundle, isNotNull);
        expect(bundle!.status, equals('partial_success'));
        expect(bundle.requiredActions, hasLength(2));
        expect(
          bundle.requiredActions.first.requiredMethod,
          equals(VerifierRequiredMethod.oauth),
        );
        expect(
          bundle.requiredActions.last.requiredMethod,
          equals(VerifierRequiredMethod.publicProof),
        );
      },
    );

    test('returns null on timeout or network failure', () async {
      when(
        () => mockHttpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenThrow(TimeoutException('request timed out'));

      final bundle = await client.verifyClaims(
        const VerifierClaimRequest(
          pubkey: '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
        ),
      );

      expect(bundle, isNull);
    });
  });
}
