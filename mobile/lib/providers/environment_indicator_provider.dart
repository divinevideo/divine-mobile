// ABOUTME: Provider + color logic for the environment / relay indicator bar.
// ABOUTME: Lives in the provider layer so it can wire the relay service config.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/relay_providers.dart';
import 'package:openvine/services/relay_discovery_service.dart';
import 'package:openvine/utils/relay_url_utils.dart';

/// Resolves the indicator bar color for the given [environment] and
/// [configuredRelays], or `null` when the indicator should be hidden.
///
/// - A user-chosen relay beyond Divine + the app's [defaultRelayUrls] →
///   purple (wins over the environment color).
/// - Otherwise, a non-production environment → its environment color.
/// - Otherwise (production on Divine / default relays) → `null` (hidden).
Color? environmentIndicatorColor({
  required EnvironmentConfig environment,
  required List<String> configuredRelays,
  required Iterable<String> defaultRelayUrls,
}) {
  if (usesUserChosenRelay(
    configuredRelays,
    defaultRelayUrls: defaultRelayUrls,
  )) {
    return VineTheme.accentPurple;
  }
  if (!environment.isProduction) {
    return Color(environment.indicatorColorValue);
  }
  return null;
}

/// The current indicator bar color, or `null` when hidden.
///
/// Sources the active relay set from [configuredRelayUrlsProvider], which is
/// updated by the app-shell relay bridge from the current relay status map.
/// This keeps the always-mounted decorative indicator from forcing client
/// initialization, while still tracking relay additions and removals.
final environmentIndicatorColorProvider = Provider<Color?>((ref) {
  final environment = ref.watch(currentEnvironmentProvider);
  final configuredRelays = ref.watch(configuredRelayUrlsProvider);
  return environmentIndicatorColor(
    environment: environment,
    configuredRelays: configuredRelays,
    // Relays every account is auto-seeded with (NIP-65 indexers + DM
    // fallbacks, current and retired). Excluded so only genuinely user-added
    // relays show purple.
    defaultRelayUrls: <String>{
      ...environment.indexerRelays,
      ...IndexerRelayConfig.safeFallbackRelays,
      ...IndexerRelayConfig.retiredSafeFallbackRelays,
    },
  );
});
