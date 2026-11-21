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
  group('FunnelcakeApiClient.getBadgeDiscovery', () {
    test('fetches ranked definitions and clips in one request', () async {
      var calls = 0;
      final transport = MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/badges/discovery');
        expect(request.url.queryParameters, {'limit': '48'});
        return http.Response(
          jsonEncode({
            'badges': [
              {
                'definition': _badge,
                'holder_count': 12,
                'follower_count': 7,
                'videos': [
                  {
                    'id': 'a' * 64,
                    'pubkey': _issuer,
                    'title': 'Clip',
                    'thumbnail': '',
                    'created_at': 1700000000,
                    'kind': 34236,
                    'moderation_labels': ['violence'],
                    'verified_archive': true,
                    'archive_provenance_available': true,
                    'tags': <Object>[],
                  },
                ],
              },
            ],
          }),
          200,
        );
      });
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: transport,
      );
      addTearDown(transport.close);
      addTearDown(client.dispose);
      final result = await client.getBadgeDiscovery();
      expect(calls, 1);
      expect(result.single.definition.toJson(), _badge);
      expect(result.single.holderCount, 12);
      expect(result.single.followerCount, 7);
      final clip = result.single.videos.single;
      expect(clip.id, 'a' * 64);
      expect(clip.moderationLabels, ['violence']);
      expect(clip.verifiedArchive, isTrue);
      expect(clip.archiveProvenanceAvailable, isTrue);
    });

    test('reports the HTTP error after one request', () async {
      var calls = 0;
      final transport = MockClient((_) async {
        calls++;
        return http.Response('', 503);
      });
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: transport,
        retryBaseDelay: Duration.zero,
      );
      addTearDown(transport.close);
      addTearDown(client.dispose);

      await expectLater(
        client.getBadgeDiscovery(),
        throwsA(isA<FunnelcakeApiException>()),
      );
      expect(calls, 1);
    });

    test('transport failures preserve their cause and stack', () async {
      final original = StateError('transport failed');
      final originalStack = StackTrace.fromString('transport-boundary');
      final transport = MockClient(
        (_) async => Error.throwWithStackTrace(original, originalStack),
      );
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: transport,
      );
      addTearDown(client.dispose);
      addTearDown(transport.close);
      try {
        await client.getBadgeDiscovery();
        fail('expected transport failure');
      } on FunnelcakeException catch (error, stackTrace) {
        expect(
          error,
          isA<FunnelcakeException>()
              .having(
                (e) => e.message,
                'message',
                'Failed to fetch badge discovery',
              )
              .having((e) => e.cause, 'cause', same(original)),
        );
        expect(stackTrace.toString(), contains('transport-boundary'));
      }
    });

    for (final timestamp in [-1, 8640000000001]) {
      test('rejects unrepresentable preview timestamp $timestamp', () async {
        final transport = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'badges': [
                {
                  'definition': _badge,
                  'holder_count': 1,
                  'follower_count': 0,
                  'videos': [
                    {
                      'id': 'a' * 64,
                      'pubkey': _issuer,
                      'created_at': timestamp,
                    },
                  ],
                },
              ],
            }),
            200,
          ),
        );
        final client = FunnelcakeApiClient(
          baseUrl: 'https://api.example.com',
          httpClient: transport,
        );
        addTearDown(client.dispose);
        addTearDown(transport.close);
        await expectLater(
          client.getBadgeDiscovery(),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.cause.toString(),
              'cause',
              contains('Invalid badge preview timestamp'),
            ),
          ),
        );
      });
    }

    test('a malformed indexed payload is a typed failure', () async {
      final transport = MockClient(
        (_) async => http.Response('{"badges":[7]}', 200),
      );
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: transport,
      );
      addTearDown(transport.close);
      addTearDown(client.dispose);
      await expectLater(
        client.getBadgeDiscovery(),
        throwsA(isA<FunnelcakeException>()),
      );
    });
  });

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
