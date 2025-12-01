// ABOUTME: Tests for gateway Riverpod providers
// ABOUTME: Validates provider initialization and dependency injection

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('RelayGatewayProviders', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sharedPreferencesProvider throws error when not overridden', () {
      final container = ProviderContainer();

      // Attempting to read the provider without overriding throws an exception
      expect(
        () => container.read(sharedPreferencesProvider),
        throwsException,
      );

      container.dispose();
    });

    test('relayGatewaySettingsProvider provides settings instance', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final settings = container.read(relayGatewaySettingsProvider);

      expect(settings, isA<RelayGatewaySettings>());
      expect(settings.isEnabled, true);

      container.dispose();
    });

    test('relayGatewayServiceProvider provides service instance', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final service = container.read(relayGatewayServiceProvider);

      expect(service, isA<RelayGatewayService>());
      expect(service.gatewayUrl, 'https://gateway.divine.video');

      container.dispose();
    });

    test('service uses custom URL from settings', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_url': 'https://custom.gateway',
      });

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final service = container.read(relayGatewayServiceProvider);

      expect(service.gatewayUrl, 'https://custom.gateway');

      container.dispose();
    });

    test('shouldUseGatewayProvider returns true when enabled and using divine relay', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final shouldUse = container.read(
        shouldUseGatewayProvider(['wss://relay.divine.video']),
      );

      expect(shouldUse, true);

      container.dispose();
    });

    test('shouldUseGatewayProvider returns false when disabled', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });

      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final shouldUse = container.read(
        shouldUseGatewayProvider(['wss://relay.divine.video']),
      );

      expect(shouldUse, false);

      container.dispose();
    });

    test('shouldUseGatewayProvider returns false when not using divine relay', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final shouldUse = container.read(
        shouldUseGatewayProvider(['wss://other.relay']),
      );

      expect(shouldUse, false);

      container.dispose();
    });

    test('shouldUseGatewayProvider returns true when divine relay is one of many', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final shouldUse = container.read(
        shouldUseGatewayProvider([
          'wss://other.relay',
          'wss://relay.divine.video',
        ]),
      );

      expect(shouldUse, true);

      container.dispose();
    });
  });
}
