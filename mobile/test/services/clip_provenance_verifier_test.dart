// ABOUTME: Tests for the on-device C2PA check a received clip must pass
// ABOUTME: before it may enter the clip library.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/c2pa_trust_anchor_service.dart';
import 'package:openvine/services/clip_provenance_verifier.dart';

class _MockTrustAnchorService extends Mock implements C2paTrustAnchorService {}

const _manifestId = 'urn:c2pa:3fa85f64-5717-4562-b3fc-2c963f66afa6';
const _ingredientManifestId = 'urn:c2pa:7c9e6679-7425-40de-944b-e07fc1f90ae7';
const _digitalCapture =
    'http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture';
const _trainedAlgorithmicMedia =
    'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia';
const _cachedPem = 'cached-pem';
const _freshPem = 'fresh-pem';

Map<String, dynamic> _actions(List<Map<String, dynamic>> actions) => {
  'label': 'c2pa.actions.v2',
  'data': {'actions': actions},
};

Map<String, dynamic> _report({
  String validationState = 'Trusted',
  List<String> failureCodes = const [],
  String? sourceType = _digitalCapture,
  String action = 'c2pa.created',
  Map<String, dynamic>? ingredientManifest,
}) => {
  'active_manifest': _manifestId,
  'manifests': {
    _manifestId: {
      'assertions': [
        _actions([
          {'action': action, 'digitalSourceType': ?sourceType},
        ]),
        {
          'label': 'cawg.training-mining',
          'data': <String, dynamic>{},
        },
      ],
    },
    _ingredientManifestId: ?ingredientManifest,
  },
  'validation_state': validationState,
  'validation_results': {
    'activeManifest': {
      'success': [
        {'code': 'claimSignature.validated'},
      ],
      'failure': [
        for (final code in failureCodes) {'code': code},
      ],
    },
  },
};

