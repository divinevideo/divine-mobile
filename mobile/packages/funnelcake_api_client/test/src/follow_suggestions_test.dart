import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
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
      expect(result.suggestions.last.isClassic, isTrue);
      expect(result.nextCursor, 'second');
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
}
