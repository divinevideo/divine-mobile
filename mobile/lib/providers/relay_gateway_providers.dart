// ABOUTME: Riverpod providers for REST gateway service and settings
// ABOUTME: Provides dependency injection for gateway functionality

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';

/// Provider for gateway settings
final relayGatewaySettingsProvider = Provider<RelayGatewaySettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return RelayGatewaySettings(prefs);
});

/// Provider for gateway service
final relayGatewayServiceProvider = Provider<RelayGatewayService>((ref) {
  final settings = ref.watch(relayGatewaySettingsProvider);
  return RelayGatewayService(gatewayUrl: settings.gatewayUrl);
});

/// Provider to check if gateway should be used for queries
final shouldUseGatewayProvider = Provider.family<bool, List<String>>((
  ref,
  configuredRelays,
) {
  final settings = ref.watch(relayGatewaySettingsProvider);
  return settings.shouldUseGateway(configuredRelays: configuredRelays);
});
