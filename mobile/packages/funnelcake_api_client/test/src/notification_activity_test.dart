import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('notification activity', () {
    const update = NotificationActivityUpdate(
      sessionId: 'c8da3021-9bd3-48fb-81e6-4b709a5b86f3',
      sequence: 2,
      visit: 1,
      state: NotificationActivityState.background,
    );

    test('posts the exact signable body and accepts an empty 204', () async {
      late http.Request sent;
      final transport = MockClient((request) async {
        sent = request;
        return http.Response('', 204);
      });
      addTearDown(transport.close);
      final client = FunnelcakeApiClient(
        baseUrl: 'https://api.example.com/',
        httpClient: transport,
      );
      addTearDown(client.dispose);

      await client.recordNotificationActivity(
        update,
        authHeaders: const {'Authorization': 'Nostr signed-request'},
      );

      expect(sent.url, client.notificationActivityUri);
      expect(
        sent.url.toString(),
        'https://api.example.com/api/v2/notifications/activity',
      );
      expect(sent.method, 'POST');
      expect(sent.headers['Authorization'], 'Nostr signed-request');
      expect(sent.headers['Content-Type'], 'application/json');
      expect(sent.body, update.body);
      expect(
        sent.body,
        '{"sessionId":"c8da3021-9bd3-48fb-81e6-4b709a5b86f3",'
        '"sequence":2,"visit":1,"state":"background"}',
      );
    });

    test('rejects every non-204 response so uncertainty can retry', () async {
      for (final status in [200, 400, 401, 503]) {
        final transport = MockClient((_) async => http.Response('', status));
        addTearDown(transport.close);
        final client = FunnelcakeApiClient(
          baseUrl: 'https://api.example.com',
          httpClient: transport,
        );
        addTearDown(client.dispose);
        await expectLater(
          client.recordNotificationActivity(update),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              status,
            ),
          ),
        );
      }
    });
  });
}
