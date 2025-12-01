// ABOUTME: Integration test for REST gateway + embedded relay + providers
// ABOUTME: Tests full flow from gateway fetch through provider wiring

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/providers/relay_gateway_providers.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Gateway Integration', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('providers wire together correctly', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      // Verify settings provider works
      final settings = container.read(relayGatewaySettingsProvider);
      expect(settings, isA<RelayGatewaySettings>());
      expect(settings.isEnabled, true);

      // Verify service provider works
      final service = container.read(relayGatewayServiceProvider);
      expect(service, isA<RelayGatewayService>());
      expect(service.gatewayUrl, 'https://gateway.divine.video');

      // Verify shouldUseGateway provider with divine relay
      final shouldUseDivine = container.read(
        shouldUseGatewayProvider(['wss://relay.divine.video']),
      );
      expect(shouldUseDivine, true);

      // Verify shouldUseGateway provider without divine relay
      final shouldUseOther = container.read(
        shouldUseGatewayProvider(['wss://other.relay']),
      );
      expect(shouldUseOther, false);

      container.dispose();
    });

    test('gateway service queries and parses response correctly', () async {
      final mockClient = MockClient((request) async {
        // Verify the request URL format
        expect(request.url.host, 'gateway.test');
        expect(request.url.path, '/query');
        expect(request.url.queryParameters.containsKey('filter'), true);

        // Decode and verify the filter
        final filterParam = request.url.queryParameters['filter']!;
        final decoded = utf8.decode(base64Url.decode(filterParam));
        final filterJson = jsonDecode(decoded) as Map<String, dynamic>;
        expect(filterJson['kinds'], [34236]);
        expect(filterJson['limit'], 50);

        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'a' * 64,
                'pubkey': 'b' * 64,
                'created_at': 1700000000,
                'kind': 34236,
                'tags': [
                  ['url', 'https://example.com/video.mp4'],
                  ['thumb', 'https://example.com/thumb.jpg'],
                  ['title', 'Test Video'],
                ],
                'content': 'Test video description',
                'sig': 'c' * 128,
              },
              {
                'id': 'd' * 64,
                'pubkey': 'e' * 64,
                'created_at': 1700000001,
                'kind': 34236,
                'tags': [
                  ['url', 'https://example.com/video2.mp4'],
                ],
                'content': '',
                'sig': 'f' * 128,
              },
            ],
            'eose': true,
            'complete': true,
            'cached': true,
            'cache_age_seconds': 45,
          }),
          200,
        );
      });

      final service = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final filter = Filter(kinds: [34236], limit: 50);
      final response = await service.query(filter);

      expect(response.events.length, 2);
      expect(response.eose, true);
      expect(response.complete, true);
      expect(response.cached, true);
      expect(response.cacheAgeSeconds, 45);

      // Verify event data
      expect(response.events[0]['id'], 'a' * 64);
      expect(response.events[0]['kind'], 34236);
      expect(response.events[1]['id'], 'd' * 64);
    });

    test('gateway service handles profile endpoint', () async {
      final testPubkey = 'a' * 64;

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/profile/$testPubkey');

        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'b' * 64,
                'pubkey': testPubkey,
                'created_at': 1700000000,
                'kind': 0,
                'tags': [],
                'content': jsonEncode({
                  'name': 'Test User',
                  'about': 'Test bio',
                  'picture': 'https://example.com/avatar.jpg',
                }),
                'sig': 'c' * 128,
              }
            ],
            'eose': true,
            'cached': true,
            'cache_age_seconds': 120,
          }),
          200,
        );
      });

      final service = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final profile = await service.getProfile(testPubkey);

      expect(profile, isNotNull);
      expect(profile!['pubkey'], testPubkey);
      expect(profile['kind'], 0);

      // Parse content to verify profile data
      final content = jsonDecode(profile['content'] as String);
      expect(content['name'], 'Test User');
      expect(content['about'], 'Test bio');
    });

    test('gateway service handles event endpoint', () async {
      final testEventId = 'a' * 64;

      final mockClient = MockClient((request) async {
        expect(request.url.path, '/event/$testEventId');

        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': testEventId,
                'pubkey': 'b' * 64,
                'created_at': 1700000000,
                'kind': 34236,
                'tags': [
                  ['url', 'https://example.com/video.mp4'],
                ],
                'content': '',
                'sig': 'c' * 128,
              }
            ],
            'eose': true,
          }),
          200,
        );
      });

      final service = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final event = await service.getEvent(testEventId);

      expect(event, isNotNull);
      expect(event!['id'], testEventId);
      expect(event['kind'], 34236);
    });

    test('settings correctly determine gateway usage', () async {
      // Test with gateway enabled and divine relay
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
      });
      var prefs = await SharedPreferences.getInstance();
      var settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
          configuredRelays: ['wss://relay.divine.video'],
        ),
        true,
      );

      // Test with gateway disabled
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });
      prefs = await SharedPreferences.getInstance();
      settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
          configuredRelays: ['wss://relay.divine.video'],
        ),
        false,
      );

      // Test with gateway enabled but no divine relay
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
      });
      prefs = await SharedPreferences.getInstance();
      settings = RelayGatewaySettings(prefs);

      expect(
        settings.shouldUseGateway(
          configuredRelays: ['wss://nos.lol', 'wss://relay.damus.io'],
        ),
        false,
      );

      // Test with divine relay among multiple relays
      expect(
        settings.shouldUseGateway(
          configuredRelays: [
            'wss://nos.lol',
            'wss://relay.divine.video',
            'wss://relay.damus.io',
          ],
        ),
        true,
      );
    });

    test('gateway fails gracefully on network error', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unavailable');
      });

      final service = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      expect(
        () => service.query(Filter(kinds: [34236])),
        throwsA(isA<GatewayException>()),
      );
    });

    test('gateway fails gracefully on server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      expect(
        () => service.query(Filter(kinds: [34236])),
        throwsA(isA<GatewayException>()),
      );
    });

    testWidgets('provider overrides work in widget tree', (tester) async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'events': [],
            'eose': true,
            'complete': true,
            'cached': true,
          }),
          200,
        );
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            relayGatewayServiceProvider.overrideWithValue(
              RelayGatewayService(
                gatewayUrl: 'https://gateway.test',
                client: mockClient,
              ),
            ),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, child) {
                final settings = ref.watch(relayGatewaySettingsProvider);
                final shouldUse = ref.watch(
                  shouldUseGatewayProvider(['wss://relay.divine.video']),
                );

                return Scaffold(
                  body: Column(
                    children: [
                      Text('Enabled: ${settings.isEnabled}'),
                      Text('Should use: $shouldUse'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Enabled: true'), findsOneWidget);
      expect(find.text('Should use: true'), findsOneWidget);
    });

    test('filter encoding handles hashtag tags correctly', () async {
      String? capturedFilter;

      final mockClient = MockClient((request) async {
        final filterParam = request.url.queryParameters['filter']!;
        capturedFilter = utf8.decode(base64Url.decode(filterParam));

        return http.Response(
          jsonEncode({
            'events': [],
            'eose': true,
            'complete': true,
          }),
          200,
        );
      });

      final service = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      // Create filter with hashtag using the t parameter
      final filter = Filter(
        kinds: [34236],
        limit: 50,
        t: ['nostr', 'bitcoin'],
      );

      await service.query(filter);

      expect(capturedFilter, isNotNull);
      final decoded = jsonDecode(capturedFilter!) as Map<String, dynamic>;
      expect(decoded['kinds'], [34236]);
      expect(decoded['limit'], 50);
      expect(decoded['#t'], ['nostr', 'bitcoin']);
    });

    test('custom gateway URL is persisted and used', () async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_url': 'https://custom.gateway.test',
        'relay_gateway_enabled': true,
      });

      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );

      final settings = container.read(relayGatewaySettingsProvider);
      expect(settings.gatewayUrl, 'https://custom.gateway.test');

      final service = container.read(relayGatewayServiceProvider);
      expect(service.gatewayUrl, 'https://custom.gateway.test');

      container.dispose();
    });
  });
}
