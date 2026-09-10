import 'dart:convert';

import 'package:c2pa_flutter/c2pa.dart';
import 'package:meta/meta.dart';
import 'package:openvine/services/nostr_creator_binding_service.dart';

@immutable
class C2paIdentityManifestBuildResult {
  const C2paIdentityManifestBuildResult({
    required this.manifestDefinition,
    required this.requiresAdvancedEmbedding,
  });

  final ManifestDefinition manifestDefinition;
  final bool requiresAdvancedEmbedding;

  String get manifestJson => manifestDefinition.toJsonString();
}

class C2paIdentityManifestService {
  C2paIdentityManifestService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  /// Builds the C2PA manifest for a created video.
  ///
  /// The `cawg.training-mining` assertion is **always** embedded as a
  /// matter of Divine policy — the platform does not offer an opt-in to
  /// AI training. See `mobile/docs/AI_TRAINING_POLICY.md`.
  C2paIdentityManifestBuildResult buildCreatedVideoManifest({
    required String claimGenerator,
    required String title,
    required DigitalSourceType sourceType,
    NostrCreatorBindingAssertion? creatorBindingAssertion,
    Map<String, dynamic>? cawgIdentityAssertion,
    bool enableAdvancedCawgEmbedding = false,
  }) {
    final requiresAdvancedEmbedding =
        enableAdvancedCawgEmbedding && cawgIdentityAssertion != null;

    final manifest = ManifestDefinition(
      title: title,
      claimGeneratorInfo: <ClaimGeneratorInfo>[
        _parseClaimGenerator(claimGenerator),
      ],
      format: 'video/mp4',
      ingredients: <Ingredient>[
        Ingredient(
          title: title,
          format: 'video/mp4',
          relationship: Relationship.parentOf,
          label: 'c2pa.ingredient.v2',
        ),
      ],
      assertions: <AssertionDefinition>[
        CustomAssertion(
          label: 'c2pa.actions.v2',
          data: <String, dynamic>{
            'actions': <Map<String, dynamic>>[
              Action.created(
                sourceType: sourceType,
                softwareAgent: claimGenerator,
                when: _now().toUtc().toIso8601String(),
              ).toJson(),
            ],
          },
        ),
        _buildTrainingMiningAssertion(),
        if (creatorBindingAssertion != null)
          CustomAssertion(
            label: creatorBindingAssertion.assertionLabel,
            data: jsonDecode(
              creatorBindingAssertion.payloadJson,
            ) as Map<String, dynamic>,
          ),
        if (cawgIdentityAssertion != null && !requiresAdvancedEmbedding)
          CustomAssertion(
            label: 'cawg.identity',
            data: Map<String, dynamic>.of(cawgIdentityAssertion),
          ),
      ],
    );

    return C2paIdentityManifestBuildResult(
      manifestDefinition: manifest,
      requiresAdvancedEmbedding: requiresAdvancedEmbedding,
    );
  }

  /// Builds the C2PA manifest for a *derived* video — one produced by
  /// re-encoding an already-signed source (an aspect-ratio crop or a
  /// watermark burn-in) that has therefore lost its embedded manifest.
  ///
  /// The already-signed source is carried forward as a `parentOf` ingredient
  /// by the caller via [ManifestBuilder.addIngredient], and the transform is
  /// recorded as a `c2pa.*` edit action via [ManifestBuilder.addAction], so
  /// this definition intentionally declares neither: it only supplies the
  /// title, claim generator, and the always-on `cawg.training-mining` opt-out
  /// (Divine policy — see `mobile/docs/AI_TRAINING_POLICY.md`).
  C2paIdentityManifestBuildResult buildDerivedVideoManifest({
    required String claimGenerator,
    required String title,
  }) {
    final manifest = ManifestDefinition(
      title: title,
      claimGeneratorInfo: <ClaimGeneratorInfo>[
        _parseClaimGenerator(claimGenerator),
      ],
      format: 'video/mp4',
      assertions: <AssertionDefinition>[_buildTrainingMiningAssertion()],
    );

    return C2paIdentityManifestBuildResult(
      manifestDefinition: manifest,
      requiresAdvancedEmbedding: false,
    );
  }

  ClaimGeneratorInfo _parseClaimGenerator(String claimGenerator) {
    final separatorIndex = claimGenerator.lastIndexOf('/');
    if (separatorIndex <= 0 || separatorIndex == claimGenerator.length - 1) {
      return ClaimGeneratorInfo(name: claimGenerator);
    }

    return ClaimGeneratorInfo(
      name: claimGenerator.substring(0, separatorIndex),
      version: claimGenerator.substring(separatorIndex + 1),
    );
  }

  CustomAssertion _buildTrainingMiningAssertion() {
    return const CustomAssertion(
      label: 'cawg.training-mining',
      data: <String, dynamic>{
        'entries': <String, dynamic>{
          'cawg.ai_training': <String, String>{'use': 'notAllowed'},
          'cawg.ai_inference': <String, String>{'use': 'notAllowed'},
          'cawg.ai_generative_training': <String, String>{'use': 'notAllowed'},
          'cawg.data_mining': <String, String>{'use': 'notAllowed'},
        },
      },
    );
  }
}
