import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  const viewer =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const video =
      '2222222222222222222222222222222222222222222222222222222222222222';

  test(
    'posts session context privately and retains the ranked envelope',
    () async {
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v2/videos/classics/recommendations');
          expect(request.url.queryParameters['moderation_profile'], 'default');
          expect(request.headers['X-Pubkey'], viewer);
          expect(request.headers['Cache-Control'], 'no-store');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['seed'], 'session-a');
          expect(body['cursor'], 'opaque');
          expect(body['recent_interactions'], [
            {'video_id': video, 'signal': 'replay'},
          ]);
          expect(body['recent_video_ids'], [video]);
          expect(body['anchor_video_id'], video);
          expect(body['preferred_languages'], ['en']);
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': video,
                  'pubkey': viewer,
                  'created_at': 1,
                  'video_url': 'https://example.com/v.mp4',
                  'platform': 'vine',
                },
              ],
              'pagination': {'next_cursor': 'next', 'has_more': true},
              'source': 'mixed',
            }),
            200,
          );
        }),
      );
      addTearDown(client.dispose);
      final result = await client.getClassicRecommendations(
        userPubkey: viewer,
        request: const ClassicRecommendationsRequest(
          seed: 'session-a',
          cursor: 'opaque',
          anchorVideoId: video,
          recentInteractions: [
            ClassicFeedInteraction(
              videoId: video,
              signal: ClassicFeedSignal.replay,
            ),
          ],
          recentVideoIds: [video],
          preferredLanguages: ['en'],
        ),
      );
      expect(result.videos.single.id, video);
      expect(result.nextCursor, 'next');
      expect(result.source, 'mixed');
    },
  );

  test('anonymous requests omit account identity', () async {
    final client = FunnelcakeApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((request) async {
        expect(
          request.headers.keys.map((v) => v.toLowerCase()),
          isNot(contains('x-pubkey')),
        );
        return http.Response(
          '{"data":[],"pagination":{"has_more":false},"source":"popular"}',
          200,
        );
      }),
    );
    addTearDown(client.dispose);
    final result = await client.getClassicRecommendations(
      request: const ClassicRecommendationsRequest(seed: 'anonymous'),
    );
    expect(result.hasMore, isFalse);
  });

  test('a disabled backend is distinguishable from an empty archive', () async {
    final client = FunnelcakeApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: MockClient((_) async => http.Response('{}', 404)),
    );
    addTearDown(client.dispose);
    await expectLater(
      client.getClassicRecommendations(
        request: const ClassicRecommendationsRequest(seed: 'session'),
      ),
      throwsA(isA<FunnelcakeNotFoundException>()),
    );
  });
}
