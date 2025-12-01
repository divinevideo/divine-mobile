// ABOUTME: Tests for gateway integration in VideoEventService
// ABOUTME: Validates gateway fetch + SQLite import + WebSocket fallback

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/relay_gateway_service.dart';
import 'package:openvine/services/relay_gateway_settings.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'video_event_service_gateway_test.mocks.dart';

// Generate mocks for INostrService
@GenerateMocks([INostrService])
import 'package:openvine/services/nostr_service_interface.dart';

void main() {
  group('VideoEventService Gateway Integration', () {
    late MockINostrService mockNostrService;
    late SubscriptionManager subscriptionManager;
    late RelayGatewaySettings gatewaySettings;
    late RelayGatewayService gatewayService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      gatewaySettings = RelayGatewaySettings(prefs);

      mockNostrService = MockINostrService();
      subscriptionManager = SubscriptionManager(mockNostrService);

      // Setup common mock behaviors
      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockNostrService.relays).thenReturn(['wss://relay.divine.video']);
      when(mockNostrService.connectedRelayCount).thenReturn(1);
      when(mockNostrService.subscribeToEvents(
        filters: anyNamed('filters'),
        bypassLimits: anyNamed('bypassLimits'),
        onEose: anyNamed('onEose'),
      )).thenAnswer((_) => Stream<Event>.empty());
    });

    test('uses gateway for discovery feed when enabled', () async {
      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'a' * 64, // Full 64-char hex ID
                'pubkey': 'b' * 64,
                'created_at': 1700000000,
                'kind': 34236,
                'tags': [
                  ['url', 'https://example.com/video.mp4'],
                  ['thumb', 'https://example.com/thumb.jpg'],
                ],
                'content': '',
                'sig': 'c' * 128,
              }
            ],
            'eose': true,
            'complete': true,
            'cached': true,
            'cache_age_seconds': 30,
          }),
          200,
        );
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      expect(gatewayCalled, true, reason: 'Gateway should be called for discovery feed');
    });

    test('skips gateway for home feed (personalized content)', () async {
      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
        return http.Response(jsonEncode({'events': []}), 200);
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
        authors: ['testpubkey123'],
        limit: 50,
      );

      expect(gatewayCalled, false, reason: 'Gateway should NOT be used for home feed');
    });

    test('falls back to WebSocket on gateway failure', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network error');
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      // Should not throw - falls back to WebSocket
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      // Verify WebSocket subscription was still created
      verify(mockNostrService.subscribeToEvents(
        filters: anyNamed('filters'),
        bypassLimits: anyNamed('bypassLimits'),
        onEose: anyNamed('onEose'),
      )).called(1);
    });

    test('skips gateway when not using divine relay', () async {
      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
        return http.Response(jsonEncode({'events': []}), 200);
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      // Mock with non-divine relay
      when(mockNostrService.relays).thenReturn(['wss://other.relay']);

      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      expect(gatewayCalled, false, reason: 'Gateway should not be used without divine relay');
    });

    test('skips gateway when gateway is disabled in settings', () async {
      // Disable gateway in settings
      SharedPreferences.setMockInitialValues({
        'relay_gateway_enabled': false,
      });
      final prefs = await SharedPreferences.getInstance();
      gatewaySettings = RelayGatewaySettings(prefs);

      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
        return http.Response(jsonEncode({'events': []}), 200);
      });

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      expect(gatewayCalled, false, reason: 'Gateway should not be used when disabled');
    });

    test('uses gateway for hashtag feed', () async {
      var gatewayCalled = false;
      final mockClient = MockClient((request) async {
        gatewayCalled = true;
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

      gatewayService = RelayGatewayService(
        gatewayUrl: 'https://gateway.test',
        client: mockClient,
      );

      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        gatewayService: gatewayService,
        gatewaySettings: gatewaySettings,
      );

      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.hashtag,
        hashtags: ['testing'],
        limit: 50,
      );

      expect(gatewayCalled, true, reason: 'Gateway should be used for hashtag feeds');
    });

    test('works without gateway dependencies (null gatewayService)', () async {
      final videoEventService = VideoEventService(
        mockNostrService,
        subscriptionManager: subscriptionManager,
        // No gateway service or settings provided
      );

      // Should not throw - just uses WebSocket
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );

      // Verify WebSocket subscription was created
      verify(mockNostrService.subscribeToEvents(
        filters: anyNamed('filters'),
        bypassLimits: anyNamed('bypassLimits'),
        onEose: anyNamed('onEose'),
      )).called(1);
    });
  });
}
