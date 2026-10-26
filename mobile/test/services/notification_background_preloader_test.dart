import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/notification_background_preloader.dart';

void main() {
  final author = 'a' * 64;
  final eventId = 'b' * 64;
  final otherAuthor = 'c' * 64;
  const thumbnail = 'https://example.com/thumbnail.jpg';

  for (final matchesAuthor in [true, false]) {
    test(
      'background thumbnail warming validates the coordinate author: $matchesAuthor',
      () async {
        final requests = <Uri>[];
        final cached = <String>[];
        final transport = MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'event': {
                'id': eventId,
                'pubkey': matchesAuthor ? author : otherAuthor,
                'created_at': 1735689600,
                'kind': 34236,
                'tags': [
                  ['d', 'synthetic-video'],
                  ['url', 'https://example.com/video.mp4'],
                  ['thumb', thumbnail],
                ],
                'content': 'Synthetic notification video',
                'sig': 'd' * 128,
              },
            }),
            200,
          );
        });
        final api = FunnelcakeApiClient(
          baseUrl: 'https://example.com',
          httpClient: transport,
        );
        addTearDown(transport.close);
        await preloadBackgroundNotification(
          {
            'type': 'like',
            'referencedAddress': '34236:$author:synthetic-video',
          },
          apiClient: api,
          cacheThumbnail: (url) async {
            cached.add(url);
          },
        );
        expect(requests, [
          Uri.parse('https://example.com/api/videos/synthetic-video'),
        ]);
        expect(cached, matchesAuthor ? [thumbnail] : isEmpty);
      },
    );
  }

  test(
    'private and unsupported notifications cause no background requests',
    () async {
      var requests = 0;
      final transport = MockClient((request) async {
        requests++;
        return http.Response('', 500);
      });
      final api = FunnelcakeApiClient(
        baseUrl: 'https://example.com',
        httpClient: transport,
      );
      addTearDown(transport.close);
      for (final type in ['directMessage', 'campaign', 'unknown']) {
        await preloadBackgroundNotification({
          'type': type,
          'eventId': eventId,
        }, apiClient: api);
      }
      expect(requests, 0);
    },
  );
}
