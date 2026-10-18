// ABOUTME: Tests that idempotent Funnelcake GETs retry transient failures.
// ABOUTME: Pins that definitive 4xx answers are never retried.

import 'dart:async';
import 'dart:io';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  group('FunnelcakeApiClient GET retry', () {
    late _MockHttpClient httpClient;
    late FunnelcakeApiClient client;

    const baseUrl = 'https://api.example.com';
    const eventId =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    const eventBody =
        '{"event":{"id":"$eventId","pubkey":"$eventId","created_at":1,'
        '"kind":34236,"tags":[],"content":"","sig":""}}';

    setUp(() {
      httpClient = _MockHttpClient();
      client = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: httpClient,
        // Zero backoff keeps the suite fast; the retry policy itself is
        // what these tests pin, not the wall-clock delay.
        retryBaseDelay: Duration.zero,
      );
    });

    test('retries a timed-out GET and returns the retried response', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw TimeoutException('boom');
        }
        return http.Response(eventBody, 200);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNotNull);
      expect(attempts, equals(2));
    });

    test('retries a 503 and returns the retried response', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) return http.Response('upstream down', 503);
        return http.Response(eventBody, 200);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNotNull);
      expect(attempts, equals(2));
    });

    test('retries a dropped connection', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) {
          throw const SocketException('connection reset');
        }
        return http.Response(eventBody, 200);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNotNull);
      expect(attempts, equals(2));
    });

    test('does not retry a 404 — absence is a definitive answer', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        return http.Response('not found', 404);
      });

      final event = await client.getVideoEvent(eventId);

      expect(event, isNull);
      expect(attempts, equals(1));
    });

    test('gives up after the attempt budget and throws', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        throw TimeoutException('still down');
      });

      await expectLater(
        client.getVideoEvent(eventId),
        throwsA(isA<FunnelcakeTimeoutException>()),
      );
      expect(attempts, equals(FunnelcakeApiClient.maxGetAttempts));
    });

    test(
      'spends the timeout budget across attempts, not per attempt',
      () async {
        var attempts = 0;
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async {
          attempts++;
          // Dead air, the shape that costs a full timeout to detect.
          await Future<void>.delayed(const Duration(seconds: 5));
          return http.Response(eventBody, 200);
        });

        final bounded = FunnelcakeApiClient(
          baseUrl: baseUrl,
          httpClient: httpClient,
          timeout: const Duration(milliseconds: 200),
          retryBaseDelay: Duration.zero,
        );

        final elapsed = Stopwatch()..start();
        await expectLater(
          bounded.getVideoEvent(eventId),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
        elapsed.stop();

        // Retrying an attempt that already spent the whole budget would
        // multiply every caller's worst case by maxGetAttempts. Callers await
        // this inline — the login pre-fetch blocks the post-auth redirect on
        // it — so the budget has to bound the call, not each attempt.
        expect(attempts, equals(1));
        expect(elapsed.elapsed, lessThan(const Duration(milliseconds: 600)));
      },
    );

    test('still retries fast failures that leave budget behind', () async {
      var attempts = 0;
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async {
        attempts++;
        if (attempts == 1) throw const SocketException('connection reset');
        return http.Response(eventBody, 200);
      });

      final bounded = FunnelcakeApiClient(
        baseUrl: baseUrl,
        httpClient: httpClient,
        timeout: const Duration(milliseconds: 200),
        retryBaseDelay: Duration.zero,
      );

      // A reset socket costs almost nothing to detect, so bounding the total
      // must not cost the retry that a flaky link actually needs.
      expect(await bounded.getVideoEvent(eventId), isNotNull);
      expect(attempts, equals(2));
    });

    // The app closes the injected client when the client's owner is torn
    // down, which aborts the request in flight (#10291).
    group('after dispose', () {
      late int attempts;
      late Completer<http.Response> firstAttempt;

      setUp(() {
        attempts = 0;
        firstAttempt = Completer<http.Response>();
        when(
          () => httpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) {
          attempts++;
          if (attempts == 1) return firstAttempt.future;
          // What a closed IOClient throws, before any I/O.
          throw http.ClientException(
            'HTTP request failed. Client is already closed.',
          );
        });
      });

      test('does not re-send a GET that dispose cut off', () async {
        final fetching = client.getVideoEvent(eventId);
        await pumpEventQueue();
        expect(attempts, equals(1));

        client.dispose();
        firstAttempt.completeError(
          http.ClientException('Connection closed while receiving data'),
        );

        // The caller sees why the request really ended, not a retry's
        // complaint about the closed client.
        await expectLater(
          fetching,
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Connection closed while receiving data'),
            ),
          ),
        );
        expect(attempts, equals(1));
      });

      test('does not send a GET started after dispose', () async {
        client.dispose();

        await expectLater(
          client.getVideoEvent(eventId),
          throwsA(isA<FunnelcakeException>()),
        );
        expect(attempts, equals(0));
      });
    });
  });
}
