// ABOUTME: Tests for the on-device C2PA check a received clip must pass
// ABOUTME: before it may enter the clip library.

import 'dart:convert';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:crypto/crypto.dart';
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
const _compositeCapture =
    'http://cv.iptc.org/newscodes/digitalsourcetype/compositeCapture';
const _cachedPem = 'cached-pem';
const _untrustedCode = 'signingCredential.untrusted';

/// BIP-340 test-vector key, so bindings in these reports carry a real
/// signature.
const _bindingKey =
    'b7e151628aed2a6abf7158809cf4f3c762e7160f38b4da56a784d9045190cfef';

Map<String, dynamic> _capture({Map<String, dynamic>? binding}) => {
  'assertions': [
    _actions([
      {'action': 'c2pa.created', 'digitalSourceType': _digitalCapture},
    ]),
    ?binding,
  ],
};

/// An ingredient as the reader reports it. One with a manifest carries the
/// validation recorded when it was added: the app signs without trust
/// anchors, so that is always `signingCredential.untrusted`, plus
/// [recordedFailures].
Map<String, dynamic> _ingredient(
  String? activeManifest, {
  String relationship = 'parentOf',
  String format = 'video/mp4',
  List<String> recordedFailures = const [],
}) => {
  'format': format,
  'relationship': relationship,
  'active_manifest': ?activeManifest,
  if (activeManifest != null)
    'validation_results': {
      'activeManifest': {
        'failure': [
          for (final code in [_untrustedCode, ...recordedFailures])
            {'code': code},
        ],
      },
    },
};

Map<String, dynamic> _edit(
  List<Map<String, dynamic>> ingredients, {
  Map<String, dynamic>? binding,
}) => {
  'ingredients': ingredients,
  'assertions': [
    _actions([
      {'action': 'c2pa.opened'},
      {'action': 'c2pa.edited'},
    ]),
    ?binding,
  ],
};

Map<String, dynamic> _composite(List<Map<String, dynamic>> ingredients) => {
  'ingredients': ingredients,
  'assertions': [
    _actions([
      {'action': 'c2pa.created', 'digitalSourceType': _compositeCapture},
    ]),
  ],
};

/// A trusted report over [manifests], the first being the active one.
///
/// The reader reports an ingredient's trusted signer as a delta from the
/// untrusted one recorded when it was added, and an [untrusted] ingredient,
/// whose status did not change, not at all.
Map<String, dynamic> _chain(
  Map<String, Map<String, dynamic>> manifests, {
  Set<String> untrusted = const {},
}) {
  final active = manifests.keys.first;
  return {
    'active_manifest': active,
    'manifests': manifests,
    'validation_state': 'Trusted',
    'validation_results': {
      'activeManifest': {
        'success': [
          {'code': 'claimSignature.validated'},
          _trustedSigner(active),
        ],
        'failure': <Map<String, dynamic>>[],
      },
      'ingredientDeltas': [
        for (final label in manifests.keys.skip(1))
          if (!untrusted.contains(label))
            {
              'ingredientAssertionURI':
                  'self#jumbf=/c2pa/$active/c2pa.assertions/c2pa.ingredient.v3',
              'validationDeltas': {
                'success': [_trustedSigner(label)],
                'informational': <Map<String, dynamic>>[],
                'failure': <Map<String, dynamic>>[],
              },
            },
      ],
    },
  };
}

Map<String, dynamic> _trustedSigner(String label) => {
  'code': 'signingCredential.trusted',
  'url': 'self#jumbf=/c2pa/$label/c2pa.signature',
};

/// Another BIP-340 test-vector key, for a second person in a history.
const _otherBindingKey =
    'c90fdaa22168c234c4c6628b80dc1cd129024e088a67cc74020bbea63b14e5c9';

