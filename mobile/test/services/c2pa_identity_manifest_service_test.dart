import 'dart:convert';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/c2pa_identity_manifest_service.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';

void main() {
  group('C2paIdentityManifestService', () {
    late C2paIdentityManifestService service;

    setUp(() {
      service = C2paIdentityManifestService(
        now: () => DateTime.utc(2026, 3, 29, 8, 30),
      );
    });

    test('builds the current actions and training-mining manifest shape', () {
      final result = service.buildCreatedVideoManifest(
        claimGenerator: 'DiVine/1.0',
        title: 'test.mp4',
        sourceType: DigitalSourceType.digitalCapture,
      );

      final json = jsonDecode(result.manifestJson) as Map<String, dynamic>;
      final assertions = json['assertions'] as List<dynamic>;
      final actionsAssertion = assertions.first as Map<String, dynamic>;
      final trainingAssertion = assertions.last as Map<String, dynamic>;

      expect(result.requiresAdvancedEmbedding, isFalse);
      expect(json['claim_generator'], equals('DiVine/1.0'));
      expect(json['format'], equals('video/mp4'));
      expect(json['ingredients'] as List<dynamic>, hasLength(1));
      expect(actionsAssertion['label'], equals('c2pa.actions.v2'));
      expect(trainingAssertion['label'], equals('cawg.training-mining'));
    });

    test(
      'builds the derived manifest with only the training-mining opt-out',
      () {
        final result = service.buildDerivedVideoManifest(
          claimGenerator: 'DiVine/1.0',
          title: 'watermarked.mp4',
        );

        final json = jsonDecode(result.manifestJson) as Map<String, dynamic>;
        final assertions = json['assertions'] as List<dynamic>;
        final labels = assertions
            .map((assertion) => (assertion as Map<String, dynamic>)['label'])
            .toList();

        expect(result.requiresAdvancedEmbedding, isFalse);
        expect(json['title'], equals('watermarked.mp4'));
        expect(json['claim_generator'], equals('DiVine/1.0'));
        expect(json['format'], equals('video/mp4'));
        // The parentOf ingredient and the edit action are attached by the
        // caller via the ManifestBuilder, so the definition must not declare
        // them — unlike buildCreatedVideoManifest, which does.
        expect(json.containsKey('ingredients'), isFalse);
        expect(labels, equals(['cawg.training-mining']));
      },
    );

    test(
      'includes creator binding and final cawg assertions when available',
      () {
        final result = service.buildCreatedVideoManifest(
          claimGenerator: 'DiVine/1.0',
          title: 'test.mp4',
          sourceType: DigitalSourceType.digitalCapture,
          creatorBindingAssertion: const NostrCreatorBindingAssertion(
            assertionLabel: 'video.divine.nostr.creator_binding',
            payloadJson: '{"version":1,"pubkey":"abc","sig_alg":"nostr.secp256k1","created_at":"2026-03-29T08:30:00.000Z","claims":{},"referenced_assertions":["c2pa.hash.data"],"hard_binding":{"alg":"sha256","value":"deadbeef"},"signature":"cafebabe"}',
            signature: 'cafebabe',
            pubkey: 'abc',
          ),
          cawgIdentityAssertion: const <String, dynamic>{
            'issuer': 'verifyer.divine.video',
            'verified_claims': <Map<String, String>>[
              <String, String>{'type': 'nip05', 'value': 'alice@example.com'},
            ],
          },
        );

        final json = jsonDecode(result.manifestJson) as Map<String, dynamic>;
        final assertions = json['assertions'] as List<dynamic>;
        final labels = assertions
            .map((assertion) => (assertion as Map<String, dynamic>)['label'])
            .toList();

        expect(result.requiresAdvancedEmbedding, isFalse);
        expect(labels, contains('video.divine.nostr.creator_binding'));
        expect(labels, contains('cawg.identity'));
      },
    );

    test(
      'omits cawg overlay when verifier output is absent and flags advanced path '
      'when requested',
      () {
        final withoutCawg = service.buildCreatedVideoManifest(
          claimGenerator: 'DiVine/1.0',
          title: 'test.mp4',
          sourceType: DigitalSourceType.digitalCapture,
          creatorBindingAssertion: const NostrCreatorBindingAssertion(
            assertionLabel: 'video.divine.nostr.creator_binding',
            payloadJson: '{"version":1,"pubkey":"abc","sig_alg":"nostr.secp256k1","created_at":"2026-03-29T08:30:00.000Z","claims":{},"referenced_assertions":["c2pa.hash.data"],"hard_binding":{"alg":"sha256","value":"deadbeef"},"signature":"cafebabe"}',
            signature: 'cafebabe',
            pubkey: 'abc',
          ),
        );

        final withoutCawgJson =
            jsonDecode(withoutCawg.manifestJson) as Map<String, dynamic>;
        final withoutCawgLabels =
            (withoutCawgJson['assertions'] as List<dynamic>)
                .map(
                  (assertion) => (assertion as Map<String, dynamic>)['label'],
                )
                .toList();

        final advanced = service.buildCreatedVideoManifest(
          claimGenerator: 'DiVine/1.0',
          title: 'test.mp4',
          sourceType: DigitalSourceType.digitalCapture,
          cawgIdentityAssertion: const <String, dynamic>{
            'issuer': 'verifyer.divine.video',
          },
          enableAdvancedCawgEmbedding: true,
        );

        final advancedJson =
            jsonDecode(advanced.manifestJson) as Map<String, dynamic>;
        final advancedLabels = (advancedJson['assertions'] as List<dynamic>)
            .map((assertion) => (assertion as Map<String, dynamic>)['label'])
            .toList();

        expect(withoutCawgLabels, isNot(contains('cawg.identity')));
        expect(advanced.requiresAdvancedEmbedding, isTrue);
        expect(advancedLabels, isNot(contains('cawg.identity')));
      },
    );
  });
}
