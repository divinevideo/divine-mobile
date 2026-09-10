// ABOUTME: Tests the version-two product analytics HTTP client.
// ABOUTME: Covers signed and anonymous request shapes plus retry classification.

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  final event = <String, Object?>{
    'event_id': 'event-a',
    'schema_version': 2,
    'occurred_at': '2026-08-20T00:00:00.000Z',
    'anonymous_id': '22222222-2222-4222-8222-222222222222',
    'session_id': '33333333-3333-4333-8333-333333333333',
    'source': 'mobile',
    'platform': 'ios',
    'release': '1.2.3',
    'consent_category': 'product_analytics',
    'event_name': 'content_impression_recorded',
    'properties': <String, Object?>{
      'content_id': 'content-a',
      'surface': 'feed',
      'position': 1,
      'visible_ms': 1000,
    },
  };

  late _MockNip98AuthService mockNip98;

  setUpAll(() => registerFallbackValue(HttpMethod.post));
  setUp(() => mockNip98 = _MockNip98AuthService());

  Nip98Token buildToken() {
    final signedEvent = Event(
      testPubkey,
      27235,
      const [
        ['u', 'https://api.divine.video/api/analytics/events'],
        ['method', 'POST'],
      ],
      '',
      createdAt: 1700000000,
    );
    final now = clock.now();
    return Nip98Token(
      token: 'fake-base64-token',
      signedEvent: signedEvent,
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 45)),
    );
  }

  void stubToken(Nip98Token? token) {
    when(
      () => mockNip98.createAuthToken(
        url: any(named: 'url'),
        method: any(named: 'method'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => token);
  }

  AnalyticsIngestClient buildClient(
    http.Client client, {
    String apiBaseUrl = 'https://api.divine.video',
  }) => AnalyticsIngestClient(
    httpClient: client,
    nip98AuthService: mockNip98,
    apiBaseUrl: () => apiBaseUrl,
  );

  group('publishBatch', () {
    test('signed batches put the subject outside version-two events', () async {
      stubToken(buildToken());
      http.Request? captured;
      final client = buildClient(
        MockClient((request) async {
          captured = request;
          return http.Response('{"accepted":true}', 200);
        }),
      );

      final result = await client.publishBatch([
        event,
      ], subjectPubkey: testPubkey);

      expect(result, isA<AnalyticsIngestAccepted>());
      expect(
        captured!.url.toString(),
        'https://api.divine.video/api/analytics/events',
      );
      expect(captured!.headers['Authorization'], 'Nostr fake-base64-token');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['subject_pubkey'], testPubkey);
      expect((body['events'] as List).single, event);
      expect((body['events'] as List).single, isNot(contains('user_pubkey')));
    });
  });

  group('publishAnonymousBatch', () {
    test(
      'anonymous acquisition batches do not request authentication',
      () async {
        http.Request? captured;
        final client = buildClient(
          MockClient((request) async {
            captured = request;
            return http.Response('{"accepted":true}', 202);
          }),
        );

        final result = await client.publishAnonymousBatch([event]);

        expect(result, isA<AnalyticsIngestAccepted>());
        expect(
          captured!.url.toString(),
          'https://api.divine.video/api/analytics/events/anonymous',
        );
        expect(captured!.headers, isNot(contains('Authorization')));
        expect(jsonDecode(captured!.body), {
          'events': [event],
        });
        verifyNever(
          () => mockNip98.createAuthToken(
            url: any(named: 'url'),
            method: any(named: 'method'),
            payload: any(named: 'payload'),
          ),
        );
      },
    );
  });

  group('response handling', () {
    for (final status in [400, 401, 403, 422]) {
      test('drops permanent HTTP $status responses', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => http.Response('bad event', status)),
        );

        final result = await client.publishBatch(
          [event],
          subjectPubkey: testPubkey,
        );

        expect(result, isA<AnalyticsIngestRejected>());
      });
    }

    test('retries HTTP 404 while the ingest endpoint is unavailable', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient((_) async => http.Response('not found', 404)),
      );

      final result = await client.publishBatch(
        [event],
        subjectPubkey: testPubkey,
      );

      expect(result, isA<AnalyticsIngestTransientFailure>());
    });

    for (final status in [408, 429, 500, 503]) {
      test('retries temporary HTTP $status responses', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => http.Response('try again', status)),
        );

        final result = await client.publishBatch(
          [event],
          subjectPubkey: testPubkey,
        );

        expect(result, isA<AnalyticsIngestTransientFailure>());
      });
    }

    test('does not POST a signed batch without a NIP-98 token', () async {
      stubToken(null);
      var requested = false;
      final client = buildClient(
        MockClient((_) async {
          requested = true;
          return http.Response('', 200);
        }),
      );

      final result = await client.publishBatch([
        event,
      ], subjectPubkey: testPubkey);

      expect(result, isA<AnalyticsIngestTransientFailure>());
      expect(requested, isFalse);
    });
  });

  group('NIP-98 signed URL equals the requested URL', () {
    // The `u` tag is signed from the composed string while the POST goes to a
    // Uri built from the same base. NIP-98 binds the two and the ingest API
    // compares them as raw strings, so a base that Uri.parse would normalize
    // makes the signed string and the request disagree, and every signed batch
    // 401s while anonymous batches to the same host keep succeeding.
    for (final base in const [
      'https://API.divine.video',
      'HTTPS://api.divine.video',
      'https://api.divine.video:443',
      'https://api.divine.video/.',
      'https://api.divine.video/',
    ]) {
      test('for a base of $base', () async {
        stubToken(buildToken());
        http.Request? captured;
        final client = buildClient(
          MockClient((request) async {
            captured = request;
            return http.Response('{"accepted":true}', 200);
          }),
          apiBaseUrl: base,
        );

        await client.publishBatch([event], subjectPubkey: testPubkey);

        final signed =
            verify(
                  () => mockNip98.createAuthToken(
                    url: captureAny(named: 'url'),
                    method: any(named: 'method'),
                    payload: any(named: 'payload'),
                  ),
                ).captured.single
                as String;

        expect(signed, equals(captured!.url.toString()));
        // Pins the value as well as the coupling: both operands above come
        // from the client, so alone they would still agree if the signed URL
        // and the request went wrong together.
        expect(signed, equals('https://api.divine.video/api/analytics/events'));
      });
    }
  });
}
