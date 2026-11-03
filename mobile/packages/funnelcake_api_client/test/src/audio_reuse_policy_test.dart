// ABOUTME: Tests the selected-video audio reuse refresh contract.
// ABOUTME: Ensures authoritative decision and lease fields fail closed.

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
    test('validates an unknown-video response and returns its denial', () {
      final policy = AudioReusePolicy.fromRefreshJson(const {
        'policies': [
          {
            'video_found': false,
            'verified_archive': false,
            'archive_audio_reuse_enabled': false,
            'audio_reuse_suppressed': false,
            'allow_audio_reuse': false,
          },
        ],
        'evaluated_at': '2026-09-10T00:00:00Z',
        'valid_until': '2026-09-10T00:01:00Z',
      }, elapsed: Duration.zero);

      expect(policy.allowAudioReuse, isFalse);
      expect(policy.videoFound, isFalse);
      expect(policy.audioReuseSuppressed, isFalse);
    });

    test(
      'validates a disabled archive rollout response and returns denial',
      () {
        final policy = AudioReusePolicy.fromRefreshJson(const {
          'policies': [
            {
              'video_found': true,
              'verified_archive': true,
              'archive_audio_reuse_enabled': false,
              'audio_reuse_suppressed': false,
              'allow_audio_reuse': false,
            },
          ],
          'evaluated_at': '2026-09-10T00:00:00Z',
          'valid_until': '2026-09-10T00:01:00Z',
        }, elapsed: Duration.zero);

        expect(policy.allowAudioReuse, isFalse);
      },
    );

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
            '{"policies":[{'
            '"video_found":true,'
            '"verified_archive":true,'
            '"archive_audio_reuse_enabled":true,'
            '"audio_reuse_suppressed":true,'
            '"allow_audio_reuse":false}],'
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

        expect(policy.allowAudioReuse, isFalse);
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
          '{"policies":[{'
          '"video_found":true,'
          '"verified_archive":true,'
          '"archive_audio_reuse_enabled":true,'
          '"audio_reuse_suppressed":false,'
          '"allow_audio_reuse":true}],'
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

    test('rejects a policy missing any authoritative decision field', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          '{"policies":[{"audio_reuse_suppressed":false}],'
          '"evaluated_at":"2026-09-10T00:00:00Z",'
          '"valid_until":"2026-09-10T00:01:00Z"}',
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

  group('refreshAudioReusePolicies', () {
    String policiesJson(List<bool> allowed) => jsonEncode({
      'policies': [
        for (final allow in allowed)
          {
            'video_found': true,
            'verified_archive': false,
            'archive_audio_reuse_enabled': false,
            'audio_reuse_suppressed': false,
            'allow_audio_reuse': allow,
          },
      ],
      'evaluated_at': '2026-09-10T00:00:00Z',
      'valid_until': '2026-09-10T00:01:00Z',
    });

    List<({int kind, String pubkey, String dTag})> videos(int count) => [
      for (var i = 0; i < count; i++)
        (kind: 34236, pubkey: pubkey, dTag: 'v$i'),
    ];

    test('asks for every video in one request and keeps their order', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(policiesJson([true, false, true]), 200),
      );

      final policies = await client.refreshAudioReusePolicies(videos(3));

      expect(policies.map((policy) => policy.allowAudioReuse), [
        true,
        false,
        true,
      ]);
      final body =
          verify(
                () => httpClient.post(
                  any(),
                  headers: any(named: 'headers'),
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as String;
      expect(
        (jsonDecode(body) as Map<String, dynamic>)['videos'],
        [
          for (var i = 0; i < 3; i++)
            {'kind': 34236, 'pubkey': pubkey.toLowerCase(), 'd_tag': 'v$i'},
        ],
      );
    });

    test('splits more videos than the server takes at once', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        final body =
            jsonDecode(invocation.namedArguments[#body] as String)
                as Map<String, dynamic>;
        final asked = (body['videos'] as List).cast<Map<String, dynamic>>();
        // Allowed when the d-tag's number is even, so the order shows.
        return http.Response(
          policiesJson([
            for (final video in asked)
              int.parse((video['d_tag'] as String).substring(1)).isEven,
          ]),
          200,
        );
      });

      final policies = await client.refreshAudioReusePolicies(videos(150));

      expect(policies, hasLength(150));
      expect(
        policies.map((policy) => policy.allowAudioReuse),
        [for (var i = 0; i < 150; i++) i.isEven],
      );
      final sizes =
          verify(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: captureAny(named: 'body'),
            ),
          ).captured.map(
            (body) =>
                ((jsonDecode(body as String) as Map<String, dynamic>)['videos']
                        as List)
                    .length,
          );
      expect(sizes, [
        FunnelcakeApiClient.maxAudioReusePolicySubjects,
        150 - FunnelcakeApiClient.maxAudioReusePolicySubjects,
      ]);
    });

    test('rejects a response holding another number of policies', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response(policiesJson([true]), 200));

      await expectLater(
        client.refreshAudioReusePolicies(videos(2)),
        throwsA(isA<FunnelcakeException>()),
      );
    });

    test('reports a server that cannot decide', () async {
      when(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 503));

      await expectLater(
        client.refreshAudioReusePolicies(videos(2)),
        throwsA(
          isA<FunnelcakeApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            503,
          ),
        ),
      );
    });

    test('asks nothing for no videos', () async {
      expect(await client.refreshAudioReusePolicies(const []), isEmpty);
      verifyNever(
        () => httpClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      );
    });

    test('asks nothing when one coordinate is malformed', () async {
      await expectLater(
        client.refreshAudioReusePolicies([
          ...videos(2),
          (kind: 34236, pubkey: 'not-hex', dTag: 'v2'),
        ]),
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

    test('fails without a configured server', () async {
      final unconfigured = FunnelcakeApiClient(
        baseUrl: '',
        httpClient: httpClient,
      );
      addTearDown(unconfigured.dispose);

      await expectLater(
        unconfigured.refreshAudioReusePolicies(videos(1)),
        throwsA(isA<FunnelcakeNotConfiguredException>()),
      );
    });
  });
}
