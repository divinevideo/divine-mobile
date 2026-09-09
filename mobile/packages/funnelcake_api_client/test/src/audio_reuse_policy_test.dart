// ABOUTME: Tests the content-addressed audio reuse policy endpoint contract.
// ABOUTME: Ensures suppression fields are strict and hashes are normalized.

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
  final hash = 'A' * 64;

  setUp(() {
    httpClient = _MockHttpClient();
    client = FunnelcakeApiClient(
      baseUrl: 'https://api.example.com',
      httpClient: httpClient,
      retryBaseDelay: Duration.zero,
    );
  });

  tearDown(() => client.dispose());

  group('getAudioReusePolicy', () {
    test('parses the authoritative policy and normalizes the hash', () async {
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          '{"allow_audio_reuse":false,"audio_reuse_suppressed":true}',
          200,
        ),
      );

      final policy = await client.getAudioReusePolicy(hash);

      expect(policy.allowAudioReuse, isFalse);
      expect(policy.audioReuseSuppressed, isTrue);
      final uri =
          verify(
                () => httpClient.get(
                  captureAny(),
                  headers: any(named: 'headers'),
                ),
              ).captured.single
              as Uri;
      expect(
        uri.path,
        '/api/videos/by-sha256/${hash.toLowerCase()}/audio-reuse',
      );
    });

    test('rejects malformed policy responses', () async {
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response('{"allow_audio_reuse":true}', 200),
      );

      await expectLater(
        client.getAudioReusePolicy(hash),
        throwsA(isA<FunnelcakeException>()),
      );
    });

    test('rejects a malformed hash before making a request', () async {
      await expectLater(
        client.getAudioReusePolicy('not-a-hash'),
        throwsA(isA<FunnelcakeException>()),
      );
      verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
    });
  });
}