void main() {
  group(ClipProvenanceVerifier, () {
    group('evaluate', () {
      test('verifies a trusted, intact camera capture', () {
        expect(
          ClipProvenanceVerifier.evaluate(_report()),
          equals(
            const ClipProvenanceResult(
              ClipProvenanceStatus.verified,
              activeManifestId: _manifestId,
            ),
          ),
        );
      });

      test('rejects a camera claim from a signer outside the anchors', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(
            validationState: 'Valid',
            failureCodes: ['signingCredential.untrusted'],
          ),
        );

        expect(result.status, equals(ClipProvenanceStatus.untrustedSigner));
      });

      test('rejects a video that no longer matches its signed hash', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(
            validationState: 'Invalid',
            failureCodes: ['assertion.bmffHash.mismatch'],
          ),
        );

        expect(result.status, equals(ClipProvenanceStatus.invalid));
      });

      test('rejects a failure code even when the state reads Trusted', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(failureCodes: ['assertion.dataHash.mismatch']),
        );

        expect(result.status, equals(ClipProvenanceStatus.invalid));
      });

      test('rejects a trusted manifest declaring generative media', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(sourceType: _trainedAlgorithmicMedia),
        );

        expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
      });

      test('rejects a manifest that records no creation', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(action: 'c2pa.edited', sourceType: null),
        );

        expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
      });

      test('rejects a capture with a generative ingredient', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(
            ingredientManifest: {
              'assertions': [
                _actions([
                  {
                    'action': 'c2pa.created',
                    'digitalSourceType': _trainedAlgorithmicMedia,
                  },
                ]),
              ],
            },
          ),
        );

        expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
      });

      test('treats a valid manifest from an unknown signer as untrusted', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(validationState: 'Valid'),
        );

        expect(result.status, equals(ClipProvenanceStatus.untrustedSigner));
      });

      test('rejects an ingredient that fails validation', () {
        // Round-tripped through JSON, as the reader delivers it.
        final report =
            jsonDecode(jsonEncode(_report())) as Map<String, dynamic>;
        (report['validation_results']
            as Map<String, dynamic>)['ingredientDeltas'] = [
          {
            'validationDeltas': {
              'failure': [
                {'code': 'assertion.dataHash.mismatch'},
              ],
            },
          },
        ];

        final result = ClipProvenanceVerifier.evaluate(report);

        expect(result.status, equals(ClipProvenanceStatus.invalid));
      });

      test('allows an action that names no source type', () {
        final result = ClipProvenanceVerifier.evaluate(
          _report(
            ingredientManifest: {
              'assertions': [
                _actions([
                  {'action': 'c2pa.transcoded'},
                ]),
              ],
            },
          ),
        );

        expect(result.status, equals(ClipProvenanceStatus.verified));
      });

      test('reports no credentials when there is no active manifest', () {
        final result = ClipProvenanceVerifier.evaluate(const {
          'manifests': <String, dynamic>{},
        });

        expect(result.status, equals(ClipProvenanceStatus.noCredentials));
      });
    });

    group('settingsJsonFor', () {
      test('trusts only the given anchors and fetches nothing remote', () {
        final settings = jsonDecode(
          ClipProvenanceVerifier.settingsJsonFor(_freshPem),
        ) as Map<String, dynamic>;

        expect(
          settings['trust'],
          equals({'trust_anchors': _freshPem, 'allowed_list': _freshPem}),
        );
        expect(settings['verify'], containsPair('verify_trust', true));
        expect(
          settings['verify'],
          containsPair('remote_manifest_fetch', false),
        );
        expect(settings['verify'], containsPair('ocsp_fetch', false));
      });
    });

    group('verify', () {
      late _MockTrustAnchorService trustAnchors;
      late List<String> readWithPems;

      setUp(() {
        trustAnchors = _MockTrustAnchorService();
        readWithPems = [];
      });

      ClipProvenanceVerifier createVerifier(
        Map<String, dynamic> Function(String pem) reportFor,
      ) {
        return ClipProvenanceVerifier(
          trustAnchors: trustAnchors,
          readManifestStore: (path, settingsJson) async {
            final settings = jsonDecode(settingsJson) as Map<String, dynamic>;
            final pem =
                (settings['trust'] as Map<String, dynamic>)['trust_anchors']
                    as String;
            readWithPems.add(pem);
            return jsonEncode(reportFor(pem));
          },
        );
      }

      test('is unavailable without trust anchors', () async {
        when(trustAnchors.load).thenAnswer((_) async => null);

        final result = await createVerifier((_) => _report()).verify('/clip');

        expect(result.status, equals(ClipProvenanceStatus.unavailable));
        expect(readWithPems, isEmpty);
      });

      test('retries an untrusted signer once with freshly fetched anchors '
          'after a key rotation', () async {
        when(trustAnchors.load).thenAnswer(
          (_) async => const C2paTrustAnchors(pem: _cachedPem, isFresh: false),
        );
        when(() => trustAnchors.load(forceRefresh: true)).thenAnswer(
          (_) async => const C2paTrustAnchors(pem: _freshPem, isFresh: true),
        );

        final result = await createVerifier(
          (pem) => pem == _freshPem
              ? _report()
              : _report(
                  validationState: 'Valid',
                  failureCodes: ['signingCredential.untrusted'],
                ),
        ).verify('/clip');

        expect(result.status, equals(ClipProvenanceStatus.verified));
        expect(readWithPems, equals([_cachedPem, _freshPem]));
      });

      test('does not retry when the anchors were already fresh', () async {
        when(trustAnchors.load).thenAnswer(
          (_) async => const C2paTrustAnchors(pem: _freshPem, isFresh: true),
        );

        final result = await createVerifier(
          (_) => _report(
            validationState: 'Valid',
            failureCodes: ['signingCredential.untrusted'],
          ),
        ).verify('/clip');

        expect(result.status, equals(ClipProvenanceStatus.untrustedSigner));
        expect(readWithPems, equals([_freshPem]));
      });

      test(
        'reports no credentials when the reader finds no manifest',
        () async {
          when(trustAnchors.load).thenAnswer(
            (_) async => const C2paTrustAnchors(pem: _freshPem, isFresh: true),
          );
          final verifier = ClipProvenanceVerifier(
            trustAnchors: trustAnchors,
            readManifestStore: (_, _) async => throw PlatformException(
              code: 'C2PA_ERROR',
              message: 'ManifestNotFound: no JUMBF data found',
            ),
          );

          final result = await verifier.verify('/clip');

          expect(result.status, equals(ClipProvenanceStatus.noCredentials));
        },
      );

      test('is unavailable where the platform has no C2PA reader', () async {
        when(trustAnchors.load).thenAnswer(
          (_) async => const C2paTrustAnchors(pem: _freshPem, isFresh: true),
        );
        final verifier = ClipProvenanceVerifier(
          trustAnchors: trustAnchors,
          readManifestStore: (_, _) async =>
              throw MissingPluginException('no c2pa on this platform'),
        );

        final result = await verifier.verify('/clip');

        expect(result.status, equals(ClipProvenanceStatus.unavailable));
      });
    });
  });
}
