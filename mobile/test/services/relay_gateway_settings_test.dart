// ABOUTME: Tests for RelayGatewaySettings persistence
// ABOUTME: Validates enable/disable toggle and URL storage

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RelayGatewaySettings', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to enabled when using divine relay', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(settings.isEnabled, true);
    });

    test('persists enabled state', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      await settings.setEnabled(false);
      expect(settings.isEnabled, false);

      await settings.setEnabled(true);
      expect(settings.isEnabled, true);
    });

    test('loads persisted state', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(settings.isEnabled, false);
    });

    test('returns default gateway URL', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(settings.gatewayUrl, 'https://gateway.divine.video');
    });

    test('persists custom gateway URL', () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      await settings.setGatewayUrl('https://custom.gateway');
      expect(settings.gatewayUrl, 'https://custom.gateway');
    });

    test('shouldUseGateway returns true when enabled and using divine relay',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
            configuredRelays: ['wss://relay.divine.video']),
        true,
      );
    });

    test('shouldUseGateway returns false when disabled', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
            configuredRelays: ['wss://relay.divine.video']),
        false,
      );
    });

    test('shouldUseGateway returns false when not using divine relay',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(configuredRelays: ['wss://other.relay']),
        false,
      );
    });

    test('shouldUseGateway returns true when divine relay is one of many',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(configuredRelays: [
          'wss://other.relay',
          'wss://relay.divine.video',
        ]),
        true,
      );
    });

    test('isDivineRelayConfigured returns true when divine relay present',
        () {
      expect(
        RelayGatewaySettings.isDivineRelayConfigured([
          'wss://other.relay',
          'wss://relay.divine.video',
        ]),
        true,
      );
    });

    test('isDivineRelayConfigured returns false when divine relay absent', () {
      expect(
        RelayGatewaySettings.isDivineRelayConfigured([
          'wss://other.relay',
          'wss://another.relay',
        ]),
        false,
      );
    });
  });
}
