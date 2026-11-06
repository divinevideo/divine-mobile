import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/observability/playback_telemetry_queue.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _Nip98 extends Mock implements Nip98AuthService {}

void main() {
  PlaybackTelemetryQueue queue(http.Client client) => PlaybackTelemetryQueue(
    client: AnalyticsIngestClient(
      httpClient: client,
      nip98AuthService: _Nip98(),
      apiBaseUrl: () => 'https://api.divine.video',
    ),
    platform: 'android',
  );
  void event() => FeedFirstFrameMetrics.start(
    videoId: 'private',
    index: 0,
  ).finish(outcome: FeedPlaybackOutcome.cancelled);

  test(
    'both initialized consent and opt-in are required at activation',
    () async {
      final requests = <http.Request>[];
      final q = queue(
        MockClient((r) async {
          requests.add(r);
          return http.Response('{"accepted":true}', 202);
        }),
      );
      addTearDown(q.dispose);
      q.configure(initializedConsent: false, b2OptIn: true);
      event();
      q.configure(initializedConsent: true, b2OptIn: false);
      event();
      await q.flush();
      expect(requests, isEmpty);
      q.configure(initializedConsent: true, b2OptIn: true);
      event();
      await q.flush();
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['schema'], 'divine.playback.batch.v1');
      expect((body['events'] as List).single['platform'], 'android');
    },
  );

  test('retries preserve event bytes and stop after three failures', () async {
    final bodies = <String>[];
    final q = queue(
      MockClient((r) async {
        bodies.add(r.body);
        return http.Response('', 503);
      }),
    );
    addTearDown(q.dispose);
    q.configure(initializedConsent: true, b2OptIn: true);
    event();
    for (var i = 0; i < 5; i++) {
      await q.flush();
    }
    expect(bodies, hasLength(3));
    expect(bodies.toSet(), hasLength(1));
  });

  test(
    'memory and HTTP batch bounds hold when ingestion is unavailable',
    () async {
      final batches = <List<dynamic>>[];
      final q = queue(
        MockClient((r) async {
          expect(utf8.encode(r.body).length, lessThanOrEqualTo(65536));
          batches.add(
            (jsonDecode(r.body) as Map<String, dynamic>)['events'] as List,
          );
          return http.Response('{"accepted":true}', 202);
        }),
      );
      addTearDown(q.dispose);
      q.configure(initializedConsent: true, b2OptIn: true);
      for (var i = 0; i < 300; i++) {
        event();
      }
      for (var i = 0; i < 6; i++) {
        await q.flush();
      }
      expect(batches, hasLength(4));
      expect(batches.every((b) => b.length == 50), isTrue);
    },
  );

  test(
    'withdrawal and identity reset drop queued and late retry events',
    () async {
      final requests = <String>[];
      final inFlight = Completer<http.Response>();
      final q = queue(
        MockClient((r) async {
          requests.add(r.body);
          return inFlight.future;
        }),
      );
      addTearDown(q.dispose);
      q.configure(initializedConsent: true, b2OptIn: true);
      event();
      final flush = q.flush();
      await Future<void>.delayed(Duration.zero);
      q.configure(initializedConsent: false, b2OptIn: true);
      inFlight.complete(http.Response('', 503));
      await flush;
      q.configure(initializedConsent: true, b2OptIn: true);
      event();
      q.configure(initializedConsent: true, b2OptIn: true, reset: true);
      await q.flush();
      expect(requests, hasLength(1));
    },
  );
}
