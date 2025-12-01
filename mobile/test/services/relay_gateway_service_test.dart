// ABOUTME: Tests for RelayGatewayService REST client
// ABOUTME: Validates filter encoding, response parsing, and error handling

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nostr_sdk/filter.dart' as nostr;
import 'package:openvine/services/relay_gateway_service.dart';

void main() {
  group('RelayGatewayService', () {
    group('query', () {
      test('encodes filter as base64url in URL', () async {
        String? capturedUrl;

        final mockClient = MockClient((request) async {
          capturedUrl = request.url.toString();
          return http.Response(
            jsonEncode({'events': [], 'eose': true, 'complete': true}),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final filter = nostr.Filter(kinds: [1], limit: 10);
        await service.query(filter);

        expect(capturedUrl, contains('https://gateway.test/query?filter='));
        // Verify it's valid base64url
        final filterParam = Uri.parse(capturedUrl!).queryParameters['filter']!;
        final decoded = utf8.decode(base64Url.decode(filterParam));
        final decodedJson = jsonDecode(decoded);
        expect(decodedJson['kinds'], [1]);
        expect(decodedJson['limit'], 10);
      });

      test('parses successful response with events', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'event1',
                  'pubkey': 'pub1',
                  'created_at': 1700000000,
                  'kind': 1,
                  'tags': [],
                  'content': 'test',
                  'sig': 'sig1',
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

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final response = await service.query(nostr.Filter(kinds: [1]));

        expect(response.events.length, 1);
        expect(response.events.first['id'], 'event1');
        expect(response.cached, true);
        expect(response.cacheAgeSeconds, 30);
      });

      test('throws GatewayException on HTTP error', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        expect(
          () => service.query(nostr.Filter(kinds: [1])),
          throwsA(isA<GatewayException>()),
        );
      });

      test('throws GatewayException on network error', () async {
        final mockClient = MockClient((request) async {
          throw http.ClientException('Network error');
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        expect(
          () => service.query(nostr.Filter(kinds: [1])),
          throwsA(isA<GatewayException>()),
        );
      });
    });

    group('getProfile', () {
      test('fetches profile by pubkey', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/profile/testpubkey123');
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'profile1',
                  'pubkey': 'testpubkey123',
                  'created_at': 1700000000,
                  'kind': 0,
                  'tags': [],
                  'content': '{"name":"Test User"}',
                  'sig': 'sig1',
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

        final event = await service.getProfile('testpubkey123');

        expect(event, isNotNull);
        expect(event!['pubkey'], 'testpubkey123');
        expect(event['kind'], 0);
      });

      test('returns null for missing profile', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'events': [], 'eose': true}),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final event = await service.getProfile('nonexistent');

        expect(event, isNull);
      });
    });

    group('getEvent', () {
      test('fetches event by ID', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/event/eventid123');
          return http.Response(
            jsonEncode({
              'events': [
                {
                  'id': 'eventid123',
                  'pubkey': 'pub1',
                  'created_at': 1700000000,
                  'kind': 34236,
                  'tags': [],
                  'content': 'video content',
                  'sig': 'sig1',
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

        final event = await service.getEvent('eventid123');

        expect(event, isNotNull);
        expect(event!['id'], 'eventid123');
      });

      test('returns null for missing event', () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'events': [], 'eose': true}),
            200,
          );
        });

        final service = RelayGatewayService(
          gatewayUrl: 'https://gateway.test',
          client: mockClient,
        );

        final event = await service.getEvent('nonexistent');

        expect(event, isNull);
      });
    });
  });
}