/// A creator binding signed with [key], as the reader returns it: keys
/// sorted, which is not the order they were signed in.
Map<String, dynamic> _binding({
  bool tampered = false,
  String key = _bindingKey,
}) {
  final pubkey = schnorr.getPublicKey(key);
  final unsigned = <String, dynamic>{
    'version': 1,
    'pubkey': pubkey,
    'sig_alg': 'nostr.secp256k1',
    'created_at': '2026-10-08T09:00:00.000Z',
    'claims': <String, dynamic>{},
    'referenced_assertions': ['c2pa.actions.v2'],
    'hard_binding': {'alg': 'sha256', 'value': 'ab' * 32},
  };
  final digest = sha256.convert(utf8.encode(jsonEncode(unsigned))).toString();
  final signature = schnorr.sign(key, digest, 'cd' * 32);
  final data = {
    ...unsigned,
    if (tampered) 'created_at': '2026-10-09T09:00:00.000Z',
    'signature': signature,
  };
  return {
    'label': 'video.divine.nostr.creator_binding',
    'data': Map.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
}

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

      group('edit chains', () {
        test('verifies an edit of a capture', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit([_ingredient('rec')]),
              'rec': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.verified));
        });

        test('verifies an edit passed on and edited again', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'second': _edit([_ingredient('first')]),
              'first': _edit([_ingredient('rec')]),
              'rec': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.verified));
        });

        test('verifies a composite of captures with a declared image', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'merged': _composite([
                _ingredient('a', relationship: 'componentOf'),
                _ingredient('b', relationship: 'componentOf'),
                _ingredient(
                  null,
                  relationship: 'componentOf',
                  format: 'image/png',
                ),
              ]),
              'a': _capture(),
              'b': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.verified));
        });

        test('verifies a merge of a recording with an edit of the same '
            'recording', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'merged': _composite([
                _ingredient('rec', relationship: 'componentOf'),
                _ingredient('edit', relationship: 'componentOf'),
              ]),
              'edit': _edit([_ingredient('rec')]),
              'rec': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.verified));
        });

        test('rejects an edit of a video with no manifest', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit([_ingredient(null)]),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
        });

        test('rejects a composite that mixes in an unsigned video', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'merged': _composite([
                _ingredient('a', relationship: 'componentOf'),
                _ingredient(null, relationship: 'componentOf'),
              ]),
              'a': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
        });

        test('rejects an ingredient that was only an input', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit([
                _ingredient('rec'),
                _ingredient('other', relationship: 'inputTo'),
              ]),
              'rec': _capture(),
              'other': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
        });

        test('rejects a history that refers back to itself', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit([_ingredient('edit')]),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
        });

        test('rejects an edit chain deeper than the limit', () {
          const depth = ClipProvenanceVerifier.maxChainDepth + 2;
          final manifests = <String, Map<String, dynamic>>{
            for (var i = 0; i < depth; i++)
              'm$i': _edit([_ingredient('m${i + 1}')]),
            'm$depth': _capture(),
          };

          final result = ClipProvenanceVerifier.evaluate(_chain(manifests));

          expect(result.status, equals(ClipProvenanceStatus.notCameraCapture));
        });

        test('credits the editor, then the recorder', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit(
                [_ingredient('rec')],
                binding: _binding(key: _otherBindingKey),
              ),
              'rec': _capture(binding: _binding()),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.verified));
          expect(
            result.contributors,
            equals([
              schnorr.getPublicKey(_otherBindingKey),
              schnorr.getPublicKey(_bindingKey),
            ]),
          );
        });

        test('credits no one whose binding does not verify', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit(
                [_ingredient('rec')],
                binding: _binding(key: _otherBindingKey),
              ),
              'rec': _capture(binding: _binding(tampered: true)),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.verified));
          expect(
            result.contributors,
            equals([schnorr.getPublicKey(_otherBindingKey)]),
          );
        });

        test('rejects an edit of a video signed outside the anchors', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain(
              {
                'edit': _edit([_ingredient('forged')]),
                'forged': _capture(),
              },
              untrusted: {'forged'},
            ),
          );

          expect(result.status, equals(ClipProvenanceStatus.untrustedSigner));
        });

        test('rejects an edit of a video that had failed validation', () {
          final result = ClipProvenanceVerifier.evaluate(
            _chain({
              'edit': _edit([
                _ingredient(
                  'rec',
                  recordedFailures: ['assertion.bmffHash.mismatch'],
                ),
              ]),
              'rec': _capture(),
            }),
          );

          expect(result.status, equals(ClipProvenanceStatus.invalid));
        });
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
