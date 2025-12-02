// ABOUTME: Persistence for REST gateway settings
// ABOUTME: Manages gateway enable/disable toggle and custom URL

import 'package:shared_preferences/shared_preferences.dart';

/// Settings persistence for REST gateway feature
class RelayGatewaySettings {
  static const String _enabledKey = 'relay_gateway_enabled';
  static const String _gatewayUrlKey = 'relay_gateway_url';
  static const String _defaultGatewayUrl = 'https://gateway.divine.video';
  static const String _divineRelayUrl = 'relay.divine.video';

  final SharedPreferences _prefs;

  RelayGatewaySettings(this._prefs);

  /// Whether the gateway is enabled (defaults to true)
  bool get isEnabled => _prefs.getBool(_enabledKey) ?? true;

  /// Set gateway enabled state
  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_enabledKey, enabled);
  }

  /// Gateway URL (defaults to gateway.divine.video)
  String get gatewayUrl =>
      _prefs.getString(_gatewayUrlKey) ?? _defaultGatewayUrl;

  /// Set custom gateway URL
  Future<void> setGatewayUrl(String url) async {
    await _prefs.setString(_gatewayUrlKey, url);
  }

  /// Check if gateway should be used based on settings and configured relays
  ///
  /// Returns true only if:
  /// 1. Gateway is enabled in settings
  /// 2. User has relay.divine.video configured
  bool shouldUseGateway({required List<String> configuredRelays}) {
    if (!isEnabled) return false;

    // Only use gateway when divine relay is configured
    return isDivineRelayConfigured(configuredRelays);
  }

  /// Check if divine relay is in the configured relays list
  static bool isDivineRelayConfigured(List<String> relays) {
    return relays.any((relay) => relay.contains(_divineRelayUrl));
  }
}
