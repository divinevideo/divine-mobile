import 'package:nostr_gateway/src/models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('GatewayResponse', () {
    const testPubkey =
        '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
    const testEventId =
        '0000000000000000000000000000000000000000000000000000000000000000';

    group('fromJson', () {
      test('creates GatewayResponse with all fields', () {
        final json = {
          'events': <Map<String, dynamic>>[
            {
              'id': testEventId,
              'pubkey': testPubkey,
              'created_at': 1234567890,
              'kind': 0,
              'tags': <dynamic>[],
              'content': '{"name":"Test"}',
              'sig': '',
            },
          ],
          'eose': true,
          'complete': true,
          'cached': true,
          'cache_age_seconds': 3600,
        };

        final response = GatewayResponse.fromJson(json);

        expect(response.events, hasLength(1));
        expect(response.events.first.id, equals(testEventId));
        expect(response.eose, isTrue);
        expect(response.complete, isTrue);
        expect(response.cached, isTrue);
        expect(response.cacheAgeSeconds, equals(3600));
      });

      test('creates GatewayResponse with empty events list', () {
        final json = {
          'events': <Map<String, dynamic>>[],
          'eose': false,
          'complete': false,
          'cached': false,
        };

        final response = GatewayResponse.fromJson(json);

        expect(response.events, isEmpty);
        expect(response.eose, isFalse);
        expect(response.complete, isFalse);
        expect(response.cached, isFalse);
        expect(response.cacheAgeSeconds, isNull);
      });

      test('uses default values when fields are missing', () {
        final json = <String, dynamic>{};

        final response = GatewayResponse.fromJson(json);

        expect(response.events, isEmpty);
        expect(response.eose, isFalse);
        expect(response.complete, isFalse);
        expect(response.cached, isFalse);
        expect(response.cacheAgeSeconds, isNull);
      });

      test('handles multiple events', () {
        final json = {
          'events': <Map<String, dynamic>>[
            {
              'id': testEventId,
              'pubkey': testPubkey,
              'created_at': 1234567890,
              'kind': 0,
              'tags': <dynamic>[],
              'content': '{"name":"Event 1"}',
              'sig': '',
            },
            {
              'id':
                  '11111111111111111111111111111111111'
                  '11111111111111111111111111111',
              'pubkey': testPubkey,
              'created_at': 1234567891,
              'kind': 1,
              'tags': <dynamic>[],
              'content': 'Event 2 content',
              'sig': '',
            },
          ],
          'eose': true,
          'complete': true,
          'cached': false,
        };

        final response = GatewayResponse.fromJson(json);

        expect(response.events, hasLength(2));
        expect(response.events.first.kind, equals(0));
        expect(response.events.last.kind, equals(1));
      });

      test('handles null cache_age_seconds', () {
        final json = {
          'events': <Map<String, dynamic>>[],
          'eose': true,
          'complete': true,
          'cached': true,
        };

        final response = GatewayResponse.fromJson(json);

        expect(response.cached, isTrue);
        expect(response.cacheAgeSeconds, isNull);
      });
    });

    group('hasEvents', () {
      test('returns true when events list is not empty', () {
        final response = GatewayResponse(
          events: <Event>[
            Event(
              testPubkey,
              0,
              <dynamic>[],
              'content',
              createdAt: 1234567890,
            ),
          ],
          eose: true,
          complete: true,
          cached: false,
        );

        expect(response.hasEvents, isTrue);
      });

      test('returns false when events list is empty', () {
        const response = GatewayResponse(
          events: <Event>[],
          eose: true,
          complete: true,
          cached: false,
        );

        expect(response.hasEvents, isFalse);
      });
    });

    group('eventCount', () {
      test('returns correct count for single event', () {
        final response = GatewayResponse(
          events: [
            Event(
              testPubkey,
              0,
              [],
              'content',
              createdAt: 1234567890,
            ),
          ],
          eose: true,
          complete: true,
          cached: false,
        );

        expect(response.eventCount, equals(1));
      });

      test('returns correct count for multiple events', () {
        final response = GatewayResponse(
          events: <Event>[
            Event(
              testPubkey,
              0,
              <dynamic>[],
              'content',
              createdAt: 1234567890,
            ),
            Event(
              testPubkey,
              1,
              <dynamic>[],
              'content',
              createdAt: 1234567891,
            ),
            Event(
              testPubkey,
              22,
              <dynamic>[],
              'content',
              createdAt: 1234567892,
            ),
          ],
          eose: true,
          complete: true,
          cached: false,
        );

        expect(response.eventCount, equals(3));
      });

      test('returns zero for empty events list', () {
        const response = GatewayResponse(
          events: <Event>[],
          eose: true,
          complete: true,
          cached: false,
        );

        expect(response.eventCount, equals(0));
      });
    });
  });
}
