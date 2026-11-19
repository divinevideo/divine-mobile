import 'package:badge_repository/src/nip58_badge_models.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';

export 'package:funnelcake_api_client/funnelcake_api_client.dart'
    show BadgeVideoPreview;

/// An active public badge enriched by the Divine discovery index.
typedef IndexedBadgeDiscovery = ({
  Nip58BadgeDefinition definition,
  List<BadgeVideoPreview> videos,
});
