import 'package:badge_repository/src/nip58_badge_models.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';

export 'package:funnelcake_api_client/funnelcake_api_client.dart'
    show BadgeVideoPreview;

/// An active public badge enriched by the Divine discovery index.
typedef IndexedBadgeDiscovery = ({
  Nip58BadgeDefinition definition,
  List<BadgeVideoPreview> videos,
});

/// Maximum community definitions per issuer across all discovery sources.
const badgeDiscoveryDefinitionsPerIssuer = 3;

/// Preserves index rank while appending unique relay definitions under one cap.
List<Nip58BadgeDefinition> mergeBadgeDiscoveryDefinitions(
  List<Nip58BadgeDefinition> primary,
  List<Nip58BadgeDefinition> federated, {
  Set<String> pinnedIssuers = const {},
}) {
  // The primary snapshot has already passed the repository's issuer cap.
  if (federated.isEmpty) return primary;
  final coordinates = <String>{};
  final counts = <String, int>{};
  return [
    for (final definition in [...primary, ...federated])
      if (coordinates.add(definition.coordinate) &&
          (pinnedIssuers.contains(definition.event.pubkey) ||
              counts.update(
                    definition.event.pubkey,
                    (count) => count + 1,
                    ifAbsent: () => 1,
                  ) <=
                  badgeDiscoveryDefinitionsPerIssuer))
        definition,
  ];
}
