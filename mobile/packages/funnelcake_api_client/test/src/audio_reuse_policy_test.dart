// ABOUTME: Tests the selected-video audio reuse refresh contract.
// ABOUTME: Ensures suppression and lease fields fail closed.

import 'dart:convert';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeUri()));

  late _MockHttpClient httpClient;
  late FunnelcakeApiClient client;
  final pubkey = 'A' * 64;

  setUp(() {
    httpClient = _MockHttpClient();
    client = FunnelcakeApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: httpClient,
      retryBaseDelay: Duration.zero,
    );
  });

  tearDown(() => client.dispose());

  group('refreshAudioReusePolicy', () {
    test(
      'posts the selected coordinate and parses a fresh suppression',
      () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            '{"policies":[{"audio_reuse_suppressed":true}],'
            '"evaluated_at":"2026-09-10T00:00:00Z",'
            '"valid_until":"2026-09-10T00:01:00Z"}',
            200,
          ),
        );

        final policy = await client.refreshAudioReusePolicy(
          kind: 34236,
          pubkey: pubkey,
          dTag: 'Classic-ID',
        );

        expect(policy.audioReuseSuppressed, isTrue);
        expect(policy.validFor, greaterThan(Duration.zero));
        final captured = verify(
          () => httpClient.post(
            captureAny(),
            headers: any(named: 'headers'),
            body: captureAny(named: 'body'),
          ),
        ).captured;
        expect((captured[0] as Uri).path, '/api/videos/audio-reuse/bulk');
        expect(jsonDecode(captured[1] as String), {
          'videos': [
            {
              'kind': 34236,
              'pubkey': pubkey.toLowerCase(),
              'd_tag': 'Classic-ID',
            },
          ],
        });
      },
    );

    test('rejects an expired policy response', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"policies":[{"audio_reuse_suppressed":false}],'
          '"evaluated_at":"2026-09-10T00:01:00Z",'
          '"valid_until":"2026-09-10T00:00:00Z"}',
          200,
        ),
      );

      await expectLater(
        client.refreshAudioReusePolicy(
          kind: 34236,
          pubkey: pubkey,
          dTag: 'classic-id',
        ),
        throwsA(isA<FunnelcakeException>()),
      );
    });

    test('rejects malformed coordinates before making a request', () async {
      await expectLater(
        client.refreshAudioReusePolicy(
          kind: 22,
          pubkey: pubkey,
          dTag: 'classic-id',
        ),
        throwsA(isA<FunnelcakeException>()),
      );
      verifyNever(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });
  });
}
