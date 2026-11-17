import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('FunnelcakeApiClient.getFollowSuggestions', () {
    test(
      'encodes opaque cursors and parses active and archived creators',
      () async {
        final pubkey = 'a' * 64;
        Uri? requested;
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            requested = request.url;
            return http.Response(
              jsonEncode({
                'suggestions': [
                  {
                    'pubkey': 'b' * 64,
                    'profile': {'display_name': 'Creator'},
                    'reason': 'personalized',
                    'is_classic': false,
                    'video_preview': {
                      'id': 'd' * 64,
                      'thumbnail_url': 'https://media.example.test/thumb.jpg',
                    },
                  },
                  {
                    'pubkey': 'c' * 64,
                    'profile': {'name': 'Archive'},
                    'reason': 'classic',
                    'is_classic': true,
                  },
                ],
                'next_cursor': 'second',
              }),
              200,
            );
          }),
        );
        final result = await client.getFollowSuggestions(
          pubkey: pubkey,
          cursor: 'a +/?=',
          limit: 3,
        );
        expect(requested!.path, '/api/users/$pubkey/follow-suggestions');
        expect(requested!.queryParameters['cursor'], 'a +/?=');
        expect(requested!.queryParameters['limit'], '3');
        expect(requested!.queryParameters['content_safety'], 'default');
        expect(result.suggestions.first.profile.displayName, 'Creator');
        expect(result.suggestions.first.videoPreview!.id, 'd' * 64);
        expect(
          result.suggestions.first.videoPreview!.thumbnailUrl,
          'https://media.example.test/thumb.jpg',
        );
        expect(result.suggestions.last.isClassic, isTrue);
        expect(result.nextCursor, 'second');
      },
    );

    test(
      'request auth binds the final encoded GET URI on every attempt',
      () async {
        final signed = <Uri>[];
        final requests = <http.Request>[];
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          retryBaseDelay: Duration.zero,
          httpClient: MockClient((request) async {
            requests.add(request);
            if (requests.length == 1) {
              throw http.ClientException('connection interrupted');
            }
            return http.Response('{"suggestions": []}', 200);
          }),
        );
        await client.getFollowSuggestions(
          pubkey: 'a' * 64,
          limit: 500,
          cursor: 'opaque +/?=',
          contentSafety: 'strict',
          requestHeaders: (uri) async {
            signed.add(uri);
            return {'Authorization': 'Nostr attempt-${signed.length}'};
          },
        );
        expect(requests, hasLength(2));
        expect(signed, requests.map((request) => request.url));
        expect(signed.first.queryParameters, {
          'limit': '50',
          'content_safety': 'strict',
          'cursor': 'opaque +/?=',
        });
        expect(requests.map((request) => request.method), ['GET', 'GET']);
        expect(requests.map((request) => request.headers['Authorization']), [
          'Nostr attempt-1',
          'Nostr attempt-2',
        ]);
      },
    );

    test(
      'retired requests never sign or dispatch after the async boundary',
      () async {
        for (final retireBeforeSigning in [false, true]) {
          var current = !retireBeforeSigning;
          var signatures = 0;
          var requests = 0;
          final client = FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            httpClient: MockClient((_) async {
              requests++;
              return http.Response('{"suggestions": []}', 200);
            }),
          );
          await expectLater(
            client.getFollowSuggestions(
              pubkey: 'a' * 64,
              isCurrent: () => current,
              requestHeaders: (_) async {
                signatures++;
                current = false;
                return {'Authorization': 'Nostr retired-owner'};
              },
            ),
            throwsA(isA<FunnelcakeException>()),
          );
          expect(signatures, retireBeforeSigning ? 0 : 1);
          expect(requests, 0);
        }
      },
    );

    test('timed-out signing never dispatches later', () async {
      final signing = Completer<Map<String, String>>();
      var requests = 0;
      final client = FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        timeout: Duration.zero,
        httpClient: MockClient((_) async {
          requests++;
          return http.Response('{"suggestions": []}', 200);
        }),
      );
      await expectLater(
        client.getFollowSuggestions(
          pubkey: 'a' * 64,
          requestHeaders: (_) => signing.future,
        ),
        throwsA(isA<FunnelcakeTimeoutException>()),
      );
      signing.complete({'Authorization': 'Nostr expired-request'});
      // Drain the completed signer's continuation, without a wall-clock bound.
      await Future<void>.delayed(Duration.zero);
      expect(requests, 0);
    });

    test('a policy 503 is surfaced before any successful retry', () async {
      var requests = 0;
      final client = FunnelcakeApiClient(
        baseUrl: 'https://example.test',
        retryBaseDelay: Duration.zero,
        httpClient: MockClient((_) async {
          requests++;
          return requests == 1
              ? http.Response('{}', 503)
              : http.Response('{"suggestions": []}', 200);
        }),
      );
      await expectLater(
        client.getFollowSuggestions(pubkey: 'a' * 64),
        throwsA(
          isA<FunnelcakeApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
      expect(requests, 1);
    });

    test(
      'transport failures still retry within the ordinary read budget',
      () async {
        var requests = 0;
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          retryBaseDelay: Duration.zero,
          httpClient: MockClient((_) async {
            requests++;
            if (requests == 1) {
              throw http.ClientException('connection interrupted');
            }
            return http.Response('{"suggestions": []}', 200);
          }),
        );
        final page = await client.getFollowSuggestions(pubkey: 'a' * 64);
        expect(page.suggestions, isEmpty);
        expect(requests, 2);
      },
    );

    test(
      'propagates unavailable endpoint as an error rather than no people',
      () async {
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((_) async => http.Response('{}', 404)),
        );
        expect(
          client.getFollowSuggestions(pubkey: 'a' * 64),
          throwsA(isA<FunnelcakeApiException>()),
        );
      },
    );
  });
}
