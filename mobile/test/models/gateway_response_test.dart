// ABOUTME: Tests for GatewayResponse model parsing
// ABOUTME: Validates JSON deserialization from REST gateway responses

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/gateway_response.dart';

void main() {
  group('GatewayResponse', () {
    test('parses complete response with events', () {
      final json = {
        'events': [
          {
            'id': 'event123',
            'pubkey': 'pubkey123',
            'created_at': 1700000000,
            'kind': 1,
            'tags': [],
            'content': 'Hello',
            'sig': 'sig123',
          }
        ],
        'eose': true,
        'complete': true,
        'cached': true,
        'cache_age_seconds': 42,
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.events.length, 1);
      expect(response.events.first['id'], 'event123');
      expect(response.eose, true);
      expect(response.complete, true);
      expect(response.cached, true);
      expect(response.cacheAgeSeconds, 42);
    });

    test('parses response with empty events', () {
      final json = {
        'events': [],
        'eose': true,
        'complete': true,
        'cached': false,
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.events, isEmpty);
      expect(response.cached, false);
      expect(response.cacheAgeSeconds, isNull);
    });

    test('handles missing optional fields', () {
      final json = {
        'events': [],
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.eose, false);
      expect(response.complete, false);
      expect(response.cached, false);
      expect(response.cacheAgeSeconds, isNull);
    });

    test('hasEvents returns true when events present', () {
      final json = {
        'events': [
          {'id': 'test'}
        ],
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.hasEvents, true);
    });

    test('hasEvents returns false when events empty', () {
      final json = {
        'events': [],
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.hasEvents, false);
    });

    test('eventCount returns correct count', () {
      final json = {
        'events': [
          {'id': 'test1'},
          {'id': 'test2'},
          {'id': 'test3'},
        ],
      };

      final response = GatewayResponse.fromJson(json);

      expect(response.eventCount, 3);
    });
  });
}
