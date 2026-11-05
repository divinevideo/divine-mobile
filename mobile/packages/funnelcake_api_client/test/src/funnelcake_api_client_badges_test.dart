import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _issuer =
    '0000000000000000000000000000000000000000000000000000000000000065';
const _badge = <String, dynamic>{
  'id': '0000000000000000000000000000000000000000000000000000000000000066',
  'pubkey': _issuer,
  'created_at': 1700000000,
  'kind': 30009,
  'tags': [
    ['d', 'synthetic-badge'],
    ['name', 'Synthetic badge'],
    ['image', 'https://example.com/badge.png', '80x80'],
    ['custom', 'preserve', 'all', 'values'],
  ],
  'content': 'Badge content',
  'sig':
      '0000000000000000000000000000000000000000000000000000000000000067'
      '0000000000000000000000000000000000000000000000000000000000000068',
};

void main() {
  group('FunnelcakeApiClient.getBadgeDefinitions', () {
    late FunnelcakeApiClient client;
    late MockClient transport;

    void respond(Object? body, {int status = 200}) {
      transport = MockClient(
        (_) async => http.Response(jsonEncode(body), status),
      );
      client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: transport,
        retryBaseDelay: Duration.zero,
      );
    }

    tearDown(() {
      client.dispose();
      transport.close();
    });

    test(
      'fetches complete raw events without dropping signed fields',
      () async {
        transport = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/badges');
          expect(request.url.queryParameters, {
            'issuer': _issuer,
            'limit': '100',
          });
          return http.Response(
            jsonEncode({
              'badges': [_badge],
              'next_cursor': null,
            }),
            200,
          );
        });
        client = FunnelcakeApiClient(
          baseUrl: 'https://api.example.com',
          httpClient: transport,
        );

        final result = await client.getBadgeDefinitions(issuer: _issuer);

        expect(result.badges.single.toJson(), _badge);
        expect(result.nextCursor, isNull);
      },
    );

    test(
      'passes opaque pagination cursors without changing their value',
      () async {
        const cursor = 'opaque+/=?&# badge';
        transport = MockClient((request) async {
          expect(request.url.queryParameters, {
            'issuer': _issuer,
            'limit': '7',
            'cursor': cursor,
          });
          return http.Response(
            jsonEncode({'badges': <Object>[], 'next_cursor': 'next+/='}),
            200,
          );
        });
        client = FunnelcakeApiClient(
          baseUrl: 'https://api.example.com',
          httpClient: transport,
        );

        final result = await client.getBadgeDefinitions(
          issuer: _issuer,
          limit: 7,
          cursor: cursor,
        );

        expect(result.nextCursor, 'next+/=');
      },
    );

    test(
      'returns an authoritative empty page for a valid empty response',
      () async {
        respond({'badges': <Object>[], 'next_cursor': null});

        final result = await client.getBadgeDefinitions(issuer: _issuer);

        expect(result.badges, isEmpty);
        expect(result.nextCursor, isNull);
      },
    );

    test(
      'preserves HTTP 404 as an API failure instead of an empty page',
      () async {
        respond({'error': 'not found'}, status: 404);

        await expectLater(
          client.getBadgeDefinitions(issuer: _issuer),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              404,
            ),
          ),
        );
      },
    );

    final malformedEnvelopes = <String, Object?>{
      'missing next_cursor': {'badges': <Object>[]},
      'missing badges': {'next_cursor': null},
      'non-list badges': {'badges': <String, Object>{}, 'next_cursor': null},
      'non-string cursor': {'badges': <Object>[], 'next_cursor': 123},
      'non-object envelope': <Object>[],
      'non-object event': {
        'badges': [123],
        'next_cursor': null,
      },
      'incomplete event': {
        'badges': [<String, Object>{}],
        'next_cursor': null,
      },
      'missing signature': {
        'badges': [Map<String, dynamic>.of(_badge)..remove('sig')],
        'next_cursor': null,
      },
      'non-integer timestamp': {
        'badges': [
          <String, dynamic>{..._badge, 'created_at': '1700000000'},
        ],
        'next_cursor': null,
      },
      'malformed tags': {
        'badges': [
          <String, dynamic>{
            ..._badge,
            'tags': [
              ['d', 42],
            ],
          },
        ],
        'next_cursor': null,
      },
    };
    for (final entry in malformedEnvelopes.entries) {
      test(
        'rejects ${entry.key} instead of treating it as an empty page',
        () async {
          respond(entry.value);

          await expectLater(
            client.getBadgeDefinitions(issuer: _issuer),
            throwsA(isA<FunnelcakeException>()),
          );
        },
      );
    }

    test('bounds an unanswered request with a typed timeout', () async {
      var requests = 0;
      transport = MockClient((_) {
        requests++;
        return Completer<http.Response>().future;
      });
      client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: transport,
        timeout: const Duration(milliseconds: 20),
        retryBaseDelay: Duration.zero,
      );

      await expectLater(
        client.getBadgeDefinitions(issuer: _issuer),
        throwsA(isA<FunnelcakeTimeoutException>()),
      );
      expect(requests, 1);
    });
  });
}
