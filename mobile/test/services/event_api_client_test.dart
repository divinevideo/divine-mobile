// ABOUTME: Tests for EventApiClient REST-first Nostr event publishing
// ABOUTME: Covers 200/401/403/422/5xx classification, NIP-98 wiring, signer match

import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/event_api_client.dart';
import 'package:openvine/services/nip98_auth_service.dart';

class _MockNip98AuthService extends Mock implements Nip98AuthService {}

void main() {
  const testPubkey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';
  const otherPubkey =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  late _MockNip98AuthService mockNip98;

  setUpAll(() {
    registerFallbackValue(HttpMethod.post);
  });

  setUp(() {
    mockNip98 = _MockNip98AuthService();
  });

  Event buildVideoEvent({String pubkey = testPubkey}) {
    return Event(
      pubkey,
      34236,
      const [
        ['d', 'test-video-id'],
        ['title', 'Plants'],
      ],
      'A plant video',
      createdAt: 1700000000,
    );
  }

  Nip98Token buildToken({String signerPubkey = testPubkey}) {
    final signedEvent = Event(
      signerPubkey,
      27235,
      const [
        ['u', 'https://api.divine.video/api/events'],
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

  EventApiClient buildClient(
    http.Client httpClient, {
    String apiBaseUrl = 'https://api.divine.video',
  }) {
    return EventApiClient(
      httpClient: httpClient,
      nip98AuthService: mockNip98,
      apiBaseUrl: () => apiBaseUrl,
    );
  }

  group(EventApiClient, () {
    test('POSTs signed event JSON to {apiBaseUrl}/api/events', () async {
      stubToken(buildToken());
      final event = buildVideoEvent();
      http.Request? captured;
      final client = buildClient(
        MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({'accepted': true, 'event_id': event.id}),
            200,
          );
        }),
      );

      await client.publishEvent(event);

      expect(captured, isNotNull);
      expect(captured!.method, equals('POST'));
      expect(
        captured!.url.toString(),
        equals('https://api.divine.video/api/events'),
      );
      expect(captured!.body, equals(jsonEncode(event.toJson())));
      expect(
        captured!.headers['Authorization'],
        equals('Nostr fake-base64-token'),
      );
    });

    test('requests NIP-98 token for the publish URL, POST, and body', () async {
      stubToken(buildToken());
      final event = buildVideoEvent();
      final client = buildClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'accepted': true, 'event_id': event.id}),
            200,
          ),
        ),
      );

      await client.publishEvent(event);

      final captured = verify(
        () => mockNip98.createAuthToken(
          url: captureAny(named: 'url'),
          method: captureAny(named: 'method'),
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      expect(captured[0], equals('https://api.divine.video/api/events'));
      expect(captured[1], equals(HttpMethod.post));
      expect(captured[2], equals(jsonEncode(event.toJson())));
    });

    test('returns EventApiAccepted on 200 {accepted:true, event_id}', () async {
      stubToken(buildToken());
      final event = buildVideoEvent();
      final client = buildClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'accepted': true, 'event_id': event.id}),
            200,
          ),
        ),
      );

      final result = await client.publishEvent(event);

      expect(result, isA<EventApiAccepted>());
      expect((result as EventApiAccepted).eventId, equals(event.id));
    });

    test('returns transient failure when accepted event_id differs', () async {
      stubToken(buildToken());
      final event = buildVideoEvent();
      final client = buildClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'accepted': true, 'event_id': 'server-event-id'}),
            200,
          ),
        ),
      );

      final result = await client.publishEvent(event);

      expect(result, isA<EventApiTransientFailure>());
    });

    test('returns transient failure on 200 without accepted:true', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient(
          (_) async => http.Response(jsonEncode({'accepted': false}), 200),
        ),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiTransientFailure>());
    });

    test('returns rejected for a restricted accepted:false response', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'accepted': false,
              'message': 'blocked: pubkey is suspended',
            }),
            200,
          ),
        ),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiRejected>());
      expect((result as EventApiRejected).statusCode, 200);
      expect(result.reason, 'blocked: pubkey is suspended');
    });

    test('treats a non-string rejection message as transient', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({'accepted': false, 'message': 42}),
            200,
          ),
        ),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiTransientFailure>());
      expect(
        (result as EventApiTransientFailure).reason,
        startsWith('not_accepted:'),
      );
    });

    for (final status in [401, 403, 422]) {
      test('returns EventApiRejected on $status', () async {
        stubToken(buildToken());
        final client = buildClient(
          MockClient((_) async => http.Response('rejected', status)),
        );

        final result = await client.publishEvent(buildVideoEvent());

        expect(result, isA<EventApiRejected>());
        expect((result as EventApiRejected).statusCode, equals(status));
      });
    }

    test('extracts the relay rejection message from a JSON response', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'accepted': false,
              'message': 'blocked: pubkey is suspended',
            }),
            403,
          ),
        ),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiRejected>());
      expect(
        (result as EventApiRejected).reason,
        'blocked: pubkey is suspended',
      );
    });

    test('returns transient failure on 500', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient((_) async => http.Response('server error', 500)),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiTransientFailure>());
    });

    test('returns transient failure on network error', () async {
      stubToken(buildToken());
      final client = buildClient(
        MockClient((_) async => throw const SocketExceptionStub()),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiTransientFailure>());
    });

    test('returns transient failure on timeout', () async {
      stubToken(buildToken());
      final client = EventApiClient(
        httpClient: MockClient((_) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return http.Response('', 200);
        }),
        nip98AuthService: mockNip98,
        apiBaseUrl: () => 'https://api.divine.video',
        timeout: const Duration(milliseconds: 50),
      );

      final result = await client.publishEvent(buildVideoEvent());

      expect(result, isA<EventApiTransientFailure>());
    });

    test(
      'returns transient failure when NIP-98 token is unavailable',
      () async {
        stubToken(null);
        var requested = false;
        final client = buildClient(
          MockClient((_) async {
            requested = true;
            return http.Response('', 200);
          }),
        );

        final result = await client.publishEvent(buildVideoEvent());

        expect(result, isA<EventApiTransientFailure>());
        expect(requested, isFalse, reason: 'must not POST without a token');
      },
    );

    test(
      'rejects when NIP-98 signer pubkey does not match event pubkey',
      () async {
        stubToken(buildToken(signerPubkey: otherPubkey));
        var requested = false;
        final client = buildClient(
          MockClient((_) async {
            requested = true;
            return http.Response('', 200);
          }),
        );

        final result = await client.publishEvent(buildVideoEvent());

        expect(result, isA<EventApiRejected>());
        expect(
          requested,
          isFalse,
          reason: 'must not POST under a mismatched key',
        );
      },
    );

    test(
      'builds the events URL for a staging base without double slashes',
      () async {
        stubToken(buildToken());
        final event = buildVideoEvent();
        http.Request? captured;
        final client = EventApiClient(
          httpClient: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({'accepted': true, 'event_id': event.id}),
              200,
            );
          }),
          nip98AuthService: mockNip98,
          apiBaseUrl: () => 'https://relay.staging.divine.video',
        );

        await client.publishEvent(event);

        expect(
          captured!.url.toString(),
          equals('https://relay.staging.divine.video/api/events'),
        );
      },
    );

    group('NIP-98 signed URL equals the requested URL', () {
      // The `u` tag is signed from publishUrl while the POST goes to a Uri
      // built from the same base. NIP-98 binds the two and the API compares
      // them as raw strings, so a base that Uri.parse would normalize makes
      // the signed string and the request disagree: the publish 401s while
      // unauthenticated calls to the same host keep working.
      for (final base in const [
        'https://API.divine.video',
        'HTTPS://api.divine.video',
        'https://api.divine.video:443',
        'https://api.divine.video/.',
        'https://api.divine.video/',
      ]) {
        test('for a base of $base', () async {
          stubToken(buildToken());
          final event = buildVideoEvent();
          http.Request? captured;
          final client = buildClient(
            MockClient((request) async {
              captured = request;
              return http.Response(
                jsonEncode({'accepted': true, 'event_id': event.id}),
                200,
              );
            }),
            apiBaseUrl: base,
          );

          await client.publishEvent(event);

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
          // from the client, so alone they would still agree if the signed
          // URL and the request went wrong together.
          expect(signed, equals('https://api.divine.video/api/events'));
        });
      }
    });
  });
}

/// Stand-in for a transport-level failure thrown by the HTTP client.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
