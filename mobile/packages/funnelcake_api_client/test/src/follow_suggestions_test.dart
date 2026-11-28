import 'dart:async';
import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _ownerPubkey =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _creatorPubkey =
    'c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5';
const _archivePubkey =
    'f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9';
const _previewVideoId =
    'e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13';

void main() {
  group('FunnelcakeApiClient.getFollowSuggestions', () {
    test(
      'encodes opaque cursors and parses active and archived creators',
      () async {
        Uri? requested;
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          httpClient: MockClient((request) async {
            requested = request.url;
            return http.Response(
              jsonEncode({
                'suggestions': [
                  {
                    'pubkey': _creatorPubkey,
                    'profile': {'display_name': 'Creator'},
                    'reason': 'personalized',
                    'is_classic': false,
                    'video_preview': {
                      'id': _previewVideoId,
                      'thumbnail_url': 'https://media.example.test/thumb.jpg',
                    },
                  },
                  {
                    'pubkey': _archivePubkey,
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
          pubkey: _ownerPubkey,
          cursor: 'a +/?=',
          limit: 3,
        );
        expect(requested!.path, '/api/users/$_ownerPubkey/follow-suggestions');
        expect(requested!.queryParameters['cursor'], 'a +/?=');
        expect(requested!.queryParameters['limit'], '3');
        expect(requested!.queryParameters['content_safety'], 'default');
        expect(result.suggestions.first.profile.displayName, 'Creator');
        expect(result.suggestions.first.videoPreview!.id, _previewVideoId);
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
          pubkey: _ownerPubkey,
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
      'retired requests abort immediately without retrying or dispatching',
      () async {
        for (final retireBeforeSigning in [false, true]) {
          var current = !retireBeforeSigning;
          var currentChecks = 0;
          var signatures = 0;
          var requests = 0;
          final client = FunnelcakeApiClient(
            baseUrl: 'https://example.test',
            retryBaseDelay: Duration.zero,
            httpClient: MockClient((_) async {
              requests++;
              return http.Response('{"suggestions": []}', 200);
            }),
          );
          await expectLater(
            client.getFollowSuggestions(
              pubkey: _ownerPubkey,
              isCurrent: () {
                currentChecks++;
                return current;
              },
              requestHeaders: (_) async {
                signatures++;
                current = false;
                return {'Authorization': 'Nostr retired-owner'};
              },
            ),
            throwsA(isA<FunnelcakeException>()),
          );
          // No retry attempts: 1 check when retired before signing, 2 checks
          // (before + after signing on attempt 1) when retired during signing.
          expect(currentChecks, retireBeforeSigning ? 1 : 2);
          expect(signatures, retireBeforeSigning ? 0 : 1);
          expect(requests, 0);
        }
      },
    );

    test(
      'retired signer error aborts immediately without retrying',
      () async {
        var current = true;
        var signatures = 0;
        var requests = 0;
        final client = FunnelcakeApiClient(
          baseUrl: 'https://example.test',
          retryBaseDelay: Duration.zero,
          httpClient: MockClient((_) async {
            requests++;
            return http.Response('{"suggestions": []}', 200);
          }),
        );
        await expectLater(
          client.getFollowSuggestions(
            pubkey: _ownerPubkey,
            isCurrent: () => current,
            requestHeaders: (_) async {
              signatures++;
              current = false;
              throw StateError('retired account');
            },
          ),
          throwsA(isA<FunnelcakeException>()),
        );
        expect(signatures, 1);
        expect(requests, 0);
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
          pubkey: _ownerPubkey,
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
        client.getFollowSuggestions(pubkey: _ownerPubkey),
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
        final page = await client.getFollowSuggestions(pubkey: _ownerPubkey);
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
          client.getFollowSuggestions(pubkey: _ownerPubkey),
          throwsA(isA<FunnelcakeApiException>()),
        );
      },
    );
  });
}
